import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/config/remote_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/api_result.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/otp_session.dart';
import '../../auth/state/auth_state.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/gritty_background.dart';
import '../../../shared/widgets/primitives.dart';

/// v1 screen 04 — Verify OTP. Back tile, "Verify your number" header, the
/// destination number, equal-width OTP boxes, a resend countdown and a
/// ghost-gold Verify & continue CTA.
///
/// The backend issues 6-digit codes, so this uses 6 boxes rather than the
/// prototype's 4-box demo fixture.
class VerifyOTPScreen extends StatefulWidget {
  const VerifyOTPScreen({super.key});

  @override
  State<VerifyOTPScreen> createState() => _VerifyOTPScreenState();
}

class _VerifyOTPScreenState extends State<VerifyOTPScreen>
    with TickerProviderStateMixin {
  /// Box count and resend window both come from the backend that issues the
  /// code. Hardcoding them here meant a server-side change to either one
  /// would have shipped a screen that disagrees with the code it is
  /// verifying.
  late final int otpLength = config
      .number('defaultSettings.otpLength', fallback: 6)
      .toInt()
      .clamp(4, 8);

  /// Fallback cooldown, used only until the server tells us the real one.
  /// `defaultSettings.otpExpirySeconds` is deliberately *not* used here —
  /// that is how long a code stays valid (300s), not how long you must wait
  /// before requesting another (60s). Conflating them showed a five-minute
  /// countdown on a one-minute cooldown.
  static const int _defaultResendSeconds = 60;

  late final List<TextEditingController> _controllers = List.generate(
    otpLength,
    (_) => TextEditingController(),
  );
  late final List<FocusNode> _focusNodes = List.generate(
    otpLength,
    (_) => FocusNode(),
  );
  late final List<FocusNode> _keyFocusNodes = List.generate(
    otpLength,
    (_) => FocusNode(),
  );

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  String _error = '';

  /// Set once the backend refuses further attempts on this request. The
  /// only way forward is a new code, so Verify is disabled until one is
  /// requested.
  bool _isLocked = false;
  int _timer = _defaultResendSeconds;
  bool _argsRead = false;
  Timer? _countdownTimer;
  late String _phone;
  late String _requestId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    LoggerService.info('Initializing OTP screen...');

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 12.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -12.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 8.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.linear));

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;

    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    _phone = args?['phoneNumber'] as String? ?? '';
    _requestId = args?['requestId'] as String? ?? '';

    // Arriving on a code that was already sent: start the countdown at the
    // server's remaining cooldown instead of a fresh minute, so the Resend
    // control unlocks exactly when the backend will honour it.
    final retryAfter = args?['retryAfter'] as int?;
    _startTimer(seconds: retryAfter);

    if (args?['alreadySent'] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('We already sent you a code — enter it below.'),
            backgroundColor: AppColors.teal,
          ),
        );
      });
    }
  }

  /// Starts the resend countdown. [seconds] is the server's `retryAfter`
  /// when it gave us one; otherwise the local fallback.
  void _startTimer({int? seconds}) {
    _countdownTimer?.cancel();
    final start = (seconds ?? _defaultResendSeconds).clamp(0, 900);
    setState(() => _timer = start);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_timer <= 0) {
        t.cancel();
      } else {
        setState(() => _timer--);
      }
    });
  }

  void _handleInput(String text, int index) {
    if (text.isNotEmpty) {
      final digit = text.replaceAll(RegExp(r'\D'), '').split('').last;
      _controllers[index].text = digit;
      if (index < otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _verifyOtp();
      }
    }
  }

  void _handleKeyEvent(KeyEvent event, int index) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  void _verifyOtp() async {
    if (_isLoading) return;
    final code = _controllers.map((c) => c.text).join();
    if (code.length < otpLength) {
      setState(() => _error = 'Please enter the $otpLength-digit OTP.');
      _shakeController.forward(from: 0.0);
      return;
    }

    LoggerService.info('Verifying OTP code: $code');
    setState(() {
      _error = '';
      _isLoading = true;
    });

    final result = await ApiService.verifyOtp(_requestId, code);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.ok) {
      setState(() => _error = _verifyError(result));
      _shakeController.forward(from: 0.0);
      // A wrong code should be easy to correct: clear the boxes and put the
      // caret back at the start instead of making the user backspace six
      // times.
      if (!_isLocked) {
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes.first.requestFocus();
      }
      return;
    }

    // The code has been spent; a later Continue must request a fresh one.
    OtpSession.clear();

    final data = result.data ?? const <String, dynamic>{};
    final isNewUser = data['isNewUser'] == true;
    final displayName = data['displayName'] as String?;
    final phoneNumber = (data['phoneNumber'] as String?) ?? _phone;

    if (isNewUser) {
      Navigator.pushReplacementNamed(
        context,
        '/create-profile',
        arguments: phoneNumber,
      );
      return;
    }

    final authState = Provider.of<AuthState>(context, listen: false);
    final name = (displayName == null || displayName.isEmpty)
        ? 'User'
        : displayName;
    await authState.saveProfile(
      ProfileData(
        name: name,
        username: name,
        dob: '',
        email: '',
        phone: phoneNumber,
        avatarColorIndex: 0,
        initials: name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase(),
      ),
    );
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  /// Turns a failed verification into something actionable.
  ///
  /// The backend reports how many tries are left (`data.remainingAttempts`)
  /// and flags the lockout with `code: MAX_ATTEMPTS`. Saying only "Invalid
  /// OTP code" hid both, so the request could lock with no warning that it
  /// was about to.
  String _verifyError(ApiResult<Map<String, dynamic>> result) {
    if (result.code == 'MAX_ATTEMPTS') {
      _isLocked = true;
      return result.display('Too many incorrect attempts. Request a new code.');
    }

    final remaining = result.data?['remainingAttempts'];
    if (remaining is int) {
      if (remaining <= 0) {
        _isLocked = true;
        return result.display(
          'Too many incorrect attempts. Request a new code.',
        );
      }
      return '${result.display('Incorrect code.')} '
          '$remaining attempt${remaining == 1 ? '' : 's'} left.';
    }

    return result.display('That code was not accepted. Please try again.');
  }

  void _handleResend() async {
    if (_isLoading || _timer > 0) return;
    for (var controller in _controllers) {
      controller.clear();
    }
    setState(() {
      _error = '';
      _isLoading = true;
    });

    final result = await ApiService.resendOtp(_requestId);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.canProceed) {
      setState(
        () => _error = result.message ?? 'Failed to resend OTP. Try again.',
      );
      return;
    }

    _requestId = result.requestId!;
    // A resend issues a new id; record it so backing out to login and
    // pressing Continue reuses this one rather than the superseded id.
    OtpSession.remember(
      phone: _phone,
      requestId: _requestId,
      expiresInSeconds: result.expiresIn,
    );
    _startTimer(seconds: result.retryAfter);
    _focusNodes[0].requestFocus();

    if (result.sentNow) {
      LoggerService.info('OTP resent. requestId: $_requestId');
    } else {
      // Throttled: the previous code is still live, so say that rather than
      // claiming a failure the user cannot act on.
      LoggerService.info('Resend throttled: ${result.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Your previous code is still valid.'),
          backgroundColor: AppColors.teal,
        ),
      );
    }
  }

  bool _isFilled() => _controllers.every((c) => c.text.isNotEmpty);

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _shakeController.dispose();
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var node in _keyFocusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// The phone arrives in E.164 (`+919876543210`). Rendering it grouped
  /// keeps it readable without re-adding a country code that is already
  /// there — the previous version printed "+91" twice.
  String get _displayPhone {
    final digits = _phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      final local = digits.substring(2);
      return '+91 ${local.substring(0, 5)} ${local.substring(5)}';
    }
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return _phone;
  }

  String get _resendLabel {
    final m = _timer ~/ 60;
    final s = _timer % 60;
    return 'RESEND IN $m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool filled = _isFilled();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GrittyBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 20, 26, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(
                  icon: PhosphorIconsRegular.arrowLeft,
                  iconSize: 17,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Verify your number',
                  style: AppText.sans(
                    27,
                    weight: FontWeight.w500,
                    color: AppColors.text,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text.rich(
                  TextSpan(
                    style: AppText.sans(13, color: AppColors.textDim),
                    children: [
                      const TextSpan(text: 'Code sent to '),
                      TextSpan(
                        text: _displayPhone,
                        style: AppText.mono(13, ls: 0, c: AppColors.text),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: child,
                  ),
                  child: Row(
                    children: List.generate(otpLength, (i) {
                      final bool hasText = _controllers[i].text.isNotEmpty;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: i == otpLength - 1 ? 0 : AppSpacing.mdLg,
                          ),
                          child: KeyboardListener(
                            focusNode: _keyFocusNodes[i],
                            onKeyEvent: (event) => _handleKeyEvent(event, i),
                            child: Container(
                              height: 62,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.card,
                                ),
                                border: Border.all(
                                  color: _error.isNotEmpty
                                      ? AppColors.destructive
                                      : (hasText
                                            ? AppColors.gold
                                            : AppColors.border),
                                ),
                              ),
                              child: TextField(
                                controller: _controllers[i],
                                focusNode: _focusNodes[i],
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                showCursor: true,
                                cursorColor: AppColors.gold,
                                style: AppText.mono(
                                  24,
                                  ls: 0,
                                  w: FontWeight.w700,
                                  c: AppColors.text,
                                ),
                                decoration: const InputDecoration(
                                  counterText: '',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (text) => _handleInput(text, i),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      _error,
                      style: AppText.sans(12, color: AppColors.destructive),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MonoLabel(
                        _timer > 0 ? _resendLabel : 'DIDN\'T GET THE CODE?',
                        size: 10.5,
                        letterSpacing: 1.2,
                        color: AppColors.textFaint,
                      ),
                      GestureDetector(
                        onTap: _timer == 0 ? _handleResend : null,
                        child: Text(
                          'Resend OTP',
                          style: AppText.sans(
                            12,
                            color: _timer == 0
                                ? AppColors.gold
                                : AppColors.textGhost,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                GoldButton(
                  label: 'Verify & continue',
                  icon: PhosphorIconsRegular.arrowRight,
                  enabled: filled && !_isLocked,
                  loading: _isLoading,
                  onTap: _verifyOtp,
                ),
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: Text(
                    config.text('auth.otpHelperText'),
                    textAlign: TextAlign.center,
                    style: AppText.sans(
                      11.5,
                      color: AppColors.textFaint,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

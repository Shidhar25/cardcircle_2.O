import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../core/config/remote_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/otp_session.dart';
import '../../../core/services/pending_invite.dart';
import '../../../shared/widgets/gritty_background.dart';
import '../../../shared/widgets/legal_text.dart';
import '../../../shared/widgets/primitives.dart';

/// v1 screen 03 — Login. Gold icon tile, "Welcome to CardCircle"
/// headline, a mobile number field with a +91 prefix and a check glyph once
/// valid, and a ghost-gold Continue CTA.
///
/// Phone + OTP is the only route in. The social buttons the prototype drew
/// are removed rather than hidden: there is no Google/Apple token exchange
/// on the backend, so they were a dead control. The server's
/// `features.socialLogin` is false today; if it is ever turned on, the
/// buttons come back with a real handler behind them, not just a flag.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  String _errorText = '';
  bool _isLoading = false;

  /// The token an invite link stashed before this screen opened, peeked
  /// (not consumed) so unchecking the box below and re-checking it can
  /// restore exactly what was pending — see [_onInviteCheckboxChanged].
  String? _pendingInviteToken;
  String? _invitedByName;

  /// Whether the "Invited by ..." box is ticked. Starts true: arriving via
  /// an invite link is itself the signal that following the inviter back
  /// is wanted, so the default matches that intent rather than making
  /// every new sign-up opt in again to something they already asked for
  /// by tapping the link.
  bool _followInviteChecked = true;

  @override
  void initState() {
    super.initState();

    _pendingInviteToken = PendingInvite.peekToken();
    _invitedByName = PendingInvite.inviterName;

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 8.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.linear));

    _phoneController.addListener(() {
      final text = _phoneController.text;
      final cleanText = text.replaceAll(RegExp(r'\D'), '');
      if (text != cleanText) {
        _phoneController.value = TextEditingValue(
          text: cleanText,
          selection: TextSelection.collapsed(offset: cleanText.length),
        );
      }
      if (_errorText.isNotEmpty) setState(() => _errorText = '');
      setState(() {});
    });
  }

  bool _isValidPhone() =>
      RegExp(r'^[6-9]\d{9}$').hasMatch(_phoneController.text.trim());

  Future<void> _handleContinue() async {
    if (_isLoading) return;
    if (!_isValidPhone()) {
      setState(() => _errorText = 'Enter a valid Indian mobile number.');
      _shakeController.forward(from: 0.0);
      return;
    }

    setState(() {
      _errorText = '';
      _isLoading = true;
    });

    final formattedPhone = '+91${_phoneController.text}';

    // Still holding a live code for this exact number? Go straight to it
    // rather than asking for another one the server will only refuse.
    final remembered = OtpSession.idFor(formattedPhone);
    if (remembered != null) {
      setState(() => _isLoading = false);
      _openOtpScreen(formattedPhone, remembered, alreadySent: true);
      return;
    }

    final result = await ApiService.sendOtp(formattedPhone, 'LOGIN');

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.canProceed) {
      OtpSession.remember(
        phone: formattedPhone,
        requestId: result.requestId!,
        expiresInSeconds: result.expiresIn,
      );
      _openOtpScreen(formattedPhone, result.requestId!);
      return;
    }

    setState(
      () => _errorText =
          result.message ?? 'Could not send the code. Please try again.',
    );
    _shakeController.forward(from: 0.0);
  }

  /// Ticking the box back on only works because [_pendingInviteToken] was
  /// peeked (not consumed) in [initState] — [PendingInvite] itself was
  /// already cleared the instant the box was unchecked, so without a local
  /// copy there would be nothing left to remember back.
  void _onInviteCheckboxChanged(bool checked) {
    setState(() => _followInviteChecked = checked);
    final token = _pendingInviteToken;
    if (token == null) return;
    if (checked) {
      PendingInvite.remember(token, inviterName: _invitedByName);
    } else {
      PendingInvite.clear();
    }
  }

  void _openOtpScreen(
    String phone,
    String requestId, {
    bool alreadySent = false,
  }) {
    Navigator.pushNamed(
      context,
      '/verify-otp',
      arguments: {
        'phoneNumber': phone,
        'requestId': requestId,
        'alreadySent': alreadySent,
      },
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool valid = _isValidPhone();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GrittyBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 20, 26, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3B2F16), AppColors.background],
                    ),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Icon(
                    PhosphorIconsRegular.circlesThree,
                    size: 23,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text.rich(
                  TextSpan(
                    style: AppText.sans(
                      31,
                      weight: FontWeight.w500,
                      color: AppColors.text,
                      letterSpacing: -0.8,
                      height: 1.15,
                    ),
                    children: const [
                      TextSpan(text: 'Welcome to\nCard'),
                      TextSpan(
                        text: 'Circle',
                        style: TextStyle(color: AppColors.gold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  config.text('auth.loginSubtitle'),
                  style: AppText.sans(
                    13.5,
                    color: AppColors.textDim,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                const MonoLabel(
                  'MOBILE NUMBER',
                  size: 9.5,
                  letterSpacing: 1.6,
                  color: AppColors.textFaint,
                ),
                const SizedBox(height: AppSpacing.sm),
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: child,
                    );
                  },
                  child: OutlinedSurface(
                    borderColor: _errorText.isNotEmpty
                        ? AppColors.destructive
                        : AppColors.border,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: SizedBox(
                      height: 54,
                      child: Row(
                        children: [
                          Text(
                            '+91',
                            style: AppText.mono(14, ls: 0, c: AppColors.text),
                          ),
                          const SizedBox(width: AppSpacing.mdLg),
                          Container(
                            width: 1,
                            height: 22,
                            color: AppColors.border,
                          ),
                          const SizedBox(width: AppSpacing.mdLg),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              focusNode: _focusNode,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              autofocus: true,
                              style: AppText.mono(
                                15,
                                ls: 1.2,
                                c: AppColors.text,
                              ),
                              decoration: InputDecoration(
                                hintText: '98765 43210',
                                hintStyle: AppText.mono(
                                  15,
                                  ls: 1.2,
                                  c: AppColors.textGhost,
                                ),
                                counterText: '',
                                border: InputBorder.none,
                                isCollapsed: true,
                              ),
                            ),
                          ),
                          if (valid)
                            const Icon(
                              PhosphorIconsFill.checkCircle,
                              size: 19,
                              color: AppColors.teal,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_errorText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      _errorText,
                      style: AppText.sans(12, color: AppColors.destructive),
                    ),
                  ),
                if (_pendingInviteToken != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _InviteCheckbox(
                    name: _invitedByName,
                    checked: _followInviteChecked,
                    onChanged: _onInviteCheckboxChanged,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                GoldButton(
                  label: 'Continue',
                  icon: PhosphorIconsRegular.arrowRight,
                  enabled: valid,
                  loading: _isLoading,
                  onTap: _handleContinue,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxxl),
                  child: LegalText(
                    text: config.text('auth.legalFooter'),
                    size: 11,
                    color: AppColors.textFaint,
                    align: TextAlign.center,
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

/// "Invited by ..." — shown only when an invite link brought the visitor
/// here (see [PendingInvite]). Ticked by default: tapping the invite link
/// already expressed the intent to follow that person, so this is a place
/// to back out of it, not a consent step someone has to actively opt into.
class _InviteCheckbox extends StatelessWidget {
  final String? name;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _InviteCheckbox({
    required this.name,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!checked),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: checked ? AppColors.gold : Colors.transparent,
              border: Border.all(
                color: checked ? AppColors.gold : AppColors.border,
                width: 1.4,
              ),
            ),
            child: checked
                ? const Icon(
                    PhosphorIconsBold.check,
                    size: 12,
                    color: AppColors.background,
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                name == null
                    ? 'Invited by a friend — follow them back once you join.'
                    : 'Invited by $name — follow them back once you join.',
                style: AppText.sans(12.5, color: AppColors.textDim),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

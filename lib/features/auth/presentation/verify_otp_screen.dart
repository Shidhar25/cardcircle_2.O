import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/api_service.dart';
import '../../auth/state/auth_state.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/mascot_character.dart';

class VerifyOTPScreen extends StatefulWidget {
  const VerifyOTPScreen({super.key});

  @override
  State<VerifyOTPScreen> createState() => _VerifyOTPScreenState();
}

class _VerifyOTPScreenState extends State<VerifyOTPScreen>
    with TickerProviderStateMixin {
  static const int otpLength = 6;
  static const int resendSeconds = 60;

  final List<TextEditingController> _controllers =
      List.generate(otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(otpLength, (_) => FocusNode());

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  late AnimationController _successController;
  late Animation<double> _successScale;

  int _activeIndex = 0;
  String _error = '';
  int _timer = resendSeconds;
  Timer? _countdownTimer;
  String _mood = 'idle';
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

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _successScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _successController, curve: Curves.bounceOut));

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _focusNodes[0].requestFocus();
      }
    });

    _startTimer();

    for (int i = 0; i < otpLength; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) {
          setState(() {
            _activeIndex = i;
          });
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>?;
    _phone = args?['phoneNumber'] ?? '+91 98765 43210';
    _requestId = args?['requestId'] ?? '';
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _timer = resendSeconds;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_timer <= 0) {
        t.cancel();
      } else {
        setState(() {
          _timer--;
        });
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

  void _handleKeyPress(RawKeyEvent event, int index) {
    if (event is RawKeyDownEvent &&
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
      setState(() {
        _error = 'Please enter the 6-digit OTP.';
      });
      _shakeController.forward(from: 0.0);
      return;
    }

    LoggerService.info('Verifying OTP code: $code');
    setState(() {
      _error = '';
      _isLoading = true;
      _mood = 'celebrate';
    });

    final response = await ApiService.verifyOtp(_requestId, code);
    setState(() {
      _isLoading = false;
    });

    if (response != null) {
      final isNewUser = response['isNewUser'] ?? false;
      final displayName = response['displayName'];
      final phoneNumber = response['phoneNumber'] ?? _phone;
      if (!mounted) return;
      final authState = Provider.of<AuthState>(context, listen: false);

      _successController.forward(from: 0.0).then((_) {
        Future.delayed(const Duration(milliseconds: 600), () async {
          if (mounted) {
            if (isNewUser) {
              Navigator.pushReplacementNamed(
                context,
                '/create-profile',
                arguments: phoneNumber,
              );
            } else {
              final profile = ProfileData(
                name: displayName ?? 'User',
                username: displayName ?? 'user',
                dob: '',
                email: '',
                phone: phoneNumber,
                avatarColorIndex: 0,
                initials: (displayName != null && displayName.isNotEmpty)
                    ? displayName.substring(0, (displayName.length >= 2) ? 2 : 1).toUpperCase()
                    : 'US',
              );
              await authState.saveProfile(profile);
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/home');
              }
            }
          }
        });
      });
    } else {
      setState(() {
        _error = 'Invalid OTP code. Please try again.';
        _mood = 'sad';
      });
      _shakeController.forward(from: 0.0);
    }
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

    final response = await ApiService.resendOtp(_requestId);
    setState(() {
      _isLoading = false;
    });

    if (response != null && response['requestId'] != null) {
      _requestId = response['requestId'];
      _startTimer();
      _focusNodes[0].requestFocus();
      LoggerService.info('OTP resent successfully. New requestId: $_requestId');
    } else {
      setState(() {
        _error = 'Failed to resend OTP. Please try again.';
      });
    }
  }

  bool _isFilled() {
    return _controllers.every((c) => c.text.isNotEmpty);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _shakeController.dispose();
    _successController.dispose();
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool filled = _isFilled();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Text(
                    '← Back',
                    style: TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    ScaleTransition(
                      scale: _successScale,
                      child: MascotCharacter(
                        size: 150,
                        mood: _mood,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Verify your number',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        text: 'We sent a 6-digit code to\n',
                        style: const TextStyle(
                          color: AppColors.mutedForeground,
                          fontSize: 15,
                          height: 1.6,
                        ),
                        children: [
                          TextSpan(
                            text: _phone,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(otpLength, (i) {
                              final bool hasText = _controllers[i].text.isNotEmpty;
                              final bool isActive = i == _activeIndex;
                              return RawKeyboardListener(
                                focusNode: FocusNode(),
                                onKey: (event) => _handleKeyPress(event, i),
                                child: Container(
                                  width: 48,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: AppColors.card,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _error.isNotEmpty
                                          ? const Color(0xFFFF4757)
                                          : (hasText
                                              ? AppColors.primary
                                              : (isActive
                                                  ? AppColors.primary.withValues(alpha: 0.5)
                                                  : AppColors.border)),
                                      width: (hasText || isActive || _error.isNotEmpty) ? 2.0 : 1.0,
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
                                    cursorColor: AppColors.primary,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    decoration: const InputDecoration(
                                      counterText: '',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (text) => _handleInput(text, i),
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      },
                    ),
                    if (_error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _error,
                          style: const TextStyle(
                            color: Color(0xFFFF4757),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      'Demo: enter any 6 digits to continue',
                      style: TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: filled
                            ? const LinearGradient(
                                colors: [Color(0xFF00D4FF), Color(0xFF0099CC)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              )
                            : null,
                        color: filled ? null : const Color(0xFF21262D),
                      ),
                      child: ElevatedButton(
                        onPressed: _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 19),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          'Verify OTP',
                          style: TextStyle(
                            color: filled ? const Color(0xFF050505) : AppColors.mutedForeground,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _timer == 0 ? _handleResend : null,
                      child: Text(
                        _timer > 0 ? 'Resend OTP in ${_timer}s' : 'Resend OTP',
                        style: TextStyle(
                          color: _timer == 0 ? AppColors.primary : AppColors.mutedForeground,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

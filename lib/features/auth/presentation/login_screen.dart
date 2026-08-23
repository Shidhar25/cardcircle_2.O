import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/widgets/neo_pop_button.dart';
import '../../../shared/widgets/mascot_character.dart';
import '../../../shared/widgets/gritty_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  bool _isFocused = false;
  String _errorText = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

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

    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });

    _phoneController.addListener(() {
      final text = _phoneController.text;
      final cleanText = text.replaceAll(RegExp(r'\D'), '');
      if (text != cleanText) {
        _phoneController.value = TextEditingValue(
          text: cleanText,
          selection: TextSelection.collapsed(offset: cleanText.length),
        );
      }
      if (_errorText.isNotEmpty) {
        setState(() {
          _errorText = '';
        });
      }
      setState(() {});
    });
  }

  void _triggerShake() {
    _shakeController.forward(from: 0.0);
  }

  bool _isValidPhone() {
    final phone = _phoneController.text.trim();
    return RegExp(r'^[6-9]\d{9}$').hasMatch(phone);
  }

  void _handleContinue() async {
    if (_isLoading) return;
    if (!_isValidPhone()) {
      setState(() {
        _errorText = 'Enter a valid Indian mobile number.';
      });
      _triggerShake();
      return;
    }

    setState(() {
      _errorText = '';
      _isLoading = true;
    });

    final formattedPhone = '+91${_phoneController.text}';
    final response = await ApiService.sendOtp(formattedPhone, 'LOGIN');

    setState(() {
      _isLoading = false;
    });

    if (response != null && response['requestId'] != null) {
      final String requestId = response['requestId'];
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/verify-otp',
          arguments: {
            'phoneNumber': formattedPhone,
            'requestId': requestId,
          },
        );
      }
    } else {
      setState(() {
        _errorText = 'Failed to send OTP. Please check your connection.';
      });
      _triggerShake();
    }
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
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Center(
                  child: MascotCharacter(
                    size: 140,
                    mood: 'idle',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome to\nCardCircle'.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 32,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Enter your mobile number to continue',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 36),
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: Container(
                        height: 62,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _errorText.isNotEmpty
                                ? AppColors.destructive
                                : (_isFocused
                                    ? AppColors.primary
                                    : AppColors.border),
                            width: (_isFocused || _errorText.isNotEmpty) ? 2.0 : 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: AppColors.border,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Text(
                                    '🇮🇳',
                                    style: TextStyle(fontSize: 22),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '+91',
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: Colors.white,
                                      fontSize: 17,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                focusNode: _focusNode,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                autofocus: true,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontSize: 20,
                                  letterSpacing: 2.0,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '98765 43210',
                                  hintStyle: TextStyle(
                                    color: AppColors.border,
                                    letterSpacing: 1.0,
                                  ),
                                  counterText: '',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (_errorText.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                      child: Text(
                        _errorText,
                        style: const TextStyle(
                          color: AppColors.destructive,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                NeoPopButton.primary(
                  onPressed: _isLoading ? null : _handleContinue,
                  isLoading: _isLoading,
                  enabled: valid,
                  depth: 6.0,
                  child: NeoPopButtonText(
                    'Continue',
                    color: valid ? AppColors.darkText : Colors.black,
                    icon: Icons.arrow_forward_rounded,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

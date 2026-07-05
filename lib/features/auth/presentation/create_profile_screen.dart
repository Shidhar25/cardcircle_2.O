import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../auth/state/auth_state.dart';
import '../../../shared/models/models.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen>
    with SingleTickerProviderStateMixin {
  final List<List<Color>> _avatarColors = [
    [const Color(0xFF00D4FF), const Color(0xFF0099CC)],
    [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
    [const Color(0xFFFFD700), const Color(0xFFB8860B)],
    [const Color(0xFF00FF88), const Color(0xFF00A855)],
    [const Color(0xFFFF4757), const Color(0xFFCC0022)],
    [const Color(0xFFFF6B35), const Color(0xFFCC4400)],
  ];

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  late String _phone;
  int _avatarColorIndex = 0;
  bool _saving = false;
  String? _focusedField;

  Timer? _debounceTimer;
  bool _isCheckingUsername = false;
  bool? _isUsernameUnique;

  late AnimationController _avatarController;
  late Animation<double> _avatarScale;

  final Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();

    _avatarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _avatarScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _avatarController, curve: Curves.easeOutBack));

    _nameController.addListener(() {
      setState(() {});
    });

    _dobController.addListener(_formatDOBListener);
    _usernameController.addListener(_usernameListener);
  }

  void _usernameListener() {
    final username = _usernameController.text.trim();
    if (username.isEmpty || username.length < 3) {
      setState(() {
        _isUsernameUnique = null;
      });
      return;
    }

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() {
        _isCheckingUsername = true;
      });
      final unique = await ApiService.checkUsername(username);
      setState(() {
        _isCheckingUsername = false;
        _isUsernameUnique = unique;
        if (!unique) {
          _errors['username'] = 'Username is already taken.';
        } else {
          _errors.remove('username');
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _phone = ModalRoute.of(context)!.settings.arguments as String? ?? '+91 98765 43210';
  }

  void _formatDOBListener() {
    final String text = _dobController.text;
    final String clean = text.replaceAll(RegExp(r'\D'), '');

    String formatted = '';
    if (clean.length > 4) {
      formatted = '${clean.substring(0, 2)} / ${clean.substring(2, 4)} / ${clean.substring(4, mathMin(clean.length, 8))}';
    } else if (clean.length > 2) {
      formatted = '${clean.substring(0, 2)} / ${clean.substring(2)}';
    } else {
      formatted = clean;
    }

    if (text != formatted) {
      _dobController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  int mathMin(int a, int b) => a < b ? a : b;

  String _safeFirstChar(String s) {
    if (s.isEmpty) return '';
    try {
      final clean = s.trim().replaceAll(RegExp(r'[^\w]'), '');
      if (clean.isNotEmpty) return clean[0];
      return String.fromCharCode(s.runes.first);
    } catch (_) {
      return '';
    }
  }

  String _getInitials() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'CC';
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'CC';
    if (parts.length > 1) {
      final f1 = _safeFirstChar(parts[0]);
      final f2 = _safeFirstChar(parts[1]);
      return (f1 + f2).toUpperCase();
    }
    return _safeFirstChar(parts[0]).toUpperCase();
  }

  void _tapAvatar() {
    _avatarController.forward(from: 0.0);
    setState(() {
      _avatarColorIndex = (_avatarColorIndex + 1) % _avatarColors.length;
    });
  }

  bool _validateForm() {
    _errors.clear();
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final dob = _dobController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || name.length < 2) {
      _errors['name'] = 'Enter your full name.';
    }
    if (username.isEmpty || !RegExp(r'^[a-zA-Z0-9_]{3,24}$').hasMatch(username)) {
      _errors['username'] = '3–24 chars: letters, numbers, _';
    }
    if (dob.replaceAll(RegExp(r'\D'), '').length < 8) {
      _errors['dob'] = 'Enter a valid date of birth.';
    }
    if (email.isEmpty || !RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) {
      _errors['email'] = 'Enter a valid email address.';
    }

    setState(() {});
    return _errors.isEmpty;
  }

  String _formatDobForBackend(String dobStr) {
    final parts = dobStr.split('/').map((s) => s.trim()).toList();
    if (parts.length == 3) {
      final day = parts[0];
      final month = parts[1];
      final year = parts[2];
      return '$year-$month-$day';
    }
    return dobStr;
  }

  Future<void> _handleSubmit() async {
    if (!_validateForm()) return;
    if (_isUsernameUnique == false) {
      setState(() {
        _errors['username'] = 'Username is already taken.';
      });
      return;
    }

    setState(() {
      _saving = true;
    });

    final String dobFormatted = _formatDobForBackend(_dobController.text);
    final userMap = await ApiService.createProfile(
      username: _usernameController.text.trim().toLowerCase(),
      name: _nameController.text.trim(),
      email: _emailController.text.trim().toLowerCase(),
      phoneNumber: _phone,
      dateOfBirth: dobFormatted,
    );

    setState(() {
      _saving = false;
    });

    if (userMap != null) {
      if (!mounted) return;
      final state = Provider.of<AuthState>(context, listen: false);
      await state.saveProfile(ProfileData(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim().toLowerCase(),
        dob: _dobController.text,
        email: _emailController.text.trim().toLowerCase(),
        phone: _phone,
        avatarColorIndex: _avatarColorIndex,
        initials: _getInitials(),
      ));

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/select-tags');
      }
    } else {
      setState(() {
        _errors['general'] = 'Failed to create profile. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Dot 1 (Active)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Line 1
                  Container(
                    width: 30,
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Dot 2 (Inactive)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.border,
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Line 2
                  Container(
                    width: 30,
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Dot 3 (Inactive)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.border,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Step 1 of 3 — Create Profile',
                style: TextStyle(
                  color: AppColors.mutedForeground,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Your CardCircle\nprofile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.6,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This is how the community sees you',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 28),
              ScaleTransition(
                scale: _avatarScale,
                child: GestureDetector(
                  onTap: _tapAvatar,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _avatarColors[_avatarColorIndex],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _getInitials(),
                          style: const TextStyle(
                            color: Color(0xFF050505),
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '✏️',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tap to change color',
                style: TextStyle(
                  color: AppColors.mutedForeground,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 28),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildField(
                      label: 'Full Name',
                      placeholder: 'Shridhar Sharma',
                      controller: _nameController,
                      errorKey: 'name',
                      textCapitalization: TextCapitalization.words,
                    ),
                    _buildField(
                      label: 'Username',
                      placeholder: 'shridharsharma',
                      controller: _usernameController,
                      errorKey: 'username',
                      prefix: '@',
                      textCapitalization: TextCapitalization.none,
                      hint: 'Letters, numbers, underscores only',
                      suffix: _isCheckingUsername
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            )
                          : (_isUsernameUnique == null
                              ? null
                              : (_isUsernameUnique!
                                  ? const Icon(Icons.check_circle_outline, color: Colors.green, size: 20)
                                  : const Icon(Icons.error_outline, color: Colors.red, size: 20))),
                    ),
                    _buildField(
                      label: 'Date of Birth',
                      placeholder: 'DD / MM / YYYY',
                      controller: _dobController,
                      errorKey: 'dob',
                      keyboardType: TextInputType.number,
                      hint: 'Must be 18+ to join',
                    ),
                    _buildField(
                      label: 'Email Address',
                      placeholder: 'shridhar@example.com',
                      controller: _emailController,
                      errorKey: 'email',
                      keyboardType: TextInputType.emailAddress,
                      textCapitalization: TextCapitalization.none,
                    ),
                    _buildField(
                      label: 'Phone Number',
                      placeholder: '',
                      controller: TextEditingController(text: _phone),
                      errorKey: 'phone',
                      enabled: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Opacity(
                opacity: _saving ? 0.6 : 1.0,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00D4FF), Color(0xFF8B5CF6)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: _saving ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 19),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Complete Profile 🚀',
                      style: TextStyle(
                        color: Color(0xFF050505),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String placeholder,
    required TextEditingController controller,
    required String errorKey,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? prefix,
    String? hint,
    bool enabled = true,
    Widget? suffix,
  }) {
    final hasError = _errors.containsKey(errorKey);
    final errorMsg = _errors[errorKey] ?? '';
    final isFocused = _focusedField == errorKey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Focus(
            onFocusChange: (hasFocus) {
              setState(() {
                if (hasFocus) {
                  _focusedField = errorKey;
                } else if (_focusedField == errorKey) {
                  _focusedField = null;
                }
              });
            },
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasError
                      ? const Color(0xFFFF4757)
                      : (isFocused ? AppColors.primary : AppColors.border),
                  width: isFocused ? 2.0 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  if (prefix != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 2.0),
                      child: Text(
                        prefix,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      textCapitalization: textCapitalization,
                      enabled: enabled,
                      style: TextStyle(
                        color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.55),
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: placeholder,
                        hintStyle: const TextStyle(
                          color: AppColors.mutedForeground,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (suffix != null) ...[
                    const SizedBox(width: 8),
                    suffix,
                  ],
                ],
              ),
            ),
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: Text(
                errorMsg,
                style: const TextStyle(
                  color: Color(0xFFFF4757),
                  fontSize: 12,
                ),
              ),
            ),
          if (!hasError && hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                hint,
                style: const TextStyle(
                  color: AppColors.mutedForeground,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

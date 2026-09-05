import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/config/remote_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../auth/state/auth_state.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/gritty_background.dart';
import '../../../shared/widgets/legal_text.dart';
import '../../../shared/widgets/primitives.dart';

/// v1 screen 05 — Create Profile. Step 1 of the three-step registration
/// flow (profile -> categories -> cards): a gold progress bar, "Create your
/// profile" header, an avatar picker and labelled fields.
///
/// There is deliberately no back control here. The OTP that got the user
/// this far has already been consumed, so the only place "back" could lead
/// is the login screen, silently discarding a half-filled registration.
/// Steps 2 and 3 do carry a back control, because those steps have a real
/// previous step to return to.
///
/// The backend's `createProfile` requires date of birth and email in
/// addition to the prototype's name/username, so those two real fields are
/// added in the same label/input style rather than dropped.
class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen>
    with SingleTickerProviderStateMixin {
  static const List<List<Color>> _avatarColors = [
    [AppColors.goldLight, AppColors.goldDark],
    [AppColors.teal, Color(0xFF1F3B39)],
    [Color(0xFFB5ABFC), Color(0xFF423A6A)],
    [Color(0xFFB2B6CA), AppColors.border],
  ];

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  late String _phone;
  int _avatarColorIndex = 0;
  bool _saving = false;
  bool _termsAccepted = false;

  Timer? _debounceTimer;
  bool _isCheckingUsername = false;
  bool? _isUsernameUnique;

  late final AnimationController _avatarController;
  late final Animation<double> _avatarScale;

  final Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();

    _avatarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _avatarScale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.0), weight: 60),
        ]).animate(
          CurvedAnimation(parent: _avatarController, curve: Curves.easeOutBack),
        );

    _nameController.addListener(() => setState(() {}));
    _dobController.addListener(_formatDOBListener);
    _usernameController.addListener(_usernameListener);
  }

  void _usernameListener() {
    final username = _usernameController.text.trim();
    if (username.isEmpty || username.length < 3) {
      setState(() => _isUsernameUnique = null);
      return;
    }

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isCheckingUsername = true);
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
    _phone =
        ModalRoute.of(context)!.settings.arguments as String? ??
        '+91 98765 43210';
  }

  void _formatDOBListener() {
    final String text = _dobController.text;
    final String clean = text.replaceAll(RegExp(r'\D'), '');

    String formatted = '';
    if (clean.length > 4) {
      formatted =
          '${clean.substring(0, 2)} / ${clean.substring(2, 4)} / ${clean.substring(4, clean.length.clamp(0, 8))}';
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

  String _safeFirstChar(String s) {
    if (s.isEmpty) return '';
    final clean = s.trim().replaceAll(RegExp(r'[^\w]'), '');
    return clean.isNotEmpty ? clean[0] : String.fromCharCode(s.runes.first);
  }

  String _getInitials() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'CC';
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'CC';
    if (parts.length > 1) {
      return (_safeFirstChar(parts[0]) + _safeFirstChar(parts[1]))
          .toUpperCase();
    }
    return _safeFirstChar(parts[0]).toUpperCase();
  }

  void _tapAvatar() {
    _avatarController.forward(from: 0.0);
    setState(
      () => _avatarColorIndex = (_avatarColorIndex + 1) % _avatarColors.length,
    );
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
    if (username.isEmpty ||
        !RegExp(r'^[a-zA-Z0-9_]{3,24}$').hasMatch(username)) {
      _errors['username'] = '3-24 chars: letters, numbers, _';
    }
    if (dob.replaceAll(RegExp(r'\D'), '').length < 8) {
      _errors['dob'] = 'Enter a valid date of birth.';
    }
    if (email.isEmpty || !RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) {
      _errors['email'] = 'Enter a valid email address.';
    }
    if (config.flag('auth.termsRequired', fallback: true) && !_termsAccepted) {
      _errors['terms'] = 'Please accept the terms to continue.';
    }

    setState(() {});
    return _errors.isEmpty;
  }

  String _formatDobForBackend(String dobStr) {
    final parts = dobStr.split('/').map((s) => s.trim()).toList();
    if (parts.length == 3) return '${parts[2]}-${parts[1]}-${parts[0]}';
    return dobStr;
  }

  Future<void> _handleSubmit() async {
    if (!_validateForm()) return;
    if (_isUsernameUnique == false) {
      setState(() => _errors['username'] = 'Username is already taken.');
      return;
    }

    setState(() => _saving = true);

    final dobFormatted = _formatDobForBackend(_dobController.text);
    final result = await ApiService.createProfile(
      username: _usernameController.text.trim().toLowerCase(),
      name: _nameController.text.trim(),
      email: _emailController.text.trim().toLowerCase(),
      phoneNumber: _phone,
      dateOfBirth: dobFormatted,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (!result.ok) {
      setState(() {
        // Point the backend's complaint at the field that caused it, so the
        // error appears under the input the user has to change rather than
        // as a general note at the bottom of the form.
        switch (result.code) {
          case 'USERNAME_EXISTS':
          case 'INVALID_USERNAME_LENGTH':
          case 'INVALID_USERNAME_FORMAT':
          case 'MISSING_USERNAME':
            _errors['username'] = result.display('That username is taken.');
            break;
          case 'EMAIL_EXISTS':
            _errors['email'] = result.display(
              'That email is already registered.',
            );
            break;
          case 'MISSING_NAME':
            _errors['name'] = result.display('Enter your full name.');
            break;
          default:
            _errors['general'] = result.display(
              'Could not create your profile. Please try again.',
            );
        }
      });
      return;
    }

    {
      final state = Provider.of<AuthState>(context, listen: false);
      await state.saveProfile(
        ProfileData(
          name: _nameController.text.trim(),
          username: _usernameController.text.trim().toLowerCase(),
          dob: _dobController.text,
          email: _emailController.text.trim().toLowerCase(),
          phone: _phone,
          avatarColorIndex: _avatarColorIndex,
          initials: _getInitials(),
        ),
      );
      if (mounted) Navigator.pushNamed(context, '/select-tags');
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
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: GrittyBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 20, 26, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: MonoLabel(
                      'Step 1 of 3',
                      size: 9.5,
                      letterSpacing: 1.6,
                      color: AppColors.textFaint,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const StepProgressBar(currentStep: 1),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Create your profile',
                    style: AppText.sans(
                      27,
                      weight: FontWeight.w500,
                      color: AppColors.text,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'This is what your circle sees.',
                    style: AppText.sans(13, color: AppColors.textDim),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Center(
                    child: ScaleTransition(
                      scale: _avatarScale,
                      child: GestureDetector(
                        onTap: _tapAvatar,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: _avatarColors[_avatarColorIndex],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Text(
                                _getInitials(),
                                style: AppText.mono(
                                  30,
                                  ls: 0,
                                  w: FontWeight.w700,
                                  c: AppColors.background,
                                ),
                              ),
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.gold,
                                ),
                                child: const Icon(
                                  PhosphorIconsFill.palette,
                                  size: 14,
                                  color: AppColors.background,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: MonoLabel(
                      'TAP TO CHANGE COLOR',
                      size: 7.5,
                      letterSpacing: 1,
                      color: AppColors.textFaint,
                      uppercase: false,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _Field(
                          label: 'FULL NAME',
                          placeholder: 'Aarav Mehta',
                          controller: _nameController,
                          error: _errors['name'],
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: AppSpacing.mdLg),
                        _Field(
                          label: 'USERNAME',
                          placeholder: 'aarav',
                          controller: _usernameController,
                          error: _errors['username'],
                          prefix: '@',
                          hint: _isUsernameUnique == null
                              ? 'Letters, numbers, underscores only'
                              : null,
                          suffix: _isCheckingUsername
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: AppColors.gold,
                                  ),
                                )
                              : (_isUsernameUnique == true
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            PhosphorIconsFill.checkCircle,
                                            size: 15,
                                            color: AppColors.teal,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Available',
                                            style: AppText.sans(
                                              11,
                                              color: AppColors.teal,
                                            ),
                                          ),
                                        ],
                                      )
                                    : null),
                        ),
                        const SizedBox(height: AppSpacing.mdLg),
                        _Field(
                          label: 'DATE OF BIRTH',
                          placeholder: 'DD / MM / YYYY',
                          controller: _dobController,
                          error: _errors['dob'],
                          keyboardType: TextInputType.number,
                          hint: 'Must be 18+ to join',
                        ),
                        const SizedBox(height: AppSpacing.mdLg),
                        _Field(
                          label: 'EMAIL ADDRESS',
                          placeholder: 'aarav@example.com',
                          controller: _emailController,
                          error: _errors['email'],
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: AppSpacing.mdLg),
                        _Field(
                          label: 'MOBILE NUMBER',
                          placeholder: '',
                          controller: TextEditingController(text: _phone),
                          enabled: false,
                        ),
                      ],
                    ),
                  ),
                  if (_errors['general'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        _errors['general']!,
                        style: AppText.sans(12, color: AppColors.destructive),
                      ),
                    ),
                  if (config.flag('auth.termsRequired', fallback: true)) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _TermsCheckbox(
                      accepted: _termsAccepted,
                      label: config.text('auth.termsText'),
                      error: _errors['terms'],
                      onChanged: (value) => setState(() {
                        _termsAccepted = value;
                        if (value) _errors.remove('terms');
                      }),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  GoldButton(
                    label: 'Continue',
                    icon: PhosphorIconsRegular.arrowRight,
                    loading: _saving,
                    onTap: _handleSubmit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// First-registration terms acceptance.
///
/// Deliberately unchecked by default and validated with the rest of the
/// form: a pre-ticked box is not consent, and this is the only point in the
/// app where the user agrees to anything.
class _TermsCheckbox extends StatelessWidget {
  final bool accepted;
  final String label;
  final String? error;
  final ValueChanged<bool> onChanged;

  const _TermsCheckbox({
    required this.accepted,
    required this.label,
    required this.error,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!accepted),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: accepted ? AppColors.gold : Colors.transparent,
                  border: Border.all(
                    color: accepted
                        ? AppColors.gold
                        : (error != null
                              ? AppColors.destructive
                              : AppColors.border),
                    width: 1.4,
                  ),
                ),
                child: accepted
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
                  // The two documents are live links, opened from the URLs
                  // the config serves. Tapping one must not toggle the
                  // box, so the spans handle their own taps and the row's
                  // GestureDetector never sees them.
                  child: LegalText(text: label),
                ),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error!,
              style: AppText.sans(12, color: AppColors.destructive),
            ),
          ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String placeholder;
  final TextEditingController controller;
  final String? error;
  final String? hint;
  final String? prefix;
  final Widget? suffix;
  final bool enabled;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;

  const _Field({
    required this.label,
    required this.placeholder,
    required this.controller,
    this.error,
    this.hint,
    this.prefix,
    this.suffix,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoLabel(
          label,
          size: 9.5,
          letterSpacing: 1.6,
          color: AppColors.textFaint,
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedSurface(
          borderColor: error != null ? AppColors.destructive : AppColors.border,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: SizedBox(
            height: 50,
            child: Row(
              children: [
                if (prefix != null) ...[
                  Text(
                    prefix!,
                    style: AppText.mono(14, ls: 0, c: AppColors.textFaint),
                  ),
                  const SizedBox(width: 2),
                ],
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    textCapitalization: textCapitalization,
                    enabled: enabled,
                    style: prefix != null
                        ? AppText.mono(
                            14,
                            ls: 0,
                            c: enabled ? AppColors.text : AppColors.textFaint,
                          )
                        : AppText.sans(
                            14,
                            color: enabled
                                ? AppColors.text
                                : AppColors.textFaint,
                          ),
                    decoration: InputDecoration(
                      hintText: placeholder,
                      hintStyle: AppText.sans(14, color: AppColors.textGhost),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  suffix!,
                ],
              ],
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              error!,
              style: AppText.sans(12, color: AppColors.destructive),
            ),
          )
        else if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: MonoLabel(
              hint!,
              size: 8,
              letterSpacing: 0.6,
              color: AppColors.textGhost,
              uppercase: true,
            ),
          ),
      ],
    );
  }
}

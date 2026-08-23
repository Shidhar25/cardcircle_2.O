import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../auth/state/auth_state.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/neo_pop_button.dart';
import '../../../shared/widgets/gritty_background.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _dobController;

  bool _loading = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    final authState = Provider.of<AuthState>(context, listen: false);
    final user = authState.user;
    final profile = authState.profile;

    _nameController = TextEditingController(text: user.name);
    _emailController = TextEditingController(text: profile?.email ?? '');
    _dobController = TextEditingController(text: profile?.dob ?? '');

    _dobController.addListener(_formatDOBListener);
  }

  void _formatDOBListener() {
    final String text = _dobController.text;
    final String clean = text.replaceAll(RegExp(r'\D'), '');

    String formatted = '';
    if (clean.length > 4) {
      formatted = '${clean.substring(0, 2)} / ${clean.substring(2, 4)} / ${clean.substring(4, _mathMin(clean.length, 8))}';
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

  int _mathMin(int a, int b) => a < b ? a : b;

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

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final dob = _dobController.text.trim();

    if (name.isEmpty || name.length < 2) {
      setState(() => _errorMsg = 'Please enter your full name.');
      return;
    }
    if (email.isEmpty || !RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) {
      setState(() => _errorMsg = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = '';
    });

    final dobFormatted = _formatDobForBackend(dob);
    final response = await ApiService.updateUserProfile(
      name: name,
      email: email,
      dateOfBirth: dobFormatted,
      profilePictureUrl: '',
    );

    setState(() {
      _loading = false;
    });

    if (response != null) {
      if (!mounted) return;
      final authState = Provider.of<AuthState>(context, listen: false);
      final currentProfile = authState.profile;
      String initials = 'U';
      if (name.isNotEmpty) {
        try {
          final clean = name.trim().replaceAll(RegExp(r'[^\w]'), '');
          initials = clean.isNotEmpty ? clean[0] : String.fromCharCode(name.runes.first);
        } catch (_) {
          initials = 'U';
        }
      }

      final updatedProfile = ProfileData(
        name: name,
        username: currentProfile?.username ?? 'user',
        dob: dob,
        email: email,
        phone: currentProfile?.phone ?? '',
        avatarColorIndex: currentProfile?.avatarColorIndex ?? 0,
        initials: initials.toUpperCase(),
      );
      
      await authState.saveProfile(updatedProfile);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.green,
          ),
        );
        Navigator.pop(context);
      }
    } else {
      setState(() {
        _errorMsg = 'Failed to update profile. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFormValid = _nameController.text.isNotEmpty && _emailController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: GrittyBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _buildField(
                    label: 'Full Name',
                    placeholder: 'Enter full name',
                    controller: _nameController,
                  ),
                  _buildField(
                    label: 'Email Address',
                    placeholder: 'Enter email address',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _buildField(
                    label: 'Date of Birth',
                    placeholder: 'DD / MM / YYYY',
                    controller: _dobController,
                    keyboardType: TextInputType.datetime,
                  ),
                  if (_errorMsg.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMsg,
                        style: const TextStyle(color: AppColors.destructive, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 24),
                  NeoPopButton.primary(
                    onPressed: isFormValid && !_loading ? _handleSave : null,
                    isLoading: _loading,
                    enabled: isFormValid && !_loading,
                    depth: 6.0,
                    child: NeoPopButtonText(
                      'Save Changes',
                      color: isFormValid && !_loading ? AppColors.darkText : Colors.black,
                      icon: Icons.check_circle_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String placeholder,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
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
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1.0),
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: const TextStyle(color: AppColors.mutedForeground),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

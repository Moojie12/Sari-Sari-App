import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/editable_profile_avatar.dart';
import '../../../shared/widgets/primary_button.dart';
import 'customer_profile_controller.dart';

/// "Edit Profile" screen: lets the customer update their own name (with
/// middle initial), email, and contact number.
class CustomerEditProfilePage extends StatefulWidget {
  const CustomerEditProfilePage({super.key});

  @override
  State<CustomerEditProfilePage> createState() => _CustomerEditProfilePageState();
}

class _CustomerEditProfilePageState extends State<CustomerEditProfilePage> {
  final _controller = CustomerProfileController();

  late final TextEditingController _firstNameController;
  late final TextEditingController _middleInitialController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _contactController;
  String? _previewPhotoPath;

  String? _firstNameError;
  String? _middleInitialError;
  String? _lastNameError;
  String? _emailError;
  String? _contactError;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onProfileChanged);
    final profile = _controller.profile;
    _firstNameController = TextEditingController(text: profile.firstName);
    _middleInitialController = TextEditingController(
      text: profile.middleInitial.replaceAll('.', '').toUpperCase(),
    );
    _lastNameController = TextEditingController(text: profile.lastName);
    _emailController = TextEditingController(text: profile.email);
    _contactController = TextEditingController(text: profile.contactNumber);
    _controller.loadProfile();
  }

  void _onProfileChanged() {
    if (!mounted) return;
    final profile = _controller.profile;
    if (_firstNameController.text.trim().isEmpty && profile.firstName.isNotEmpty) {
      _firstNameController.text = profile.firstName;
    }
    if (_middleInitialController.text.trim().isEmpty && profile.middleInitial.isNotEmpty) {
      _middleInitialController.text = profile.middleInitial.replaceAll('.', '').toUpperCase();
    }
    if (_lastNameController.text.trim().isEmpty && profile.lastName.isNotEmpty) {
      _lastNameController.text = profile.lastName;
    }
    if (_emailController.text.trim().isEmpty && profile.email.isNotEmpty) {
      _emailController.text = profile.email;
    }
    if (_contactController.text.trim().isEmpty && profile.contactNumber.isNotEmpty) {
      _contactController.text = profile.contactNumber;
    }
  }

  String get _computedInitials {
    final f = _firstNameController.text.trim();
    final l = _lastNameController.text.trim();
    if (f.isNotEmpty || l.isNotEmpty) {
      final fChar = f.isNotEmpty ? f[0].toUpperCase() : '';
      final lChar = l.isNotEmpty ? l[0].toUpperCase() : '';
      return '$fChar$lChar';
    }
    return _controller.profile.initials;
  }

  // --- Validation Helpers ---

  String? _validateFirstName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Please enter your first name';
    }
    if (value.length > 50) {
      return 'First name cannot exceed 50 characters';
    }
    if (value.contains('  ')) {
      return 'Only single space allowed between words';
    }
    if (!RegExp(r'^[a-zA-Z]+( [a-zA-Z]+)*$').hasMatch(value)) {
      return 'Must contain letters with single space between words';
    }
    return null;
  }

  String? _validateLastName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Please enter your last name';
    }
    if (value.length > 50) {
      return 'Last name cannot exceed 50 characters';
    }
    if (value.contains('  ')) {
      return 'Only single space allowed between words';
    }
    if (!RegExp(r'^[a-zA-Z]+( [a-zA-Z]+)*$').hasMatch(value)) {
      return 'Must contain letters with single space between words';
    }
    return null;
  }

  String? _validateMiddleInitial(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      if (trimmed.length > 1 || !RegExp(r'^[a-zA-Z]$').hasMatch(trimmed)) {
        return 'M.I. must be a single letter';
      }
    }
    return null;
  }

  String? _validateEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Please enter your email address';
    }
    if (!trimmed.toLowerCase().endsWith('@gmail.com')) {
      return 'Email must be a valid @gmail.com address';
    }
    final prefix = trimmed.substring(0, trimmed.length - 10);
    if (prefix.length <= 3) {
      return 'Email name must be more than 3 characters before @gmail.com';
    }
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+$').hasMatch(prefix)) {
      return 'Email contains invalid characters';
    }
    return null;
  }

  String? _validatePhone(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Please enter your contact number';
    }
    if (!trimmed.startsWith('09') && !trimmed.startsWith('+639')) {
      return 'Contact number must start with 09 or +639';
    }
    if (trimmed.startsWith('09') && trimmed.length != 11) {
      return 'Contact number starting with 09 must be exactly 11 digits';
    }
    if (trimmed.startsWith('+639') && trimmed.length != 13) {
      return 'Contact number starting with +639 must be exactly 13 characters';
    }
    if (RegExp(r'(\d)\1{3}').hasMatch(trimmed)) {
      return 'Contact number cannot contain 4 consecutive same digits';
    }
    return null;
  }

  void _onFirstNameChanged(String value) {
    setState(() {
      _firstNameError = _validateFirstName(value);
    });
  }

  void _onMiddleInitialChanged(String value) {
    setState(() {
      _middleInitialError = _validateMiddleInitial(value);
    });
  }

  void _onLastNameChanged(String value) {
    setState(() {
      _lastNameError = _validateLastName(value);
    });
  }

  void _onEmailChanged(String value) {
    setState(() {
      _emailError = _validateEmail(value);
    });
  }

  void _onContactChanged(String value) {
    setState(() {
      _contactError = _validatePhone(value);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onProfileChanged);
    _firstNameController.dispose();
    _middleInitialController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _saveChanges() async {
    final fnError = _validateFirstName(_firstNameController.text);
    final miError = _validateMiddleInitial(_middleInitialController.text);
    final lnError = _validateLastName(_lastNameController.text);
    final emError = _validateEmail(_emailController.text);
    final phError = _validatePhone(_contactController.text);

    setState(() {
      _firstNameError = fnError;
      _middleInitialError = miError;
      _lastNameError = lnError;
      _emailError = emError;
      _contactError = phError;
    });

    if (fnError != null || miError != null || lnError != null || emError != null || phError != null) {
      TopNotification.show(context, 'Please fix the errors in the form.', isError: true);
      return;
    }

    final firstName = _firstNameController.text.trim();
    final middleInitial = _middleInitialController.text.trim().toUpperCase();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final contact = _contactController.text.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Changes', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Do you want to save the changes to your profile?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    if (_previewPhotoPath != null) {
      await _controller.setPhoto(_previewPhotoPath == '' ? null : _previewPhotoPath);
    }
    await _controller.updateProfile(
      firstName: firstName,
      middleInitial: middleInitial,
      lastName: lastName,
      email: email,
      contactNumber: contact,
    );

    if (!mounted) return;
    TopNotification.show(context, 'Profile updated successfully.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) {
                    final photoToDisplay = _previewPhotoPath == ''
                        ? null
                        : (_previewPhotoPath ?? _controller.profile.photoPath);
                    return EditableProfileAvatar(
                      initials: _computedInitials,
                      photoPath: photoToDisplay,
                      onPhotoChanged: (newPath) {
                        setState(() {
                          _previewPhotoPath = newPath ?? '';
                        });
                      },
                      radius: 46,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _previewPhotoPath != null && _previewPhotoPath!.isNotEmpty
                      ? 'Photo preview ready. Tap Save Changes to keep.'
                      : 'Tap avatar to change photo',
                  style: TextStyle(
                    color: _previewPhotoPath != null && _previewPhotoPath!.isNotEmpty
                        ? AppColors.primaryOrange
                        : AppColors.secondaryText,
                    fontSize: 12,
                    fontWeight: _previewPhotoPath != null && _previewPhotoPath!.isNotEmpty
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Personal Information',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'First Name',
                          style: TextStyle(
                            color: AppColors.labelText,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        CustomTextField(
                          hint: 'First Name',
                          icon: Icons.person_outline,
                          controller: _firstNameController,
                          errorText: _firstNameError,
                          maxLength: 50,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                            LengthLimitingTextInputFormatter(50),
                          ],
                          onChanged: _onFirstNameChanged,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'M.I.',
                          style: TextStyle(
                            color: AppColors.labelText,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        CustomTextField(
                          hint: 'M.I.',
                          textAlign: TextAlign.center,
                          controller: _middleInitialController,
                          errorText: _middleInitialError,
                          maxLength: 1,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                            LengthLimitingTextInputFormatter(1),
                            TextInputFormatter.withFunction(
                              (oldValue, newValue) => newValue.copyWith(
                                text: newValue.text.toUpperCase(),
                              ),
                            ),
                          ],
                          onChanged: _onMiddleInitialChanged,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Last Name',
                style: TextStyle(
                  color: AppColors.labelText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              CustomTextField(
                hint: 'Last Name',
                icon: Icons.badge_outlined,
                controller: _lastNameController,
                errorText: _lastNameError,
                maxLength: 50,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                  LengthLimitingTextInputFormatter(50),
                ],
                onChanged: _onLastNameChanged,
              ),
              const SizedBox(height: 14),
              const Text(
                'Email Address',
                style: TextStyle(
                  color: AppColors.labelText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              CustomTextField(
                hint: 'Email Address',
                icon: Icons.email_outlined,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
                onChanged: _onEmailChanged,
              ),
              const SizedBox(height: 14),
              const Text(
                'Contact Number',
                style: TextStyle(
                  color: AppColors.labelText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              CustomTextField(
                hint: 'Contact Number',
                icon: Icons.phone_outlined,
                controller: _contactController,
                keyboardType: TextInputType.phone,
                errorText: _contactError,
                maxLength: 13,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                  LengthLimitingTextInputFormatter(13),
                ],
                onChanged: _onContactChanged,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Save Changes',
                height: 48,
                onPressed: _saveChanges,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


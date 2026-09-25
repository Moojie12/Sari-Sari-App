import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/editable_profile_avatar.dart';
import '../../../shared/widgets/primary_button.dart';
import 'employee_profile_controller.dart';

/// "Edit Profile" screen: lets the employee update their own name (with
/// middle initial), email, and contact number. Fields here match exactly
/// what's shown on "Profile Information" — there is no username field,
/// since Profile Information doesn't show one either.
class EmployeeEditProfilePage extends StatefulWidget {
  const EmployeeEditProfilePage({super.key});

  @override
  State<EmployeeEditProfilePage> createState() => _EmployeeEditProfilePageState();
}

class _EmployeeEditProfilePageState extends State<EmployeeEditProfilePage> {
  final _controller = EmployeeProfileController();

  late final TextEditingController _firstNameController;
  late final TextEditingController _middleInitialController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _contactController;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onProfileChanged);
    final profile = _controller.profile;
    _firstNameController = TextEditingController(text: profile.firstName);
    _middleInitialController = TextEditingController(text: profile.middleInitial);
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
      _middleInitialController.text = profile.middleInitial;
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
    final firstName = _firstNameController.text.trim();
    final middleInitial = _middleInitialController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final contact = _contactController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty) {
      TopNotification.show(context, 'Please fill in all required fields.', isError: true);
      return;
    }

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
                    return EditableProfileAvatar(
                      initials: _controller.profile.initials,
                      photoPath: _controller.profile.photoPath,
                      onPhotoChanged: _controller.setPhoto,
                      radius: 46,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Tap avatar to change photo',
                  style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
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
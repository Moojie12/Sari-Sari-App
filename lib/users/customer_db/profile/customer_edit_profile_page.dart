import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import 'customer_profile_controller.dart';

/// "Edit Profile" screen: lets the customer update their own name (with
/// middle initial), email, and contact number. Fields here match exactly
/// what's shown on "Profile Information" — there is no username field,
/// since Profile Information doesn't show one either.
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

  @override
  void initState() {
    super.initState();
    final profile = _controller.profile;
    _firstNameController = TextEditingController(text: profile.firstName);
    _middleInitialController = TextEditingController(text: profile.middleInitial);
    _lastNameController = TextEditingController(text: profile.lastName);
    _emailController = TextEditingController(text: profile.email);
    _contactController = TextEditingController(text: profile.contactNumber);
  }

  @override
  void dispose() {
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

    _controller.updateProfile(
      firstName: firstName,
      middleInitial: middleInitial,
      lastName: lastName,
      email: email,
      contactNumber: contact,
    );

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
                    child: CustomTextField(
                      hint: 'First Name',
                      icon: Icons.person_outline,
                      controller: _firstNameController,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: CustomTextField(
                      hint: 'M.I.',
                      icon: Icons.badge_outlined,
                      controller: _middleInitialController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              CustomTextField(
                hint: 'Last Name',
                icon: Icons.person_outline,
                controller: _lastNameController,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                hint: 'Email Address',
                icon: Icons.email_outlined,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
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
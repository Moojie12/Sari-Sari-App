import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';

class CustomerEditProfilePage extends StatefulWidget {
  const CustomerEditProfilePage({super.key});

  @override
  State<CustomerEditProfilePage> createState() => _CustomerEditProfilePageState();
}

class _CustomerEditProfilePageState extends State<CustomerEditProfilePage> {
  final _firstNameController = TextEditingController(text: 'Juan');
  final _lastNameController = TextEditingController(text: 'Dela Cruz');
  final _usernameController = TextEditingController(text: 'juan_dc');
  final _emailController = TextEditingController(text: 'juan.delacruz@email.com');
  final _contactController = TextEditingController(text: '+63 912 345 6789');

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _saveChanges() {
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
                    child: CustomTextField(
                      hint: 'First Name',
                      icon: Icons.person_outline,
                      controller: _firstNameController,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomTextField(
                      hint: 'Last Name',
                      icon: Icons.person_outline,
                      controller: _lastNameController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              CustomTextField(
                hint: 'Username',
                icon: Icons.alternate_email,
                controller: _usernameController,
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

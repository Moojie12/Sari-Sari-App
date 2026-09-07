import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';

class CustomerChangePasswordPage extends StatefulWidget {
  const CustomerChangePasswordPage({super.key});

  @override
  State<CustomerChangePasswordPage> createState() => _CustomerChangePasswordPageState();
}

class _CustomerChangePasswordPageState extends State<CustomerChangePasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() async {
    final current = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (current.isEmpty || newPassword.isEmpty || confirm.isEmpty) {
      TopNotification.show(context, 'Please fill in all fields.', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Changes', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to update your password?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    TopNotification.show(context, 'Password changed successfully.');
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
          'Change Password',
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
                'Enter your current password, then choose a new one.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
              const SizedBox(height: 20),
              CustomTextField(
                hint: 'Current Password',
                icon: Icons.lock_outline,
                isPassword: true,
                controller: _currentPasswordController,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                hint: 'New Password',
                icon: Icons.lock_outline,
                isPassword: true,
                controller: _newPasswordController,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                hint: 'Confirm New Password',
                icon: Icons.lock_outline,
                isPassword: true,
                controller: _confirmPasswordController,
              ),
              const SizedBox(height: 6),
              const Text(
                'Must be at least 8 characters.',
                style: TextStyle(color: AppColors.placeholderColor, fontSize: 11),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Update Password',
                height: 48,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

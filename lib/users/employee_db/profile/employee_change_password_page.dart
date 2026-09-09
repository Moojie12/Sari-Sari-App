import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import 'employee_profile_controller.dart';

/// "Change Password" screen: lets the employee update their account
/// password after re-entering the current one.
class EmployeeChangePasswordPage extends StatefulWidget {
  const EmployeeChangePasswordPage({super.key});

  @override
  State<EmployeeChangePasswordPage> createState() => _EmployeeChangePasswordPageState();
}

class _EmployeeChangePasswordPageState extends State<EmployeeChangePasswordPage> {
  final _controller = EmployeeProfileController();

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

    final result = _controller.changePassword(
      currentPassword: current,
      newPassword: newPassword,
      confirmPassword: confirm,
    );

    switch (result) {
      case ChangePasswordResult.success:
        if (!mounted) return;
        TopNotification.show(context, 'Password changed successfully.');
        Navigator.pop(context);
        break;
      case ChangePasswordResult.incorrectCurrentPassword:
        if (!mounted) return;
        TopNotification.show(context, 'Current password is incorrect.', isError: true);
        break;
      case ChangePasswordResult.newPasswordTooShort:
        if (!mounted) return;
        TopNotification.show(context, 'New password must be at least 8 characters.', isError: true);
        break;
      case ChangePasswordResult.newPasswordsDoNotMatch:
        if (!mounted) return;
        TopNotification.show(context, 'New password and confirmation do not match.', isError: true);
        break;
    }
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
              Text(
                'Enter your current password, then choose a new one.',
                style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.8), fontSize: 13),
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
              Text(
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
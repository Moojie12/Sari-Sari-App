import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/password_validator.dart';
import '../../../shared/utils/top_notification.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/password_requirements_widget.dart';
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

  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;
  bool _isLoading = false;

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

    final currentErr = current.isEmpty ? 'Please enter your current password.' : null;
    final newErr = PasswordValidator.validate(newPassword, fieldName: 'New password');
    final confirmErr = PasswordValidator.validateConfirmPassword(confirm, newPassword);

    setState(() {
      _currentPasswordError = currentErr;
      _newPasswordError = newErr;
      _confirmPasswordError = confirmErr;
    });

    if (current.isEmpty || newPassword.isEmpty || confirm.isEmpty) {
      TopNotification.show(context, 'Please fill in all fields.', isError: true);
      return;
    }

    if (newErr != null) {
      TopNotification.show(context, newErr, isError: true);
      return;
    }

    if (confirmErr != null) {
      TopNotification.show(context, confirmErr, isError: true);
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

    setState(() => _isLoading = true);

    final result = await _controller.changePassword(
      currentPassword: current,
      newPassword: newPassword,
      confirmPassword: confirm,
    );

    if (mounted) {
      setState(() => _isLoading = false);
    }

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
      case ChangePasswordResult.invalidPasswordFormat:
      case ChangePasswordResult.newPasswordTooShort:
        if (!mounted) return;
        TopNotification.show(
          context,
          'New password must be at least 8 characters long, contain an uppercase letter, a lowercase letter, a number, and a special character.',
          isError: true,
        );
        break;
      case ChangePasswordResult.newPasswordsDoNotMatch:
        if (!mounted) return;
        TopNotification.show(context, 'New password and confirmation do not match.', isError: true);
        break;
      case ChangePasswordResult.failed:
        if (!mounted) return;
        TopNotification.show(context, 'Failed to update password. Please try again.', isError: true);
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
                errorText: _currentPasswordError,
                onChanged: (val) {
                  if (_currentPasswordError != null) {
                    setState(() => _currentPasswordError = null);
                  }
                },
              ),
              const SizedBox(height: 14),
              CustomTextField(
                hint: 'New Password',
                icon: Icons.lock_outline,
                isPassword: true,
                controller: _newPasswordController,
                errorText: _newPasswordError,
                onChanged: (val) {
                  setState(() {
                    if (_newPasswordError != null) {
                      _newPasswordError = PasswordValidator.validate(val, fieldName: 'New password');
                    }
                    if (_confirmPasswordError != null && _confirmPasswordController.text.isNotEmpty) {
                      _confirmPasswordError = PasswordValidator.validateConfirmPassword(
                        _confirmPasswordController.text,
                        val,
                      );
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              CustomTextField(
                hint: 'Confirm New Password',
                icon: Icons.lock_outline,
                isPassword: true,
                controller: _confirmPasswordController,
                errorText: _confirmPasswordError,
                onChanged: (val) {
                  setState(() {
                    if (_confirmPasswordError != null) {
                      _confirmPasswordError = PasswordValidator.validateConfirmPassword(
                        val,
                        _newPasswordController.text,
                      );
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              PasswordRequirementsWidget(
                password: _newPasswordController.text,
                confirmPassword: _confirmPasswordController.text,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _isLoading ? 'Updating...' : 'Update Password',
                isLoading: _isLoading,
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

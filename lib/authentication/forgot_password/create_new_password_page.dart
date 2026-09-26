// lib/authentication/forgot_password/create_new_password_page.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/utils/top_notification.dart';
import '../../core/services/auth_service.dart';

class CreateNewPasswordPage extends StatefulWidget {
  const CreateNewPasswordPage({
    super.key,
    required this.email,
  });

  final String email;

  @override
  State<CreateNewPasswordPage> createState() => _CreateNewPasswordPageState();
}

class _CreateNewPasswordPageState extends State<CreateNewPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  String? _passwordError;
  String? _confirmPasswordError;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least 1 uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least 1 lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least 1 number';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\]').hasMatch(value)) {
      return 'Password must contain at least 1 special character';
    }
    return null;
  }

  String? _validateConfirmPassword(String value) {
    if (value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _handleSavePassword() async {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      _passwordError = _validatePassword(password);
      _confirmPasswordError = _validateConfirmPassword(confirmPassword);
    });

    if (_passwordError != null || _confirmPasswordError != null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final resultMessage = await AuthService().resetUserPassword(
        email: widget.email,
        newPassword: password,
      );

      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (resultMessage != null && resultMessage.toLowerCase().contains('could not')) {
        if (mounted) {
          TopNotification.show(context, resultMessage, isError: true);
        }
        return;
      }

      if (mounted) {
        final message = resultMessage ?? 'Password updated successfully! You can now log in with your new password.';
        TopNotification.show(
          context,
          message,
          isError: false,
        );

        // Return straight back to Login Page
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        TopNotification.show(
          context,
          'An error occurred while resetting password: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Create New Password',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your new password must be unique from those previously used.',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              
              const Text(
                'New Password',
                style: TextStyle(
                  color: AppColors.labelText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 7),
              CustomTextField(
                hint: 'Enter new password',
                icon: Icons.lock_outline,
                isPassword: true,
                controller: _passwordController,
                errorText: _passwordError,
                onChanged: (val) {
                  if (_passwordError != null) {
                    setState(() {
                      _passwordError = _validatePassword(val);
                      if (_confirmPasswordController.text.isNotEmpty) {
                        _confirmPasswordError = _validateConfirmPassword(_confirmPasswordController.text);
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              
              const Text(
                'Confirm Password',
                style: TextStyle(
                  color: AppColors.labelText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 7),
              CustomTextField(
                hint: 'Confirm new password',
                icon: Icons.lock_clock_outlined,
                isPassword: true,
                controller: _confirmPasswordController,
                errorText: _confirmPasswordError,
                onChanged: (val) {
                  if (_confirmPasswordError != null) {
                    setState(() {
                      _confirmPasswordError = _validateConfirmPassword(val);
                    });
                  }
                },
              ),
              const SizedBox(height: 32),
              
              PrimaryButton(
                label: _isLoading ? 'Saving...' : 'Save & Login',
                isLoading: _isLoading,
                onPressed: _handleSavePassword,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

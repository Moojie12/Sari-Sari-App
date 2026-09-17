// lib/authentication/forgot_password/create_new_password_page.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../../shared/widgets/primary_button.dart';

class CreateNewPasswordPage extends StatefulWidget {
  const CreateNewPasswordPage({super.key});

  @override
  State<CreateNewPasswordPage> createState() => _CreateNewPasswordPageState();
}

class _CreateNewPasswordPageState extends State<CreateNewPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
              ),
              const SizedBox(height: 32),
              
              PrimaryButton(
                label: 'Save & Login',
                onPressed: () {
                  if (_passwordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill out all fields.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }
                  
                  if (_passwordController.text != _confirmPasswordController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Passwords do not match!'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }

                  // Ipakita na successful
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password changed successfully! Please login with your new password.'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // I-pop pabalik hanggang sa marating ang Login screen
                  // Tatanggalin ang tatlong screen sa navigation stack (ForgotPassword -> Otp -> CreateNew)
                  int count = 0;
                  Navigator.popUntil(context, (route) => count++ == 3);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

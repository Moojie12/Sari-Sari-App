// lib/authentication/forgot_password/forgot_password_page.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import 'otp_verification_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  String? _emailError;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    final validationError = _validateEmail(email);

    if (validationError != null) {
      setState(() {
        _emailError = validationError;
      });
      return;
    }

    setState(() {
      _emailError = null;
      _isLoading = true;
    });

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationPage(
            email: email,
            isSignUpFlow: false,
          ),
        ),
      );
    }
  }

  VoidCallback get _sendPressed => () { _sendOtp(); };

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
                'Forgot Password?',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your email address below to receive an OTP verification code.',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Email Address',
                style: TextStyle(
                  color: AppColors.labelText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 7),
              CustomTextField(
                hint: 'Enter your email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                controller: _emailController,
                errorText: _emailError,
                onChanged: (value) {
                  if (_emailError != null) {
                    setState(() {
                      _emailError = _validateEmail(value);
                    });
                  }
                },
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: _isLoading ? 'Sending OTP...' : 'Send OTP',
                onPressed: _sendPressed,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

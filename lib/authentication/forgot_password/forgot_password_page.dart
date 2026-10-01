// lib/authentication/forgot_password/forgot_password_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      body: Stack(
        children: [
          // Background Image from app login
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_image.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Dark Gradient Scrim
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.78),
                    Colors.black.withValues(alpha: 0.52),
                    AppColors.primaryOrange.withValues(alpha: 0.38),
                  ],
                ),
              ),
            ),
          ),

          // Main Responsive Shell
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = constraints.maxWidth;
                    final isDesktop = screenWidth >= 1024;
                    final isTablet = screenWidth >= 768 && screenWidth < 1024;

                    return Center(
                      child: isDesktop || isTablet
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // LEFT SIDE: Forgot Password Card
                                Flexible(
                                  flex: isDesktop ? 5 : 6,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: isDesktop ? 440 : 390,
                                    ),
                                    child: _buildForgotPasswordCard(isCompact: isTablet),
                                  ),
                                ),
                                SizedBox(width: isDesktop ? 60 : 36),
                                // RIGHT SIDE: Website Branding & Logo
                                Flexible(
                                  flex: isDesktop ? 6 : 5,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: isDesktop ? 480 : 380,
                                    ),
                                    child: _buildBrandingSection(isCompact: isTablet),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildCompactBrandingSection(),
                                const SizedBox(height: 24),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 420),
                                  child: _buildForgotPasswordCard(isCompact: true),
                                ),
                              ],
                            ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForgotPasswordCard({bool isCompact = false}) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _sendOtp,
      },
      child: Container(
        padding: EdgeInsets.all(isCompact ? 24 : 34),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.lock_reset_rounded,
                    size: 15,
                    color: AppColors.primaryOrange,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'ACCOUNT RECOVERY',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isCompact ? 12 : 16),
            Text(
              'Forgot Password?',
              style: TextStyle(
                fontSize: isCompact ? 22 : 26,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter your registered email address below to receive an OTP verification code.',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: isCompact ? 12 : 13,
                height: 1.35,
              ),
            ),
            SizedBox(height: isCompact ? 20 : 28),

            // Email Input Field
            const Text(
              'Email Address',
              style: TextStyle(
                color: AppColors.labelText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            CustomTextField(
              hint: 'Enter your email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              controller: _emailController,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _sendOtp(),
              errorText: _emailError,
              onChanged: (value) {
                if (_emailError != null) {
                  setState(() {
                    _emailError = _validateEmail(value);
                  });
                }
              },
            ),
            SizedBox(height: isCompact ? 20 : 28),

            // Action Button
            PrimaryButton(
              label: _isLoading ? 'Sending OTP...' : 'Send OTP',
              onPressed: _sendPressed,
              isLoading: _isLoading,
              height: isCompact ? 44 : 48,
            ),
            const SizedBox(height: 20),

            // Back to Login Link
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 16,
                  color: AppColors.primaryOrange,
                ),
                label: const Text(
                  'Back to Login',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Footer
            const Center(
              child: Text(
                '© 2026 Tindahan ni Eca App System',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingSection({bool isCompact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isCompact ? 80 : 96,
          height: isCompact ? 80 : 96,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppColors.primaryOrange.withValues(alpha: 0.35),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        SizedBox(height: isCompact ? 16 : 22),

        Text(
          'Tindahan ni Eca',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 32 : 40,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            shadows: const [
              Shadow(
                color: Colors.black87,
                offset: Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.storefront_rounded, size: 16, color: AppColors.primaryOrange),
              SizedBox(width: 8),
              Text(
                'Management Portal & Retail Suite',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactBrandingSection() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Tindahan ni Eca',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: Colors.black87,
                offset: Offset(0, 3),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Account Recovery',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}

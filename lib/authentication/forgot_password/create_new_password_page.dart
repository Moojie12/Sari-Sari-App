// lib/authentication/forgot_password/create_new_password_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../../shared/widgets/password_requirements_widget.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/utils/top_notification.dart';
import '../../shared/utils/password_validator.dart';
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
    return PasswordValidator.validate(value);
  }

  String? _validateConfirmPassword(String value) {
    return PasswordValidator.validateConfirmPassword(value, _passwordController.text);
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

      if (resultMessage != null) {
        if (mounted) {
          TopNotification.show(context, resultMessage, isError: true);
        }
        return;
      }

      if (mounted) {
        TopNotification.show(context, 'Password updated successfully! You can now log in with your new password.');
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        TopNotification.show(context, 'Failed to update password: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_image.jpg',
              fit: BoxFit.cover,
            ),
          ),
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
                                Flexible(
                                  flex: isDesktop ? 5 : 6,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: isDesktop ? 440 : 390,
                                    ),
                                    child: _buildCreatePasswordCard(isCompact: isTablet),
                                  ),
                                ),
                                SizedBox(width: isDesktop ? 60 : 36),
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
                                  child: _buildCreatePasswordCard(isCompact: true),
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

  Widget _buildCreatePasswordCard({bool isCompact = false}) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _handleSavePassword,
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
                    Icons.key_rounded,
                    size: 15,
                    color: AppColors.primaryOrange,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'RESET PASSWORD',
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
              'Create New Password',
              style: TextStyle(
                fontSize: isCompact ? 22 : 26,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your new password must be different from previously used passwords.',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: isCompact ? 12 : 13,
                height: 1.35,
              ),
            ),
            SizedBox(height: isCompact ? 18 : 24),

            // New Password
            const Text(
              'New Password',
              style: TextStyle(
                color: AppColors.labelText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            CustomTextField(
              controller: _passwordController,
              hint: 'Enter new password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              textInputAction: TextInputAction.next,
              errorText: _passwordError,
              onChanged: (val) {
                setState(() {
                  _passwordError = _validatePassword(val);
                });
              },
            ),
            const SizedBox(height: 10),

            PasswordRequirementsWidget(
              password: _passwordController.text,
            ),
            SizedBox(height: isCompact ? 14 : 18),

            // Confirm New Password
            const Text(
              'Confirm New Password',
              style: TextStyle(
                color: AppColors.labelText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            CustomTextField(
              controller: _confirmPasswordController,
              hint: 'Confirm new password',
              icon: Icons.lock_clock_outlined,
              isPassword: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSavePassword(),
              errorText: _confirmPasswordError,
              onChanged: (val) {
                setState(() {
                  _confirmPasswordError = _validateConfirmPassword(val);
                });
              },
            ),
            SizedBox(height: isCompact ? 20 : 28),

            PrimaryButton(
              label: _isLoading ? 'Updating...' : 'Save New Password',
              onPressed: _handleSavePassword,
              isLoading: _isLoading,
              height: isCompact ? 44 : 48,
            ),
            const SizedBox(height: 20),

            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
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
            'Reset Password',
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

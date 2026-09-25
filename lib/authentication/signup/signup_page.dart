// lib/authentication/signup/signup_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/utils/top_notification.dart';
import '../../core/services/auth_service.dart';
import '../forgot_password/otp_verification_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // Form controllers
  final _firstNameController = TextEditingController();
  final _middleInitialController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Validation states
  String? _firstNameError;
  String? _surnameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _confirmPasswordError;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleInitialController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- Real-time Validation Helper Methods ---

  String? _validateFirstName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Please enter your first name';
    }
    if (value.length > 50) {
      return 'First name cannot exceed 50 characters';
    }
    if (value.contains('  ')) {
      return 'Only single space allowed between words';
    }
    if (!RegExp(r'^[a-zA-Z]+( [a-zA-Z]+)*$').hasMatch(value)) {
      return 'Must contain letters with single space between words';
    }
    return null;
  }

  String? _validateLastName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Please enter your lastname';
    }
    if (value.length > 50) {
      return 'Lastname cannot exceed 50 characters';
    }
    if (value.contains('  ')) {
      return 'Only single space allowed between words';
    }
    if (!RegExp(r'^[a-zA-Z]+( [a-zA-Z]+)*$').hasMatch(value)) {
      return 'Must contain letters with single space between words';
    }
    return null;
  }

  String? _validateEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Please enter your email address';
    }
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$').hasMatch(trimmed)) {
      return 'Email must be a valid @gmail.com address';
    }
    return null;
  }

  String? _validatePhone(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Please enter your phone number';
    }
    if (!trimmed.startsWith('09') && !trimmed.startsWith('+639')) {
      return 'Phone number must start with 09 or +639';
    }
    if (trimmed.startsWith('09') && trimmed.length != 11) {
      return 'Phone starting with 09 must be exactly 11 digits';
    }
    if (trimmed.startsWith('+639') && trimmed.length != 13) {
      return 'Phone starting with +639 must be exactly 13 characters';
    }
    if (RegExp(r'(\d)\1{3}').hasMatch(trimmed)) {
      return 'Phone cannot contain 4 consecutive same digits';
    }
    return null;
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

  Future<void> _handleSignUp() async {
    final firstName = _firstNameController.text;
    final middleInitial = _middleInitialController.text.trim().toUpperCase();
    final surname = _surnameController.text;
    final email = _emailController.text;
    final phone = _phoneController.text;
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validate all fields on submit
    setState(() {
      _firstNameError = _validateFirstName(firstName);
      _surnameError = _validateLastName(surname);
      _emailError = _validateEmail(email);
      _phoneError = _validatePhone(phone);
      _passwordError = _validatePassword(password);
      _confirmPasswordError = _validateConfirmPassword(confirmPassword);
    });

    if (_firstNameError != null ||
        _surnameError != null ||
        _emailError != null ||
        _phoneError != null ||
        _passwordError != null ||
        _confirmPasswordError != null) {
      return;
    }

    setState(() => _isLoading = true);

    bool isEmailTaken = false;
    try {
      isEmailTaken = await AuthService().isEmailInUse(email.trim());
    } catch (e) {
      debugPrint('Error checking email availability: $e');
      isEmailTaken = false;
    }

    if (isEmailTaken) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _emailError = 'Email address is already in use';
        });
        TopNotification.show(
          context,
          'This email is already registered. Please sign in or use another email.',
          isError: true,
        );
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationPage(
            email: email.trim(),
            firstName: firstName.trim(),
            middleInitial: middleInitial,
            surname: surname.trim(),
            phone: phone.trim(),
            password: password,
            isSignUpFlow: true,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false, // Papayagan ang Header na umabot sa pinaka-itaas (Status Bar)
        child: Column(
          children: [
            // Nakapirme ang Header dito, eksaktong kapareho ng proportion sa login page (flex 5)
            const Expanded(flex: 5, child: _Header()),
            Expanded(
              flex: 10, // Default base size na katulad ng sa login page upang pantay silang dalawa
              child: Transform.translate(
                offset: const Offset(0, 35), // Match login page offset
                child: Container(
                  color: Colors.transparent,
                  child: _SignUpCard(
                    firstNameController: _firstNameController,
                    middleInitialController: _middleInitialController,
                    surnameController: _surnameController,
                    emailController: _emailController,
                    phoneController: _phoneController,
                    passwordController: _passwordController,
                    confirmPasswordController: _confirmPasswordController,
                    firstNameError: _firstNameError,
                    surnameError: _surnameError,
                    emailError: _emailError,
                    phoneError: _phoneError,
                    passwordError: _passwordError,
                    confirmPasswordError: _confirmPasswordError,
                    isLoading: _isLoading,
                    handleSignUp: _handleSignUp,
                    onFirstNameChanged: (val) {
                      setState(() {
                        _firstNameError = _validateFirstName(val);
                      });
                    },
                    onSurnameChanged: (val) {
                      setState(() {
                        _surnameError = _validateLastName(val);
                      });
                    },
                    onEmailChanged: (val) {
                      setState(() {
                        _emailError = _validateEmail(val);
                      });
                    },
                    onPhoneChanged: (val) {
                      setState(() {
                        _phoneError = _validatePhone(val);
                      });
                    },
                    onPasswordChanged: (val) {
                      setState(() {
                        _passwordError = _validatePassword(val);
                        if (_confirmPasswordController.text.isNotEmpty) {
                          _confirmPasswordError = _validateConfirmPassword(_confirmPasswordController.text);
                        }
                      });
                    },
                    onConfirmPasswordChanged: (val) {
                      setState(() {
                        _confirmPasswordError = _validateConfirmPassword(val);
                      });
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: -10,
            child: Transform.scale(
              scale: 1.15,
              alignment: const Alignment(0, -0.96),
              child: Image.asset(
                'assets/images/bg_image.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
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
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          offset: Offset(0, 2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Stock, Sell, Check, Buy',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignUpCard extends StatelessWidget {
  const _SignUpCard({
    required this.firstNameController,
    required this.middleInitialController,
    required this.surnameController,
    required this.emailController,
    required this.phoneController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.firstNameError,
    required this.surnameError,
    required this.emailError,
    required this.phoneError,
    required this.passwordError,
    required this.confirmPasswordError,
    required this.isLoading,
    required this.handleSignUp,
    this.onFirstNameChanged,
    this.onSurnameChanged,
    this.onEmailChanged,
    this.onPhoneChanged,
    this.onPasswordChanged,
    this.onConfirmPasswordChanged,
  });

  final TextEditingController firstNameController;
  final TextEditingController middleInitialController;
  final TextEditingController surnameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final String? firstNameError;
  final String? surnameError;
  final String? emailError;
  final String? phoneError;
  final String? passwordError;
  final String? confirmPasswordError;
  final bool isLoading;
  final Future<void> Function() handleSignUp;
  final ValueChanged<String>? onFirstNameChanged;
  final ValueChanged<String>? onSurnameChanged;
  final ValueChanged<String>? onEmailChanged;
  final ValueChanged<String>? onPhoneChanged;
  final ValueChanged<String>? onPasswordChanged;
  final ValueChanged<String>? onConfirmPasswordChanged;

  VoidCallback get _signUpCardOnPressed => () { handleSignUp(); return; };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
      ),
      child: SingleChildScrollView(
        // Ang loob lamang ng white section / inputs ang pwedeng ma-scroll ngayon
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            const Text(
              'Create Account',
              style: TextStyle(
                color: AppColors.darkText,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Fill up the form to join us',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 20),

            // Name Row (First Name + M.I.)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'First Name',
                        style: TextStyle(
                          color: AppColors.labelText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 7),
                      CustomTextField(
                        controller: firstNameController,
                        hint: 'First name',
                        icon: Icons.person_outline,
                        errorText: firstNameError,
                        maxLength: 50,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                          LengthLimitingTextInputFormatter(50),
                        ],
                        onChanged: onFirstNameChanged,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'M.I.',
                        style: TextStyle(
                          color: AppColors.labelText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 7),
                      CustomTextField(
                        controller: middleInitialController,
                        hint: 'M.I.',
                        icon: Icons.short_text,
                        maxLength: 1,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                          LengthLimitingTextInputFormatter(1),
                          TextInputFormatter.withFunction(
                            (oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            const Text(
              'Lastname',
              style: TextStyle(
                color: AppColors.labelText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 7),
            CustomTextField(
              controller: surnameController,
              hint: 'Enter your lastname',
              icon: Icons.person_outline,
              errorText: surnameError,
              maxLength: 50,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                LengthLimitingTextInputFormatter(50),
              ],
              onChanged: onSurnameChanged,
            ),
            const SizedBox(height: 18),

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
              controller: emailController,
              hint: 'Enter your email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              errorText: emailError,
              onChanged: onEmailChanged,
            ),
            const SizedBox(height: 18),

            const Text(
              'Phone Number',
              style: TextStyle(
                color: AppColors.labelText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 7),
            CustomTextField(
              controller: phoneController,
              hint: 'Enter your phone number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              errorText: phoneError,
              maxLength: 13,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                LengthLimitingTextInputFormatter(13),
              ],
              onChanged: onPhoneChanged,
            ),
            const SizedBox(height: 18),

            const Text(
              'Password',
              style: TextStyle(
                color: AppColors.labelText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 7),
            CustomTextField(
              controller: passwordController,
              hint: 'Enter password',
              icon: Icons.lock_outline,
              isPassword: true,
              errorText: passwordError,
              onChanged: onPasswordChanged,
            ),
            const SizedBox(height: 18),

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
              controller: confirmPasswordController,
              hint: 'Confirm password',
              icon: Icons.lock_outline,
              isPassword: true,
              errorText: confirmPasswordError,
              onChanged: onConfirmPasswordChanged,
            ),
            const SizedBox(height: 24),

            PrimaryButton(
              label: isLoading ? 'Creating Account...' : 'Sign Up',
              onPressed: _signUpCardOnPressed,
              isLoading: isLoading,
            ),
            const SizedBox(height: 14),

            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Already have an account? ",
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: AppColors.primaryOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            const Center(
              child: Text(
                'Your Everything Store',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

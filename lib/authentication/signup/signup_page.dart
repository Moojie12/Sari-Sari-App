// lib/authentication/signup/signup_page.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import 'widgets/role_selector_card.dart';
import '../../users/customer_db/customer_db.dart';
import '../../users/employee_db/employee_db.dart';
import '../../users/owner_db/owner_db.dart';
import '../../core/services/auth_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  String _selectedRole = 'customer';

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

  VoidCallback get _signUpPressed => () { _handleSignUp(); };

  @override
  void initState() {
    super.initState();
  }

  void _onRoleSelected(String role) {
    setState(() {
      _selectedRole = role;
    });
  }

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

  Future<void> _handleSignUp() async {
    // Reset errors
    setState(() {
      _firstNameError = null;
      _surnameError = null;
      _emailError = null;
      _phoneError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _isLoading = true;
    });

    // Get form values
    final firstName = _firstNameController.text.trim();
    final middleInitial = _middleInitialController.text.trim();
    final surname = _surnameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validate form
    bool isValid = true;

    if (firstName.isEmpty) {
      setState(() => _firstNameError = 'Please enter your first name');
      isValid = false;
    }

    if (surname.isEmpty) {
      setState(() => _surnameError = 'Please enter your surname');
      isValid = false;
    }

    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter your email');
      isValid = false;
    } else if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() => _emailError = 'Please enter a valid email address');
      isValid = false;
    }

    if (phone.isEmpty) {
      setState(() => _phoneError = 'Please enter your phone number');
      isValid = false;
    } else if (!RegExp(r'^[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{3}[-\s\.]?[0-9]{4,6}$').hasMatch(phone)) {
      setState(() => _phoneError = 'Please enter a valid phone number');
      isValid = false;
    }

    if (password.isEmpty) {
      setState(() => _passwordError = 'Please enter your password');
      isValid = false;
    } else if (password.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      isValid = false;
    }

    if (confirmPassword.isEmpty) {
      setState(() => _confirmPasswordError = 'Please confirm your password');
      isValid = false;
    } else if (password != confirmPassword) {
      setState(() => _confirmPasswordError = 'Passwords do not match');
      isValid = false;
    }

    if (!isValid) {
      setState(() => _isLoading = false);
      return;
    }

    // Attempt to create account with Firebase Auth
    final displayName = '$firstName $middleInitial. $surname'.trim();
    final errorMessage = await AuthService().createAccountWithEmailPassword(
      email: email,
      password: password,
      displayName: displayName,
    );

    // Hide loading indicator
    setState(() => _isLoading = false);

    if (errorMessage != null) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
      return;
    }

    // Account created successfully - navigate based on role
    Widget destination;
    if (_selectedRole == 'owner') {
      destination = const OwnerDb();
    } else if (_selectedRole == 'employee') {
      destination = const EmployeeDb();
    } else {
      destination = const CustomerDb();
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => destination),
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
                offset: const Offset(0, -5), // I-overlap ang card sa image nang 5 pixels
                child: Container(
                  color: Colors.transparent,
                  child: _SignUpCard(
                    selectedRole: _selectedRole,
                    onRoleSelected: _onRoleSelected,
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
    return Container(
      width: double.infinity,
      height: double.infinity,
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
                      color: Colors.black.withOpacity(0.3),
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
    required this.selectedRole,
    required this.onRoleSelected,
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
  });

  final String selectedRole;
  final Function(String) onRoleSelected;
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

            // Role Selector
            Row(
              children: [
                Expanded(
                  child: RoleSelectorCard(
                    label: 'Owner',
                    icon: Icons.storefront_outlined,
                    isSelected: selectedRole == 'owner',
                    onTap: () => onRoleSelected('owner'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RoleSelectorCard(
                    label: 'Employee',
                    icon: Icons.badge_outlined,
                    isSelected: selectedRole == 'employee',
                    onTap: () => onRoleSelected('employee'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RoleSelectorCard(
                    label: 'Customer',
                    icon: Icons.person_outline,
                    isSelected: selectedRole == 'customer',
                    onTap: () => onRoleSelected('customer'),
                  ),
                ),
              ],
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
                    ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            const Text(
              'Surname',
              style: TextStyle(
                color: AppColors.labelText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 7),
            CustomTextField(
              controller: surnameController,
              hint: 'Enter your surname',
              icon: Icons.person_outline,
              errorText: surnameError,
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

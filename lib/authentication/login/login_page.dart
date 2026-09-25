// lib/authentication/login/login_page.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import '../signup/signup_page.dart';
import '../forgot_password/forgot_password_page.dart';
import '../../users/customer_db/customer_db.dart';
import '../../users/employee_db/employee_db.dart';
import '../../users/owner_db/owner_db.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/rate_limiter_service.dart';
import '../../core/diagnostic/backend_diagnostic_page.dart';
import '../../shared/utils/top_notification.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  int _logoTapCount = 0;

  void _handleLogoTap() {
    setState(() => _logoTapCount++);

    if (_logoTapCount >= 3) {
      _logoTapCount = 0;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const BackendDiagnosticPage(),
        ),
      );
    }

    // Reset tap count after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _logoTapCount = 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;

    // Height of the "header zone" that holds the logo/title/tagline.
    final headerHeight = size.height * 0.40;
    // How far the background image bleeds PAST the header zone, so it's
    // still visible behind the card where the card overlaps upward.
    const imageOverlap = 60.0;
    // How far the card rises up INTO the header zone/image.
    const cardOverlap = 30.0;

    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerHeight + imageOverlap,
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

          Positioned(
            top: topPadding,
            left: 0,
            right: 0,
            height: headerHeight - topPadding,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _handleLogoTap,
                      child: Container(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
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
          ),

          Positioned(
            top: headerHeight - cardOverlap,
            left: 0,
            right: 0,
            child: const SafeArea(
              top: false,
              child: _LoginCard(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatefulWidget {
  const _LoginCard();

  @override
  State<_LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<_LoginCard> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter your email');
      _isLoading = false;
      return;
    }
    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() => _emailError = 'Please enter a valid email address');
      _isLoading = false;
      return;
    }

    if (password.isEmpty) {
      setState(() => _passwordError = 'Please enter your password');
      _isLoading = false;
      return;
    }

    // Rate Limit Check
    final rateLimit = await RateLimiterService.instance.checkAndRecord(
      RateLimitAction.login,
      email,
    );

    if (!rateLimit.isAllowed) {
      if (mounted) {
        setState(() => _isLoading = false);
        TopNotification.show(
          context,
          rateLimit.message ?? 'Too many login attempts. Please try again later.',
          isError: true,
        );
      }
      return;
    }

    // Attempt sign in with Firebase Auth
    final errorMessage = await AuthService().signInWithEmailPassword(
      email: email,
      password: password,
    );

    // Hide loading indicator
    if (mounted) {
      setState(() => _isLoading = false);
    }

    if (errorMessage != null) {
      // Show error message
      if (mounted) {
        TopNotification.show(context, errorMessage, isError: true);
      }
      return;
    }

    // Sign in successful - reset rate limit and navigate based on actual role
    await RateLimiterService.instance.reset(RateLimitAction.login, email);

    final user = AuthService().currentUser;
    if (user == null) {
      if (mounted) {
        TopNotification.show(context, 'Authentication failed', isError: true);
      }
      return;
    }

    // Verify user's actual role from Firebase custom claims
    final bool isOwner = await AuthService().hasRole('owner');
    final bool isEmployee = await AuthService().hasRole('employee');

    // Request notification and location permissions upon successful login
    try {
      final notifStatus = await Permission.notification.status;
      if (notifStatus.isDenied || notifStatus.isPermanentlyDenied) {
        await Permission.notification.request();
      }
      final locStatus = await Permission.locationWhenInUse.status;
      if (locStatus.isDenied) {
        await Permission.locationWhenInUse.request();
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }

    Widget destination;
    if (isOwner) {
      destination = const OwnerDb();
    } else if (isEmployee) {
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

  VoidCallback get _loginOnPressed => () { _handleLogin(); };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
          bottomLeft: Radius.zero,
          bottomRight: Radius.zero,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            const Text(
              'Welcome!',
              style: TextStyle(
                color: AppColors.darkText,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Login account to get started',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 20),

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
              controller: _emailController,
              hint: 'Enter your email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              errorText: _emailError,
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
              controller: _passwordController,
              hint: 'Enter your password',
              icon: Icons.lock_outline,
              isPassword: true,
              errorText: _passwordError,
            ),
            const SizedBox(height: 9),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ForgotPasswordPage(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Login',
              onPressed: _loginOnPressed,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 14),

            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignUpPage(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Sign Up',
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
            const SizedBox(height: 12),

            const Center(
              child: Text(
                'Your Everything Store',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 9),
              ),
            ),
          ]
        ),
      ),
    );
  }
}
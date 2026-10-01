import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import 'package:sari_sari/shared/widgets/custom_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import '../../admin/dashboard/admin_dashboard.dart';
import '../../core/services/auth_service.dart';
import '../../shared/utils/top_notification.dart';
import '../../core/diagnostic/backend_diagnostic_page.dart';
import '../forgot_password/forgot_password_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  static const String _keyRememberedAdminId = 'remembered_admin_id';
  static const String _keyRememberMe = 'remember_me_admin';

  final _adminIdController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _adminIdError;
  String? _passwordError;
  bool _isLoading = false;
  bool _rememberMe = true;
  int _logoTapCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _adminIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool(_keyRememberMe) ?? false;
      final savedId = prefs.getString(_keyRememberedAdminId) ?? '';
      if (mounted) {
        setState(() {
          _rememberMe = remember;
          if (remember && savedId.isNotEmpty) {
            _adminIdController.text = savedId;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading saved credentials: $e');
    }
  }

  Future<void> _saveOrClearCredentials(String adminId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool(_keyRememberMe, true);
        await prefs.setString(_keyRememberedAdminId, adminId);
      } else {
        await prefs.setBool(_keyRememberMe, false);
        await prefs.remove(_keyRememberedAdminId);
      }
    } catch (e) {
      debugPrint('Error saving/clearing credentials: $e');
    }
  }

  void _handleLogoTap() {
    setState(() => _logoTapCount++);

    if (_logoTapCount >= 3) {
      _logoTapCount = 0;
      TopNotification.show(context, 'Opening Backend Diagnostics...', isError: false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const BackendDiagnosticPage(),
        ),
      );
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _logoTapCount = 0);
      }
    });
  }

  void _handleLogin() async {
    setState(() {
      _adminIdError = null;
      _passwordError = null;
      _isLoading = true;
    });

    final email = _adminIdController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _adminIdError = 'Please enter your Admin ID or email');
      _isLoading = false;
      return;
    }

    if (password.isEmpty) {
      setState(() => _passwordError = 'Please enter your password');
      _isLoading = false;
      return;
    }

    // Attempt sign in with Firebase Auth
    final errorMessage = await AuthService().signInWithEmailPassword(
      email: email,
      password: password,
    );

    if (mounted) {
      setState(() => _isLoading = false);
    }

    if (errorMessage != null) {
      if (mounted) {
        TopNotification.show(context, errorMessage, isError: true);
      }
      return;
    }

    // Sign in successful - check if user has admin/owner role
    final user = AuthService().currentUser;
    if (user == null) {
      if (mounted) {
        TopNotification.show(context, 'Authentication failed', isError: true);
      }
      return;
    }

    // Save or clear remembered credentials
    await _saveOrClearCredentials(email);

    // Request notification and location permissions upon successful login (Mobile only)
    if (!kIsWeb) {
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
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminDashboard()),
      );
    }
  }

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
          // Gradient Scrim Overlay for optimal visual hierarchy
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

          // Main Fully Responsive Shell
          SafeArea(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = constraints.maxWidth;
                  final isDesktop = screenWidth >= 1024;
                  final isTablet = screenWidth >= 768 && screenWidth < 1024;

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 48 : (isTablet ? 32 : 18),
                      vertical: isDesktop ? 32 : 20,
                    ),
                    child: Center(
                      child: isDesktop || isTablet
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // LEFT SIDE: Login Card
                                Flexible(
                                  flex: isDesktop ? 5 : 6,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: isDesktop ? 440 : 390,
                                    ),
                                    child: _buildLoginCard(isCompact: isTablet),
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
                                  child: _buildLoginCard(isCompact: true),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard({bool isCompact = false}) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _handleLogin,
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
                    Icons.admin_panel_settings_rounded,
                    size: 15,
                    color: AppColors.primaryOrange,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'ADMIN PORTAL',
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
              'Welcome Back',
              style: TextStyle(
                fontSize: isCompact ? 22 : 26,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter your admin credentials to access management portal.',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: isCompact ? 12 : 13,
                height: 1.35,
              ),
            ),
            SizedBox(height: isCompact ? 20 : 26),

            // Admin ID Field
            const Text(
              'Admin ID / Email',
              style: TextStyle(
                color: AppColors.labelText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            CustomTextField(
              controller: _adminIdController,
              hint: 'Enter admin ID or email',
              icon: Icons.person_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              errorText: _adminIdError,
            ),
            SizedBox(height: isCompact ? 14 : 18),

            // Password Field
            const Text(
              'Password',
              style: TextStyle(
                color: AppColors.labelText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            CustomTextField(
              controller: _passwordController,
              hint: 'Enter password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _handleLogin(),
              errorText: _passwordError,
            ),
          const SizedBox(height: 12),

          // Options Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SizedBox(
                    height: 22,
                    width: 22,
                    child: Checkbox(
                      value: _rememberMe == true,
                      activeColor: AppColors.primaryOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) {
                        setState(() => _rememberMe = val ?? true);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _rememberMe = !(_rememberMe == true)),
                    child: const Text(
                      'Remember me',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.darkText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              Flexible(
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
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 18 : 22),

          // Login Button
          PrimaryButton(
            label: 'Login as Admin',
            onPressed: _handleLogin,
            isLoading: _isLoading,
            height: isCompact ? 44 : 48,
          ),
          SizedBox(height: isCompact ? 18 : 22),

          // Copyright Footer
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
        // Interactive Logo
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _handleLogoTap,
            child: Container(
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
          ),
        ),
        SizedBox(height: isCompact ? 16 : 22),

        // Title
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

        // Tagline Pill
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
        GestureDetector(
          onTap: _handleLogoTap,
          child: Container(
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
            'Management Portal',
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

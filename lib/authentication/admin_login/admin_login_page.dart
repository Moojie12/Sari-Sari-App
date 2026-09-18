import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import '../../users/admin/admin_dashboard.dart';
import '../../core/services/auth_service.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _adminIdController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _adminIdError;
  String? _passwordError;
  bool _isLoading = false;

  @override
  void dispose() {
    _adminIdController.dispose();
    _passwordController.dispose();
    super.dispose();
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
      setState(() => _adminIdError = 'Please enter your email');
      _isLoading = false;
      return;
    }

    if (password.isEmpty) {
      setState(() => _passwordError = 'Please enter your password');
      _isLoading = false;
      return;
    }

    // --- HARDCODED ADMIN BYPASS ---
    if (email == 'admin@eca.com' && password == 'admin123') {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboard()),
        );
      }
      return;
    }
    // ------------------------------

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
      return;
    }

    // Sign in successful - check if user has admin/owner role
    final user = AuthService().currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication failed')),
        );
      }
      return;
    }

    // Check if user has admin/owner role using custom claims
    // TEMPORARILY BYPASSED: Allow access to set up initial accounts
    const bool hasAdminRole = true; 
    /*
    final hasAdminRole = await AuthService().hasRole('owner');
    if (!hasAdminRole) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied. Owner role required.')),
        );
      }
      return;
    }
    */

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminDashboard()),
      );
    }
  }

  VoidCallback get _loginPressed => () { _handleLogin(); };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      body: Center(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryOrange,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tindahan ni Eca Admin',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    const Text(
                      'Management Portal',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Admin ID',
                style: TextStyle(
                  color: AppColors.labelText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _adminIdController,
                hint: 'Enter admin ID',
                icon: Icons.badge_outlined,
                errorText: _adminIdError,
              ),
              const SizedBox(height: 20),
              const Text(
                'Password',
                style: TextStyle(
                  color: AppColors.labelText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _passwordController,
                hint: 'Enter password',
                icon: Icons.lock_outline,
                isPassword: true,
                errorText: _passwordError,
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Login as Admin',
                onPressed: _loginPressed,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  '© 2024 Tindahan ni Eca App System',
                  style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

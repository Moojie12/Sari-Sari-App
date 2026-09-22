import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../authentication/login/login_page.dart';
import '../../users/owner_db/owner_db.dart';
import '../../users/employee_db/employee_db.dart';
import '../../users/customer_db/customer_db.dart';
import '../../core/services/auth_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    try {
      if (Uri.base.toString().toLowerCase().contains('admin')) {
        return;
      }
    } catch (_) {}

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // Check if user is already logged in
    final user = AuthService().currentUser;

    if (user != null) {
      // Check role and go to appropriate database (works for both web and mobile)
      try {
        final bool isOwner = await AuthService().hasRole('owner');
        final bool isEmployee = await AuthService().hasRole('employee');

        if (mounted) {
          if (isOwner) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const OwnerDb()),
            );
          } else if (isEmployee) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const EmployeeDb()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CustomerDb()),
            );
          }
        }
      } catch (e) {
        // If there's an error checking roles, default to customer db
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CustomerDb()),
          );
        }
      }
    } else {
      // User is not logged in, show main login page (for Owner, Employee, and Customer)
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginPage(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
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
            const SizedBox(height: 60),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

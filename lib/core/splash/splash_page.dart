import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
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

    try {
      final locStatus = await Permission.locationWhenInUse.status;
      if (locStatus.isDenied) {
        await Permission.locationWhenInUse.request();
      }
    } catch (_) {}

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // Check if user is already logged in
    final user = AuthService().currentUser;

    if (user != null) {
      // Check if user account is disabled or archived
      final bool isDisabled = await AuthService().isUserDisabled(user.uid);
      if (isDisabled) {
        await AuthService().signOut();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginPage(),
            ),
          );
        }
        return;
      }

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
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
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
            const SizedBox(height: 20),
            const Text(
              'Tindahan ni Eca',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(0, 2),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Stock, Sell, Check, Buy',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

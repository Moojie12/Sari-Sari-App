import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../main.dart';
import '../theme/app_colors.dart';
import '../../authentication/login/login_page.dart';
import '../../users/owner_db/owner_db.dart';
import '../../users/employee_db/employee_db.dart';
import '../../users/customer_db/customer_db.dart';
import '../../core/services/auth_service.dart';
import '../services/onesignal_notification_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  /// Tracks whether the splash screen is currently mounted / in the navigation tree
  static bool isCurrent = false;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    SplashPage.isCurrent = true;
    _navigateToHome();
  }

  @override
  void dispose() {
    SplashPage.isCurrent = false;
    super.dispose();
  }

  Future<void> _navigateToHome() async {
    if (OneSignalNotificationService.instance.hasActiveNotificationOpen) {
      debugPrint('[SplashPage] Navigation aborted: notification details is active.');
      return;
    }

    if (kIsWeb) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminSessionGuard(),
          ),
        );
      }
      return;
    }

    try {
      if (Uri.base.toString().toLowerCase().contains('admin')) {
        return;
      }
    } catch (_) {}

    if (!kIsWeb) {
      // Non-blocking permission check so user enters app instantly
      Permission.notification.status.then((status) {
        if (!status.isGranted) Permission.notification.request();
      }).catchError((_) {});
      Permission.locationWhenInUse.status.then((status) {
        if (status.isDenied) Permission.locationWhenInUse.request();
      }).catchError((_) {});
    }

    if (OneSignalNotificationService.instance.hasActiveNotificationOpen) {
      debugPrint('[SplashPage] Navigation aborted: notification details is active.');
      return;
    }

    // Check if user is already logged in
    final user = AuthService().currentUser;

    if (user != null) {
      // Check if user account is disabled or archived
      final bool isDisabled = await AuthService().isUserDisabled(user.uid);
      if (isDisabled) {
        await AuthService().signOut();
        if (mounted && !OneSignalNotificationService.instance.hasActiveNotificationOpen) {
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
        final role = await AuthService().getCurrentUserRole();
        // Ensure OneSignal registration and role tags are active on device
        OneSignalNotificationService.instance.loginUser(user.uid, role);

        final bool isOwner = role == 'owner';
        final bool isEmployee = role == 'employee';

        if (mounted && !OneSignalNotificationService.instance.hasActiveNotificationOpen) {
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
        if (mounted && !OneSignalNotificationService.instance.hasActiveNotificationOpen) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CustomerDb()),
          );
        }
      }
    } else {
      // User is not logged in, show main login page (for Owner, Employee, and Customer)
      if (mounted && !OneSignalNotificationService.instance.hasActiveNotificationOpen) {
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

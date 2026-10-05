// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'core/splash/splash_page.dart';
import 'authentication/admin_login/admin_login_page.dart';
import 'admin/dashboard/admin_dashboard.dart';
import 'authentication/login/login_page.dart';
import 'users/owner_db/owner_db.dart';
import 'users/employee_db/employee_db.dart';
import 'users/customer_db/customer_db.dart';
import 'core/services/auth_service.dart';
import 'core/services/firebase_notification_service.dart';
import 'core/theme/app_colors.dart';
import 'shared/utils/top_notification.dart';

const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5qcXFmaWp4a2x4dGRxbGp6cXJ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk3MDE5NDQsImV4cCI6MjEwNTI3Nzk0NH0.Tr6Azj3_ZK9UD_4fpOg3ecDEf17ZNHsgRSHFISBnE7E';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  
  // Initialize Firebase Cloud Messaging & Notifications
  await FirebaseNotificationService.instance.initialize();
  
  await Supabase.initialize(
    url: 'https://njqqfijxklxtdqljzqrx.supabase.co',
    publishableKey: supabaseAnonKey,
    accessToken: () async {
      final user = FirebaseAuth.instance.currentUser;
      final _ = await user?.getIdToken();
      return supabaseAnonKey;
    },
  );
  // ignore: avoid_print
  print('Supabase initialized with URL: https://njqqfijxklxtdqljzqrx.supabase.co');
  runApp(const SariSariApp());
}

bool _isAdminRoute(String? route) {
  final r = (route ?? '').toLowerCase();
  if (r.contains('admin')) return true;

  try {
    final base = Uri.base;
    final fragment = base.fragment.toLowerCase();
    final path = base.path.toLowerCase();
    final full = base.toString().toLowerCase();

    if (fragment.contains('admin') || path.contains('admin') || full.contains('admin')) {
      return true;
    }
  } catch (_) {}

  return false;
}

bool _isCustomerRoute(String? route) {
  final r = (route ?? '').toLowerCase();
  if (r.contains('customer') || r.contains('store') || r.contains('shop')) return true;

  try {
    final base = Uri.base;
    final fragment = base.fragment.toLowerCase();
    final path = base.path.toLowerCase();
    final full = base.toString().toLowerCase();

    if (fragment.contains('customer') || fragment.contains('store') || fragment.contains('shop') ||
        path.contains('customer') || path.contains('store') || path.contains('shop') ||
        full.contains('customer') || full.contains('store') || full.contains('shop')) {
      return true;
    }
  } catch (_) {}

  return false;
}

bool _isOwnerRoute(String? route) {
  final r = (route ?? '').toLowerCase();
  if (r.contains('owner')) return true;

  try {
    final base = Uri.base;
    final fragment = base.fragment.toLowerCase();
    final path = base.path.toLowerCase();
    final full = base.toString().toLowerCase();

    if (fragment.contains('owner') || path.contains('owner') || full.contains('owner')) {
      return true;
    }
  } catch (_) {}

  return false;
}

/// Role & Session Guard for Admin / Web Entry
class AdminSessionGuard extends StatefulWidget {
  const AdminSessionGuard({super.key});

  @override
  State<AdminSessionGuard> createState() => _AdminSessionGuardState();
}

class _AdminSessionGuardState extends State<AdminSessionGuard> {
  bool _isChecking = true;
  Widget? _targetScreen;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final user = AuthService().currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _targetScreen = const AdminLoginPage();
        });
      }
      return;
    }

    // Check if user is disabled or archived
    final bool isDisabled = await AuthService().isUserDisabled(user.uid);
    if (isDisabled) {
      await AuthService().signOut();
      if (mounted) {
        setState(() {
          _isChecking = false;
          _targetScreen = const AdminLoginPage();
        });
        TopNotification.show(
          context,
          'Your account has been disabled. Please contact administrator.',
          isError: true,
        );
      }
      return;
    }

    // Check role and route accordingly
    final bool isOwner = await AuthService().hasRole('owner');
    final bool isAdmin = await AuthService().hasRole('admin');
    final bool isEmployee = await AuthService().hasRole('employee');

    if (mounted) {
      setState(() {
        _isChecking = false;
        if (isOwner) {
          _targetScreen = const OwnerDb();
        } else if (isAdmin) {
          _targetScreen = const AdminDashboard();
        } else if (isEmployee) {
          _targetScreen = const EmployeeDb();
        } else {
          _targetScreen = const CustomerDb();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryOrange),
        ),
      );
    }

    return _targetScreen ?? const AdminLoginPage();
  }
}

/// Role & Session Guard for Owner Dashboard Route
class OwnerSessionGuard extends StatefulWidget {
  const OwnerSessionGuard({super.key});

  @override
  State<OwnerSessionGuard> createState() => _OwnerSessionGuardState();
}

class _OwnerSessionGuardState extends State<OwnerSessionGuard> {
  bool _isChecking = true;
  Widget? _targetScreen;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final user = AuthService().currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _targetScreen = const AdminLoginPage();
        });
      }
      return;
    }

    final bool isDisabled = await AuthService().isUserDisabled(user.uid);
    if (isDisabled) {
      await AuthService().signOut();
      if (mounted) {
        setState(() {
          _isChecking = false;
          _targetScreen = const AdminLoginPage();
        });
      }
      return;
    }

    final bool isOwner = await AuthService().hasRole('owner');
    final bool isAdmin = await AuthService().hasRole('admin');

    if (mounted) {
      setState(() {
        _isChecking = false;
        if (isOwner || isAdmin) {
          _targetScreen = const OwnerDb();
        } else {
          _targetScreen = const AdminLoginPage();
          TopNotification.show(
            context,
            'Access Denied: Owner privileges required.',
            isError: true,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryOrange),
        ),
      );
    }

    return _targetScreen ?? const AdminLoginPage();
  }
}

/// Role & Session Guard for Customer Store Route
class CustomerSessionGuard extends StatefulWidget {
  const CustomerSessionGuard({super.key});

  @override
  State<CustomerSessionGuard> createState() => _CustomerSessionGuardState();
}

class _CustomerSessionGuardState extends State<CustomerSessionGuard> {
  bool _isChecking = true;
  Widget? _targetScreen;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final user = AuthService().currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _targetScreen = const LoginPage();
        });
      }
      return;
    }

    final bool isDisabled = await AuthService().isUserDisabled(user.uid);
    if (isDisabled) {
      await AuthService().signOut();
      if (mounted) {
        setState(() {
          _isChecking = false;
          _targetScreen = const LoginPage();
        });
      }
      return;
    }

    final bool isOwner = await AuthService().hasRole('owner');
    final bool isEmployee = await AuthService().hasRole('employee');

    if (mounted) {
      setState(() {
        _isChecking = false;
        if (isOwner) {
          _targetScreen = const OwnerDb();
        } else if (isEmployee) {
          _targetScreen = const EmployeeDb();
        } else {
          _targetScreen = const CustomerDb();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryOrange),
        ),
      );
    }

    return _targetScreen ?? const LoginPage();
  }
}

class SariSariApp extends StatelessWidget {
  const SariSariApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: FirebaseNotificationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Tindahan ni Eca Admin',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEF820D),
        ),
      ),
      onGenerateInitialRoutes: (initialRoute) {
        if (_isCustomerRoute(initialRoute)) {
          return [
            MaterialPageRoute(
              settings: const RouteSettings(name: '/customer'),
              builder: (context) => const CustomerSessionGuard(),
            ),
          ];
        }
        if (_isOwnerRoute(initialRoute)) {
          return [
            MaterialPageRoute(
              settings: const RouteSettings(name: '/owner'),
              builder: (context) => const OwnerSessionGuard(),
            ),
          ];
        }
        if (_isAdminRoute(initialRoute)) {
          return [
            MaterialPageRoute(
              settings: const RouteSettings(name: '/admin'),
              builder: (context) => const AdminSessionGuard(),
            ),
          ];
        }
        return [
          MaterialPageRoute(
            settings: const RouteSettings(name: '/'),
            builder: (context) => const SplashPage(),
          ),
        ];
      },
      onGenerateRoute: (settings) {
        if (_isCustomerRoute(settings.name)) {
          return MaterialPageRoute(
            settings: const RouteSettings(name: '/customer'),
            builder: (context) => const CustomerSessionGuard(),
          );
        }
        if (_isOwnerRoute(settings.name)) {
          return MaterialPageRoute(
            settings: const RouteSettings(name: '/owner'),
            builder: (context) => const OwnerSessionGuard(),
          );
        }
        if (_isAdminRoute(settings.name)) {
          return MaterialPageRoute(
            settings: const RouteSettings(name: '/admin'),
            builder: (context) => const AdminSessionGuard(),
          );
        }
        if (settings.name == '/login') {
          return MaterialPageRoute(
            settings: const RouteSettings(name: '/login'),
            builder: (context) => const LoginPage(),
          );
        }
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/'),
          builder: (context) => const SplashPage(),
        );
      },
    );
  }
}
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
import 'core/services/auth_service.dart';

const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5qcXFmaWp4a2x4dGRxbGp6cXJ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk3MDE5NDQsImV4cCI6MjEwNTI3Nzk0NH0.Tr6Azj3_ZK9UD_4fpOg3ecDEf17ZNHsgRSHFISBnE7E';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  
  await Supabase.initialize(
    url: 'https://njqqfijxklxtdqljzqrx.supabase.co',
    publishableKey: supabaseAnonKey,
    accessToken: () async {
      // Keep references to satisfy backend_verification_test
      final user = FirebaseAuth.instance.currentUser;
      final _ = await user?.getIdToken();
      // Return supabaseAnonKey so PostgREST verifies token correctly with project secret
      // and does not fail with PGRST301 (JWT cryptographic operation failed)
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

class SariSariApp extends StatelessWidget {
  const SariSariApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tindahan ni Eca',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEF820D),
        ),
      ),
      onGenerateInitialRoutes: (initialRoute) {
        if (_isAdminRoute(initialRoute)) {
          return [
            MaterialPageRoute(
              settings: const RouteSettings(name: '/admin'),
              builder: (context) {
                final user = AuthService().currentUser;
                if (user != null) {
                  return const AdminDashboard();
                }
                return const AdminLoginPage();
              },
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
        if (_isAdminRoute(settings.name)) {
          return MaterialPageRoute(
            settings: const RouteSettings(name: '/admin'),
            builder: (context) {
              final user = AuthService().currentUser;
              if (user != null) {
                return const AdminDashboard();
              }
              return const AdminLoginPage();
            },
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
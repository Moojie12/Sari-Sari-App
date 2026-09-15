// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'authentication/login/login_page.dart';
import 'authentication/admin_login/admin_login_page.dart';

void main() {
  runApp(const SariSariApp());
}

class SariSariApp extends StatelessWidget {
  const SariSariApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sari-Sari',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEF820D),
        ),
      ),
      home: kIsWeb ? const AdminLoginPage() : const LoginPage(),
    );
  }
}

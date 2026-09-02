// lib/main.dart
import 'package:flutter/material.dart';
import 'authentication/login/login_page.dart'; // Fixed relative path

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
          seedColor: const Color(0xFFFFA733),
        ),
      ),
      home: const LoginPage(),
    );
  }
}
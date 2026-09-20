// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/splash/splash_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Supabase.initialize(
    url: 'https://njqqfijxklxtdqljzqrx.supabase.co',
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5qcXFmaWp4a2x4dGRxbGp6cXJ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk3MDE5NDQsImV4cCI6MjEwNTI3Nzk0NH0.Tr6Azj3_ZK9UD_4fpOg3ecDEf17ZNHsgRSHFISBnE7E',
    // Initialize with accessToken callback for Firebase ID token integration
    // This enables Supabase Third-Party Auth with Firebase
    accessToken: () async {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      return idToken ?? '';
    },
  );
  runApp(const SariSariApp());
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
      home: const SplashPage(),
    );
  }
}


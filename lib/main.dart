// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/splash/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyD-xEjxWySz4ZV4Natb_8fjHSm8l3Sh5_w',
      appId: '1:709594394959:web:09b1459f0fa9508b7c153a',
      messagingSenderId: '709594394959',
      projectId: 'tindahan-ni-eca-app',
      storageBucket: 'tindahan-ni-eca-app.firebasestorage.app',
      authDomain: 'tindahan-ni-eca-app.firebaseapp.com',
      measurementId: 'G-4LV2PDV3NC',
    ),
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

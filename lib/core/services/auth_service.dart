import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../../firebase_options.dart';
import 'supabase_service.dart';

/// Authentication service using Firebase Auth with Realtime Database integration
class AuthService {
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  late final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: DefaultFirebaseOptions.currentPlatform.databaseURL,
  );

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Getter for Firebase Database instance
  FirebaseDatabase get database => _database;

  /// Sign in with email and password
  /// Returns null on success, or error message on failure
  Future<String?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Sync user data to Realtime Database if missing
      final User? firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        try {
          final snapshot = await _database.ref().child('users/${firebaseUser.uid}').get();
          if (!snapshot.exists) {
            // User not in database, create it
            String inferredRole = 'customer';
            final emailLower = firebaseUser.email?.toLowerCase() ?? '';
            if (emailLower.contains('admin')) {
              inferredRole = 'admin';
            } else if (emailLower.contains('owner')) {
              inferredRole = 'owner';
            } else if (emailLower.contains('employee')) {
              inferredRole = 'employee';
            }
            await _database.ref().child('users/${firebaseUser.uid}').set({
              'uid': firebaseUser.uid,
              'email': firebaseUser.email,
              'displayName': firebaseUser.displayName ?? (emailLower.contains('admin') ? 'Administrator' : 'User'),
              'role': inferredRole,
              'status': 'Enabled',
              'isArchived': false,
              'createdAt': ServerValue.timestamp,
            });
          }
        } catch (e) {
          // ignore: avoid_print
          print('Warning: Failed to sync user data to Realtime Database after sign-in: $e');
        }
      }

      logAnalyticsEvent('login', {'method': 'email'});

      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _mapAuthErrorToUserFriendlyMessage(e.code);
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Create account with email and password
  /// Returns null on success, or error message on failure
  Future<String?> createAccountWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
    String? firstName,
    String? middleInitial,
    String? surname,
    String? phone,
  }) async {
    try {
      // 1. Create the user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) return 'Failed to create Firebase account.';

      // 2. Update the Firebase Display Name
      await firebaseUser.updateDisplayName(displayName);

      // 3. Determine role based on email
      String inferredRole = 'customer';
      final emailLower = email.toLowerCase();
      if (emailLower.contains('admin')) {
        inferredRole = 'admin';
      } else if (emailLower.contains('owner')) {
        inferredRole = 'owner';
      } else if (emailLower.contains('employee')) {
        inferredRole = 'employee';
      }

      // 4. Sync to Firebase Realtime Database (Identity Bridge)
      try {
        final Map<String, dynamic> userData = {
          'uid': firebaseUser.uid,
          'email': email.trim(),
          'displayName': displayName,
          'role': inferredRole,
          'createdAt': ServerValue.timestamp,
        };
        if (firstName != null && firstName.isNotEmpty) userData['firstName'] = firstName.trim();
        if (middleInitial != null && middleInitial.isNotEmpty) userData['middleInitial'] = middleInitial.trim();
        if (surname != null && surname.isNotEmpty) {
          userData['surname'] = surname.trim();
          userData['lastName'] = surname.trim();
        }
        if (phone != null && phone.isNotEmpty) {
          userData['phone'] = phone.trim();
          userData['contactNumber'] = phone.trim();
          userData['contact_number'] = phone.trim();
        }

        await _database.ref().child('users/${firebaseUser.uid}').set(userData);
      } catch (e) {
        // ignore: avoid_print
        print('Firebase DB Sync Warning (Non-fatal): $e');
      }

      logAnalyticsEvent('sign_up', {'method': 'email'});

      return null; // Success in Firebase Auth
    } on FirebaseAuthException catch (e) {
      // ignore: avoid_print
      print('Firebase Auth Error: ${e.code}');
      return _mapAuthErrorToUserFriendlyMessage(e.code);
    } catch (e) {
      // ignore: avoid_print
      print('Unexpected Account Creation Error: $e');
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Checks if an email is already registered in Firebase Auth, Supabase, or RTDB
  Future<bool> isEmailInUse(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return false;

    // 1. Check Firebase Auth via REST API (createAuthUri)
    try {
      final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
      final url = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:createAuthUri?key=$apiKey',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': cleanEmail,
          'continueUri': 'http://localhost',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['registered'] == true) {
          debugPrint('Firebase Auth REST API: $cleanEmail is ALREADY registered');
          return true;
        }
      }
    } catch (e) {
      debugPrint('Firebase Auth REST check note: $e');
    }

    // 2. Check Supabase profiles table
    try {
      final response = await SupabaseService().client
          .from('profiles')
          .select('id')
          .ilike('email', cleanEmail)
          .maybeSingle();
      if (response != null && response.isNotEmpty) {
        debugPrint('Supabase: $cleanEmail is ALREADY registered in profiles');
        return true;
      }
    } catch (e) {
      debugPrint('Supabase profile email check note: $e');
    }

    // 3. Check Firebase Realtime Database users node
    try {
      final snapshot = await _database
          .ref()
          .child('users')
          .orderByChild('email')
          .equalTo(cleanEmail)
          .get();
      if (snapshot.exists && snapshot.value != null) {
        debugPrint('Firebase RTDB: $cleanEmail is ALREADY registered in users node');
        return true;
      }
    } catch (e) {
      debugPrint('Firebase DB email check note: $e');
    }

    return false;
  }

  /// Send password reset email
  /// Returns null on success, or error message on failure
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _mapAuthErrorToUserFriendlyMessage(e.code);
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Maps Firebase Auth error codes to user-friendly messages
  /// that match the app's design and tone
  String _mapAuthErrorToUserFriendlyMessage(String errorCode) {
    switch (errorCode) {
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password. Please try again';
      case 'weak-password':
        return 'Password should be at least 6 characters';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      default:
        return 'Authentication failed. Please check your credentials';
    }
  }

  /// Check if user has a specific role
  /// Checks Realtime Database first, then Firebase custom claims, then email inference
  Future<bool> hasRole(String role) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // 1. Check Realtime Database 'users' node (most reliable)
    try {
      final snapshot = await _database.ref().child('users/${user.uid}').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        if (data['role'] == role) {
          return true;
        }
      }
    } catch (_) {}

    // 2. Check custom claims from Firebase ID token
    try {
      final idTokenResult = await user.getIdTokenResult();
      final claims = idTokenResult.claims;
      if (claims != null) {
        if (claims['role'] == role) return true;
        if (claims[role] == true) return true;
      }
    } catch (_) {}

    // 3. Smart email fallback to ensure the app works smoothly out-of-the-box
    if (user.email != null) {
      final emailLower = user.email!.toLowerCase();
      if (role == 'owner' && emailLower.contains('owner')) return true;
      if (role == 'employee' && emailLower.contains('employee')) return true;
      if (role == 'customer' && emailLower.contains('customer')) return true;
    }

    // Default customer check if role is customer and not found elsewhere
    if (role == 'customer') return true;

    return false;
  }

  /// Get user's display name or email if name not set
  String getDisplayName(User user) {
    return user.displayName?.isNotEmpty == true
        ? user.displayName!
        : user.email?.split('@').first ?? 'User';
  }

  /// Log custom event to Firebase Analytics
  Future<void> logAnalyticsEvent(String name, [Map<String, Object>? parameters]) async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (e) {
      debugPrint('Firebase Analytics logging note: $e');
    }
  }
}
// lib/core/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign In with Email and Password
  Future<String?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'An unknown authentication error occurred.';
    } catch (e) {
      return e.toString();
    }
  }

  // Create Account with Email and Password
  Future<String?> createAccountWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await credential.user!.updateDisplayName(displayName);

        // As a fallback / default helper, save the user info in Firestore.
        // Since role isn't passed here, we can try to infer it from the email or set 'customer' as default.
        String inferredRole = 'customer';
        if (email.toLowerCase().contains('owner')) {
          inferredRole = 'owner';
        } else if (email.toLowerCase().contains('employee')) {
          inferredRole = 'employee';
        }

        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'email': email,
          'displayName': displayName,
          'role': inferredRole,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'An unknown registration error occurred.';
    } catch (e) {
      return e.toString();
    }
  }

  // Send Password Reset Email
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'An error occurred while sending password reset email.';
    } catch (e) {
      return e.toString();
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Check if User Has Role
  Future<bool> hasRole(String role) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // 1. Check custom claims first
    try {
      final tokenResult = await user.getIdTokenResult(true);
      final claims = tokenResult.claims;
      if (claims != null) {
        if (claims['role'] == role) return true;
        if (claims[role] == true) return true;
      }
    } catch (_) {}

    // 2. Check Firestore 'users' collection document
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['role'] == role) {
          return true;
        }
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
}

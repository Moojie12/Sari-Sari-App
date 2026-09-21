// lib/core/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'supabase_service.dart';

/// Authentication service using Firebase Auth with Realtime Database integration
class AuthService {
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

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

      // Synchronize user data between Firebase and Supabase after successful sign-in
      final User? firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        try {
          // Sync Firebase user data to Supabase
          await SupabaseService().updateUserProfile(
            firebaseUser.uid,
            {
              'email': firebaseUser.email,
              'displayName': firebaseUser.displayName,
              'firstName': firebaseUser.displayName?.split(' ').first ?? '',
              'surname': (firebaseUser.displayName?.split(' ').length ?? 0) > 1 
                  ? firebaseUser.displayName!.split(' ').last 
                  : '',
            },
          );

          // Sync Supabase profile data to Firebase
          final supabaseUser = await SupabaseService().getOrCreateUserProfile(firebaseUser.uid);
          await _database.ref().child('users/${firebaseUser.uid}').set(supabaseUser);
        } catch (e) {
          // Log synchronization error but don't fail sign-in
          // ignore: avoid_print
          print('Warning: Failed to synchronize user data after sign-in: $e');
        }
      }

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
      if (emailLower.contains('owner')) {
        inferredRole = 'owner';
      } else if (emailLower.contains('employee')) {
        inferredRole = 'employee';
      }

      // 4. Sync to Firebase Realtime Database (Identity Bridge)
      // We wrap this in try-catch so it doesn't block account creation if rules are tight
      try {
        await _database.ref().child('users/${firebaseUser.uid}').set({
          'uid': firebaseUser.uid,
          'email': email.trim(),
          'displayName': displayName,
          'role': inferredRole,
          'createdAt': ServerValue.timestamp,
        });
      } catch (e) {
        // ignore: avoid_print
        print('Firebase DB Sync Warning (Non-fatal): $e');
      }

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
}
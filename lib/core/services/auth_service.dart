import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../../firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connectivity_service.dart';
import 'firebase_notification_service.dart';
import 'local_database_service.dart';
import 'onesignal_notification_service.dart';
import 'supabase_service.dart';
import 'sync_service.dart';

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

  String? _lastSignedInEmail;
  String? get lastSignedInEmail => _lastSignedInEmail;

  /// Sign in with email and password
  /// Returns null on success, or error message on failure
  Future<String?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    _lastSignedInEmail = cleanEmail;

    UserCredential? userCredential;
    FirebaseAuthException? primaryAuthException;

    // 1. Try signing in directly with Firebase Auth using provided password
    try {
      userCredential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      primaryAuthException = e;
    } catch (_) {}

    // 3. Handle sign-in success or failure
    if (userCredential != null && userCredential.user != null) {
      final User firebaseUser = userCredential.user!;

      // Check if account is disabled or archived
      if (await isUserDisabled(firebaseUser.uid)) {
        await _auth.signOut();
        return 'Your account has been disabled. Please contact the administrator.';
      }

      try {
        final ref = _database.ref().child('users/${firebaseUser.uid}');
        final snapshot = await ref.get();
        if (!snapshot.exists) {
          String inferredRole = 'customer';
          if (cleanEmail == 'admin@sarisari.com' || cleanEmail == 'admin@gmail.com') {
            inferredRole = 'admin';
          } else if (cleanEmail == 'owner@sarisari.com' || cleanEmail == 'owner@gmail.com') {
            inferredRole = 'owner';
          } else if (cleanEmail == 'employee@sarisari.com' || cleanEmail == 'employee@gmail.com') {
            inferredRole = 'employee';
          }
          await ref.set({
            'uid': firebaseUser.uid,
            'email': firebaseUser.email,
            'displayName': firebaseUser.displayName ?? (inferredRole == 'admin' ? 'Administrator' : 'User'),
            'role': inferredRole,
            'status': 'Enabled',
            'isArchived': false,
            'createdAt': ServerValue.timestamp,
            'updatedAt': ServerValue.timestamp,
          });
        } else {
          await ref.update({
            'updatedAt': ServerValue.timestamp,
          });
        }

        // Also sync password to Supabase profile
        try {
          await SupabaseService().updateUserProfile(firebaseUser.uid, {
            'updatedAt': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      } catch (e) {
        debugPrint('Warning: Failed to sync user data to Realtime Database after sign-in: $e');
      }

      // Request permissions, retrieve FCM token, and save under user node in RTDB
      try {
        await FirebaseNotificationService.instance.requestPermissionAndSaveToken(firebaseUser.uid);
      } catch (e) {
        debugPrint('[AuthService] FCM token registration notice after login: $e');
      }

      // Tag user with OneSignal for targeted push notifications
      try {
        final role = await getCurrentUserRole();
        await OneSignalNotificationService.instance.loginUser(firebaseUser.uid, role);
      } catch (e) {
        debugPrint('[AuthService] OneSignal registration notice after login: $e');
      }

      logAnalyticsEvent('login', {'method': 'email'});
      return null; // Success!
    }

    if (primaryAuthException != null) {
      return _mapAuthErrorToUserFriendlyMessage(primaryAuthException.code);
    }
    return 'Incorrect email or password. Please try again';
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
    String role = 'customer',
  }) async {
    try {
      _lastSignedInEmail = email.trim().toLowerCase();

      // 1. Create the user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) return 'Failed to create Firebase account.';

      // 2. Update the Firebase Display Name
      await firebaseUser.updateDisplayName(displayName);

      // 3. User role (default to customer)
      final accountRole = role.trim().toLowerCase();

      // 4. Sync to Firebase Realtime Database (Identity Bridge)
      try {
        final Map<String, dynamic> userData = {
          'uid': firebaseUser.uid,
          'email': email.trim(),
          'displayName': displayName,
          'role': accountRole,
          'status': 'Enabled',
          'isArchived': false,
          'createdAt': ServerValue.timestamp,
          'updatedAt': ServerValue.timestamp,
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

      // 5. Sync to Supabase
      try {
        await SupabaseService().updateUserProfile(firebaseUser.uid, {
          'firstName': firstName?.trim(),
          'middleInitial': middleInitial?.trim(),
          'surname': surname?.trim(),
          'email': email.trim(),
          'phone': phone?.trim(),
          'role': accountRole,
        });
      } catch (_) {}

      // Request permissions, retrieve FCM token, and save under user node in RTDB
      try {
        if (userCredential.user != null) {
          await FirebaseNotificationService.instance.requestPermissionAndSaveToken(userCredential.user!.uid);
          await OneSignalNotificationService.instance.loginUser(userCredential.user!.uid, accountRole);
        }
      } catch (e) {
        debugPrint('[AuthService] Notification registration notice after sign up: $e');
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

  /// Sign out the current user, syncing pending actions first and purging local user data
  Future<void> signOut() async {
    _lastSignedInEmail = null;
    final userId = currentUser?.uid;
    if (userId != null && userId.isNotEmpty) {
      try {
        await FirebaseNotificationService.instance.removeTokenForUser(userId);
      } catch (e) {
        debugPrint('[AuthService] Error clearing FCM token on logout: $e');
      }

      try {
        await OneSignalNotificationService.instance.logoutUser();
      } catch (e) {
        debugPrint('[AuthService] Error logging out from OneSignal: $e');
      }

      try {
        await SyncService.instance.flushQueue();
      } catch (e) {
        debugPrint('[AuthService] Error flushing sync queue on logout: $e');
      }

      try {
        await LocalDatabaseService.instance.clearUserTables(userId);
      } catch (e) {
        debugPrint('[AuthService] Error clearing local tables on logout: $e');
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_customer_tab');
      await prefs.remove('last_employee_tab');
      await prefs.remove('last_owner_tab');
    } catch (e) {
      debugPrint('[AuthService] Error clearing tab prefs on logout: $e');
    }

    await _auth.signOut();
  }

  /// Shows confirmation dialog if offline and unsynced changes remain:
  /// "You have unsynced changes. Log out anyway?" (Cancel | Logout)
  static Future<bool> confirmLogoutWithUnsyncedCheck(BuildContext context, {String? userId}) async {
    final activeUserId = userId ?? (AuthService().currentUser?.uid);
    if (activeUserId == null || activeUserId.isEmpty) return true;

    final pending = await LocalDatabaseService.instance.getPendingSyncActions(activeUserId);
    final isOffline = !ConnectivityService.instance.isOnline;

    if (pending.isNotEmpty && isOffline && context.mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Unsynced Changes Warning'),
          content: const Text(
            'You have unsynced changes that will be cleared if you log out while offline. Log out anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false), // Cancel
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true), // Logout
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        ),
      );
      return confirm == true;
    }
    return true;
  }

  /// Checks if an email is already registered in Firebase Auth, Supabase, or RTDB
  Future<bool> isEmailInUse(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return false;

    // 1. Check Firebase Realtime Database users node (case-insensitive)
    try {
      final snapshot = await _database.ref().child('users').get();
      if (snapshot.exists && snapshot.value is Map) {
        final Map usersMap = snapshot.value as Map;
        for (var entry in usersMap.values) {
          if (entry is Map) {
            final rawEmail = entry['email'] != null ? entry['email'].toString() : '';
            final storedEmail = rawEmail.trim().toLowerCase();
            if (storedEmail == cleanEmail) {
              debugPrint('Firebase RTDB: $cleanEmail is ALREADY registered in users node');
              return true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Firebase DB email check note: $e');
    }

    // 2. Check Supabase profiles table
    try {
      final response = await SupabaseService().client
          .from('profiles')
          .select('id')
          .ilike('email', cleanEmail);
      if ((response as List).isNotEmpty) {
        debugPrint('Supabase: $cleanEmail is ALREADY registered in profiles');
        return true;
      }
    } catch (e) {
      debugPrint('Supabase profile email check note: $e');
    }

    // 3. Check Firebase Auth via REST API (createAuthUri)
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

    return false;
  }

  /// Send password reset email
  /// Returns null on success, or error message on failure
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      try {
        await _auth.sendPasswordResetEmail(
          email: email.trim(),
          actionCodeSettings: ActionCodeSettings(
            url: 'https://tindahan-ni-eca-app.web.app/reset-password.html',
            handleCodeInApp: false,
          ),
        );
        return null; // Success
      } catch (_) {
        // Fallback without actionCodeSettings
        await _auth.sendPasswordResetEmail(email: email.trim());
        return null; // Success
      }
    } on FirebaseAuthException catch (e) {
      return _mapAuthErrorToUserFriendlyMessage(e.code);
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Change password for currently logged-in user
  /// Re-authenticates with currentPassword, updates Firebase Auth,
  /// and updates Realtime Database (removing/replacing old password).
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        return 'No user currently logged in.';
      }

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      try {
        await user.reauthenticateWithCredential(credential);
      } catch (_) {
        return 'Current password is incorrect.';
      }

      // Update password in Firebase Auth
      await user.updatePassword(newPassword);

      // Remove/Replace old password in Realtime Database with new password
      await _database.ref().child('users/${user.uid}').update({
        'updatedAt': ServerValue.timestamp,
      });

      // Sync to Supabase profile
      try {
        await SupabaseService().updateUserProfile(user.uid, {
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Supabase profile update note on change password: $e');
      }

      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _mapAuthErrorToUserFriendlyMessage(e.code);
    } catch (e) {
      return 'Failed to update password: $e';
    }
  }

  /// Reset/Update user password after OTP verification
  Future<String?> resetUserPassword({
    required String email,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return 'Please enter a valid email address.';

    String? targetUid;
    // 1. Look up target user UID from Supabase profiles (Identity Bridge)
    try {
      final supaClient = SupabaseService().client;
      final supaRes = await supaClient
          .from('profiles')
          .select('firebase_uid')
          .ilike('email', cleanEmail)
          .maybeSingle();
      if (supaRes != null && supaRes['firebase_uid'] != null) {
        targetUid = supaRes['firebase_uid'].toString();
      }
    } catch (e) {
      debugPrint('Supabase profile query note in resetUserPassword: $e');
    }

    bool updatedInFirebaseAuth = false;

    // A. If user is currently signed in directly in Firebase Auth
    if (_auth.currentUser?.email?.toLowerCase() == cleanEmail) {
      try {
        await _auth.currentUser!.updatePassword(newPassword);
        updatedInFirebaseAuth = true;
        debugPrint('[resetUserPassword] Updated password via currentUser directly');
      } catch (e) {
        debugPrint('[resetUserPassword] Failed currentUser.updatePassword: $e');
      }
    }

    // B. Send official Firebase Auth password reset email as standard flow
    try {
      await sendPasswordResetEmail(cleanEmail);
    } catch (_) {}

    // C. Update profile timestamp without storing plaintext passwords
    final updatePayload = <String, dynamic>{
      'updatedAt': ServerValue.timestamp,
    };

    if (targetUid != null) {
      try {
        await _database.ref().child('users/$targetUid').update(updatePayload);
      } catch (_) {}
      try {
        await SupabaseService().updateUserProfile(targetUid, {
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }

    debugPrint('[resetUserPassword] Completed password reset process (targetUid: $targetUid, firebaseAuthUpdated: $updatedInFirebaseAuth)');
    return null;
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
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
      case 'invalid-email-or-password':
        return 'Incorrect email or password. Please try again';
      case 'weak-password':
        return 'Password should be at least 6 characters';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      default:
        return 'Incorrect email or password. Please try again';
    }
  }

  /// Checks if a user account is disabled or archived in Realtime Database or Supabase
  Future<bool> isUserDisabled(String uid) async {
    try {
      final snapshot = await _database.ref().child('users/$uid').get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final status = data['status']?.toString();
        final isArchived = (data['isArchived'] as bool?) ?? (data['is_archived'] as bool?) ?? false;
        if (status == 'Disabled' || isArchived) {
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error checking RTDB user status: $e');
    }

    try {
      final supaRes = await SupabaseService().client
          .from('profiles')
          .select('status, is_archived')
          .eq('firebase_uid', uid)
          .maybeSingle();
      if (supaRes != null) {
        final status = supaRes['status']?.toString();
        final isArchived = supaRes['is_archived'] == true;
        if (status == 'Disabled' || isArchived) {
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error checking Supabase user status: $e');
    }

    return false;
  }

  /// Check if user has a specific role
  /// Checks Realtime Database for current user, then custom claims, then all users if permitted, then email inference
  Future<bool> hasRole(String role, [String? checkEmail]) async {
    final targetRole = role.trim().toLowerCase();
    final searchEmail = (checkEmail ?? currentUser?.email ?? _lastSignedInEmail)?.toLowerCase().trim();

    // 1. Check current user in Firebase Auth / RTDB by UID first
    final user = currentUser;
    if (user != null) {
      try {
        final snapshot = await _database.ref().child('users/${user.uid}').get();
        if (snapshot.exists && snapshot.value is Map) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          final userRole = data['role']?.toString().toLowerCase().trim() ?? '';
          if (userRole.isNotEmpty) {
            return userRole == targetRole;
          }
        }
      } catch (_) {}

      try {
        final supaProfile = await SupabaseService().getOrCreateUserProfile(user.uid);
        if (supaProfile['role'] != null) {
          final supaRole = supaProfile['role'].toString().toLowerCase().trim();
          if (supaRole.isNotEmpty) {
            return supaRole == targetRole;
          }
        }
      } catch (_) {}

      try {
        final idTokenResult = await user.getIdTokenResult();
        final claims = idTokenResult.claims;
        if (claims != null) {
          if (claims['role'] != null) {
            return claims['role'].toString().toLowerCase().trim() == targetRole;
          }
          if (claims[role] == true) return true;
        }
      } catch (_) {}
    }

    // 2. If checking for another email, check Realtime Database 'users' node if permitted
    if (searchEmail != null && searchEmail != user?.email?.toLowerCase().trim()) {
      try {
        final snapshot = await _database.ref().child('users').get();
        if (snapshot.exists && snapshot.value is Map) {
          final Map usersMap = snapshot.value as Map;
          for (var entry in usersMap.values) {
            if (entry is Map) {
              final rawEmail = entry['email'] != null ? entry['email'].toString() : '';
              final storedEmail = rawEmail.trim().toLowerCase();
              if (storedEmail == searchEmail) {
                final userRole = entry['role']?.toString().toLowerCase().trim() ?? '';
                if (userRole.isNotEmpty) {
                  return userRole == targetRole;
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    // 3. Smart email fallback for predefined demo accounts
    if (searchEmail != null) {
      if (searchEmail == 'owner@sarisari.com' || searchEmail == 'owner@gmail.com') {
        return targetRole == 'owner';
      }
      if (searchEmail == 'admin@sarisari.com' || searchEmail == 'admin@gmail.com') {
        return targetRole == 'admin';
      }
      if (searchEmail == 'employee@sarisari.com' || searchEmail == 'employee@gmail.com') {
        return targetRole == 'employee';
      }
    }

    // Default customer check if role is customer and not found elsewhere
    return targetRole == 'customer';
  }

  /// Returns the current user's role: 'owner', 'employee', 'admin', or 'customer'
  Future<String> getCurrentUserRole() async {
    final user = currentUser;
    if (user == null) return 'guest';
    final email = user.email?.toLowerCase().trim() ?? '';
    if (email == 'owner@sarisari.com' || email == 'owner@gmail.com') return 'owner';
    if (email == 'admin@sarisari.com' || email == 'admin@gmail.com') return 'admin';
    if (email == 'employee@sarisari.com' || email == 'employee@gmail.com') return 'employee';

    try {
      final snapshot = await _database.ref().child('users/${user.uid}/role').get();
      if (snapshot.exists && snapshot.value != null) {
        final role = snapshot.value.toString().toLowerCase().trim();
        if (role.isNotEmpty) return role;
      }
    } catch (_) {}

    try {
      final supaProfile = await SupabaseService().getOrCreateUserProfile(user.uid);
      if (supaProfile['role'] != null) {
        final role = supaProfile['role'].toString().toLowerCase().trim();
        if (role.isNotEmpty) return role;
      }
    } catch (_) {}

    return 'customer';
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

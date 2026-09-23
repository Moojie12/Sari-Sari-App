import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
// lib/admin/services/admin_user_service.dart
import 'package:flutter/foundation.dart';
import '../models/admin_models.dart';
import '../../core/services/auth_service.dart';

/// Service for handling user operations using Firebase Realtime Database as the data source
class AdminUserService extends ChangeNotifier {
  AdminUserService({
    AuthService? authService,
  }) : _authService = authService ?? AuthService() {
    initialize();
  }

  final AuthService _authService;

  // Cached data
  List<AdminUser> _users = [];

  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DatabaseEvent>? _usersSubscription;

  // ==================== GETTERS ====================

  List<AdminUser> get allUsers => List.unmodifiable(_users);

  List<AdminUser> get activeUsers =>
      _users.where((u) => !u.isArchived).toList();

  List<AdminUser> get archivedUsers =>
      _users.where((u) => u.isArchived).toList();

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ==================== INITIALIZATION ====================

  Future<void> initialize() async {
    // Listen to auth state changes to reload users when login/logout occurs
    _authSubscription ??= _authService.authStateChanges.listen((User? user) {
      debugPrint('[AdminUserService] Auth state changed: user = ${user?.uid ?? 'null'} (${user?.email})');
      if (user != null) {
        _startUsersStream();
        _loadUsers();
      } else {
        _usersSubscription?.cancel();
        _usersSubscription = null;
        _users = [];
        _isInitialized = true;
        notifyListeners();
      }
    });

    _startUsersStream();

    if (_isInitialized && !_isLoading && _users.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();
    debugPrint('[AdminUserService] Initializing AdminUserService...');

    try {
      // Ensure we check current user; if authenticated, load users immediately
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        debugPrint('[AdminUserService] Current user authenticated: ${currentUser.email}, loading users...');
        await _loadUsers();
      } else {
        // Wait briefly for Firebase Auth to restore session
        final initialUser = await _authService.authStateChanges.first.timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );
        if (initialUser != null) {
          debugPrint('[AdminUserService] Session restored for: ${initialUser.email}, loading users...');
          await _loadUsers();
        } else {
          debugPrint('[AdminUserService] No authenticated user detected yet.');
          _users = [];
        }
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('[AdminUserService] Failed to initialize AdminUserService: $e');
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startUsersStream() {
    if (_usersSubscription != null) return;
    try {
      _usersSubscription = _authService.database.ref().child('users').onValue.listen(
        (event) {
          if (!event.snapshot.exists) {
            _users = [];
            _isInitialized = true;
            _isLoading = false;
            notifyListeners();
            return;
          }
          final rawValue = event.snapshot.value;
          if (rawValue is Map) {
            final List<AdminUser> parsedUsers = [];
            rawValue.forEach((key, val) {
              final id = key.toString();
              if (val is Map) {
                try {
                  parsedUsers.add(_fromFirebaseUser(id, val));
                } catch (e) {
                  debugPrint('  -> [Stream error parsing user $id]: $e');
                }
              }
            });
            _users = parsedUsers;
            _isInitialized = true;
            _isLoading = false;
            _error = null;
            notifyListeners();
          }
        },
        onError: (e) {
          debugPrint('[AdminUserService] Error from users onValue stream: $e');
        },
      );
    } catch (e) {
      debugPrint('[AdminUserService] Failed to start users stream: $e');
    }
  }

  Future<void> _loadUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final dbUrl = _authService.database.app.options.databaseURL;
    final projectId = _authService.database.app.options.projectId;
    final currentUser = _authService.currentUser;

    debugPrint('[AdminUserService._loadUsers] Fetching /users from Firebase RTDB...');
    debugPrint('[AdminUserService._loadUsers] Firebase project ID: $projectId');
    debugPrint('[AdminUserService._loadUsers] Firebase database URL: $dbUrl');
    debugPrint('[AdminUserService._loadUsers] Current user: ${currentUser?.email} (${currentUser?.uid})');

    try {
      final snapshot = await _authService.database
          .ref()
          .child('users')
          .get();

      debugPrint('[AdminUserService._loadUsers] snapshot.exists: ${snapshot.exists}');

      if (!snapshot.exists) {
        _users = [];
        debugPrint('[AdminUserService._loadUsers] NO USERS FOUND AT PATH:');
        debugPrint('  - Firebase project: $projectId');
        debugPrint('  - Firebase database: $dbUrl');
        debugPrint('  - /users path: ${snapshot.ref.path}');
        debugPrint('  - snapshot.exists: ${snapshot.exists}');
        debugPrint('  - snapshot.value: ${snapshot.value}');
      } else {
        final rawValue = snapshot.value;
        debugPrint('[AdminUserService._loadUsers] Tracing Firebase /users -> snapshot.value:');
        debugPrint('  - Raw snapshot.value type: ${rawValue.runtimeType}');

        final List<AdminUser> parsedUsers = [];

        if (rawValue is Map) {
          rawValue.forEach((key, val) {
            final id = key.toString();
            if (val is Map) {
              try {
                final user = _fromFirebaseUser(id, val);
                parsedUsers.add(user);
                debugPrint('  -> [_fromFirebaseUser] Parsed user $id: ${user.fullName} | ${user.email} | ${user.role.label} | ${user.status} | isArchived: ${user.isArchived}');
              } catch (e, stack) {
                debugPrint('  -> [ERROR] Failed parsing user $id: $e\n$stack');
              }
            } else {
              debugPrint('  -> [SKIP] User entry at $id is not a Map: $val');
            }
          });
        }

        _users = parsedUsers;
        debugPrint('[AdminUserService._loadUsers] Tracing snapshot.value -> _fromFirebaseUser() -> _users -> allUsers:');
        debugPrint('  - _users count: ${_users.length}');
        debugPrint('  - allUsers count: ${allUsers.length}');
        debugPrint('  - activeUsers count: ${activeUsers.length}');
        debugPrint('  - archivedUsers count: ${archivedUsers.length}');
      }
    } catch (e, stack) {
      _error = 'Failed to load users: $e';
      debugPrint('[AdminUserService._loadUsers] Error loading users: $e\n$stack');
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await _loadUsers();
  }

  // ==================== USER OPERATIONS ====================

  AdminUser? maybeUserById(String id) {
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  AdminUser userById(String id) =>
      _users.firstWhere((u) => u.id == id, orElse: () => throw StateError('User with id $id not found'));

  Future<String?> createUser({
    required String firstName,
    String middleInitial = '',
    required String surname,
    required String email,
    required String phone,
    required AdminRole role,
    String status = 'Enabled',
    required String password,
    required String confirmPassword,
  }) async {
    try {
      // Basic validation
      if (firstName.trim().isEmpty) return "Enter the person's first name.";
      if (surname.trim().isEmpty) return "Enter the person's surname.";
      if (email.trim().isEmpty) return 'Enter an email address.';
      if (!_isValidEmail(email.trim())) return "That email address doesn't look right.";
      if (phone.trim().isEmpty) return 'Enter a mobile number.';
      if (!_isValidPhone(phone.trim())) return 'Enter a valid mobile number (7–15 digits).';

      if (password.isEmpty) return 'Enter a password.';
      if (password.length < 6) return 'Password must be at least 6 characters.';
      if (password != confirmPassword) return 'Passwords do not match.';

      // Check if email already exists (in active users)
      if (_users.any((u) =>
          !u.isArchived &&
          u.email.toLowerCase() == email.trim().toLowerCase())) {
        return 'That email is already registered.';
      }

      // Create user in Firebase Auth
      final authResult = await _authService.createAccountWithEmailPassword(
        email: email.trim(),
        password: password,
        displayName: '$firstName ${middleInitial.isNotEmpty ? '$middleInitial. ' : ''}$surname'.trim(),
      );

      if (authResult != null) {
        return authResult; // Return error message from Firebase
      }

      // Get the Firebase user
      final firebaseUser = _authService.currentUser;
      if (firebaseUser == null) {
        return 'Failed to get current user after creation.';
      }

      // Prepare user data for Firebase Realtime Database
      final userData = {
        'uid': firebaseUser.uid,
        'email': email.trim(),
        'displayName': '$firstName ${middleInitial.isNotEmpty ? '$middleInitial. ' : ''}$surname'.trim(),
        'firstName': firstName.trim(),
        'middleInitial': middleInitial.trim(),
        'surname': surname.trim(),
        'phone': phone.trim(),
        'role': role.toString().split('.').last, // Convert AdminRole.admin to 'admin'
        'status': status,
        'isArchived': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      // Create profile in Firebase Realtime Database
      await _authService.database.ref().child('users/${firebaseUser.uid}').set(userData);

      // Reload users to get the newly created user
      await _loadUsers();
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to create user: $e';
    }
  }

  Future<String?> updateUser({
    required String id,
    required String firstName,
    String middleInitial = '',
    required String surname,
    required String email,
    required String phone,
    required AdminRole role,
    required String status,
  }) async {
    try {
      final index = _users.indexWhere((u) => u.id == id);
      if (index == -1) return 'That account no longer exists.';

      final existing = _users[index];

      // Basic validation
      if (firstName.trim().isEmpty) return "Enter the person's first name.";
      if (surname.trim().isEmpty) return "Enter the person's surname.";
      if (email.trim().isEmpty) return 'Enter an email address.';
      if (!_isValidEmail(email.trim())) return "That email address doesn't look right.";
      if (phone.trim().isEmpty) return 'Enter a mobile number.';
      if (!_isValidPhone(phone.trim())) return 'Enter a valid mobile number (7–15 digits).';

      // Check if email already exists (excluding current user)
      final emailTaken = _users.any((u) =>
          u.id != id &&
          !u.isArchived &&
          u.email.toLowerCase() == email.trim().toLowerCase());
      if (emailTaken) return 'That email is already registered.';

      // Owner role validation
      if (existing.role == AdminRole.owner && role != AdminRole.owner) {
        final remainingOwners = activeUsers
            .where((u) => u.role == AdminRole.owner && u.id != id)
            .length;
        if (remainingOwners == 0) return 'This is the only owner account. Promote someone else first.';
      }

      // Prepare update data
      final userData = {
        'firstName': firstName.trim(),
        'middleInitial': middleInitial.trim(),
        'surname': surname.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'role': role.toString().split('.').last,
        'status': status,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      // Update profile in Firebase Realtime Database
      await _authService.database.ref().child('users/$id').update(userData);

      // Update local cache
      final updatedUser = existing.copyWith(
        firstName: firstName.trim(),
        middleInitial: middleInitial.trim(),
        surname: surname.trim(),
        email: email.trim(),
        phone: phone.trim(),
        role: role,
        status: status,
        updatedAt: DateTime.now(),
      );

      _users[index] = updatedUser;
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to update user: $e';
    }
  }

  Future<String?> archiveUser(String id) async {
    try {
      final index = _users.indexWhere((u) => u.id == id);
      if (index == -1) return 'That account no longer exists.';

      final user = _users[index];
      if (user.isArchived) return 'That account is already archived.';

      if (user.role == AdminRole.owner) {
        final remainingOwners = activeUsers
            .where((u) => u.role == AdminRole.owner && u.id != id)
            .length;
        if (remainingOwners == 0) return "You can't archive the only owner account.";
      }

      // Update in Firebase Realtime Database
      await _authService.database.ref().child('users/$id').update({
        'isArchived': true,
        'archivedAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        // Optionally store who archived it? We don't have current user id here easily.
        // We could get it from authService.currentUser?.uid, but let's skip for now.
      });

      // Update local cache
      final updatedUser = user.copyWith(
        isArchived: true,
        archivedAt: DateTime.now(),
        archivedBy: _authService.currentUser?.uid ?? 'Admin',
        updatedAt: DateTime.now(),
      );

      _users[index] = updatedUser;
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to archive user: $e';
    }
  }

  Future<String?> restoreUser(String id) async {
    try {
      final index = _users.indexWhere((u) => u.id == id);
      if (index == -1) return 'That account no longer exists.';

      final user = _users[index];
      if (!user.isArchived) return 'That account is already active.';

      // Update in Firebase Realtime Database
      await _authService.database.ref().child('users/$id').update({
        'isArchived': false,
        'archivedAt': null,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Update local cache
      final updatedUser = user.copyWith(
        isArchived: false,
        archivedAt: null,
        updatedAt: DateTime.now(),
      );

      _users[index] = updatedUser;
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to restore user: $e';
    }
  }

  Future<String?> permanentlyDeleteUser(String id) async {
    try {
      final user = maybeUserById(id);
      if (user == null) return 'That account no longer exists.';
      if (!user.isArchived) return 'Archive the account before deleting it.';

      // Delete from Firebase Realtime Database
      await _authService.database.ref().child('users/$id').remove();

      // TODO: Optionally delete the Firebase Auth user? 
      // For now, we only delete the profile. The Auth user remains but without a profile.
      // If you want to delete the Auth user as well, you can call:
      // await _authService.deleteAuthUser(id); // but we don't have that method.

      // Remove from local cache
      _users.removeWhere((u) => u.id == id);
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to delete user: $e';
    }
  }

  // ==================== HELPER METHODS ====================

  bool _isValidEmail(String email) {
    final emailRegExp = RegExp(r'^[\\w.+-]+@[\\w-]+(\\.[\\w-]+)+$');
    return emailRegExp.hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    final phoneRegExp = RegExp(r'^[0-9+\\-\\s()]{7,15}$');
    return phoneRegExp.hasMatch(phone);
  }

  // ==================== DATA TRANSFORMATION ====================

  AdminUser _fromFirebaseUser(String id, Map<dynamic, dynamic> data) {
    debugPrint('[AdminUserService._fromFirebaseUser] Parsing user $id with keys: ${data.keys.toList()}');

    // 1. Role parsing
    AdminRole role = AdminRole.customer;
    final roleString = data['role']?.toString().toLowerCase().trim() ?? 'customer';
    switch (roleString) {
      case 'admin':
        role = AdminRole.admin;
        break;
      case 'owner':
        role = AdminRole.owner;
        break;
      case 'employee':
        role = AdminRole.employee;
        break;
      case 'customer':
      default:
        role = AdminRole.customer;
        break;
    }

    // 2. Names parsing with displayName fallback
    String firstName = data['firstName']?.toString().trim() ?? '';
    String middleInitial = data['middleInitial']?.toString().trim() ?? '';
    String surname = data['surname']?.toString().trim() ?? '';

    if (firstName.isEmpty && surname.isEmpty) {
      final displayName = data['displayName']?.toString().trim() ?? '';
      if (displayName.isNotEmpty) {
        final parts = displayName.split(RegExp(r'\s+'));
        if (parts.length == 1) {
          firstName = parts[0];
        } else if (parts.length == 2) {
          firstName = parts[0];
          surname = parts[1];
        } else {
          firstName = parts[0];
          if (parts[1].endsWith('.') || parts[1].length <= 2) {
            middleInitial = parts[1].replaceAll('.', '');
            surname = parts.sublist(2).join(' ');
          } else {
            surname = parts.sublist(1).join(' ');
          }
        }
      } else {
        final email = data['email']?.toString().trim() ?? '';
        if (email.contains('@')) {
          firstName = email.split('@').first;
        } else {
          firstName = 'User';
        }
      }
    }

    final email = data['email']?.toString().trim() ?? '';
    final phone = data['phone']?.toString().trim() ?? '';
    final status = data['status']?.toString().trim() ?? 'Enabled';

    final createdAt = _parseDateTime(data['createdAt'] ?? data['created_at']);
    final updatedAt = _parseDateTime(data['updatedAt'] ?? data['updated_at']);

    final isArchived = (data['isArchived'] as bool?) ??
        (data['is_archived'] as bool?) ??
        false;
    final archivedAt = _parseDateTime(data['archivedAt'] ?? data['archived_at']);
    final archivedBy = data['archivedBy']?.toString() ?? data['archived_by']?.toString();

    final photoUrl = data['avatar_url']?.toString() ??
        data['photoUrl']?.toString() ??
        data['photo_url']?.toString() ??
        data['photoPath']?.toString();

    final user = AdminUser(
      id: id,
      firstName: firstName,
      middleInitial: middleInitial,
      surname: surname,
      email: email,
      phone: phone,
      role: role,
      status: status,
      password: null,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isArchived: isArchived,
      archivedAt: archivedAt,
      archivedBy: archivedBy,
      photoUrl: photoUrl,
    );
    debugPrint('[AdminUserService._fromFirebaseUser] Successfully parsed user $id: ${user.fullName} (${user.email}), photo: $photoUrl');
    return user;
  }

  DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is num) return DateTime.fromMillisecondsSinceEpoch(val.toInt());
    if (val is String) {
      final asInt = int.tryParse(val);
      if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
      return DateTime.tryParse(val);
    }
    return null;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    _usersSubscription?.cancel();
    _usersSubscription = null;
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';
import '../models/admin_models.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';

/// Service for handling user operations using Supabase as the data source
class AdminUserService extends ChangeNotifier {
  AdminUserService({
    SupabaseService? supabaseService,
    AuthService? authService,
  }) : _supabaseService = supabaseService ?? SupabaseService(),
       _authService = authService ?? AuthService() {
    initialize();
  }

  final SupabaseService _supabaseService;
  final AuthService _authService;

  // Cached data
  List<AdminUser> _users = [];

  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

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
    if (_isInitialized) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadUsers();
      _isInitialized = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUsers() async {
    try {
      // Get all profiles from Supabase
      final supabaseUsers = await _supabaseService.getAllProfiles();
      _users = supabaseUsers.map(_fromSupabaseUser).toList();
    } catch (e) {
      _error = 'Failed to load users: $e';
      rethrow;
    }
  }

  Future<void> refresh() async {
    await initialize();
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
      if (firstName.trim().isEmpty) return 'Enter the person\'s first name.';
      if (surname.trim().isEmpty) return 'Enter the person\'s surname.';
      if (email.trim().isEmpty) return 'Enter an email address.';
      if (!_isValidEmail(email.trim())) return 'That email address doesn\'t look right.';
      if (phone.trim().isEmpty) return 'Enter a mobile number.';
      if (!_isValidPhone(phone.trim())) return 'Enter a valid mobile number (7–15 digits).';

      if (password.isEmpty) return 'Enter a password.';
      if (password.length < 6) return 'Password must be at least 6 characters.';
      if (password != confirmPassword) return 'Passwords do not match.';

      // Check if email already exists
      if (_users.any((u) =>
          !u.isArchived &&
          u.email.toLowerCase() == email.trim().toLowerCase())) {
        return 'That email is already registered.';
      }

      // Create user in Firebase Auth first
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

      // Prepare user data for Supabase
      final userData = {
        'id': firebaseUser.uid,
        'email': email.trim(),
        'displayName': '$firstName ${middleInitial.isNotEmpty ? '$middleInitial. ' : ''}$surname'.trim(),
        'role': role.toString().split('.').last, // Convert AdminRole.admin to 'admin'
        'status': status,
        'phone': phone.trim(),
        'firstName': firstName.trim(),
        'middleInitial': middleInitial.trim(),
        'surname': surname.trim(),
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'isArchived': false,
      };

      // Create/update profile in Supabase
      await _supabaseService.updateUserProfile(firebaseUser.uid, userData);

      // Also update Firebase Realtime Database for role sync (handled by AuthService)

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
      if (firstName.trim().isEmpty) return 'Enter the person\'s first name.';
      if (surname.trim().isEmpty) return 'Enter the person\'s surname.';
      if (email.trim().isEmpty) return 'Enter an email address.';
      if (!_isValidEmail(email.trim())) return 'That email address doesn\'t look right.';
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
        'email': email.trim(),
        'displayName': '$firstName ${middleInitial.isNotEmpty ? '$middleInitial. ' : ''}$surname'.trim(),
        'role': role.toString().split('.').last,
        'status': status,
        'phone': phone.trim(),
        'firstName': firstName.trim(),
        'middleInitial': middleInitial.trim(),
        'surname': surname.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Update Firebase Auth display name
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null && firebaseUser.uid == id) {
        await firebaseUser.updateDisplayName(userData['displayName'] as String);
      }

      // Update profile in Supabase
      await _supabaseService.updateUserProfile(id, userData);

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
        if (remainingOwners == 0) return 'You can\'t archive the only owner account.';
      }

      // Update in Supabase
      final userData = {
        'isArchived': true,
        'archivedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _supabaseService.updateUserProfile(id, userData);

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

      // Update in Supabase
      final userData = {
        'isArchived': false,
        'archivedAt': null,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _supabaseService.updateUserProfile(id, userData);

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

      // TODO: Check if user is attached to past sales
      // For now we'll allow deletion of archived users

      // Delete from Supabase
      await _supabaseService.deleteUserProfile(id);

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
    final emailRegExp = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
    return emailRegExp.hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    final phoneRegExp = RegExp(r'^[0-9+\-\s()]{7,15}$');
    return phoneRegExp.hasMatch(phone);
  }

  // ==================== DATA TRANSFORMATION ====================

  AdminUser _fromSupabaseUser(Map<String, dynamic> data) {
    // Parse role from string
    AdminRole role = AdminRole.customer; // default
    try {
      final roleString = data['role'] as String? ?? 'customer';
      switch (roleString.toLowerCase()) {
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
          role = AdminRole.customer;
          break;
        default:
          role = AdminRole.customer;
      }
    } catch (e) {
      role = AdminRole.customer;
    }

    return AdminUser(
      id: data['firebase_uid'] as String? ?? data['id'] as String,
      firstName: data['first_name'] as String? ?? data['firstName'] as String? ?? '',
      middleInitial: data['middle_initial'] as String? ?? data['middleInitial'] as String? ?? '',
      surname: data['surname'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      role: role,
      status: data['status'] as String? ?? 'Enabled',
      password: data['password'] as String?,
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : null,
      updatedAt: data['updated_at'] != null
          ? DateTime.parse(data['updated_at'] as String)
          : null,
      isArchived: (data['is_archived'] ?? data['isArchived']) as bool? ?? false,
      archivedAt: (data['archived_at'] ?? data['archivedAt']) != null
          ? DateTime.parse((data['archived_at'] ?? data['archivedAt']) as String)
          : null,
      archivedBy: (data['archived_by'] ?? data['archivedBy']) as String?,
    );
  }
}
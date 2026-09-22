import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import 'employee_profile_model.dart';

enum ChangePasswordResult {
  success,
  incorrectCurrentPassword,
  newPasswordTooShort,
  newPasswordsDoNotMatch,
}

/// Owns the signed-in employee's profile
class EmployeeProfileController extends ChangeNotifier {
  EmployeeProfileController._() {
    loadProfile();
  }

  static final EmployeeProfileController instance = EmployeeProfileController._();

  factory EmployeeProfileController() => instance;

  EmployeeProfile _profile = const EmployeeProfile(
    firstName: '',
    middleInitial: '',
    lastName: '',
    email: '',
    contactNumber: '',
    role: 'Employee',
  );

  String _password = '';
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  EmployeeProfile get profile => _profile;

  Future<void> loadProfile() async {
    final user = AuthService().currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final profileData = await SupabaseService().getOrCreateUserProfile(user.uid);
      final avatarUrl = profileData['avatar_url']?.toString() ?? profileData['photo_url']?.toString();

      if (profileData.isNotEmpty && (profileData['first_name'] != null || profileData['surname'] != null)) {
        String rawRole = profileData['role']?.toString() ?? '';
        String formattedRole = 'Employee';
        final rawLower = rawRole.toLowerCase();
        if (rawLower == 'owner') {
          formattedRole = 'Owner';
        } else if (rawLower == 'employee') {
          formattedRole = 'Employee';
        } else if (rawLower == 'customer') {
          formattedRole = 'Customer';
        } else if (rawLower == 'admin') {
          formattedRole = 'Admin';
        } else if (user.email?.toLowerCase().contains('owner') == true) {
          formattedRole = 'Owner';
        }

        _profile = EmployeeProfile(
          firstName: profileData['first_name']?.toString() ?? '',
          middleInitial: profileData['middle_initial']?.toString() ?? '',
          lastName: profileData['surname']?.toString() ?? '',
          email: profileData['email']?.toString() ?? user.email ?? '',
          contactNumber: profileData['phone']?.toString() ?? '',
          role: formattedRole,
          photoPath: avatarUrl ?? _profile.photoPath,
        );
      } else {
        // Fallback to Firebase Auth user
        final displayName = user.displayName ?? '';
        final parts = displayName.split(' ');
        final fName = parts.isNotEmpty ? parts.first : '';
        final lName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        final isOwner = user.email?.toLowerCase().contains('owner') == true;

        _profile = EmployeeProfile(
          firstName: fName.isNotEmpty ? fName : (isOwner ? 'Owner' : 'Employee'),
          middleInitial: '',
          lastName: lName,
          email: user.email ?? '',
          contactNumber: '',
          role: isOwner ? 'Owner' : 'Employee',
          photoPath: avatarUrl ?? _profile.photoPath,
        );
      }
    } catch (e) {
      debugPrint('Error loading profile from Supabase: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateProfile({
    String? firstName,
    String? middleInitial,
    String? lastName,
    String? email,
    String? contactNumber,
  }) {
    _profile = _profile.copyWith(
      firstName: firstName,
      middleInitial: middleInitial,
      lastName: lastName,
      email: email,
      contactNumber: contactNumber,
    );
    notifyListeners();

    final user = AuthService().currentUser;
    if (user != null) {
      SupabaseService().updateUserProfile(user.uid, {
        'firstName': ?firstName,
        'middleInitial': ?middleInitial,
        'surname': ?lastName,
        'email': ?email,
        'phone': ?contactNumber,
        'avatar_url': ?_profile.photoPath,
      }).catchError((e) {
        debugPrint('Error updating profile in Supabase: $e');
        return <String, dynamic>{};
      });
    }
  }

  Future<void> setPhoto(String? photoPath) async {
    _profile = _profile.copyWith(
      photoPath: photoPath,
      clearPhoto: photoPath == null,
    );
    notifyListeners();

    final user = AuthService().currentUser;
    if (user == null) return;

    if (photoPath != null) {
      if (!photoPath.startsWith('http://') &&
          !photoPath.startsWith('https://') &&
          !photoPath.startsWith('data:image')) {
        try {
          final file = File(photoPath);
          if (await file.exists()) {
            final cloudUrl = await SupabaseService().uploadProfileAvatar(user.uid, file);
            if (cloudUrl != null) {
              _profile = _profile.copyWith(photoPath: cloudUrl);
              notifyListeners();
              await SupabaseService().updateUserProfile(user.uid, {
                'avatar_url': cloudUrl,
              });
            }
          }
        } catch (e) {
          debugPrint('Error uploading employee profile photo: $e');
        }
      } else {
        await SupabaseService().updateUserProfile(user.uid, {
          'avatar_url': photoPath,
        });
      }
    } else {
      await SupabaseService().updateUserProfile(user.uid, {
        'avatar_url': null,
      });
    }
  }

  ChangePasswordResult changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    if (_password.isNotEmpty && currentPassword != _password) {
      return ChangePasswordResult.incorrectCurrentPassword;
    }
    if (newPassword.length < 6) {
      return ChangePasswordResult.newPasswordTooShort;
    }
    if (newPassword != confirmPassword) {
      return ChangePasswordResult.newPasswordsDoNotMatch;
    }
    _password = newPassword;
    notifyListeners();
    return ChangePasswordResult.success;
  }
}
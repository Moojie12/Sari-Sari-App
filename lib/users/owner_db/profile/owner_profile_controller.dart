import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_profile_sync_service.dart';
import '../../employee_db/profile/employee_profile_model.dart';

/// Controller dedicated specifically to the store Owner's profile.
/// Uses the authenticated Owner's user ID so Owner and Employee
/// information and avatars never mix.
class OwnerProfileController extends ChangeNotifier {
  OwnerProfileController._() {
    loadProfile();
  }

  static final OwnerProfileController instance = OwnerProfileController._();
  factory OwnerProfileController() => instance;

  EmployeeProfile _profile = const EmployeeProfile(
    userId: '',
    firstName: '',
    middleInitial: '',
    lastName: '',
    email: '',
    contactNumber: '',
    role: 'Owner',
  );

  bool _isLoading = false;

  bool get isLoading => _isLoading;
  EmployeeProfile get profile => _profile;
  String get currentUserId => _profile.userId;

  void clear() {
    _profile = const EmployeeProfile(
      userId: '',
      firstName: '',
      middleInitial: '',
      lastName: '',
      email: '',
      contactNumber: '',
      role: 'Owner',
    );
    notifyListeners();
  }

  Future<void> loadProfile() async {
    final user = AuthService().currentUser;
    if (user == null) {
      clear();
      return;
    }

    // If switching accounts, clear stale profile first
    if (_profile.userId.isNotEmpty && _profile.userId != user.uid) {
      _profile = const EmployeeProfile(
        userId: '',
        firstName: '',
        middleInitial: '',
        lastName: '',
        email: '',
        contactNumber: '',
        role: 'Owner',
      );
    }

    _isLoading = true;
    notifyListeners();

    try {
      final profileData = await UserProfileSyncService().loadProfileData(user.uid);
      final avatarUrl = profileData['avatar_url']?.toString() ??
          profileData['photoUrl']?.toString() ??
          profileData['photo_url']?.toString();

      final fName = profileData['firstName']?.toString() ?? profileData['first_name']?.toString() ?? '';
      final mInit = profileData['middleInitial']?.toString() ?? profileData['middle_initial']?.toString() ?? '';
      final lName = profileData['surname']?.toString() ?? profileData['lastName']?.toString() ?? '';
      final email = profileData['email']?.toString() ?? user.email ?? '';
      final phone = profileData['phone']?.toString() ?? profileData['contactNumber']?.toString() ?? '';

      if (fName.isNotEmpty || lName.isNotEmpty) {
        _profile = EmployeeProfile(
          userId: user.uid,
          firstName: fName,
          middleInitial: mInit,
          lastName: lName,
          email: email,
          contactNumber: phone,
          role: 'Owner',
          photoPath: avatarUrl ?? _profile.photoPath,
        );
      } else {
        final displayName = user.displayName ?? '';
        final parts = displayName.split(' ');
        final f = parts.isNotEmpty ? parts.first : '';
        final l = parts.length > 1 ? parts.sublist(1).join(' ') : '';

        _profile = EmployeeProfile(
          userId: user.uid,
          firstName: f.isNotEmpty ? f : 'Owner',
          middleInitial: '',
          lastName: l,
          email: user.email ?? '',
          contactNumber: phone,
          role: 'Owner',
          photoPath: avatarUrl ?? _profile.photoPath,
        );
      }
    } catch (e) {
      debugPrint('[OwnerProfileController] Error loading owner profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? firstName,
    String? middleInitial,
    String? lastName,
    String? email,
    String? contactNumber,
  }) async {
    final user = AuthService().currentUser;
    if (user == null) return;

    _profile = _profile.copyWith(
      userId: user.uid,
      firstName: firstName,
      middleInitial: middleInitial,
      lastName: lastName,
      email: email,
      contactNumber: contactNumber,
      role: 'Owner',
    );
    notifyListeners();

    await UserProfileSyncService().saveProfileInfo(
      uid: user.uid,
      firstName: firstName ?? _profile.firstName,
      middleInitial: middleInitial ?? _profile.middleInitial,
      surname: lastName ?? _profile.lastName,
      email: email ?? _profile.email,
      phone: contactNumber ?? _profile.contactNumber,
      photoUrl: _profile.photoPath,
    );
  }

  Future<void> setPhoto(String? photoPath) async {
    final user = AuthService().currentUser;
    if (user == null) return;

    _profile = _profile.copyWith(
      userId: user.uid,
      photoPath: photoPath,
      clearPhoto: photoPath == null,
    );
    notifyListeners();

    if (photoPath != null) {
      if (!photoPath.startsWith('http://') &&
          !photoPath.startsWith('https://') &&
          !photoPath.startsWith('data:image')) {
        final file = File(photoPath);
        final uploadedUrl = await UserProfileSyncService().uploadAvatar(
          uid: user.uid,
          file: file,
        );
        if (uploadedUrl != null) {
          _profile = _profile.copyWith(photoPath: uploadedUrl);
          notifyListeners();
          await UserProfileSyncService().savePhoto(
            uid: user.uid,
            photoUrl: uploadedUrl,
          );
        }
      } else {
        await UserProfileSyncService().savePhoto(
          uid: user.uid,
          photoUrl: photoPath,
        );
      }
    } else {
      await UserProfileSyncService().savePhoto(
        uid: user.uid,
        photoUrl: null,
      );
    }
  }
}

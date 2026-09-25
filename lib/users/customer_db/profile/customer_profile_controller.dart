import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_profile_sync_service.dart';
import 'customer_profile_model.dart';

class CustomerProfileController extends ChangeNotifier {
  CustomerProfileController._() {
    loadProfile();
  }

  static final CustomerProfileController instance = CustomerProfileController._();

  factory CustomerProfileController() => instance;

  CustomerProfile _profile = const CustomerProfile(
    userId: '',
    firstName: '',
    middleInitial: '',
    lastName: '',
    email: '',
    contactNumber: '',
  );

  bool _isLoading = false;

  bool get isLoading => _isLoading;
  CustomerProfile get profile => _profile;
  String get currentUserId => _profile.userId;

  void clear() {
    _profile = const CustomerProfile(
      userId: '',
      firstName: '',
      middleInitial: '',
      lastName: '',
      email: '',
      contactNumber: '',
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
      _profile = const CustomerProfile(
        userId: '',
        firstName: '',
        middleInitial: '',
        lastName: '',
        email: '',
        contactNumber: '',
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
      final lName = profileData['surname']?.toString() ?? profileData['lastName']?.toString() ?? profileData['last_name']?.toString() ?? '';
      final email = profileData['email']?.toString() ?? user.email ?? '';
      final phone = profileData['phone']?.toString() ??
          profileData['contactNumber']?.toString() ??
          profileData['contact_number']?.toString() ??
          profileData['phoneNumber']?.toString() ??
          (user.phoneNumber ?? '');

      if (fName.trim().isNotEmpty || lName.trim().isNotEmpty) {
        _profile = CustomerProfile(
          userId: user.uid,
          firstName: fName.trim(),
          middleInitial: mInit.trim(),
          lastName: lName.trim(),
          email: email.trim(),
          contactNumber: phone.trim(),
          photoPath: avatarUrl ?? _profile.photoPath,
        );
      } else {
        final displayName = (profileData['displayName']?.toString() ?? user.displayName ?? '').trim();
        final parsed = _parseDisplayName(displayName);

        _profile = CustomerProfile(
          userId: user.uid,
          firstName: parsed['firstName']!.isNotEmpty ? parsed['firstName']! : 'Customer',
          middleInitial: parsed['middleInitial']!,
          lastName: parsed['lastName']!,
          email: email.trim(),
          contactNumber: phone.trim(),
          photoPath: avatarUrl ?? _profile.photoPath,
        );
      }
    } catch (e) {
      debugPrint('Error loading customer profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Map<String, String> _parseDisplayName(String displayName) {
    final clean = displayName.replaceAll('  ', ' ').trim();
    if (clean.isEmpty) {
      return {'firstName': '', 'middleInitial': '', 'lastName': ''};
    }

    final parts = clean.split(' ');
    if (parts.length == 1) {
      return {'firstName': parts.first, 'middleInitial': '', 'lastName': ''};
    }

    int miIndex = -1;
    for (int i = 1; i < parts.length - 1; i++) {
      final token = parts[i].replaceAll('.', '');
      if (token.length == 1 && RegExp(r'^[a-zA-Z]$').hasMatch(token)) {
        miIndex = i;
        break;
      }
    }

    if (miIndex != -1) {
      final fName = parts.sublist(0, miIndex).join(' ');
      final mInit = parts[miIndex].replaceAll('.', '').toUpperCase();
      final lName = parts.sublist(miIndex + 1).join(' ');
      return {'firstName': fName, 'middleInitial': mInit, 'lastName': lName};
    } else {
      final fName = parts.sublist(0, parts.length - 1).join(' ');
      final lName = parts.last;
      return {'firstName': fName, 'middleInitial': '', 'lastName': lName};
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
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import 'customer_profile_model.dart';

class CustomerProfileController extends ChangeNotifier {
  CustomerProfileController._() {
    loadProfile();
  }

  static final CustomerProfileController instance = CustomerProfileController._();

  factory CustomerProfileController() => instance;

  CustomerProfile _profile = const CustomerProfile(
    firstName: '',
    middleInitial: '',
    lastName: '',
    email: '',
    contactNumber: '',
  );

  bool _isLoading = false;

  bool get isLoading => _isLoading;
  CustomerProfile get profile => _profile;

  Future<void> loadProfile() async {
    final user = AuthService().currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final profileData = await SupabaseService().getOrCreateUserProfile(user.uid);
      final avatarUrl = profileData['avatar_url']?.toString() ?? profileData['photo_url']?.toString();

      if (profileData.isNotEmpty && (profileData['first_name'] != null || profileData['surname'] != null)) {
        _profile = CustomerProfile(
          firstName: profileData['first_name']?.toString() ?? '',
          middleInitial: profileData['middle_initial']?.toString() ?? '',
          lastName: profileData['surname']?.toString() ?? '',
          email: profileData['email']?.toString() ?? user.email ?? '',
          contactNumber: profileData['phone']?.toString() ?? '',
          photoPath: avatarUrl ?? _profile.photoPath,
        );
      } else {
        final displayName = user.displayName ?? '';
        final parts = displayName.split(' ');
        final fName = parts.isNotEmpty ? parts.first : '';
        final lName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

        _profile = CustomerProfile(
          firstName: fName.isNotEmpty ? fName : 'Customer',
          middleInitial: '',
          lastName: lName,
          email: user.email ?? '',
          contactNumber: '',
          photoPath: avatarUrl ?? _profile.photoPath,
        );
      }
    } catch (e) {
      debugPrint('Error loading customer profile from Supabase: $e');
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
        debugPrint('Error updating customer profile in Supabase: $e');
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
          debugPrint('Error uploading customer profile photo: $e');
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
}
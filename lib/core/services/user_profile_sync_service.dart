import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'supabase_service.dart';

/// Centralized service to sync user profile changes (info & avatar)
/// directly to Firebase Realtime Database and Supabase.
class UserProfileSyncService {
  UserProfileSyncService._internal();
  static final UserProfileSyncService _instance = UserProfileSyncService._internal();
  factory UserProfileSyncService() => _instance;

  final AuthService _authService = AuthService();

  /// Loads profile data from Firebase Realtime Database, with Supabase fallback.
  Future<Map<String, dynamic>> loadProfileData(String uid) async {
    final result = <String, dynamic>{};

    // 1. Fetch from Firebase Realtime Database
    try {
      final snapshot = await _authService.database.ref().child('users/$uid').get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        result.addAll(data);
      }
    } catch (e) {
      debugPrint('[UserProfileSyncService] Error fetching from Firebase RTDB: $e');
    }

    String phoneInResult = result['phone']?.toString() ??
        result['contactNumber']?.toString() ??
        result['contact_number']?.toString() ??
        result['phoneNumber']?.toString() ??
        result['phone_number']?.toString() ??
        result['contact']?.toString() ??
        result['mobile']?.toString() ??
        result['contactNo']?.toString() ??
        result['contact_no']?.toString() ??
        '';

    // 2. Fetch from Supabase to fill in any missing fields
    try {
      final sbData = await SupabaseService().getOrCreateUserProfile(uid);
      if (sbData.isNotEmpty) {
        final fName = result['firstName']?.toString() ?? result['first_name']?.toString() ?? '';
        if (fName.trim().isEmpty && sbData['first_name'] != null) {
          result['firstName'] = sbData['first_name'];
        }
        final mInit = result['middleInitial']?.toString() ?? result['middle_initial']?.toString() ?? '';
        if (mInit.trim().isEmpty && sbData['middle_initial'] != null) {
          result['middleInitial'] = sbData['middle_initial'];
        }
        final sName = result['surname']?.toString() ?? result['lastName']?.toString() ?? result['last_name']?.toString() ?? '';
        if (sName.trim().isEmpty && sbData['surname'] != null) {
          result['surname'] = sbData['surname'];
        }

        if (phoneInResult.trim().isEmpty) {
          final sbPhone = sbData['phone']?.toString() ??
              sbData['contact_number']?.toString() ??
              sbData['contactNumber']?.toString() ??
              sbData['phone_number']?.toString() ??
              sbData['mobile']?.toString() ??
              '';
          if (sbPhone.trim().isNotEmpty) {
            phoneInResult = sbPhone.trim();
          }
        }

        final avatar = result['avatar_url']?.toString() ?? result['photoUrl']?.toString() ?? result['photo_url']?.toString() ?? '';
        if (avatar.trim().isEmpty && (sbData['avatar_url'] != null || sbData['photo_url'] != null)) {
          result['avatar_url'] = sbData['avatar_url'] ?? sbData['photo_url'];
        }
      }
    } catch (e) {
      debugPrint('[UserProfileSyncService] Error fetching from Supabase: $e');
    }

    // 3. Fallback to Firebase Auth user phoneNumber
    if (phoneInResult.trim().isEmpty) {
      final currentUser = _authService.currentUser;
      if (currentUser != null && (currentUser.phoneNumber?.trim().isNotEmpty ?? false)) {
        phoneInResult = currentUser.phoneNumber!.trim();
      }
    }

    if (phoneInResult.trim().isNotEmpty) {
      result['phone'] = phoneInResult.trim();
      result['contactNumber'] = phoneInResult.trim();
      result['contact_number'] = phoneInResult.trim();
    }

    return result;
  }

  /// Uploads avatar image:
  /// 1. Attempts Firebase Storage
  /// 2. Falls back to Supabase Storage
  /// 3. Falls back to Base64 data URI
  Future<String?> uploadAvatar({required String uid, required File file}) async {
    try {
      if (!await file.exists()) return null;

      final fileSize = await file.length();
      const maxBytes = 5 * 1024 * 1024; // 5 MB
      if (fileSize > maxBytes) {
        throw Exception('Image size exceeds 5MB limit.');
      }

      final ext = file.path.split('.').last.toLowerCase();
      final validExt = (ext == 'png' || ext == 'webp') ? ext : 'jpg';
      final fileName = '${uid}_${DateTime.now().millisecondsSinceEpoch}.$validExt';
      final storagePath = 'avatars/$uid/$fileName';

      // 1. Try Firebase Storage
      try {
        final ref = FirebaseStorage.instance.ref().child(storagePath);
        await ref.putFile(
          file,
          SettableMetadata(contentType: 'image/$validExt'),
        );
        final downloadUrl = await ref.getDownloadURL();
        debugPrint('[UserProfileSyncService] Uploaded to Firebase Storage: $downloadUrl');
        return downloadUrl;
      } catch (fbError) {
        debugPrint('[UserProfileSyncService] Firebase storage upload error: $fbError');
      }

      // 2. Try Supabase Storage
      try {
        final sbUrl = await SupabaseService().uploadProfileAvatar(uid, file);
        if (sbUrl != null && sbUrl.isNotEmpty) {
          debugPrint('[UserProfileSyncService] Uploaded to Supabase Storage: $sbUrl');
          return sbUrl;
        }
      } catch (sbError) {
        debugPrint('[UserProfileSyncService] Supabase storage upload error: $sbError');
      }

      // 3. Fallback to Base64 data URI
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      final dataUri = 'data:image/$validExt;base64,$base64String';
      debugPrint('[UserProfileSyncService] Using Base64 data URI fallback for avatar');
      return dataUri;
    } catch (e) {
      debugPrint('[UserProfileSyncService] Failed to upload avatar: $e');
      return null;
    }
  }

  /// Saves updated profile information to Firebase Realtime Database,
  /// Firebase Auth displayName, and Supabase.
  Future<void> saveProfileInfo({
    required String uid,
    required String firstName,
    required String middleInitial,
    required String surname,
    required String email,
    required String phone,
    String? photoUrl,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final displayName = '$firstName ${middleInitial.isNotEmpty ? '$middleInitial. ' : ''}$surname'.trim();

    // 1. Firebase Realtime Database
    try {
      final Map<String, dynamic> updates = {
        'firstName': firstName.trim(),
        'middleInitial': middleInitial.trim(),
        'surname': surname.trim(),
        'lastName': surname.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'contactNumber': phone.trim(),
        'contact_number': phone.trim(),
        'displayName': displayName.isNotEmpty ? displayName : email.trim(),
        'updatedAt': now,
      };
      if (photoUrl != null && photoUrl.isNotEmpty) {
        updates['avatar_url'] = photoUrl;
        updates['photoUrl'] = photoUrl;
      }
      await _authService.database.ref().child('users/$uid').update(updates);
      debugPrint('[UserProfileSyncService] Saved profile info to Firebase RTDB for $uid');
    } catch (e) {
      debugPrint('[UserProfileSyncService] Error saving profile info to Firebase RTDB: $e');
    }

    // 2. Firebase Auth Display Name
    try {
      final currentUser = _authService.currentUser;
      if (currentUser != null && currentUser.uid == uid && displayName.isNotEmpty) {
        await currentUser.updateDisplayName(displayName);
      }
    } catch (e) {
      debugPrint('[UserProfileSyncService] Error updating Firebase Auth displayName: $e');
    }

    // 3. Supabase
    try {
      await SupabaseService().updateUserProfile(uid, {
        'firstName': firstName.trim(),
        'middleInitial': middleInitial.trim(),
        'surname': surname.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'avatar_url': photoUrl,
      });
      debugPrint('[UserProfileSyncService] Synced profile info to Supabase for $uid');
    } catch (e) {
      debugPrint('[UserProfileSyncService] Error syncing profile info to Supabase: $e');
    }
  }

  /// Saves or removes avatar photo across Firebase Realtime Database,
  /// Firebase Auth photoURL, and Supabase.
  Future<void> savePhoto({
    required String uid,
    required String? photoUrl,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Firebase Realtime Database
    try {
      final Map<String, dynamic> updates = {
        'avatar_url': photoUrl,
        'photoUrl': photoUrl,
        'photo_url': photoUrl,
        'updatedAt': now,
      };
      await _authService.database.ref().child('users/$uid').update(updates);
      debugPrint('[UserProfileSyncService] Saved avatar to Firebase RTDB for $uid: $photoUrl');
    } catch (e) {
      debugPrint('[UserProfileSyncService] Error saving avatar to Firebase RTDB: $e');
    }

    // 2. Firebase Auth photoURL
    try {
      final currentUser = _authService.currentUser;
      if (currentUser != null && currentUser.uid == uid) {
        if (photoUrl != null && (photoUrl.startsWith('http://') || photoUrl.startsWith('https://'))) {
          await currentUser.updatePhotoURL(photoUrl);
        } else if (photoUrl == null) {
          await currentUser.updatePhotoURL(null);
        }
      }
    } catch (e) {
      debugPrint('[UserProfileSyncService] Error updating Firebase Auth photoURL: $e');
    }

    // 3. Supabase
    try {
      await SupabaseService().updateUserProfile(uid, {
        'avatar_url': photoUrl,
      });
      debugPrint('[UserProfileSyncService] Synced avatar to Supabase for $uid');
    } catch (e) {
      debugPrint('[UserProfileSyncService] Error syncing avatar to Supabase: $e');
    }
  }
}

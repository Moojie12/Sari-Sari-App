import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/auth_service.dart';

/// Service managing the onboarding tutorial status for Owner and Employee accounts.
class StaffTutorialService {
  StaffTutorialService._();

  static const String _ownerPrefKey = 'owner_tutorial_completed_v1';
  static const String _employeePrefKey = 'employee_tutorial_completed_v1';

  static bool? _mockOwnerSeen;
  static bool? _mockEmployeeSeen;

  static String _getKey({required bool isOwner}) {
    final base = isOwner ? _ownerPrefKey : _employeePrefKey;
    try {
      final uid = AuthService().currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        return '${base}_$uid';
      }
    } catch (_) {}
    return base;
  }

  /// Visible for testing to mock tutorial completed state.
  @visibleForTesting
  static void setMockSeen({bool? isOwner, bool? seen}) {
    if (isOwner == true) {
      _mockOwnerSeen = seen;
    } else if (isOwner == false) {
      _mockEmployeeSeen = seen;
    } else {
      _mockOwnerSeen = seen;
      _mockEmployeeSeen = seen;
    }
  }

  /// Returns true if the user has completed or skipped the tutorial for the given role.
  static Future<bool> hasSeenTutorial({required bool isOwner}) async {
    if (isOwner && _mockOwnerSeen != null) return _mockOwnerSeen!;
    if (!isOwner && _mockEmployeeSeen != null) return _mockEmployeeSeen!;

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_getKey(isOwner: isOwner)) ?? false;
    } catch (e) {
      debugPrint('StaffTutorialService error: $e');
      return false;
    }
  }

  /// Marks the tutorial as completed for the role.
  static Future<void> markTutorialCompleted({required bool isOwner}) async {
    if (isOwner) {
      _mockOwnerSeen = true;
    } else {
      _mockEmployeeSeen = true;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_getKey(isOwner: isOwner), true);
    } catch (e) {
      debugPrint('StaffTutorialService error: $e');
    }
  }

  /// Resets tutorial status for testing or manual re-viewing.
  static Future<void> resetTutorial({required bool isOwner}) async {
    if (isOwner) {
      _mockOwnerSeen = false;
    } else {
      _mockEmployeeSeen = false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getKey(isOwner: isOwner));
    } catch (e) {
      debugPrint('StaffTutorialService error: $e');
    }
  }
}

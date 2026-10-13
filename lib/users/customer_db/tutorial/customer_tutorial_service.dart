import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/auth_service.dart';

/// Service managing the onboarding tutorial status for customers.
class CustomerTutorialService {
  CustomerTutorialService._();

  static const String _prefKey = 'customer_tutorial_completed_v1';
  static bool? _mockSeenTutorial;

  static String _getKey() {
    try {
      final uid = AuthService().currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        return '${_prefKey}_$uid';
      }
    } catch (_) {}
    return _prefKey;
  }

  /// Visible for testing to mock tutorial completed state.
  @visibleForTesting
  static void setMockSeenTutorial(bool? seen) {
    _mockSeenTutorial = seen;
  }

  /// Returns true if the customer has already completed or skipped the tutorial.
  static Future<bool> hasSeenTutorial() async {
    if (_mockSeenTutorial != null) {
      return _mockSeenTutorial!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_getKey()) ?? false;
    } catch (e) {
      debugPrint('CustomerTutorialService: Error checking tutorial status: $e');
      return false;
    }
  }

  /// Marks the tutorial as completed so it will not show automatically again.
  static Future<void> markTutorialCompleted() async {
    _mockSeenTutorial = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_getKey(), true);
    } catch (e) {
      debugPrint('CustomerTutorialService: Error saving tutorial status: $e');
    }
  }

  /// Resets the tutorial status (e.g. for testing or explicit reset).
  static Future<void> resetTutorial() async {
    _mockSeenTutorial = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getKey());
    } catch (e) {
      debugPrint('CustomerTutorialService: Error resetting tutorial status: $e');
    }
  }
}

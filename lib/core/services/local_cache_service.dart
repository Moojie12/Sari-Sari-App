import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Slim SharedPreferences wrapper for lightweight cache settings,
/// last-sync timestamps, and 5-minute Cache TTL checks.
class LocalCacheService {
  LocalCacheService._internal();
  static final LocalCacheService instance = LocalCacheService._internal();

  static const Duration defaultCacheTtl = Duration(minutes: 5);

  /// Returns true if the cached key is still valid within the TTL
  Future<bool> isCacheValid(String cacheKey, {Duration ttl = defaultCacheTtl}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncStr = prefs.getString('cache_ts_$cacheKey');
      if (lastSyncStr == null) return false;
      final lastSync = DateTime.tryParse(lastSyncStr);
      if (lastSync == null) return false;
      return DateTime.now().difference(lastSync) < ttl;
    } catch (e) {
      return false;
    }
  }

  /// Marks a cache key as freshly synced at current timestamp
  Future<void> updateLastSyncTime(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_ts_$cacheKey', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('[LocalCacheService] Error saving sync time: $e');
    }
  }

  /// Returns formatted string of when the cache key was last synced
  Future<String?> getLastSyncTimeString(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncStr = prefs.getString('cache_ts_$cacheKey');
      if (lastSyncStr == null) return null;
      final dt = DateTime.tryParse(lastSyncStr);
      if (dt == null) return null;
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return null;
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'local_database_service.dart';
import 'supabase_service.dart';

/// Service responsible for processing offline `sync_queue` actions
/// when network connectivity is restored.
class SyncService {
  SyncService._internal() {
    _init();
  }
  static final SyncService instance = SyncService._internal();

  StreamSubscription<bool>? _connectivitySub;
  bool _isProcessing = false;

  void _init() {
    _connectivitySub = ConnectivityService.instance.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        flushQueue();
      }
    });
  }

  /// Flushes all pending sync actions in the SQLite queue for the current logged in user
  Future<void> flushQueue() async {
    if (_isProcessing) return;
    final currentUser = AuthService().currentUser;
    final userId = currentUser?.uid;
    if (userId == null || userId.isEmpty) return;

    if (!ConnectivityService.instance.isOnline) return;

    _isProcessing = true;
    try {
      final pendingActions = await LocalDatabaseService.instance.getPendingSyncActions(userId);
      if (pendingActions.isEmpty) {
        _isProcessing = false;
        return;
      }

      debugPrint('[SyncService] Processing ${pendingActions.length} pending offline actions...');

      for (final item in pendingActions) {
        final syncId = item['id'].toString();
        final action = item['action'].toString();
        final payloadStr = item['payload'].toString();
        final retryCount = (item['retry_count'] as num?)?.toInt() ?? 0;

        Map<String, dynamic> payload = {};
        try {
          payload = jsonDecode(payloadStr) as Map<String, dynamic>;
        } catch (_) {}

        bool success = false;
        try {
          switch (action) {
            case 'UPDATE_PROFILE':
              success = await _processProfileUpdate(userId, payload);
              break;
            case 'UPDATE_CART':
              success = await _processCartUpdate(userId, payload);
              break;
            default:
              success = true; // Unknown action auto-resolves
              break;
          }
        } catch (e) {
          debugPrint('[SyncService] Action $action failed: $e');
          success = false;
        }

        if (success) {
          await LocalDatabaseService.instance.markSyncActionCompleted(syncId);
          debugPrint('[SyncService] Action $syncId ($action) completed and removed from queue');
        } else {
          await LocalDatabaseService.instance.incrementSyncRetry(syncId, retryCount);
        }
      }
    } catch (e) {
      debugPrint('[SyncService] Error flushing sync queue: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<bool> _processProfileUpdate(String userId, Map<String, dynamic> payload) async {
    try {
      await SupabaseService().updateUserProfile(userId, {
        'first_name': payload['firstName']?.toString() ?? '',
        'middle_initial': payload['middleInitial']?.toString() ?? '',
        'surname': payload['surname']?.toString() ?? '',
        'phone': payload['phone']?.toString() ?? '',
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _processCartUpdate(String userId, Map<String, dynamic> payload) async {
    try {
      final db = AuthService().database;
      await db.ref().child('carts/$userId').set(payload);
      return true;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}

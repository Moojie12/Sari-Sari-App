import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sari_sari/core/services/local_database_service.dart';
import 'package:sari_sari/core/services/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDatabaseService.dbName = 'sari_sari_sync_test.db';
  });

  group('SyncService Queue Processing Tests', () {
    test('SyncService instance initializes correctly', () {
      final syncService = SyncService.instance;
      expect(syncService, isNotNull);
    });

    test('Offline queue action increments retry count and marks failed after 3 attempts', () async {
      final localDb = LocalDatabaseService.instance;
      await localDb.database;

      await localDb.queueOfflineAction(
        userId: 'sync_test_user_1',
        action: 'UPDATE_CART',
        payload: {'cart': 'item_1'},
      );

      var pending = await localDb.getPendingSyncActions('sync_test_user_1');
      expect(pending.length, equals(1));
      final syncId = pending.first['id'].toString();

      // Retry 1
      await localDb.incrementSyncRetry(syncId, 0);
      pending = await localDb.getPendingSyncActions('sync_test_user_1');
      expect(pending.first['retry_count'], equals(1));

      // Retry 2
      await localDb.incrementSyncRetry(syncId, 1);
      pending = await localDb.getPendingSyncActions('sync_test_user_1');
      expect(pending.first['retry_count'], equals(2));

      // Retry 3 (fails and drops from pending)
      await localDb.incrementSyncRetry(syncId, 2);
      pending = await localDb.getPendingSyncActions('sync_test_user_1');
      expect(pending, isEmpty); // Retry count >= 3 drops from active pending queue
    });
  });
}

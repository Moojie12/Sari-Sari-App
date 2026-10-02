import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sari_sari/core/services/local_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDatabaseService.dbName = 'sari_sari_db_test.db';
  });

  group('LocalDatabaseService Unit Tests', () {
    final localDb = LocalDatabaseService.instance;

    test('LocalDatabaseService initializes and opens database', () async {
      final db = await localDb.database;
      expect(db, isNotNull);
      expect(db!.isOpen, isTrue);
    });

    test('Insert and Query User Orders with User ID Isolation', () async {
      final orderA = {
        'order_id': 'TEST-ORD-001',
        'user_id': 'user_a_123',
        'customer_name': 'Customer A',
        'total_amount': 150.0,
        'status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      };

      final orderB = {
        'order_id': 'TEST-ORD-002',
        'user_id': 'user_b_456',
        'customer_name': 'Customer B',
        'total_amount': 250.0,
        'status': 'completed',
        'updated_at': DateTime.now().toIso8601String(),
      };

      await localDb.insert('orders', orderA);
      await localDb.insert('orders', orderB);

      final userAOrders = await localDb.queryAll('orders', userId: 'user_a_123');
      expect(userAOrders.length, 1);
      expect(userAOrders.first['order_id'], 'TEST-ORD-001');

      final userBOrders = await localDb.queryAll('orders', userId: 'user_b_456');
      expect(userBOrders.length, 1);
      expect(userBOrders.first['order_id'], 'TEST-ORD-002');
    });

    test('Sync Queue offline action queuing and retrieval', () async {
      await localDb.queueOfflineAction(
        userId: 'user_a_123',
        action: 'UPDATE_CART',
        payload: {'product_id': 'prod_99', 'qty': 3},
      );

      final pending = await localDb.getPendingSyncActions('user_a_123');
      expect(pending.length, equals(1));
      expect(pending.first['action'], equals('UPDATE_CART'));

      final syncId = pending.first['id'].toString();
      await localDb.markSyncActionCompleted(syncId);

      final afterCompleted = await localDb.getPendingSyncActions('user_a_123');
      expect(afterCompleted, isEmpty);
    });

    test('Clear user tables purges user data on logout', () async {
      await localDb.clearUserTables('user_a_123');

      final userAOrders = await localDb.queryAll('orders', userId: 'user_a_123');
      expect(userAOrders, isEmpty);

      // User B's order should remain untouched
      final userBOrders = await localDb.queryAll('orders', userId: 'user_b_456');
      expect(userBOrders.length, equals(1));
    });
  });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Backend Implementation Verification', () {
    test('main.dart contains accessToken callback for Firebase-Supabase integration', () {
      final mainFile = File('lib/main.dart');
      expect(mainFile.existsSync(), isTrue, reason: 'lib/main.dart should exist');

      final contents = mainFile.readAsStringSync();
      expect(contents, contains('accessToken: () async'),
          reason: 'main.dart should contain accessToken callback');
      expect(contents, contains('FirebaseAuth.instance.currentUser'),
          reason: 'accessToken callback should get current Firebase user');
      expect(contents, contains('getIdToken()'),
          reason: 'accessToken callback should get Firebase ID token');
    });

    test('supabase_service.dart uses RPC functions for atomic operations', () {
      final serviceFile = File('lib/core/services/supabase_service.dart');
      expect(serviceFile.existsSync(), isTrue, reason: 'lib/core/services/supabase_service.dart should exist');

      final contents = serviceFile.readAsStringSync();
      expect(contents, contains('createOrderWithItems'),
          reason: 'Should have createOrderWithItems method');
      expect(contents, contains('createPreOrderWithItems'),
          reason: 'Should have createPreOrderWithItems method');
      expect(contents, contains('convertPreOrderToOrder'),
          reason: 'Should have convertPreOrderToOrder method');
      expect(contents, contains('.rpc('),
          reason: 'Should use RPC calls for atomic operations');
      expect(contents, contains('create_sale_transaction'),
          reason: 'Should call create_sale_transaction RPC');
      expect(contents, contains('create_preorder_transaction'),
          reason: 'Should call create_preorder_transaction RPC');
      expect(contents, contains('convert_preorder_to_order'),
          reason: 'Should call convert_preorder_to_order RPC');
    });

    test('No user_profiles references exist (should all be profiles)', () {
      final libDir = Directory('lib');
      final files = libDir.listSync(recursive: true)
          .where((entity) => entity is File && entity.path.endsWith('.dart'))
          .map((entity) => entity as File)
          .toList();

      final problematicMatches = <String>[];

      for (final file in files) {
        try {
          final contents = file.readAsStringSync();
          if (contents.contains('user_profiles')) {
            problematicMatches.add('${file.path}: Contains user_profiles reference');
          }
        } catch (e) {
          // Skip files that can't be read
        }
      }

      expect(problematicMatches, isEmpty,
          reason: 'No user_profiles references should exist in Dart files\n${problematicMatches.join('\n')}');
    });

    test('Required migration files exist', () {
      final supabaseDir = Directory('supabase/migrations');
      expect(supabaseDir.existsSync(), isTrue, reason: 'supabase/migrations directory should exist');

      final requiredFiles = [
        '001_create_profiles_table.sql',
        '008_fix_inventory_logic.sql',
        '009_create_rls_policies.sql'
      ];

      final missingFiles = <String>[];

      for (final fileName in requiredFiles) {
        final file = File('supabase/migrations/$fileName');
        if (!file.existsSync()) {
          missingFiles.add(fileName);
        }
      }

      expect(missingFiles, isEmpty,
          reason: 'All required migration files should exist\nMissing: ${missingFiles.join(', ')}');
    });

    test('008_fix_inventory_logic.sql contains all three RPC functions', () {
      final migrationFile = File('supabase/migrations/008_fix_inventory_logic.sql');
      expect(migrationFile.existsSync(), isTrue, reason: '008_fix_inventory_logic.sql should exist');

      final contents = migrationFile.readAsStringSync();
      expect(contents, contains('create_sale_transaction'),
          reason: 'Should contain create_sale_transaction function');
      expect(contents, contains('create_preorder_transaction'),
          reason: 'Should contain create_preorder_transaction function');
      expect(contents, contains('convert_preorder_to_order'),
          reason: 'Should contain convert_preorder_to_order function');
      expect(contents, contains('FEFO'),
          reason: 'Should mention FEFO (First Expire, First Out) logic');
      expect(contents, contains('FOR UPDATE'),
          reason: 'Should use FOR UPDATE locking to prevent race conditions');
    });

    test('009_create_rls_policies.sql contains RLS policies for all tables', () {
      final migrationFile = File('supabase/migrations/009_create_rls_policies.sql');
      expect(migrationFile.existsSync(), isTrue, reason: '009_create_rls_policies.sql should exist');

      final contents = migrationFile.readAsStringSync();
      final tables = ['profiles', 'categories', 'products', 'product_batches',
                     'inventory_transactions', 'orders', 'order_items',
                     'pre_orders', 'shipments'];

      final missingTables = <String>[];
      for (final table in tables) {
        if (!contents.contains('ALTER TABLE $table')) {
          missingTables.add(table);
        }
      }

      expect(missingTables, isEmpty,
          reason: 'Should contain RLS policies for all tables\nMissing tables: ${missingTables.join(', ')}');
    });
  });
}
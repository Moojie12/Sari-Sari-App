import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sari_sari/core/services/connectivity_service.dart';
import 'package:sari_sari/core/services/local_database_service.dart';
import 'package:sari_sari/core/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDatabaseService.dbName = 'logout_test_db.db';
  });

  group('Logout Unsynced Changes Dialog Tests', () {
    testWidgets('Shows confirmation dialog when offline and unsynced changes exist', (tester) async {
      // 1. Setup offline state
      ConnectivityService.instance.setOnlineForTesting(false);

      // 2. Queue offline action
      await LocalDatabaseService.instance.queueOfflineAction(
        userId: 'test_logout_user_1',
        action: 'UPDATE_CART',
        payload: {'qty': 5},
      );

      // 3. Build Test Widget to trigger dialog
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await AuthService.confirmLogoutWithUnsyncedCheck(context, userId: 'test_logout_user_1');
                },
                child: const Text('Trigger Logout'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Logout'));
      await tester.pumpAndSettle();

      expect(find.text('Unsynced Changes Warning'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}

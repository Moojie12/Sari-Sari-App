import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/users/customer_db/customer_dashboard.dart';
import 'package:sari_sari/users/employee_db/employee_dashboard.dart';
import 'package:sari_sari/users/employee_db/employee_inventory_controller.dart';
import 'package:sari_sari/users/employee_db/home/employee_home_page.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_batch_model.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_product_model.dart';
import 'package:sari_sari/users/employee_db/pos/employee_pos_controller.dart';
import 'package:sari_sari/users/owner_db/home/owner_home_page.dart';
import 'package:sari_sari/users/owner_db/owner_dashboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dashboard Home Landing & Overview Tests', () {
    late EmployeeInventoryController inventory;
    late EmployeePosController posController;

    setUp(() {
      inventory = EmployeeInventoryController.instance;
      inventory.setProductsForTesting([
        EmployeeProduct(
          id: 'PROD-HOME-001',
          name: 'Instant Noodles Spicy',
          category: 'Noodles',
          barcode: '9876543210',
          price: 15.0,
          capital: 10.0,
          batches: [
            ProductBatch(
              id: 'BATCH-001',
              expiryDate: DateTime.now().add(const Duration(days: 60)),
              quantity: 25.0,
            ),
          ],
        ),
      ]);
      posController = EmployeePosController(inventory: inventory);
    });

    testWidgets('CustomerDashboard initializes with Home tab (index 0)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerDashboard(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final state = tester.state<CustomerDashboardState>(find.byType(CustomerDashboard));
      // Tab index must be 0 (CustomerHomePage)
      expect(state.selectedIndex, equals(0));
    });

    testWidgets('EmployeeDashboard initializes with Home tab (index 0)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmployeeDashboard(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final state = tester.state<EmployeeDashboardState>(find.byType(EmployeeDashboard));
      expect(state.selectedIndex, equals(0));
    });

    testWidgets('OwnerDashboard initializes with Home tab (index 0)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OwnerDashboard(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final state = tester.state<OwnerDashboardState>(find.byType(OwnerDashboard));
      expect(state.selectedIndex, equals(0));
    });

    testWidgets('EmployeeHomePage displays Today\'s Sales and Products & Stock preview', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmployeeHomePage(
            inventory: inventory,
            posController: posController,
            onOpenInventory: () {},
            onOpenPos: () {},
            onOpenExpiringProducts: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 1. Sales overview
      expect(find.text("TODAY'S SALES"), findsOneWidget);

      // 2. Items & Stock preview
      expect(find.text('Products & Stock'), findsOneWidget);
      expect(find.text('Instant Noodles Spicy'), findsOneWidget);
      expect(find.text('₱ 15.00'), findsOneWidget);
      expect(find.text('25 in stock'), findsOneWidget);
    });

    testWidgets('OwnerHomePage displays Today\'s Sales and Products & Stock preview', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OwnerHomePage(
            inventory: inventory,
            posController: posController,
            onOpenInventory: () {},
            onOpenPos: () {},
            onOpenExpiringProducts: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 1. Sales overview
      expect(find.text("TODAY'S SALES"), findsOneWidget);

      // 2. Items & Stock preview
      expect(find.text('Products & Stock'), findsOneWidget);
      expect(find.text('Instant Noodles Spicy'), findsOneWidget);
      expect(find.text('₱ 15.00'), findsOneWidget);
      expect(find.text('25 in stock'), findsOneWidget);
    });
  });
}

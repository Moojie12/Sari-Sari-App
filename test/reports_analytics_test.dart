import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
import 'package:sari_sari/users/employee_db/employee_inventory_controller.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_batch_model.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_product_model.dart';
import 'package:sari_sari/users/employee_db/orders/employee_orders_controller.dart';
import 'package:sari_sari/users/owner_db/reports/owner_report_detail_screen.dart';
import 'package:sari_sari/users/owner_db/reports/owner_reports_page.dart';
import 'package:sari_sari/users/owner_db/reports/owner_operational_logs_page.dart';
import 'package:sari_sari/users/owner_db/profile/owner_profile_page.dart';
import 'package:sari_sari/users/owner_db/profile/shop_settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final inventory = EmployeeInventoryController.instance;
    final orderController = EmployeeOrderController.instance;

    inventory.setProductsForTesting([
      EmployeeProduct(
        id: 'PROD-TEST-1',
        name: 'San Miguel Pale Pilsen',
        barcode: '123456789',
        category: 'Beverages',
        price: 55.0,
        capital: 42.0,
        lowStockThreshold: 10.0,
        batches: [
          ProductBatch(
            id: 'BATCH-1',
            quantity: 12.0,
            expiryDate: DateTime.now().add(const Duration(days: 90)),
          ),
        ],
      ),
    ]);

    orderController.clearOrdersForTesting();
    orderController.addOrderForTesting(
      CustomerOrder(
        orderId: 'TEST-ORD-001',
        customerName: 'Juan Dela Cruz',
        orderDate: DateTime.now(),
        status: OrderStatus.completed,
        orderType: OrderType.pickup,
        paymentMethod: PaymentMethod.cashOnDelivery,
        paymentStatus: PaymentStatus.paid,
        items: const [
          CustomerOrderItem(
            productId: 'PROD-TEST-1',
            productName: 'San Miguel Pale Pilsen',
            price: 55.0,
            capital: 42.0,
            quantity: 3,
            subtotal: 165.0,
          ),
        ],
        subtotal: 165.0,
        deliveryFee: 0.0,
        totalAmount: 165.0,
      ),
    );
  });

  group('Reports & Analytics Tests', () {
    testWidgets('OwnerReportsPage renders with working analytics and no deleted items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OwnerReportsPage(),
        ),
      );

      await tester.pump();

      // Check title and Analytics tabs
      expect(find.text('Reports & Analytics'), findsOneWidget);
      expect(find.text('Descriptive'), findsWidgets);
      expect(find.text('Predictive'), findsWidgets);
      expect(find.text('Prescriptive'), findsWidgets);

      // Verify removed items are NOT present
      expect(find.text('Payment Reconciliation'), findsNothing);
      expect(find.text('Sales Channel Comparison'), findsNothing);
      expect(find.text('Total Inventory Value'), findsNothing);
      expect(find.text('Restock Checklist'), findsNothing);
      expect(find.text('Business Insights'), findsNothing);

      // Verify print icon is NOT present
      expect(find.byIcon(Icons.print), findsNothing);
      expect(find.byIcon(Icons.print_outlined), findsNothing);

      // Verify operational logs exist
      expect(find.text('Daily Revenue Summary'), findsOneWidget);
      expect(find.text('Wastage & Expiry Log'), findsOneWidget);
      expect(find.text('Consumables / Product Loss Log'), findsOneWidget);

      // Verify Descriptive Analytics components render
      expect(find.text('7-Day Revenue & Profit Trend'), findsOneWidget);
      expect(find.text('Sales by Category Share'), findsOneWidget);
      expect(find.text('Top Selling Products (Volume)'), findsOneWidget);
    });

    testWidgets('Switching analytics tabs displays predictive and prescriptive views', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OwnerReportsPage(),
        ),
      );

      await tester.pump();

      // Tap Predictive tab
      await tester.tap(find.text('Predictive').first);
      await tester.pump();

      expect(find.text('7-Day Sales Demand Forecast'), findsOneWidget);
      expect(find.text('Stockout Depletion Timeline'), findsOneWidget);

      // Tap Prescriptive tab
      await tester.tap(find.text('Prescriptive').first);
      await tester.pump();

      expect(find.text('Prescribed Restock Quantities'), findsOneWidget);
      expect(find.text('Expiry Markdown Strategy (Waste Prevention)'), findsOneWidget);
      expect(find.text('Profit Margin Optimization Actions'), findsOneWidget);
    });

    testWidgets('OwnerReportDetailScreen renders for all updated report types without print icon', (tester) async {
      for (final type in [
        OwnerReportType.descriptiveAnalytics,
        OwnerReportType.predictiveAnalytics,
        OwnerReportType.prescriptiveAnalytics,
        OwnerReportType.dailyRevenue,
        OwnerReportType.wastageLog,
        OwnerReportType.consumablesLog,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: OwnerReportDetailScreen(type: type),
          ),
        );

        await tester.pump();

        expect(find.byIcon(Icons.print), findsNothing);
        expect(find.byIcon(Icons.print_outlined), findsNothing);
      }
    });

    testWidgets('Analytics Deep-Dive Reports button section is removed from OwnerReportsPage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OwnerReportsPage(),
        ),
      );

      await tester.pump();

      expect(find.text('Analytics Deep-Dive Reports'), findsNothing);
    });

    testWidgets('OwnerOperationalLogsPage renders with the 3 operational logs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OwnerOperationalLogsPage(),
        ),
      );

      await tester.pump();

      expect(find.text('Operational Logs & Summaries'), findsWidgets);
      expect(find.text('Daily Revenue Summary'), findsOneWidget);
      expect(find.text('Wastage & Expiry Log'), findsOneWidget);
      expect(find.text('Consumables / Product Loss Log'), findsOneWidget);
    });

    testWidgets('OwnerProfilePage shows Transaction History, Reports & Analytics, and Operational Logs while removing Shift Reports, Employee Activity Logs, Archived Products, and My Consumables', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OwnerProfilePage(),
        ),
      );

      await tester.pump();

      // Verify the 3 remaining/added items exist
      expect(find.text('Transaction History'), findsOneWidget);
      expect(find.text('View Reports & Analytics'), findsOneWidget);
      expect(find.text('Operational Logs & Summaries'), findsOneWidget);

      // Verify the 4 removed items are absent
      expect(find.text('Shift Reports'), findsNothing);
      expect(find.text('Employee Activity Logs'), findsNothing);
      expect(find.text('Archived Products'), findsNothing);
      expect(find.text('My Consumables'), findsNothing);
    });

    test('ShopSettingsController enforces 2-digit limits on threshold and delivery fee', () {
      final controller = ShopSettingsController.instance;

      controller.updateLowStockThreshold(50);
      expect(controller.lowStockThreshold, 50);

      // Clamps above 99 to 99
      controller.updateLowStockThreshold(150);
      expect(controller.lowStockThreshold, 99);

      // Clamps negative to 0
      controller.updateLowStockThreshold(-5);
      expect(controller.lowStockThreshold, 0);

      controller.updateDeliveryFee(25.0);
      expect(controller.deliveryFeePer500m, 25.0);

      // Clamps above 99 to 99.0
      controller.updateDeliveryFee(250.0);
      expect(controller.deliveryFeePer500m, 99.0);

      // Clamps negative to 0.0
      controller.updateDeliveryFee(-10.0);
      expect(controller.deliveryFeePer500m, 0.0);
    });

    testWidgets('Low-stock threshold and Delivery Fee dialogs open and display 2-digit limits', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OwnerProfilePage(),
        ),
      );
      await tester.pump();

      // Scroll to Low-Stock Threshold and open dialog
      final thresholdTile = find.text('Low-Stock Threshold');
      await tester.scrollUntilVisible(thresholdTile, 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(thresholdTile);
      await tester.pumpAndSettle();

      expect(find.text('Low-Stock Threshold'), findsWidgets);
      expect(find.textContaining('max 2 digits'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Scroll to Delivery Fee Config and open dialog
      final deliveryTile = find.text('Delivery Fee Config');
      await tester.scrollUntilVisible(deliveryTile, 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(deliveryTile);
      await tester.pumpAndSettle();

      expect(find.text('Delivery Fee Settings'), findsOneWidget);
      expect(find.textContaining('max 2 digits'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });
}


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
import 'package:sari_sari/users/employee_db/employee_inventory_controller.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_batch_model.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_product_model.dart';
import 'package:sari_sari/users/employee_db/orders/employee_orders_controller.dart';
import 'package:sari_sari/users/employee_db/pos/employee_pos_controller.dart';
import 'package:sari_sari/users/owner_db/home/owner_home_page.dart';
import 'package:sari_sari/users/owner_db/reports/owner_report_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('POS to Today\'s Sales Integration & Print Removal Tests', () {
    late EmployeeInventoryController inventory;
    late EmployeePosController posController;
    late EmployeeOrderController orderController;

    setUp(() {
      inventory = EmployeeInventoryController.instance;
      inventory.setProductsForTesting([
        EmployeeProduct(
          id: 'PROD-TEST-101',
          name: 'Canned Goods - Sardines',
          category: 'Canned Goods',
          barcode: '1234567890',
          price: 25.0,
          capital: 18.0,
          batches: [
            ProductBatch(
              id: 'BATCH-101',
              expiryDate: DateTime.now().add(const Duration(days: 90)),
              quantity: 50.0,
            ),
          ],
        ),
      ]);

      posController = EmployeePosController(inventory: inventory);
      orderController = EmployeeOrderController.instance;
      orderController.clearOrdersForTesting();
    });

    test('POS checkout creates a completed order with correct capital, revenue, and profit', () {
      final product = inventory.findById('PROD-TEST-101')!;
      final batch = product.batches.first;

      final added = posController.addBatchToCart(product, batch, quantity: 2.0);
      expect(added, isTrue);
      expect(posController.totalAmount, equals(50.0));

      final receipt = posController.checkout(
        paymentMethod: EmployeePaymentMethod.cash,
        amountPaid: 100.0,
      );

      expect(receipt, isNotNull);
      expect(receipt!.totalAmount, equals(50.0));
      expect(receipt.totalCapital, equals(36.0));
      expect(receipt.totalProfit, equals(14.0));

      // Verify that the order was added to EmployeeOrderController
      final order = orderController.orders.firstWhere((o) => o.orderId == receipt.receiptNumber);
      expect(order.status, equals(OrderStatus.completed));
      expect(order.subtotal, equals(50.0));
      expect(order.totalCapital, equals(36.0));
      expect(order.totalProfit, equals(14.0));
    });

    test('CustomerOrderItem.fromSupabase restores capital from inventory if unit_cost is missing', () {
      final supabaseMap = {
        'product_id': 'PROD-TEST-101',
        'product_name': 'Canned Goods - Sardines',
        'unit_price': 25.0,
        'unit_cost': 0.0, // Simulated missing unit_cost from DB schema
        'quantity': 2,
        'total_price': 50.0,
      };

      final item = CustomerOrderItem.fromSupabase(supabaseMap);
      expect(item.productId, equals('PROD-TEST-101'));
      expect(item.price, equals(25.0));
      expect(item.capital, equals(18.0)); // Restored from inventory fallback!
      expect(item.subtotal, equals(50.0));
      expect(item.totalCapital, equals(36.0));
      expect(item.profit, equals(14.0));
    });

    testWidgets('OwnerReportDetailScreen renders without Print Icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OwnerReportDetailScreen(type: OwnerReportType.dailyRevenue),
        ),
      );

      await tester.pumpAndSettle();

      // Verify print icon is completely removed
      expect(find.byIcon(Icons.print_outlined), findsNothing);
      expect(find.byIcon(Icons.print), findsNothing);
      expect(find.text('Daily Revenue Summary'), findsOneWidget);
    });

    testWidgets('OwnerHomePage displays live Today\'s Sales after POS checkout', (tester) async {
      final product = inventory.findById('PROD-TEST-101')!;
      final batch = product.batches.first;

      // Add item and checkout
      posController.addBatchToCart(product, batch, quantity: 4.0);
      posController.checkout(
        paymentMethod: EmployeePaymentMethod.cash,
        amountPaid: 200.0,
      );

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

      await tester.pumpAndSettle();

      // Revenue: 4 * 25 = 100.00
      expect(find.text("₱ 100.00"), findsOneWidget);
      // Transactions: 1 transaction today
      expect(find.text("1"), findsWidgets);
      // Net Profit: 100 - 4*18 (72) = 28.00
      expect(find.text("₱ 28.00"), findsOneWidget);
    });
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_controller.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
import 'package:sari_sari/users/employee_db/orders/employee_orders_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Customer Cancel Order Functionality Tests', () {
    late EmployeeOrderController sharedController;
    late CustomerOrderController customerController;

    setUp(() {
      sharedController = EmployeeOrderController.instance;
      customerController = CustomerOrderController.instance;
    });

    CustomerOrder createTestOrder({
      required String orderId,
      required OrderStatus status,
    }) {
      return CustomerOrder(
        orderId: orderId,
        customerName: 'Test Customer',
        orderDate: DateTime.now(),
        items: const [
          CustomerOrderItem(
            productId: 'prod-001',
            productName: 'Instant Noodles',
            price: 15.0,
            capital: 10.0,
            quantity: 2,
            subtotal: 30.0,
          ),
        ],
        orderType: OrderType.pickup,
        paymentMethod: PaymentMethod.cashOnDelivery,
        paymentStatus: PaymentStatus.unpaid,
        subtotal: 30.0,
        deliveryFee: 0.0,
        totalAmount: 30.0,
        status: status,
        userId: 'cust-123',
      );
    }

    test('Customer CAN cancel order when status is pending', () async {
      final pendingOrder = createTestOrder(
        orderId: 'SS-PENDING-001',
        status: OrderStatus.pending,
      );

      // Place the order
      customerController.placeOrder(pendingOrder);

      // Verify it is placed and pending
      final placed = customerController.getOrderById('SS-PENDING-001');
      expect(placed, isNotNull);
      expect(placed!.status, OrderStatus.pending);

      // Cancel the order
      final result = await customerController.cancelOrder('SS-PENDING-001');
      expect(result, isTrue, reason: 'Pending order should be successfully cancelled');

      // Verify the status is now cancelled
      final cancelled = customerController.getOrderById('SS-PENDING-001');
      expect(cancelled, isNotNull);
      expect(cancelled!.status, OrderStatus.cancelled);
    });

    test('Customer CANNOT cancel order when status is changed to preparing/confirmed/completed/etc.', () async {
      final nonPendingStatuses = [
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.readyForShipment,
        OrderStatus.readyForPickup,
        OrderStatus.outForDelivery,
        OrderStatus.delivered,
        OrderStatus.completed,
        OrderStatus.cancelled,
      ];

      for (final nonPendingStatus in nonPendingStatuses) {
        final orderId = 'SS-${nonPendingStatus.name.toUpperCase()}-001';
        final order = createTestOrder(
          orderId: orderId,
          status: nonPendingStatus,
        );

        customerController.placeOrder(order);

        // Verify status before attempting cancel
        expect(customerController.getOrderById(orderId)?.status, nonPendingStatus);

        // Attempt to cancel
        final result = await customerController.cancelOrder(orderId);
        expect(
          result,
          isFalse,
          reason: 'Order with status ${nonPendingStatus.label} must NOT be cancellable',
        );

        // Verify status remains unchanged
        expect(
          customerController.getOrderById(orderId)?.status,
          nonPendingStatus,
          reason: 'Status should stay ${nonPendingStatus.label} after rejected cancel attempt',
        );
      }
    });

    test('Cancelled orders appear in cancelled tab filter and disappear from active orders', () async {
      final order = createTestOrder(
        orderId: 'SS-FILTER-TEST-001',
        status: OrderStatus.pending,
      );

      customerController.placeOrder(order);

      // Before cancel: should be in pending filter and in activeOrders
      final pendingBefore = customerController.getOrdersByStatus([OrderStatus.pending]);
      expect(pendingBefore.any((o) => o.orderId == 'SS-FILTER-TEST-001'), isTrue);
      expect(sharedController.activeOrders.any((o) => o.orderId == 'SS-FILTER-TEST-001'), isTrue);

      // Perform cancellation
      final success = await customerController.cancelOrder('SS-FILTER-TEST-001');
      expect(success, isTrue);

      // After cancel: must be in cancelled filter and NOT in activeOrders
      final cancelledList = customerController.getOrdersByStatus([OrderStatus.cancelled]);
      expect(cancelledList.any((o) => o.orderId == 'SS-FILTER-TEST-001'), isTrue);
      expect(sharedController.activeOrders.any((o) => o.orderId == 'SS-FILTER-TEST-001'), isFalse);
    });

    test('Non-existent orderId returns false on cancel attempt', () async {
      final result = await customerController.cancelOrder('NON_EXISTENT_ORDER_9999');
      expect(result, isFalse);
    });
  });
}

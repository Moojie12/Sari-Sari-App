import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sari_sari/core/services/stock_reservation_service.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
import 'package:sari_sari/users/employee_db/employee_inventory_controller.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_batch_model.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_product_model.dart';
import 'package:sari_sari/users/employee_db/orders/employee_orders_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Order Inventory Deduction and Restocking Lifecycle Tests', () {
    late EmployeeInventoryController inventoryController;
    late EmployeeOrderController ordersController;
    late StockReservationService reservationService;

    setUp(() {
      inventoryController = EmployeeInventoryController.instance;
      ordersController = EmployeeOrderController.instance;
      reservationService = StockReservationService.instance;

      reservationService.clearReservationsForTesting();

      // Setup clean test products
      inventoryController.setProductsForTesting([
        EmployeeProduct(
          id: 'prod-test-coke',
          name: 'Coca Cola 1.5L',
          category: 'Beverages',
          price: 65.0,
          capital: 50.0,
          barcode: '480001',
          batches: [
            ProductBatch(
              id: 'batch-coke-1',
              quantity: 20.0,
              expiryDate: DateTime.now().add(const Duration(days: 90)),
            ),
          ],
        ),
        EmployeeProduct(
          id: 'prod-test-chips',
          name: 'Potato Chips',
          category: 'Snacks',
          price: 25.0,
          capital: 18.0,
          barcode: '480002',
          batches: [
            ProductBatch(
              id: 'batch-chips-1',
              quantity: 15.0,
              expiryDate: DateTime.now().add(const Duration(days: 60)),
            ),
          ],
        ),
      ]);
    });

    CustomerOrder createTestOrder({
      required String orderId,
      required OrderStatus status,
      int cokeQty = 3,
      int chipsQty = 2,
      bool isStockDeducted = false,
    }) {
      return CustomerOrder(
        orderId: orderId,
        customerName: 'Juan Dela Cruz',
        orderDate: DateTime.now(),
        items: [
          CustomerOrderItem(
            productId: 'prod-test-coke',
            productName: 'Coca Cola 1.5L',
            price: 65.0,
            capital: 50.0,
            quantity: cokeQty,
            subtotal: 65.0 * cokeQty,
          ),
          CustomerOrderItem(
            productId: 'prod-test-chips',
            productName: 'Potato Chips',
            price: 25.0,
            capital: 18.0,
            quantity: chipsQty,
            subtotal: 25.0 * chipsQty,
          ),
        ],
        orderType: OrderType.delivery,
        paymentMethod: PaymentMethod.cashOnDelivery,
        paymentStatus: PaymentStatus.unpaid,
        subtotal: (65.0 * cokeQty) + (25.0 * chipsQty),
        deliveryFee: 40.0,
        totalAmount: (65.0 * cokeQty) + (25.0 * chipsQty) + 40.0,
        status: status,
        userId: 'cust-inventory-test-01',
        isStockDeducted: isStockDeducted,
      );
    }

    test('1. Placing an order as PENDING does NOT deduct inventory batches yet', () {
      final initialCoke = inventoryController.findById('prod-test-coke')!.quantity;
      final initialChips = inventoryController.findById('prod-test-chips')!.quantity;
      expect(initialCoke, 20.0);
      expect(initialChips, 15.0);

      final pendingOrder = createTestOrder(
        orderId: 'ORD-PENDING-001',
        status: OrderStatus.pending,
        cokeQty: 4,
        chipsQty: 2,
      );

      ordersController.placeOrder(pendingOrder);

      final orderInStore = ordersController.getOrderById('ORD-PENDING-001');
      expect(orderInStore, isNotNull);
      expect(orderInStore!.status, OrderStatus.pending);
      expect(orderInStore.isStockDeducted, isFalse);

      // Batches in inventory MUST remain intact
      expect(inventoryController.findById('prod-test-coke')!.quantity, 20.0);
      expect(inventoryController.findById('prod-test-chips')!.quantity, 15.0);
    });

    test('2. Confirming an order DEDUCTS inventory batches immediately and sets isStockDeducted to true', () {
      final order = createTestOrder(
        orderId: 'ORD-CONFIRM-001',
        status: OrderStatus.pending,
        cokeQty: 5,
        chipsQty: 3,
      );
      ordersController.placeOrder(order);

      // Staff confirms the order
      ordersController.updateOrderStatus('ORD-CONFIRM-001', OrderStatus.confirmed);

      final confirmedOrder = ordersController.getOrderById('ORD-CONFIRM-001');
      expect(confirmedOrder, isNotNull);
      expect(confirmedOrder!.status, OrderStatus.confirmed);
      expect(confirmedOrder.isStockDeducted, isTrue);

      // Batches must now be reduced: 20 - 5 = 15 for Coke, 15 - 3 = 12 for Chips
      expect(inventoryController.findById('prod-test-coke')!.quantity, 15.0);
      expect(inventoryController.findById('prod-test-chips')!.quantity, 12.0);
    });

    test('3. Progressing through preparing, ready, outForDelivery, and completed does NOT double-deduct stock', () {
      final order = createTestOrder(
        orderId: 'ORD-LIFECYCLE-001',
        status: OrderStatus.pending,
        cokeQty: 4,
        chipsQty: 2,
      );
      ordersController.placeOrder(order);

      // 1. Confirm -> deducts 4 Coke, 2 Chips (Coke: 16, Chips: 13)
      ordersController.updateOrderStatus('ORD-LIFECYCLE-001', OrderStatus.confirmed);
      expect(inventoryController.findById('prod-test-coke')!.quantity, 16.0);
      expect(inventoryController.findById('prod-test-chips')!.quantity, 13.0);

      // 2. Preparing -> no extra deduction
      ordersController.updateOrderStatus('ORD-LIFECYCLE-001', OrderStatus.preparing);
      expect(inventoryController.findById('prod-test-coke')!.quantity, 16.0);
      expect(inventoryController.findById('prod-test-chips')!.quantity, 13.0);

      // 3. Ready for Shipment -> no extra deduction
      ordersController.updateOrderStatus('ORD-LIFECYCLE-001', OrderStatus.readyForShipment);
      expect(inventoryController.findById('prod-test-coke')!.quantity, 16.0);
      expect(inventoryController.findById('prod-test-chips')!.quantity, 13.0);

      // 4. Out for Delivery -> no extra deduction
      ordersController.updateOrderStatus('ORD-LIFECYCLE-001', OrderStatus.outForDelivery);
      expect(inventoryController.findById('prod-test-coke')!.quantity, 16.0);
      expect(inventoryController.findById('prod-test-chips')!.quantity, 13.0);

      // 5. Delivered -> no extra deduction
      ordersController.updateOrderStatus('ORD-LIFECYCLE-001', OrderStatus.delivered);
      expect(inventoryController.findById('prod-test-coke')!.quantity, 16.0);
      expect(inventoryController.findById('prod-test-chips')!.quantity, 13.0);

      // 6. Completed -> no extra deduction!
      ordersController.updateOrderStatus('ORD-LIFECYCLE-001', OrderStatus.completed);
      final finalOrder = ordersController.getOrderById('ORD-LIFECYCLE-001');
      expect(finalOrder!.status, OrderStatus.completed);
      expect(finalOrder.isStockDeducted, isTrue);

      expect(inventoryController.findById('prod-test-coke')!.quantity, 16.0);
      expect(inventoryController.findById('prod-test-chips')!.quantity, 13.0);
    });

    test('4. Cancelling an ALREADY-CONFIRMED order RESTOCKS items back into inventory', () async {
      final order = createTestOrder(
        orderId: 'ORD-CANCEL-RESTOCK-001',
        status: OrderStatus.pending,
        cokeQty: 6,
        chipsQty: 4,
      );
      ordersController.placeOrder(order);

      // Confirm order: Coke drops to 14, Chips drops to 11
      ordersController.updateOrderStatus('ORD-CANCEL-RESTOCK-001', OrderStatus.confirmed);
      expect(inventoryController.findById('prod-test-coke')!.quantity, 14.0);
      expect(inventoryController.findById('prod-test-chips')!.quantity, 11.0);

      // Now cancel the order (by staff)
      final cancelResult = await ordersController.cancelOrder(
        'ORD-CANCEL-RESTOCK-001',
        reason: 'Customer requested cancellation',
        isStaff: true,
      );
      expect(cancelResult, isTrue);

      final cancelledOrder = ordersController.getOrderById('ORD-CANCEL-RESTOCK-001');
      expect(cancelledOrder!.status, OrderStatus.cancelled);
      expect(cancelledOrder.isStockDeducted, isFalse);

      // Stock MUST be restored back to original amounts: 14 + 6 = 20, 11 + 4 = 15
      expect(inventoryController.findById('prod-test-coke')!.quantity, 20.0);
      expect(inventoryController.findById('prod-test-chips')!.quantity, 15.0);
    });

    test('5. Cancelling a PENDING order does NOT restock inventory (prevents artificial stock inflation)', () async {
      final order = createTestOrder(
        orderId: 'ORD-CANCEL-PENDING-001',
        status: OrderStatus.pending,
        cokeQty: 5,
        chipsQty: 5,
      );
      ordersController.placeOrder(order);

      // Verify initial stock
      expect(inventoryController.findById('prod-test-coke')!.quantity, 20.0);
      expect(inventoryController.findById('prod-test-chips')!.quantity, 15.0);

      // Cancel while pending
      final cancelResult = await ordersController.cancelOrder(
        'ORD-CANCEL-PENDING-001',
        reason: 'Change of mind',
        isStaff: false,
      );
      expect(cancelResult, isTrue);

      final cancelledOrder = ordersController.getOrderById('ORD-CANCEL-PENDING-001');
      expect(cancelledOrder!.status, OrderStatus.cancelled);
      expect(cancelledOrder.isStockDeducted, isFalse);

      // Stock must NOT be increased beyond 20 and 15
      expect(inventoryController.findById('prod-test-coke')!.quantity, 20.0);
      expect(inventoryController.findById('prod-test-chips')!.quantity, 15.0);
    });

    test('6. hasSufficientStock correctly checks stock availability', () {
      final orderWithinStock = createTestOrder(
        orderId: 'ORD-STOCK-OK',
        status: OrderStatus.pending,
        cokeQty: 10,
        chipsQty: 5,
      );
      expect(ordersController.hasSufficientStock(orderWithinStock), isTrue);

      final orderExceedingStock = createTestOrder(
        orderId: 'ORD-STOCK-EXCEED',
        status: OrderStatus.pending,
        cokeQty: 25, // Only 20 in stock
        chipsQty: 5,
      );
      expect(ordersController.hasSufficientStock(orderExceedingStock), isFalse);
    });
  });
}

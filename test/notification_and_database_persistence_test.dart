import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/users/customer_db/notifications/customer_notification_model.dart';
import 'package:sari_sari/users/customer_db/notifications/customer_notifications_controller.dart';
import 'package:sari_sari/users/customer_db/profile/customer_address_controller.dart';
import 'package:sari_sari/users/customer_db/profile/customer_address_model.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_controller.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
import 'package:sari_sari/users/employee_db/notifications/employee_notification_model.dart';
import 'package:sari_sari/users/employee_db/notifications/employee_notifications_controller.dart';
import 'package:sari_sari/users/employee_db/orders/employee_orders_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Comprehensive Notifications & Database Persistence Tests', () {
    late EmployeeOrderController employeeOrderController;
    late CustomerOrderController customerOrderController;
    late CustomerNotificationsController customerNotifController;
    late EmployeeNotificationsController employeeNotifController;

    setUp(() {
      employeeOrderController = EmployeeOrderController.instance;
      customerOrderController = CustomerOrderController.instance;
      customerNotifController = CustomerNotificationsController.instance;
      employeeNotifController = EmployeeNotificationsController.instance;

      customerNotifController.clear();
      employeeNotifController.clear();
    });

    CustomerOrder createSampleOrder(String orderId, OrderStatus status) {
      return CustomerOrder(
        orderId: orderId,
        customerName: 'Juan Dela Cruz',
        orderDate: DateTime.now(),
        items: const [
          CustomerOrderItem(
            productId: 'p-1',
            productName: 'Canned Sardines',
            price: 25.0,
            capital: 18.0,
            quantity: 3,
            subtotal: 75.0,
          ),
        ],
        orderType: OrderType.delivery,
        paymentMethod: PaymentMethod.cashOnDelivery,
        paymentStatus: PaymentStatus.unpaid,
        subtotal: 75.0,
        deliveryFee: 15.0,
        totalAmount: 90.0,
        status: status,
        userId: 'test_user_777',
      );
    }

    test('Placing an order generates notifications for BOTH Employee and Customer', () {
      final initialCustomerNotifs = customerNotifController.notifications.length;
      final initialEmployeeNotifs = employeeNotifController.notifications.length;

      final order = createSampleOrder('ORD-NOTIF-001', OrderStatus.pending);
      customerOrderController.placeOrder(order);

      // Verify Customer notification was added
      final customerNotifs = customerNotifController.notifications;
      expect(customerNotifs.length, initialCustomerNotifs + 1);
      final custNotif = customerNotifs.first;
      expect(custNotif.title, 'Order Placed');
      expect(custNotif.message, contains('ORD-NOTIF-001'));
      expect(custNotif.message, contains('90.00'));
      expect(custNotif.isRead, isFalse);

      // Verify Employee notification was added
      final employeeNotifs = employeeNotifController.notifications;
      expect(employeeNotifs.length, initialEmployeeNotifs + 1);
      final empNotif = employeeNotifs.first;
      expect(empNotif.title, 'New Order Received');
      expect(empNotif.message, contains('ORD-NOTIF-001'));
      expect(empNotif.message, contains('Juan Dela Cruz'));
    });

    test('Order status updates generate customized notifications for Customer across all lifecycle stages', () {
      final order = createSampleOrder('ORD-NOTIF-002', OrderStatus.pending);
      customerOrderController.placeOrder(order);

      final statusExpectations = [
        (OrderStatus.confirmed, 'Order Confirmed', 'confirmed by the store'),
        (OrderStatus.preparing, 'Order Preparing', 'being prepared'),
        (OrderStatus.readyForShipment, 'Ready for Shipment', 'packed and ready'),
        (OrderStatus.outForDelivery, 'Out for Delivery', 'Rider is on the way'),
        (OrderStatus.delivered, 'Order Delivered', 'has been delivered'),
        (OrderStatus.completed, 'Order Completed', 'completed'),
      ];

      for (final (status, expectedTitle, expectedSnippet) in statusExpectations) {
        employeeOrderController.updateOrderStatus('ORD-NOTIF-002', status);

        final latestCustNotif = customerNotifController.notifications.first;
        expect(latestCustNotif.title, expectedTitle);
        expect(latestCustNotif.message, contains(expectedSnippet));
        expect(latestCustNotif.message, contains('ORD-NOTIF-002'));
      }
    });

    test('Order cancellation by customer notifies both Customer and Employee', () async {
      final order = createSampleOrder('ORD-NOTIF-003', OrderStatus.pending);
      customerOrderController.placeOrder(order);

      final success = await customerOrderController.cancelOrder('ORD-NOTIF-003');
      expect(success, isTrue);

      // Check customer notification
      final customerNotif = customerNotifController.notifications.first;
      expect(customerNotif.title, 'Order Cancelled');
      expect(customerNotif.message, contains('ORD-NOTIF-003'));

      // Check employee notification
      final employeeNotif = employeeNotifController.notifications.first;
      expect(employeeNotif.title, 'Order Cancelled');
      expect(employeeNotif.message, contains('ORD-NOTIF-003'));
    });

    test('Customer notification markAsRead and markAllAsRead update state properly', () {
      customerNotifController.addNotification(
        type: CustomerNotificationType.orderUpdate,
        title: 'Test Notif 1',
        message: 'Message 1',
      );
      customerNotifController.addNotification(
        type: CustomerNotificationType.promotion,
        title: 'Test Notif 2',
        message: 'Message 2',
      );

      expect(customerNotifController.unreadCount, 2);

      final firstId = customerNotifController.notifications.first.id;
      customerNotifController.markAsRead(firstId);

      expect(customerNotifController.unreadCount, 1);

      customerNotifController.markAllAsRead();
      expect(customerNotifController.unreadCount, 0);
    });

    test('Employee notification markAsRead and markAllAsRead update state properly', () {
      employeeNotifController.addNotification(
        type: EmployeeNotificationType.newOrder,
        title: 'Emp Notif 1',
        message: 'Message 1',
      );
      employeeNotifController.addNotification(
        type: EmployeeNotificationType.assignedTask,
        title: 'Emp Notif 2',
        message: 'Message 2',
      );

      final dynamicCount = employeeNotifController.notifications.where((n) => n.id.startsWith('store_notif_')).length;
      expect(dynamicCount, 2);

      final firstId = employeeNotifController.notifications.first.id;
      employeeNotifController.markAsRead(firstId);

      final firstNotif = employeeNotifController.notifications.firstWhere((n) => n.id == firstId);
      expect(firstNotif.isRead, isTrue);
    });

    test('CustomerAddressController manages addresses correctly and supports default switching', () {
      final addressController = CustomerAddressController.instance;

      const newAddress = CustomerAddress(
        id: 'addr_test_999',
        type: 'Condo',
        address: 'Unit 12B Horizon Tower, BGC, Taguig City',
        isDefault: false,
      );

      final added = addressController.addAddress(newAddress);
      expect(added, isTrue);

      final found = addressController.addresses.where((a) => a.id == 'addr_test_999').firstOrNull;
      expect(found, isNotNull);
      expect(found!.type, 'Condo');
      expect(found.address, 'Unit 12B Horizon Tower, BGC, Taguig City');

      // Set as default
      addressController.setDefault('addr_test_999');
      final updatedDefault = addressController.defaultAddress;
      expect(updatedDefault?.id, 'addr_test_999');

      // Delete address
      addressController.deleteAddress('addr_test_999');
      expect(addressController.addresses.any((a) => a.id == 'addr_test_999'), isFalse);
    });

    test('Customer can place multiple orders which accumulate and NEVER overwrite previous orders', () {
      final initialCount = employeeOrderController.orders.length;

      // Order 1
      final orderNumber1 = customerOrderController.generateOrderNumber();
      final order1 = createSampleOrder(orderNumber1, OrderStatus.pending);
      customerOrderController.placeOrder(order1);

      expect(employeeOrderController.orders.length, initialCount + 1);
      expect(employeeOrderController.orders.any((o) => o.orderId == orderNumber1), isTrue);

      // Order 2 by the same customer
      final orderNumber2 = customerOrderController.generateOrderNumber();
      expect(orderNumber1, isNot(equals(orderNumber2))); // Different order numbers

      final order2 = createSampleOrder(orderNumber2, OrderStatus.pending);
      customerOrderController.placeOrder(order2);

      // Both orders must exist - order 1 was NOT replaced by order 2
      expect(employeeOrderController.orders.length, initialCount + 2);
      expect(employeeOrderController.orders.any((o) => o.orderId == orderNumber1), isTrue);
      expect(employeeOrderController.orders.any((o) => o.orderId == orderNumber2), isTrue);

      // Order 3 by the same customer
      final orderNumber3 = customerOrderController.generateOrderNumber();
      final order3 = createSampleOrder(orderNumber3, OrderStatus.pending);
      customerOrderController.placeOrder(order3);

      expect(employeeOrderController.orders.length, initialCount + 3);
      expect(employeeOrderController.orders.any((o) => o.orderId == orderNumber1), isTrue);
      expect(employeeOrderController.orders.any((o) => o.orderId == orderNumber2), isTrue);
      expect(employeeOrderController.orders.any((o) => o.orderId == orderNumber3), isTrue);
    });

    test('placeOrder prevents collision: inserting an order with an existing ID generates a unique ID and appends', () {
      final initialCount = employeeOrderController.orders.length;
      final duplicateId = 'ORD-DUPLICATE-ID-999';

      final orderFirst = createSampleOrder(duplicateId, OrderStatus.pending);
      employeeOrderController.placeOrder(orderFirst);
      expect(employeeOrderController.orders.length, initialCount + 1);

      // Place another order with identical ID
      final orderSecond = createSampleOrder(duplicateId, OrderStatus.pending);
      employeeOrderController.placeOrder(orderSecond);

      // Count MUST increase to initialCount + 2, NOT replace!
      expect(employeeOrderController.orders.length, initialCount + 2);
      // Both the original ID and modified suffixed ID exist
      expect(employeeOrderController.orders.any((o) => o.orderId == duplicateId), isTrue);
      expect(employeeOrderController.orders.any((o) => o.orderId.startsWith('$duplicateId-')), isTrue);
    });

    test('CustomerOrder toMap and fromMap serialization roundtrip preserves all fields', () {
      final original = createSampleOrder('ORD-MAP-TEST-1', OrderStatus.confirmed);
      final map = original.toMap();

      expect(map['orderId'], 'ORD-MAP-TEST-1');
      expect(map['customerName'], 'Juan Dela Cruz');
      expect(map['status'], 'confirmed');
      expect(map['totalAmount'], 90.0);
      expect(map['userId'], 'test_user_777');
      expect(map['items'], isNotEmpty);

      final deserialized = CustomerOrder.fromMap(map);
      expect(deserialized.orderId, original.orderId);
      expect(deserialized.customerName, original.customerName);
      expect(deserialized.status, original.status);
      expect(deserialized.totalAmount, original.totalAmount);
      expect(deserialized.userId, original.userId);
      expect(deserialized.items.length, original.items.length);
      expect(deserialized.items.first.productName, original.items.first.productName);
      expect(deserialized.items.first.capital, original.items.first.capital);
      expect(deserialized.items.first.price, original.items.first.price);
    });
  });
}

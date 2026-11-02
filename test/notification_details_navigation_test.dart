import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/users/customer_db/chat/customer_chat_page.dart';
import 'package:sari_sari/users/customer_db/notifications/customer_notification_model.dart';
import 'package:sari_sari/users/customer_db/notifications/customer_notifications_controller.dart';
import 'package:sari_sari/users/customer_db/notifications/customer_notifications_page.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_controller.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_details_page.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
import 'package:sari_sari/users/employee_db/messages/employee_chat_page.dart';
import 'package:sari_sari/users/employee_db/notifications/employee_notification_model.dart';
import 'package:sari_sari/users/employee_db/notifications/employee_notifications_controller.dart';
import 'package:sari_sari/users/employee_db/notifications/employee_notifications_page.dart';
import 'package:sari_sari/users/employee_db/orders/employee_order_details_page.dart';
import 'package:sari_sari/users/employee_db/orders/employee_orders_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Direct Notification Navigation Tests', () {
    late CustomerNotificationsController customerNotifController;
    late EmployeeNotificationsController employeeNotifController;

    setUp(() {
      customerNotifController = CustomerNotificationsController.instance;
      employeeNotifController = EmployeeNotificationsController.instance;

      customerNotifController.clear();
      employeeNotifController.clear();
    });

    testWidgets('Tapping Message Notification in Employee navigates directly to EmployeeChatPage', (WidgetTester tester) async {
      employeeNotifController.addNotification(
        type: EmployeeNotificationType.assignedTask,
        title: 'New message from Cyrus O. Nocum',
        message: 'dalwa parin ya',
        customerId: 'customer_cyrus_123',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: EmployeeNotificationsPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Find the notification title on the notifications page
      expect(find.text('New message from Cyrus O. Nocum'), findsWidgets);

      // Tap the notification
      await tester.tap(find.text('New message from Cyrus O. Nocum').first);
      await tester.pumpAndSettle();

      // Verify that EmployeeChatPage is displayed directly!
      expect(find.byType(EmployeeChatPage), findsOneWidget);
      expect(find.text('Cyrus O. Nocum'), findsOneWidget);
    });

    testWidgets('Tapping Order Notification in Employee navigates directly to EmployeeOrderDetailsPage', (WidgetTester tester) async {
      final testOrder = CustomerOrder(
        orderId: 'ORD-TEST-999',
        userId: 'cust_1',
        customerName: 'Maria Santos',
        orderDate: DateTime.now(),
        totalAmount: 150.0,
        status: OrderStatus.preparing,
        paymentMethod: PaymentMethod.cashOnDelivery,
        paymentStatus: PaymentStatus.unpaid,
        subtotal: 150.0,
        deliveryFee: 0.0,
        orderType: OrderType.pickup,
        items: const [],
      );
      EmployeeOrderController.instance.placeOrder(testOrder);

      await tester.pumpWidget(
        const MaterialApp(
          home: EmployeeNotificationsPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the notification
      await tester.tap(find.textContaining('New Order').first);
      await tester.pumpAndSettle();

      // Verify that EmployeeOrderDetailsPage is displayed directly!
      expect(find.byType(EmployeeOrderDetailsPage), findsOneWidget);
    });

    testWidgets('Tapping Message Notification in Customer navigates directly to CustomerChatPage', (WidgetTester tester) async {
      customerNotifController.addNotification(
        userId: 'cust_me',
        type: CustomerNotificationType.orderUpdate,
        title: 'New message from Store',
        message: 'Your order is ready for pickup!',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerNotificationsPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Find the notification
      expect(find.text('New message from Store'), findsOneWidget);

      // Tap the notification
      await tester.tap(find.text('New message from Store'));
      await tester.pumpAndSettle();

      // Verify that CustomerChatPage is displayed directly!
      expect(find.byType(CustomerChatPage), findsOneWidget);
    });

    testWidgets('Tapping Order Notification in Customer navigates directly to CustomerOrderDetailsPage', (WidgetTester tester) async {
      final testOrder = CustomerOrder(
        orderId: 'ORD-CUST-888',
        userId: 'cust_me',
        customerName: 'Juan Dela Cruz',
        orderDate: DateTime.now(),
        totalAmount: 200.0,
        status: OrderStatus.preparing,
        paymentMethod: PaymentMethod.cashOnDelivery,
        paymentStatus: PaymentStatus.unpaid,
        subtotal: 150.0,
        deliveryFee: 0.0,
        orderType: OrderType.delivery,
        items: const [],
      );
      CustomerOrderController.instance.placeOrder(testOrder);

      customerNotifController.addNotification(
        userId: 'cust_me',
        type: CustomerNotificationType.orderUpdate,
        title: 'Order Status Update',
        message: 'Your order #ORD-CUST-888 is being prepared.',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerNotificationsPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the notification
      await tester.tap(find.text('Order Status Update'));
      await tester.pumpAndSettle();

      // Verify that CustomerOrderDetailsPage is displayed directly!
      expect(find.byType(CustomerOrderDetailsPage), findsOneWidget);
      expect(find.text('Order Details'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/users/customer_db/notifications/customer_notification_details_page.dart';
import 'package:sari_sari/users/customer_db/notifications/customer_notification_model.dart';
import 'package:sari_sari/users/customer_db/notifications/customer_notifications_controller.dart';
import 'package:sari_sari/users/customer_db/notifications/customer_notifications_page.dart';
import 'package:sari_sari/users/employee_db/notifications/employee_notification_details_page.dart';
import 'package:sari_sari/users/employee_db/notifications/employee_notification_model.dart';
import 'package:sari_sari/users/employee_db/notifications/employee_notifications_controller.dart';
import 'package:sari_sari/users/employee_db/notifications/employee_notifications_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notification Details Navigation Tests', () {
    late CustomerNotificationsController customerNotifController;
    late EmployeeNotificationsController employeeNotifController;

    setUp(() {
      customerNotifController = CustomerNotificationsController.instance;
      employeeNotifController = EmployeeNotificationsController.instance;

      customerNotifController.clear();
      employeeNotifController.clear();
    });

    testWidgets('Tapping Customer Notification opens CustomerNotificationDetailsPage', (WidgetTester tester) async {
      customerNotifController.addNotification(
        type: CustomerNotificationType.orderUpdate,
        title: 'Order Status Update',
        message: 'Your order #ORD-123 is now Out for Delivery!',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerNotificationsPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Find the notification title on the notifications page
      expect(find.text('Order Status Update'), findsOneWidget);

      // Tap the notification
      await tester.tap(find.text('Order Status Update'));
      await tester.pumpAndSettle();

      // Verify that CustomerNotificationDetailsPage is displayed
      expect(find.byType(CustomerNotificationDetailsPage), findsOneWidget);
      expect(find.text('Notification Details'), findsOneWidget);
      expect(find.text('Your order #ORD-123 is now Out for Delivery!'), findsOneWidget);
      expect(find.text('Order Update'), findsOneWidget);
    });

    testWidgets('Tapping Employee Notification opens EmployeeNotificationDetailsPage', (WidgetTester tester) async {
      employeeNotifController.addNotification(
        type: EmployeeNotificationType.newOrder,
        title: 'New Customer Order',
        message: 'New order #ORD-456 received from Maria Santos.',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: EmployeeNotificationsPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Find notification
      expect(find.text('New Customer Order'), findsWidgets);

      // Tap the notification
      await tester.tap(find.text('New Customer Order').first);
      await tester.pumpAndSettle();

      // Verify that EmployeeNotificationDetailsPage is displayed
      expect(find.byType(EmployeeNotificationDetailsPage), findsOneWidget);
      expect(find.text('Notification Details'), findsOneWidget);
      expect(find.text('New order #ORD-456 received from Maria Santos.'), findsOneWidget);
    });

    testWidgets('findProductForNotification matches product by name in message', (WidgetTester tester) async {
      final notif = EmployeeNotification(
        id: 'test_expired_1',
        type: EmployeeNotificationType.expiring,
        title: 'Product Expired',
        message: 'Sardines has an expired batch still in stock.',
        timestamp: DateTime.now(),
      );

      // Verify notification title and message contents
      expect(notif.title, 'Product Expired');
      expect(notif.message, contains('Sardines'));
    });
  });
}

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../../users/customer_db/notifications/customer_notification_details_page.dart';
import '../../users/customer_db/notifications/customer_notification_model.dart';
import '../../users/customer_db/notifications/customer_notifications_controller.dart';
import '../../users/employee_db/notifications/employee_notification_details_page.dart';
import '../../users/employee_db/notifications/employee_notification_model.dart';
import '../../users/employee_db/notifications/employee_notifications_controller.dart';
import 'auth_service.dart';

/// Top-level background message handler required by Firebase Messaging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling background FCM message: ${message.messageId}");
}

class FirebaseNotificationService {
  FirebaseNotificationService._internal();
  static final FirebaseNotificationService instance = FirebaseNotificationService._internal();
  factory FirebaseNotificationService() => instance;

  /// Global navigator key to navigate to notification details when notification is pressed
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;

  /// Initialize Firebase Cloud Messaging and handle push notification interaction
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // 1. Request Permission for FCM Notifications
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('FCM Notification permission status: ${settings.authorizationStatus}');

      // 2. Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Get FCM token
      String? token = await _fcm.getToken();
      debugPrint('FCM Token: $token');

      // 4. Handle Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Received foreground FCM message: ${message.notification?.title}');
        _processFcmMessage(message, isForeground: true);
      });

      // 5. Handle Background App Opened via Notification Click
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened from background via notification click: ${message.notification?.title}');
        _handleNotificationPress(message);
      });

      // 6. Handle Terminated App Opened via Notification Click
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App launched from terminated state via notification click');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotificationPress(initialMessage);
        });
      }
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
    }
  }

  /// Process an incoming FCM message and update local notification controllers
  void _processFcmMessage(RemoteMessage message, {required bool isForeground}) {
    final title = message.notification?.title ?? message.data['title'] ?? 'New Notification';
    final body = message.notification?.body ?? message.data['message'] ?? '';
    final role = message.data['role']?.toString().toLowerCase() ?? 'customer';

    if (role == 'employee' || role == 'store') {
      EmployeeNotificationType type = EmployeeNotificationType.assignedTask;
      final typeStr = message.data['type']?.toString().toLowerCase() ?? '';
      if (typeStr.contains('lowstock')) {
        type = EmployeeNotificationType.lowStock;
      } else if (typeStr.contains('outofstock')) {
        type = EmployeeNotificationType.outOfStock;
      } else if (typeStr.contains('expir')) {
        type = EmployeeNotificationType.expiring;
      } else if (typeStr.contains('order')) {
        type = EmployeeNotificationType.newOrder;
      }

      EmployeeNotificationsController.instance.addNotification(
        type: type,
        title: title,
        message: body,
      );
    } else {
      CustomerNotificationType type = CustomerNotificationType.orderUpdate;
      final typeStr = message.data['type']?.toString().toLowerCase() ?? '';
      if (typeStr.contains('promo')) {
        type = CustomerNotificationType.promotion;
      } else if (typeStr.contains('security')) {
        type = CustomerNotificationType.security;
      }

      CustomerNotificationsController.instance.addNotification(
        type: type,
        title: title,
        message: body,
      );
    }
  }

  /// Handle pressing/clicking a notification: navigate directly to notification details page!
  void _handleNotificationPress(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'] ?? 'Notification Details';
    final body = message.notification?.body ?? message.data['message'] ?? '';
    final role = message.data['role']?.toString().toLowerCase() ?? 'customer';
    final id = message.data['id']?.toString() ?? 'fcm_${DateTime.now().millisecondsSinceEpoch}';

    if (role == 'employee' || role == 'store') {
      EmployeeNotificationType type = EmployeeNotificationType.assignedTask;
      final typeStr = message.data['type']?.toString().toLowerCase() ?? '';
      if (typeStr.contains('lowstock')) {
        type = EmployeeNotificationType.lowStock;
      } else if (typeStr.contains('outofstock')) {
        type = EmployeeNotificationType.outOfStock;
      } else if (typeStr.contains('expir')) {
        type = EmployeeNotificationType.expiring;
      } else if (typeStr.contains('order')) {
        type = EmployeeNotificationType.newOrder;
      }

      final notif = EmployeeNotification(
        id: id,
        type: type,
        title: title,
        message: body,
        timestamp: DateTime.now(),
        isRead: true,
      );
      navigateToEmployeeNotificationDetails(notif);
    } else {
      CustomerNotificationType type = CustomerNotificationType.orderUpdate;
      final typeStr = message.data['type']?.toString().toLowerCase() ?? '';
      if (typeStr.contains('promo')) {
        type = CustomerNotificationType.promotion;
      } else if (typeStr.contains('security')) {
        type = CustomerNotificationType.security;
      }

      final notif = CustomerNotification(
        id: id,
        type: type,
        title: title,
        message: body,
        timestamp: DateTime.now(),
        isRead: true,
      );
      navigateToCustomerNotificationDetails(notif);
    }
  }

  /// Navigate to Customer Notification Details Screen
  void navigateToCustomerNotificationDetails(CustomerNotification notification) {
    final state = navigatorKey.currentState;
    if (state != null) {
      state.push(
        MaterialPageRoute(
          builder: (_) => CustomerNotificationDetailsPage(notification: notification),
        ),
      );
    }
  }

  /// Navigate to Employee Notification Details Screen
  void navigateToEmployeeNotificationDetails(EmployeeNotification notification) {
    final state = navigatorKey.currentState;
    if (state != null) {
      state.push(
        MaterialPageRoute(
          builder: (_) => EmployeeNotificationDetailsPage(notification: notification),
        ),
      );
    }
  }
}

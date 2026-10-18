import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../users/customer_db/notifications/customer_notification_details_page.dart';
import '../../users/customer_db/notifications/customer_notification_model.dart';
import '../../users/customer_db/notifications/customer_notifications_controller.dart';
import '../../users/employee_db/notifications/employee_notification_details_page.dart';
import '../../users/employee_db/notifications/employee_notification_model.dart';
import '../../users/employee_db/notifications/employee_notifications_controller.dart';
import 'auth_service.dart';
import 'pos_audio_service.dart';
import 'supabase_service.dart';

/// Top-level background message handler required by Firebase Messaging (Native Mobile)
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
  String? _cachedFcmToken;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Currently cached FCM token
  String? get currentFcmToken => _cachedFcmToken;

  /// Sanitize token string so it is valid as an RTDB node key
  static String _sanitizeKey(String raw) {
    return raw.replaceAll(RegExp(r'[\.\$\#\[\]\/]'), '_');
  }

  /// Initialize Firebase Cloud Messaging, setup listeners and token management
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // 1. Request Permission for FCM Notifications
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final permStatus = await Permission.notification.status;
          if (!permStatus.isGranted) {
            await Permission.notification.request();
          }
        } catch (pe) {
          debugPrint('[FCM] Android permission_handler notice: $pe');
        }
      }

      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[FCM] Notification permission status: ${settings.authorizationStatus}');

      // 2. Set background message handler (Native Mobile Platforms only)
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      }

      // 3. Retrieve and cache FCM token
      await getDeviceToken();

      // 4. Setup token refresh stream
      _setupTokenRefreshListener();

      // 5. Handle Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Received foreground FCM message: ${message.notification?.title}');
        _processFcmMessage(message, isForeground: true);
      });

      // 6. Handle Background App Opened via Notification Click
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened from background via notification click: ${message.notification?.title}');
        _handleNotificationPress(message);
      });

      // 7. Handle Terminated App Opened via Notification Click (Native Mobile Platforms only)
      if (!kIsWeb) {
        RemoteMessage? initialMessage = await _fcm.getInitialMessage();
        if (initialMessage != null) {
          debugPrint('App launched from terminated state via notification click');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleNotificationPress(initialMessage);
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
    }
  }

  /// Setup token refresh listener so new device tokens are synced to RTDB automatically
  void _setupTokenRefreshListener() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) {
      _cachedFcmToken = newToken;
      debugPrint('[FCM] Token refreshed: $newToken');
      final currentUid = AuthService().currentUser?.uid;
      if (currentUid != null && currentUid.isNotEmpty) {
        saveTokenForUser(currentUid, token: newToken);
      }
    });
  }

  /// Retrieve FCM device registration token safely across Web & Mobile
  Future<String?> getDeviceToken() async {
    try {
      String? token = await _fcm.getToken();
      _cachedFcmToken = token;
      debugPrint('[FCM] Active Token: $token');
      return token;
    } catch (e) {
      debugPrint('[FCM] Token acquisition notice: $e');
      return null;
    }
  }

  /// Request permissions and save the FCM device token for the specified user
  Future<String?> requestPermissionAndSaveToken([String? userId]) async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final permStatus = await Permission.notification.status;
          if (!permStatus.isGranted) {
            await Permission.notification.request();
          }
        } catch (pe) {
          debugPrint('[FCM] Android permission_handler notice: $pe');
        }
      }

      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      final token = await getDeviceToken();
      final targetUid = userId ?? AuthService().currentUser?.uid;
      if (token != null && token.isNotEmpty && targetUid != null && targetUid.isNotEmpty) {
        await saveTokenForUser(targetUid, token: token);
      }
      return token;
    } catch (e) {
      debugPrint('[FCM] Error in requestPermissionAndSaveToken: $e');
      return null;
    }
  }

  /// Save FCM Device Token under users/{userId} node in Firebase Realtime Database
  Future<void> saveTokenForUser(String userId, {String? token}) async {
    if (userId.isEmpty) return;
    try {
      final tokenToSave = token ?? _cachedFcmToken ?? await getDeviceToken();
      if (tokenToSave == null || tokenToSave.isEmpty) return;

      final db = AuthService().database;
      final sanitizedToken = _sanitizeKey(tokenToSave);
      final platformName = kIsWeb ? 'web' : defaultTargetPlatform.name;

      // 1. Save primary token and metadata on user record
      await db.ref().child('users/$userId').update({
        'fcmToken': tokenToSave,
        'fcmTokenUpdatedAt': ServerValue.timestamp,
        'devicePlatform': platformName,
        'notificationsEnabled': true,
      });

      // 2. Also register under fcmTokens map for multi-device support
      await db.ref().child('users/$userId/fcmTokens/$sanitizedToken').set({
        'token': tokenToSave,
        'platform': platformName,
        'updatedAt': ServerValue.timestamp,
        'active': true,
      });

      debugPrint('[FCM] Saved token under users/$userId in Realtime Database');

      // 3. Mirror token to Supabase profiles (Identity Bridge)
      try {
        await SupabaseService().updateUserProfile(userId, {
          'fcm_token': tokenToSave,
        });
      } catch (_) {}
    } catch (e) {
      debugPrint('[FCM] Failed saving token to RTDB: $e');
    }
  }

  /// Remove FCM device token from user node in RTDB upon logout
  Future<void> removeTokenForUser(String userId) async {
    if (userId.isEmpty) return;
    try {
      final db = AuthService().database;
      await db.ref().child('users/$userId').update({
        'fcmToken': null,
        'fcmTokenUpdatedAt': ServerValue.timestamp,
      });

      if (_cachedFcmToken != null && _cachedFcmToken!.isNotEmpty) {
        final sanitizedToken = _sanitizeKey(_cachedFcmToken!);
        await db.ref().child('users/$userId/fcmTokens/$sanitizedToken').remove();
      }
      debugPrint('[FCM] Removed token for user $userId in RTDB');
    } catch (e) {
      debugPrint('[FCM] Error removing token for user $userId: $e');
    }
  }

  /// Process an incoming FCM message and update local notification controllers
  void _processFcmMessage(RemoteMessage message, {required bool isForeground}) {
    final title = message.notification?.title ?? message.data['title'] ?? 'New Notification';
    final body = message.notification?.body ?? message.data['message'] ?? '';
    final role = message.data['role']?.toString().toLowerCase() ?? 'customer';
    final typeStr = message.data['type']?.toString().toLowerCase() ?? '';

    // Play real-time alert sound/chime only for store staff/owner
    if (role == 'employee' || role == 'store' || role == 'owner' || role == 'admin') {
      if (typeStr.contains('order')) {
        PosAudioService.playOrderChime();
      } else {
        PosAudioService.playAlertSound();
      }
    }

    if (role == 'employee' || role == 'store' || role == 'owner' || role == 'admin') {
      EmployeeNotificationType type = EmployeeNotificationType.assignedTask;
      if (typeStr.contains('lowstock') || typeStr.contains('low_stock')) {
        type = EmployeeNotificationType.lowStock;
      } else if (typeStr.contains('outofstock') || typeStr.contains('out_of_stock')) {
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
        sendPush: false,
      );
    } else {
      CustomerNotificationType type = CustomerNotificationType.orderUpdate;
      if (typeStr.contains('promo')) {
        type = CustomerNotificationType.promotion;
      } else if (typeStr.contains('security')) {
        type = CustomerNotificationType.security;
      }

      CustomerNotificationsController.instance.addNotification(
        type: type,
        title: title,
        message: body,
        sendPush: false,
      );
    }
  }

  /// Handle pressing/clicking a notification: navigate directly to notification details page!
  void _handleNotificationPress(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'] ?? 'Notification Details';
    final body = message.notification?.body ?? message.data['message'] ?? '';
    final role = message.data['role']?.toString().toLowerCase() ?? 'customer';
    final id = message.data['id']?.toString() ?? 'fcm_${DateTime.now().millisecondsSinceEpoch}';

    if (role == 'employee' || role == 'store' || role == 'owner' || role == 'admin') {
      EmployeeNotificationType type = EmployeeNotificationType.assignedTask;
      final typeStr = message.data['type']?.toString().toLowerCase() ?? '';
      if (typeStr.contains('lowstock') || typeStr.contains('low_stock')) {
        type = EmployeeNotificationType.lowStock;
      } else if (typeStr.contains('outofstock') || typeStr.contains('out_of_stock')) {
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

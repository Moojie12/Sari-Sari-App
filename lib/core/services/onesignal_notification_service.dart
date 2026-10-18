// lib/core/services/onesignal_notification_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../users/employee_db/notifications/employee_notifications_controller.dart';
import '../../users/employee_db/notifications/employee_notification_model.dart';
import '../../users/customer_db/notifications/customer_notifications_controller.dart';
import '../../users/customer_db/notifications/customer_notification_model.dart';
import '../../users/employee_db/notifications/employee_notification_details_page.dart';
import '../../users/customer_db/notifications/customer_notification_details_page.dart';
import '../../users/employee_db/orders/employee_orders_controller.dart';
import '../../users/employee_db/orders/employee_order_details_page.dart';
import '../../users/customer_db/purchases/customer_order_controller.dart';
import '../../users/customer_db/purchases/customer_order_details_page.dart';
import '../../users/customer_db/purchases/customer_order_model.dart';
import '../../users/owner_db/owner_db.dart';
import '../../users/employee_db/employee_db.dart';
import '../../users/customer_db/customer_db.dart';
import '../splash/splash_page.dart';
import 'auth_service.dart';
import 'firebase_notification_service.dart';
import 'onesignal_config.dart';
import 'pos_audio_service.dart';

class OneSignalNotificationService {
  OneSignalNotificationService._internal();
  static final OneSignalNotificationService instance = OneSignalNotificationService._internal();
  factory OneSignalNotificationService() => instance;

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _initialized = false;
  String? _currentUserId;
  String? _currentUserRole;
  bool hasActiveNotificationOpen = false;

  bool get isInitialized => _initialized;
  String? get currentUserId => _currentUserId;
  String? get currentUserRole => _currentUserRole;

  static String get _authHeader {
    final key = OneSignalConfig.restApiKey.trim();
    if (key.startsWith('os_v2_') || key.startsWith('os_v1_')) {
      return 'Key $key';
    }
    return 'Basic $key';
  }

  /// Initialize OneSignal SDK, setup listeners and request permissions
  Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb) {
      debugPrint('[OneSignal] Web platform detected. Native OneSignal push disabled.');
      _initialized = true;
      return;
    }

    if (!OneSignalConfig.isConfigured) {
      debugPrint('[OneSignal] Notice: App ID not configured yet in onesignal_config.dart. Push notifications will be inactive until configured.');
      _initialized = true;
      return;
    }

    try {
      // 1. Debug log level
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }

      // 2. Initialize OneSignal with App ID
      OneSignal.initialize(OneSignalConfig.appId);

      // 3. Request Notification Permission and Opt In
      final permission = await OneSignal.Notifications.requestPermission(true);
      await OneSignal.User.pushSubscription.optIn();
      debugPrint('[OneSignal] Notification permission granted: $permission, optedIn: ${OneSignal.User.pushSubscription.optedIn}');

      // 4. Push subscription observer
      OneSignal.User.pushSubscription.addObserver((state) {
        debugPrint('[OneSignal] Push subscription update: id=${state.current.id}, token=${state.current.token}, optedIn=${state.current.optedIn}');
      });

      // 5. Foreground notification display listener
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        debugPrint('[OneSignal] Foreground push received: ${event.notification.title}');
        final data = event.notification.additionalData;
        _processPushPayload(
          title: event.notification.title ?? 'New Notification',
          body: event.notification.body ?? '',
          data: data,
          isForeground: true,
        );
        // Display the standard system notification even while app is in foreground
        event.notification.display();
      });

      // 6. Notification clicked / opened listener
      OneSignal.Notifications.addClickListener((event) {
        debugPrint('[OneSignal] Notification clicked: ${event.notification.title}');
        final data = event.notification.additionalData;
        _handleNotificationPress(
          title: event.notification.title ?? 'Notification',
          body: event.notification.body ?? '',
          data: data,
        );
      });

      // 7. Clear any lingering test notifications from notification bar
      try {
        OneSignal.Notifications.clearAll();
      } catch (_) {}

      _initialized = true;
      debugPrint('[OneSignal] Initialization successful.');

      // If user is already signed in, register their tag and external_id
      final currentUser = AuthService().currentUser;
      if (currentUser != null && currentUser.uid.isNotEmpty) {
        final role = await AuthService().getCurrentUserRole();
        await loginUser(currentUser.uid, role);
      }
    } catch (e) {
      debugPrint('[OneSignal] Initialization error: $e');
    }
  }

  /// Register user and assign their specific role tag in OneSignal
  Future<void> loginUser(String userId, String role) async {
    if (kIsWeb || !OneSignalConfig.isConfigured || userId.isEmpty) return;

    try {
      final cleanRole = role.toLowerCase().trim();
      _currentUserId = userId;
      _currentUserRole = cleanRole;

      // Link device to external user ID (Firebase UID)
      await OneSignal.login(userId);

      // Look up Supabase profile ID if available so OneSignal knows both IDs
      String? supabaseProfileId;
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('firebase_uid', userId)
            .maybeSingle();
        supabaseProfileId = profile?['id']?.toString();
      } catch (_) {}

      // Set user role and ID tags for targeted filtering
      final userTags = <String, String>{
        'role': cleanRole,
        'userId': userId,
      };
      if (supabaseProfileId != null) {
        userTags['supabaseId'] = supabaseProfileId;
      }
      await OneSignal.User.addTags(userTags);

      if (supabaseProfileId != null) {
        try {
          await OneSignal.User.addAlias('supabase_id', supabaseProfileId);
        } catch (_) {}
      }

      // Explicitly opt in to push subscriptions
      await OneSignal.User.pushSubscription.optIn();

      debugPrint('[OneSignal] User tagged successfully: id=$userId, supabaseId=$supabaseProfileId, role=$cleanRole');

      // Sync FCM push token to OneSignal player so notifications are delivered reliably
      await syncPushSubscriptionToken(userId);
    } catch (e) {
      debugPrint('[OneSignal] Failed to login and tag user: $e');
    }
  }

  /// Ensure device FCM token is properly registered and subscribed with OneSignal player
  Future<void> syncPushSubscriptionToken(String userId) async {
    if (kIsWeb || !OneSignalConfig.canSendPush || userId.isEmpty) return;

    try {
      await OneSignal.User.pushSubscription.optIn();

      // Check if OneSignal push token is already ready
      String? pushToken = OneSignal.User.pushSubscription.token;

      // If null, retrieve FCM token directly from Firebase Messaging
      if (pushToken == null || pushToken.isEmpty) {
        pushToken = FirebaseNotificationService.instance.currentFcmToken;
        pushToken ??= await FirebaseNotificationService.instance.getDeviceToken();
      }

      if (pushToken == null || pushToken.isEmpty) {
        debugPrint('[OneSignal] Note: No push token available yet to sync for user $userId');
        return;
      }

      // Try local subscription id first
      String? subId = OneSignal.User.pushSubscription.id;

      // If null locally, query OneSignal for this user's subscription
      if (subId == null || subId.isEmpty) {
        final userUrl = Uri.parse(
          'https://onesignal.com/api/v1/apps/${OneSignalConfig.appId}/users/by/external_id/$userId',
        );
        final userResp = await http.get(userUrl, headers: {
          'Authorization': _authHeader,
        });
        if (userResp.statusCode >= 200 && userResp.statusCode < 300) {
          final userData = jsonDecode(userResp.body);
          final subs = userData['subscriptions'] as List?;
          if (subs != null && subs.isNotEmpty) {
            subId = subs.first['id']?.toString();
          }
        }
      }

      // Register or update token on OneSignal player
      if (subId != null && subId.isNotEmpty) {
        final playerUrl = Uri.parse('https://onesignal.com/api/v1/players/$subId');
        final updateResp = await http.put(
          playerUrl,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': _authHeader,
          },
          body: jsonEncode({
            'app_id': OneSignalConfig.appId,
            'identifier': pushToken,
            'notification_types': 1,
          }),
        );
        debugPrint('[OneSignal] Synced push token to OneSignal subscription $subId (status: ${updateResp.statusCode})');
      }
    } catch (e) {
      debugPrint('[OneSignal] Exception syncing push token: $e');
    }
  }

  /// Clear tags and logout user from OneSignal
  Future<void> logoutUser() async {
    if (kIsWeb || !OneSignalConfig.isConfigured) return;

    try {
      await OneSignal.User.removeTags(['role', 'userId']);
      await OneSignal.logout();
      _currentUserId = null;
      _currentUserRole = null;
      debugPrint('[OneSignal] User logged out from OneSignal.');
    } catch (e) {
      debugPrint('[OneSignal] Error logging out user: $e');
    }
  }

  /// Send push notification for a new order strictly to Store Staff (Owner, Employee, Admin)
  Future<bool> sendNewOrderNotificationToStaff({
    required String orderId,
    required String customerName,
    required double totalAmount,
    String? excludeUserId,
  }) async {
    final displayName = customerName.isNotEmpty ? customerName : 'A customer';
    final title = 'New Order Placed';
    final body = 'Order #$orderId from $displayName for \u{20B1}${totalAmount.toStringAsFixed(2)}';
    return sendStaffNotification(
      title: title,
      body: body,
      orderId: orderId,
      type: 'new_order',
      excludeUserId: excludeUserId,
    );
  }

  /// Send push notification to Store Staff (Owner, Employee, Admin)
  /// for ANY staff-bound notification (New order, Order cancelled, Refund details, etc.)
  Future<bool> sendStaffNotification({
    required String title,
    required String body,
    String? orderId,
    String? type,
    String? excludeUserId,
  }) async {
    if (!OneSignalConfig.canSendPush) {
      debugPrint('[OneSignal] Cannot send push: REST API Key or App ID not configured in onesignal_config.dart');
      return false;
    }

    try {
      final url = Uri.parse('https://onesignal.com/api/v1/notifications');

      // Build filters targeting owner, employee, and admin
      // If excludeUserId is present, exclude that specific user from receiving the push
      final actorToExclude = excludeUserId ?? AuthService().currentUser?.uid;
      final filters = <Map<String, dynamic>>[];
      final roles = ['owner', 'employee', 'admin'];
      for (int i = 0; i < roles.length; i++) {
        if (i > 0) filters.add({'operator': 'OR'});
        filters.add({'field': 'tag', 'key': 'role', 'relation': '=', 'value': roles[i]});
        if (actorToExclude != null && actorToExclude.isNotEmpty) {
          filters.add({'field': 'tag', 'key': 'userId', 'relation': '!=', 'value': actorToExclude});
        }
      }

      final payload = {
        'app_id': OneSignalConfig.appId,
        'headings': {'en': title},
        'contents': {'en': body},
        'filters': filters,
        'data': {
          'type': type ?? 'staff_alert',
          'targetRole': 'staff',
          ...?orderId != null ? {'orderId': orderId} : null,
        },
        'priority': 10,
        'android_visibility': 1,
        'android_accent_color': 'FFEF820D',
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': _authHeader,
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final resData = jsonDecode(response.body);
        final notifId = resData['id'];
        final recipients = resData['recipients'];
        final errors = resData['errors'];
        debugPrint('[OneSignal] Staff push sent: id=$notifId, recipients=$recipients, errors=$errors');
        return true;
      } else {
        debugPrint('[OneSignal] Error sending staff push: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[OneSignal] Exception sending staff push: $e');
      return false;
    }
  }

  /// Send push notification to a specific customer (e.g. order ready, delivery update, etc.)
  Future<bool> sendCustomerNotification({
    required String customerUserId,
    required String title,
    required String body,
    String? orderId,
    String? type,
    String? excludeUserId,
  }) async {
    if (!OneSignalConfig.canSendPush || customerUserId.isEmpty) return false;

    // Collect all possible identifiers for this customer (Firebase UID and Supabase Profile UUID)
    final targetIds = <String>{customerUserId};

    // If customerUserId is a UUID (from Supabase orders table), resolve to Firebase UID
    final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(customerUserId);
    if (isUuid) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('firebase_uid')
            .eq('id', customerUserId)
            .maybeSingle();
        final fUid = profile?['firebase_uid']?.toString();
        if (fUid != null && fUid.isNotEmpty) {
          targetIds.add(fUid);
          debugPrint('[OneSignal] Resolved customer Supabase ID $customerUserId -> Firebase UID $fUid');
        }
      } catch (e) {
        debugPrint('[OneSignal] Error resolving customer Supabase ID: $e');
      }
    } else {
      // If customerUserId is a Firebase UID, also resolve to Supabase Profile UUID
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('firebase_uid', customerUserId)
            .maybeSingle();
        final pId = profile?['id']?.toString();
        if (pId != null && pId.isNotEmpty) {
          targetIds.add(pId);
        }
      } catch (_) {}
    }

    // Do NOT send push notification to customer if they performed the action themselves!
    final actor = excludeUserId ?? AuthService().currentUser?.uid;
    if (actor != null && targetIds.contains(actor)) {
      debugPrint('[OneSignal] Suppressing customer push for own action on user $customerUserId');
      return false;
    }

    try {
      final url = Uri.parse('https://onesignal.com/api/v1/notifications');
      final payload = {
        'app_id': OneSignalConfig.appId,
        'headings': {'en': title},
        'contents': {'en': body},
        'include_aliases': {
          'external_id': targetIds.toList(),
        },
        'target_channel': 'push',
        'data': {
          'type': type ?? 'order_update',
          'targetRole': 'customer',
          ...?orderId != null ? {'orderId': orderId} : null,
        },
        'priority': 10,
        'android_visibility': 1,
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': _authHeader,
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final resData = jsonDecode(response.body);
        final notifId = resData['id'];
        final errors = resData['errors'];
        debugPrint('[OneSignal] Customer push sent: id=$notifId, targets=$targetIds, errors=$errors');
        return true;
      } else {
        debugPrint('[OneSignal] Error sending customer push: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[OneSignal] Exception sending customer push: $e');
      return false;
    }
  }

  /// Process incoming notification data payload and update in-app controllers
  void _processPushPayload({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    required bool isForeground,
  }) {
    final typeStr = data?['type']?.toString().toLowerCase() ?? '';
    final targetRole = data?['targetRole']?.toString().toLowerCase() ?? '';
    final orderId = data?['orderId']?.toString();

    // Check if receiver is store staff
    final isStaff = _currentUserRole == 'owner' ||
        _currentUserRole == 'employee' ||
        _currentUserRole == 'admin' ||
        targetRole == 'staff';

    if (isStaff) {
      if (typeStr.contains('order')) {
        PosAudioService.playOrderChime();
      } else {
        PosAudioService.playAlertSound();
      }

      EmployeeNotificationType type = EmployeeNotificationType.newOrder;
      if (typeStr.contains('lowstock')) {
        type = EmployeeNotificationType.lowStock;
      } else if (typeStr.contains('outofstock')) {
        type = EmployeeNotificationType.outOfStock;
      }

      EmployeeNotificationsController.instance.addNotification(
        type: type,
        title: title,
        message: body,
        orderId: orderId,
        sendPush: false, // Prevent infinite loop of sending push
      );
    } else {
      CustomerNotificationsController.instance.addNotification(
        type: CustomerNotificationType.orderUpdate,
        title: title,
        message: body,
        orderId: orderId,
        sendPush: false, // Prevent infinite loop of sending push
      );
    }
  }

  /// Open corresponding order details (or fallback to notification details) when notification is tapped
  void _handleNotificationPress({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) {
    hasActiveNotificationOpen = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final nav = navigatorKey.currentState;
      if (nav == null) {
        hasActiveNotificationOpen = false;
        return;
      }

      final targetRole = data?['targetRole']?.toString().toLowerCase() ?? '';
      final isStaff = _currentUserRole == 'owner' ||
          _currentUserRole == 'employee' ||
          _currentUserRole == 'admin' ||
          targetRole == 'staff';
      final orderId = data?['orderId']?.toString();

      Widget targetDetailsPage;

      if (isStaff) {
        CustomerOrder? matchedOrder;
        if (orderId != null && orderId.isNotEmpty) {
          // 1. Try to find the order in EmployeeOrderController memory
          try {
            matchedOrder = EmployeeOrderController.instance.orders.firstWhere(
              (o) => o.orderId == orderId || o.displayOrderId == orderId,
            );
          } catch (_) {}

          // 2. If not found in memory, fetch directly from Firebase Realtime Database
          if (matchedOrder == null) {
            try {
              final snapshot = await AuthService().database.ref().child('orders/$orderId').get();
              if (snapshot.value != null && snapshot.value is Map) {
                matchedOrder = CustomerOrder.fromMap(snapshot.value as Map);
              }
            } catch (e) {
              debugPrint('[OneSignal] Error fetching order for staff press: $e');
            }
          }
        }

        if (matchedOrder != null) {
          targetDetailsPage = EmployeeOrderDetailsPage(
            order: matchedOrder,
            controller: EmployeeOrderController.instance,
          );
        } else {
          // Fallback: Show Employee Notification Details
          final notif = EmployeeNotification(
            id: 'onesignal_${DateTime.now().millisecondsSinceEpoch}',
            type: EmployeeNotificationType.newOrder,
            title: title,
            message: body,
            timestamp: DateTime.now(),
            orderId: orderId,
          );
          targetDetailsPage = EmployeeNotificationDetailsPage(notification: notif);
        }
      } else {
        // Customer Role: Navigate directly to Customer Order Details
        CustomerOrder? matchedOrder;
        if (orderId != null && orderId.isNotEmpty) {
          matchedOrder = CustomerOrderController.instance.getOrderById(orderId);

          if (matchedOrder == null) {
            try {
              final snapshot = await AuthService().database.ref().child('orders/$orderId').get();
              if (snapshot.value != null && snapshot.value is Map) {
                matchedOrder = CustomerOrder.fromMap(snapshot.value as Map);
              }
            } catch (e) {
              debugPrint('[OneSignal] Error fetching order for customer press: $e');
            }
          }
        }

        if (matchedOrder != null) {
          targetDetailsPage = CustomerOrderDetailsPage(order: matchedOrder);
        } else {
          // Fallback: Show Customer Notification Details
          final notif = CustomerNotification(
            id: 'onesignal_${DateTime.now().millisecondsSinceEpoch}',
            type: CustomerNotificationType.orderUpdate,
            title: title,
            message: body,
            timestamp: DateTime.now(),
          );
          targetDetailsPage = CustomerNotificationDetailsPage(notification: notif);
        }
      }

      // If splash screen is currently active (e.g. app launched cold or from background restart),
      // replace the root with the appropriate user Dashboard and push details on top.
      // This prevents SplashPage timers from evicting detailsPage, and pressing back returns cleanly to dashboard!
      if (SplashPage.isCurrent) {
        Widget rootDashboard;
        if (isStaff) {
          bool isOwner = false;
          try {
            isOwner = await AuthService().hasRole('owner');
          } catch (_) {}
          rootDashboard = isOwner ? const OwnerDb() : const EmployeeDb();
        } else {
          rootDashboard = const CustomerDb();
        }

        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => rootDashboard),
          (route) => false,
        );
      }

      // Navigate to the target details page and stay there until user explicitly taps back
      try {
        await nav.push(
          MaterialPageRoute(builder: (_) => targetDetailsPage),
        );
      } finally {
        hasActiveNotificationOpen = false;
      }
    });
  }
}

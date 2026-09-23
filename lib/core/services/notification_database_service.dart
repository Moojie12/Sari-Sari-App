import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../users/customer_db/notifications/customer_notification_model.dart';
import '../../users/employee_db/notifications/employee_notification_model.dart';
import 'auth_service.dart';

/// Database service dedicated to persisting and streaming notifications in real-time
/// via Firebase Realtime Database.
class NotificationDatabaseService {
  NotificationDatabaseService._internal();
  static final NotificationDatabaseService instance = NotificationDatabaseService._internal();
  factory NotificationDatabaseService() => instance;

  final AuthService _authService = AuthService();

  // =========================================================================
  // CUSTOMER NOTIFICATIONS
  // =========================================================================

  /// Save a customer notification to Firebase Realtime Database at:
  /// `notifications/customers/$userId/$notifId`
  Future<void> saveCustomerNotification(
    String userId,
    CustomerNotification notification,
  ) async {
    if (userId.isEmpty) return;
    try {
      final db = _authService.database;
      final ref = db.ref().child('notifications/customers/$userId/${notification.id}');
      await ref.set({
        'id': notification.id,
        'type': notification.type.name,
        'title': notification.title,
        'message': notification.message,
        'timestamp': notification.timestamp.toIso8601String(),
        'isRead': notification.isRead,
      });
      debugPrint('Saved customer notification #${notification.id} to database for user $userId');
    } catch (e) {
      debugPrint('Failed to save customer notification to database: $e');
    }
  }

  /// Update the isRead flag for a customer notification in Firebase Realtime Database
  Future<void> markCustomerNotificationRead(String userId, String notifId) async {
    if (userId.isEmpty || notifId.isEmpty) return;
    try {
      final db = _authService.database;
      await db.ref().child('notifications/customers/$userId/$notifId').update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('Failed to mark customer notification read in database: $e');
    }
  }

  /// Mark all customer notifications as read in Firebase Realtime Database
  Future<void> markAllCustomerNotificationsRead(String userId, List<String> notifIds) async {
    if (userId.isEmpty || notifIds.isEmpty) return;
    try {
      final db = _authService.database;
      final updates = <String, dynamic>{};
      for (final id in notifIds) {
        updates['notifications/customers/$userId/$id/isRead'] = true;
      }
      await db.ref().update(updates);
    } catch (e) {
      debugPrint('Failed to mark all customer notifications read: $e');
    }
  }

  /// Load existing customer notifications from Firebase Realtime Database
  Future<List<CustomerNotification>> loadCustomerNotifications(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final db = _authService.database;
      final snapshot = await db.ref().child('notifications/customers/$userId').get();
      if (!snapshot.exists || snapshot.value == null) return [];

      final data = snapshot.value;
      final list = <CustomerNotification>[];

      if (data is Map) {
        data.forEach((key, val) {
          if (val is Map) {
            final parsed = _parseCustomerNotification(Map<String, dynamic>.from(val));
            if (parsed != null) list.add(parsed);
          }
        });
      }
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    } catch (e) {
      debugPrint('Failed to load customer notifications: $e');
      return [];
    }
  }

  // =========================================================================
  // STORE / EMPLOYEE NOTIFICATIONS
  // =========================================================================

  /// Save a store/employee notification to Firebase Realtime Database at:
  /// `notifications/store/$notifId`
  Future<void> saveStoreNotification(EmployeeNotification notification) async {
    try {
      final db = _authService.database;
      final ref = db.ref().child('notifications/store/${notification.id}');
      await ref.set({
        'id': notification.id,
        'type': notification.type.name,
        'title': notification.title,
        'message': notification.message,
        'timestamp': notification.timestamp.toIso8601String(),
        'isRead': notification.isRead,
      });
      debugPrint('Saved store notification #${notification.id} to database');
    } catch (e) {
      debugPrint('Failed to save store notification to database: $e');
    }
  }

  /// Update the isRead flag for a store notification in Firebase Realtime Database
  Future<void> markStoreNotificationRead(String notifId) async {
    if (notifId.isEmpty) return;
    try {
      final db = _authService.database;
      await db.ref().child('notifications/store/$notifId').update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('Failed to mark store notification read: $e');
    }
  }

  /// Mark all store notifications as read in Firebase Realtime Database
  Future<void> markAllStoreNotificationsRead(List<String> notifIds) async {
    if (notifIds.isEmpty) return;
    try {
      final db = _authService.database;
      final updates = <String, dynamic>{};
      for (final id in notifIds) {
        updates['notifications/store/$id/isRead'] = true;
      }
      await db.ref().update(updates);
    } catch (e) {
      debugPrint('Failed to mark all store notifications read: $e');
    }
  }

  /// Load existing store notifications from Firebase Realtime Database
  Future<List<EmployeeNotification>> loadStoreNotifications() async {
    try {
      final db = _authService.database;
      final snapshot = await db.ref().child('notifications/store').get();
      if (!snapshot.exists || snapshot.value == null) return [];

      final data = snapshot.value;
      final list = <EmployeeNotification>[];

      if (data is Map) {
        data.forEach((key, val) {
          if (val is Map) {
            final parsed = _parseEmployeeNotification(Map<String, dynamic>.from(val));
            if (parsed != null) list.add(parsed);
          }
        });
      }
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    } catch (e) {
      debugPrint('Failed to load store notifications: $e');
      return [];
    }
  }

  // =========================================================================
  // PARSING HELPERS
  // =========================================================================

  CustomerNotification? _parseCustomerNotification(Map<String, dynamic> map) {
    try {
      final id = map['id']?.toString() ?? '';
      final title = map['title']?.toString() ?? 'Notification';
      final message = map['message']?.toString() ?? '';
      final isRead = map['isRead'] == true;
      final timestampStr = map['timestamp']?.toString();
      final timestamp = timestampStr != null
          ? DateTime.tryParse(timestampStr) ?? DateTime.now()
          : DateTime.now();

      final typeStr = map['type']?.toString().toLowerCase() ?? 'orderupdate';
      CustomerNotificationType type = CustomerNotificationType.orderUpdate;
      if (typeStr.contains('promo')) {
        type = CustomerNotificationType.promotion;
      } else if (typeStr.contains('security')) {
        type = CustomerNotificationType.security;
      }

      return CustomerNotification(
        id: id,
        type: type,
        title: title,
        message: message,
        timestamp: timestamp,
        isRead: isRead,
      );
    } catch (e) {
      debugPrint('Error parsing customer notification: $e');
      return null;
    }
  }

  EmployeeNotification? _parseEmployeeNotification(Map<String, dynamic> map) {
    try {
      final id = map['id']?.toString() ?? '';
      final title = map['title']?.toString() ?? 'Notification';
      final message = map['message']?.toString() ?? '';
      final isRead = map['isRead'] == true;
      final timestampStr = map['timestamp']?.toString();
      final timestamp = timestampStr != null
          ? DateTime.tryParse(timestampStr) ?? DateTime.now()
          : DateTime.now();

      final typeStr = map['type']?.toString().toLowerCase() ?? 'assignedtask';
      EmployeeNotificationType type = EmployeeNotificationType.assignedTask;
      if (typeStr.contains('lowstock')) {
        type = EmployeeNotificationType.lowStock;
      } else if (typeStr.contains('outofstock')) {
        type = EmployeeNotificationType.outOfStock;
      } else if (typeStr.contains('expir')) {
        type = EmployeeNotificationType.expiring;
      } else if (typeStr.contains('neworder') || typeStr.contains('order')) {
        type = EmployeeNotificationType.newOrder;
      }

      return EmployeeNotification(
        id: id,
        type: type,
        title: title,
        message: message,
        timestamp: timestamp,
        isRead: isRead,
      );
    } catch (e) {
      debugPrint('Error parsing employee notification: $e');
      return null;
    }
  }
}

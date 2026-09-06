import 'package:flutter/foundation.dart';

import '../employee_inventory_controller.dart';
import 'employee_notification_model.dart';

/// Owns the employee "Notifications" list.
///
/// Low stock / out of stock / expiring alerts are *derived live* from
/// [EmployeeInventoryController] — the same source of truth as the Home
/// tab's stat cards — so a notification always matches what's actually in
/// the inventory. "New order" and "assigned task" alerts are frontend-only
/// mock entries, since there's no order/task backend yet.
class EmployeeNotificationsController extends ChangeNotifier {
  EmployeeNotificationsController._() {
    _inventory.addListener(notifyListeners);
  }

  static final EmployeeNotificationsController instance = EmployeeNotificationsController._();

  factory EmployeeNotificationsController() => instance;

  final EmployeeInventoryController _inventory = EmployeeInventoryController();

  /// Ids the employee has already opened/dismissed. Kept separately from
  /// the derived list itself, since inventory-based notifications are
  /// recomputed from live stock on every read rather than stored.
  final Set<String> _readIds = {};

  final List<EmployeeNotification> _dynamicNotifications = [];

  final List<EmployeeNotification> _mockNotifications = [
    EmployeeNotification(
      id: 'order-1001',
      type: EmployeeNotificationType.newOrder,
      title: 'New Order Received',
      message: 'Order #1001 from Maria Santos is ready for preparation.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
    ),
  ];

  /// Full notification list, newest first: live inventory alerts plus the
  /// mock order/task entries, each with its read state applied.
  List<EmployeeNotification> get notifications {
    final now = DateTime.now();
    final derived = <EmployeeNotification>[];

    for (final product in _inventory.outOfStockProducts) {
      final id = 'outofstock-${product.id}';
      derived.add(EmployeeNotification(
        id: id,
        type: EmployeeNotificationType.outOfStock,
        title: 'Out of Stock',
        message: '${product.name} is now out of stock.',
        timestamp: now.subtract(const Duration(minutes: 10)),
        isRead: _readIds.contains(id),
      ));
    }
    for (final product in _inventory.lowStockProducts) {
      final id = 'lowstock-${product.id}';
      derived.add(EmployeeNotification(
        id: id,
        type: EmployeeNotificationType.lowStock,
        title: 'Low Stock',
        message: '${product.name} has only ${product.sellableQuantity} left.',
        timestamp: now.subtract(const Duration(minutes: 30)),
        isRead: _readIds.contains(id),
      ));
    }
    for (final product in _inventory.expiredProducts) {
      final id = 'expired-${product.id}';
      derived.add(EmployeeNotification(
        id: id,
        type: EmployeeNotificationType.expiring,
        title: 'Product Expired',
        message: '${product.name} has an expired batch still in stock.',
        timestamp: now.subtract(const Duration(hours: 1)),
        isRead: _readIds.contains(id),
      ));
    }
    for (final product in _inventory.expiringSoonProducts) {
      final id = 'expiringsoon-${product.id}';
      derived.add(EmployeeNotification(
        id: id,
        type: EmployeeNotificationType.expiring,
        title: 'Expiring Soon',
        message: '${product.name} has a batch expiring soon.',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 15)),
        isRead: _readIds.contains(id),
      ));
    }

    final mock = _mockNotifications.map((n) => n.copyWith(isRead: _readIds.contains(n.id)));
    final dynamicNotifs = _dynamicNotifications.map((n) => n.copyWith(isRead: _readIds.contains(n.id)));

    final all = [...derived, ...mock, ...dynamicNotifs]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all;
  }

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  void markAsRead(String id) {
    if (_readIds.add(id)) notifyListeners();
  }

  void markAllAsRead() {
    final ids = notifications.map((n) => n.id);
    _readIds.addAll(ids);
    notifyListeners();
  }

  void addNotification({
    required EmployeeNotificationType type,
    required String title,
    required String message,
  }) {
    final newNotif = EmployeeNotification(
      id: 'dynamic-${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: title,
      message: message,
      timestamp: DateTime.now(),
    );
    _dynamicNotifications.add(newNotif);
    notifyListeners();
  }
}
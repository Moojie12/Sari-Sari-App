import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/services/notification_database_service.dart';
import '../employee_inventory_controller.dart';
import 'employee_notification_model.dart';

/// Owns the employee and store-wide "Notifications" list.
///
/// Low stock / out of stock / expiring alerts are *derived live* from
/// [EmployeeInventoryController] — the same source of truth as the Home
/// tab's stat cards — so a notification always matches what's actually in
/// the inventory. Order and task alerts are dynamically created and persisted
/// to the database via [NotificationDatabaseService].
class EmployeeNotificationsController extends ChangeNotifier {
  EmployeeNotificationsController._() {
    _inventory.addListener(notifyListeners);
    loadStoreNotifications();
  }

  static final EmployeeNotificationsController instance = EmployeeNotificationsController._();

  factory EmployeeNotificationsController() => instance;

  final EmployeeInventoryController _inventory = EmployeeInventoryController();
  final NotificationDatabaseService _dbService = NotificationDatabaseService.instance;

  final Set<String> _readIds = {};
  final List<EmployeeNotification> _dynamicNotifications = [];
  final List<EmployeeNotification> _mockNotifications = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  /// Full notification list, newest first: live inventory alerts plus the
  /// persisted order/task entries, each with its read state applied.
  List<EmployeeNotification> get notifications {
    final now = DateTime.now();
    final derived = <EmployeeNotification>[];

    for (final product in _inventory.outOfStockProducts) {
      final id = 'outofstock-${product.id}';
      derived.add(EmployeeNotification(
        id: id,
        productId: product.id,
        productName: product.name,
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
        productId: product.id,
        productName: product.name,
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
        productId: product.id,
        productName: product.name,
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
        productId: product.id,
        productName: product.name,
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

  StreamSubscription<List<EmployeeNotification>>? _subscription;

  /// Load store notifications persisted in the database
  Future<void> loadStoreNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final dbNotifs = await _dbService.loadStoreNotifications();
      if (dbNotifs.isNotEmpty) {
        final existingIds = _dynamicNotifications.map((n) => n.id).toSet();
        for (final notif in dbNotifs) {
          if (!existingIds.contains(notif.id)) {
            _dynamicNotifications.add(notif);
          } else {
            final idx = _dynamicNotifications.indexWhere((n) => n.id == notif.id);
            if (idx != -1 && notif.isRead) {
              _readIds.add(notif.id);
            }
          }
        }
      }

      _subscription?.cancel();
      _subscription = _dbService.subscribeStoreNotifications().listen(
        (realtimeNotifs) {
          if (realtimeNotifs.isNotEmpty) {
            final existingIds = _dynamicNotifications.map((n) => n.id).toSet();
            bool changed = false;
            for (final notif in realtimeNotifs) {
              if (!existingIds.contains(notif.id)) {
                _dynamicNotifications.add(notif);
                changed = true;
              } else if (notif.isRead && _readIds.add(notif.id)) {
                changed = true;
              }
            }
            if (changed) notifyListeners();
          }
        },
        onError: (error) {
          debugPrint('Store notifications subscription error: $error');
        },
      );
    } catch (e) {
      debugPrint('Error loading store notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void markAsRead(String id) {
    if (_readIds.add(id)) {
      final idx = _dynamicNotifications.indexWhere((n) => n.id == id);
      if (idx != -1) {
        _dynamicNotifications[idx] = _dynamicNotifications[idx].copyWith(isRead: true);
      }
      notifyListeners();
      _dbService.markStoreNotificationRead(id).catchError((e) {
        debugPrint('Failed to mark store notification read: $e');
      });
    }
  }

  void markAllAsRead() {
    final ids = notifications.map((n) => n.id).toList();
    _readIds.addAll(ids);
    for (int i = 0; i < _dynamicNotifications.length; i++) {
      _dynamicNotifications[i] = _dynamicNotifications[i].copyWith(isRead: true);
    }
    notifyListeners();
    _dbService.markAllStoreNotificationsRead(ids).catchError((e) {
      debugPrint('Failed to mark all store notifications read: $e');
    });
  }

  /// Clear/delete all notifications that are already marked as read
  void clearReadNotifications() {
    final readNotifications = notifications.where((n) => n.isRead).toList();
    final readIds = readNotifications.map((n) => n.id).toList();

    for (final id in readIds) {
      _readIds.add(id);
      _dynamicNotifications.removeWhere((n) => n.id == id);
      if (id.startsWith('store_notif_')) {
        _dbService.deleteStoreNotification(id).catchError((e) {
          debugPrint('Failed to delete store notification: $e');
        });
      }
    }
    notifyListeners();
  }

  /// Delete a single store notification
  void deleteNotification(String id) {
    _dynamicNotifications.removeWhere((n) => n.id == id);
    _readIds.add(id);
    notifyListeners();

    _dbService.deleteStoreNotification(id).catchError((e) {
      debugPrint('Failed to delete store notification: $e');
    });
  }

  /// Clear all dynamic store notifications
  void clearAllNotifications() {
    _dynamicNotifications.clear();
    notifyListeners();

    _dbService.clearStoreNotifications().catchError((e) {
      debugPrint('Failed to clear store notifications: $e');
    });
  }

  /// Add a store/employee notification and persist it to the database
  void addNotification({
    required EmployeeNotificationType type,
    required String title,
    required String message,
    String? productId,
    String? productName,
    String? orderId,
  }) {
    final newNotif = EmployeeNotification(
      id: 'store_notif_${DateTime.now().millisecondsSinceEpoch}_${_dynamicNotifications.length}',
      type: type,
      title: title,
      message: message,
      productId: productId,
      productName: productName,
      orderId: orderId,
      timestamp: DateTime.now(),
      isRead: false,
    );
    _dynamicNotifications.insert(0, newNotif);
    notifyListeners();

    _dbService.saveStoreNotification(newNotif).catchError((e) {
      debugPrint('Failed to save store notification: $e');
    });
  }

  /// Clear in-memory notifications on logout
  void clear() {
    _dynamicNotifications.clear();
    _readIds.clear();
    notifyListeners();
  }
}
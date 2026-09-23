import 'package:flutter/foundation.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/notification_database_service.dart';
import 'customer_notification_model.dart';

class CustomerNotificationsController extends ChangeNotifier {
  CustomerNotificationsController._() {
    loadNotifications();
  }

  static final CustomerNotificationsController instance = CustomerNotificationsController._();

  factory CustomerNotificationsController() => instance;

  final NotificationDatabaseService _dbService = NotificationDatabaseService.instance;
  final Set<String> _readIds = {};
  final List<CustomerNotification> _notifications = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  List<CustomerNotification> get notifications {
    return _notifications
        .map((n) => n.copyWith(isRead: _readIds.contains(n.id) || n.isRead))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  /// Load existing customer notifications from the database
  Future<void> loadNotifications([String? userId]) async {
    final effectiveUserId = userId ?? AuthService().currentUser?.uid;
    if (effectiveUserId == null || effectiveUserId.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      final dbNotifs = await _dbService.loadCustomerNotifications(effectiveUserId);
      if (dbNotifs.isNotEmpty) {
        // Merge without duplicating
        final existingIds = _notifications.map((n) => n.id).toSet();
        for (final notif in dbNotifs) {
          if (!existingIds.contains(notif.id)) {
            _notifications.add(notif);
          } else {
            // Update read state from database if newer
            final idx = _notifications.indexWhere((n) => n.id == notif.id);
            if (idx != -1 && notif.isRead) {
              _readIds.add(notif.id);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading customer notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void markAsRead(String id) {
    if (_readIds.add(id)) {
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx != -1) {
        _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      }
      notifyListeners();

      final userId = AuthService().currentUser?.uid;
      if (userId != null && userId.isNotEmpty) {
        _dbService.markCustomerNotificationRead(userId, id);
      }
    }
  }

  void markAllAsRead() {
    final ids = notifications.map((n) => n.id).toList();
    _readIds.addAll(ids);
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();

    final userId = AuthService().currentUser?.uid;
    if (userId != null && userId.isNotEmpty) {
      _dbService.markAllCustomerNotificationsRead(userId, ids);
    }
  }

  /// Add a notification for the customer and persist it to the database
  void addNotification({
    required CustomerNotificationType type,
    required String title,
    required String message,
    String? userId,
  }) {
    final notification = CustomerNotification(
      id: 'cust_notif_${DateTime.now().millisecondsSinceEpoch}_${_notifications.length}',
      type: type,
      title: title,
      message: message,
      timestamp: DateTime.now(),
      isRead: false,
    );

    _notifications.insert(0, notification);
    notifyListeners();

    final targetUserId = userId ?? AuthService().currentUser?.uid;
    if (targetUserId != null && targetUserId.isNotEmpty) {
      _dbService.saveCustomerNotification(targetUserId, notification);
    }
  }

  /// Clear in-memory notifications on logout
  void clear() {
    _notifications.clear();
    _readIds.clear();
    notifyListeners();
  }
}

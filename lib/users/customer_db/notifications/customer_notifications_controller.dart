import 'package:flutter/foundation.dart';
import 'customer_notification_model.dart';

class CustomerNotificationsController extends ChangeNotifier {
  CustomerNotificationsController._();

  static final CustomerNotificationsController instance = CustomerNotificationsController._();

  factory CustomerNotificationsController() => instance;

  final Set<String> _readIds = {};

  final List<CustomerNotification> _mockNotifications = [
    CustomerNotification(
      id: 'order-update-1',
      type: CustomerNotificationType.orderUpdate,
      title: 'Order Confirmed',
      message: 'Your order #12345 has been confirmed and is being prepared.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
    ),
    CustomerNotification(
      id: 'promo-1',
      type: CustomerNotificationType.promotion,
      title: 'Special Discount!',
      message: 'Enjoy 10% off on all beverages this weekend.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    CustomerNotification(
      id: 'order-update-2',
      type: CustomerNotificationType.orderUpdate,
      title: 'Out for Delivery',
      message: 'Your order #12344 is on its way to your address.',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    CustomerNotification(
      id: 'security-1',
      type: CustomerNotificationType.security,
      title: 'Login Detected',
      message: 'A new login was detected from a new device.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
  ];

  List<CustomerNotification> get notifications {
    return _mockNotifications
        .map((n) => n.copyWith(isRead: _readIds.contains(n.id) || n.isRead))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
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
}

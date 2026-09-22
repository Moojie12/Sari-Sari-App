import 'package:flutter/foundation.dart';
import 'customer_notification_model.dart';

class CustomerNotificationsController extends ChangeNotifier {
  CustomerNotificationsController._();

  static final CustomerNotificationsController instance = CustomerNotificationsController._();

  factory CustomerNotificationsController() => instance;

  final Set<String> _readIds = {};

  final List<CustomerNotification> _mockNotifications = [];

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

  void addNotification({
    required CustomerNotificationType type,
    required String title,
    required String message,
  }) {
    final notification = CustomerNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}_${_mockNotifications.length}',
      type: type,
      title: title,
      message: message,
      timestamp: DateTime.now(),
      isRead: false,
    );
    _mockNotifications.insert(0, notification);
    notifyListeners();
  }
}

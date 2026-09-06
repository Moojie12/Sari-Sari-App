import 'package:flutter/material.dart';

/// What triggered an [EmployeeNotification] — mirrors the alert types
/// called out in the Employee Notifications spec: low stock, out of
/// stock, expiring products, new orders, and other assigned activities.
enum EmployeeNotificationType {
  lowStock,
  outOfStock,
  expiring,
  newOrder,
  assignedTask,
}

extension EmployeeNotificationTypeStyle on EmployeeNotificationType {
  IconData get icon {
    switch (this) {
      case EmployeeNotificationType.lowStock:
        return Icons.trending_down;
      case EmployeeNotificationType.outOfStock:
        return Icons.remove_shopping_cart_outlined;
      case EmployeeNotificationType.expiring:
        return Icons.event_busy;
      case EmployeeNotificationType.newOrder:
        return Icons.receipt_long_outlined;
      case EmployeeNotificationType.assignedTask:
        return Icons.assignment_outlined;
    }
  }

  Color get color {
    switch (this) {
      case EmployeeNotificationType.lowStock:
        return Colors.orange;
      case EmployeeNotificationType.outOfStock:
        return Colors.red;
      case EmployeeNotificationType.expiring:
        return Colors.deepOrange;
      case EmployeeNotificationType.newOrder:
        return Colors.blue;
      case EmployeeNotificationType.assignedTask:
        return Colors.purple;
    }
  }
}

/// A single alert on the employee "Notifications" screen.
@immutable
class EmployeeNotification {
  const EmployeeNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  final String id;
  final EmployeeNotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  EmployeeNotification copyWith({bool? isRead}) {
    return EmployeeNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}
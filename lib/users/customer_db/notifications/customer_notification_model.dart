import 'package:flutter/material.dart';

enum CustomerNotificationType {
  orderUpdate,
  promotion,
  security,
}

extension CustomerNotificationTypeStyle on CustomerNotificationType {
  IconData get icon {
    switch (this) {
      case CustomerNotificationType.orderUpdate:
        return Icons.local_shipping_outlined;
      case CustomerNotificationType.promotion:
        return Icons.campaign_outlined;
      case CustomerNotificationType.security:
        return Icons.security_outlined;
    }
  }

  Color get color {
    switch (this) {
      case CustomerNotificationType.orderUpdate:
        return Colors.blue;
      case CustomerNotificationType.promotion:
        return Colors.orange;
      case CustomerNotificationType.security:
        return Colors.red;
    }
  }
}

@immutable
class CustomerNotification {
  const CustomerNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  final String id;
  final CustomerNotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  CustomerNotification copyWith({bool? isRead}) {
    return CustomerNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}

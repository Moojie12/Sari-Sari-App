import 'package:flutter/foundation.dart';

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  readyForShipment,
  readyForPickup,
  outForDelivery,
  delivered,
  completed,
  cancelled,
}

extension OrderStatusLabel on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending: return 'Pending';
      case OrderStatus.confirmed: return 'Confirmed';
      case OrderStatus.preparing: return 'Preparing';
      case OrderStatus.readyForShipment: return 'Ready for Shipment';
      case OrderStatus.readyForPickup: return 'Ready for Pickup';
      case OrderStatus.outForDelivery: return 'Out for Delivery';
      case OrderStatus.delivered: return 'Delivered';
      case OrderStatus.completed: return 'Completed';
      case OrderStatus.cancelled: return 'Cancelled';
    }
  }
}

enum OrderType {
  pickup,
  delivery,
}

enum PaymentMethod {
  cashOnDelivery,
  gCash,
}

enum PaymentStatus {
  unpaid,
  partiallyPaid,
  paid,
}

@immutable
class CustomerOrderItem {
  const CustomerOrderItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.subtotal,
  });

  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final double subtotal;
}

@immutable
class CustomerOrder {
  const CustomerOrder({
    required this.orderId,
    required this.orderDate,
    required this.items,
    required this.orderType,
    required this.paymentMethod,
    required this.paymentStatus,
    this.deliveryAddress,
    required this.subtotal,
    required this.deliveryFee,
    required this.totalAmount,
    required this.status,
  });

  final String orderId;
  final DateTime orderDate;
  final List<CustomerOrderItem> items;
  final OrderType orderType;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final String? deliveryAddress;
  final double subtotal;
  final double deliveryFee;
  final double totalAmount;
  final OrderStatus status;

  String get formattedDate => '${orderDate.day}/${orderDate.month}/${orderDate.year}';
}

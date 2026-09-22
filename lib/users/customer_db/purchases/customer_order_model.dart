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
    required this.capital,
    required this.quantity,
    required this.subtotal,
  });

  final String productId;
  final String productName;
  final double price;
  final double capital;
  final int quantity;
  final double subtotal;

  double get totalCapital => capital * quantity;
  double get profit => subtotal - totalCapital;

  factory CustomerOrderItem.fromSupabase(Map<String, dynamic> map) {
    final qty = (map['quantity'] as num?)?.toDouble() ?? 1.0;
    final unitPrice = (map['unit_price'] as num?)?.toDouble() ?? 0.0;
    final unitCost = (map['unit_cost'] as num?)?.toDouble() ?? 0.0;
    final totalPrice = (map['total_price'] as num?)?.toDouble() ?? (qty * unitPrice);

    return CustomerOrderItem(
      productId: map['product_id']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? 'Product',
      price: unitPrice,
      capital: unitCost,
      quantity: qty.round(),
      subtotal: totalPrice,
    );
  }

  Map<String, dynamic> toSupabaseMap(String dbOrderId) {
    return {
      'order_id': dbOrderId,
      'product_id': productId,
      'product_name': productName,
      'unit_price': price,
      'unit_cost': capital,
      'quantity': quantity,
      'total_price': subtotal,
    };
  }
}

@immutable
class CustomerOrder {
  const CustomerOrder({
    required this.orderId,
    required this.customerName,
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
    this.userId,
    this.dbId,
  });

  final String orderId;
  final String customerName;
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
  final String? userId;
  final String? dbId;

  String get formattedDate => '${orderDate.day}/${orderDate.month}/${orderDate.year}';

  double get totalCapital => items.fold(0.0, (sum, item) => sum + item.totalCapital);
  double get totalProfit => subtotal - totalCapital;

  factory CustomerOrder.fromSupabase(Map<String, dynamic> map, [List<CustomerOrderItem>? itemsList]) {
    final items = itemsList != null ? List<CustomerOrderItem>.from(itemsList) : <CustomerOrderItem>[];
    if (items.isEmpty && map['order_items'] != null && map['order_items'] is List) {
      for (var itemMap in map['order_items']) {
        if (itemMap is Map<String, dynamic>) {
          items.add(CustomerOrderItem.fromSupabase(itemMap));
        }
      }
    }

    final placedAtStr = map['placed_at']?.toString() ?? map['created_at']?.toString();
    final parsedDate = placedAtStr != null ? DateTime.tryParse(placedAtStr) ?? DateTime.now() : DateTime.now();

    return CustomerOrder(
      dbId: map['id']?.toString(),
      orderId: map['order_number']?.toString() ?? map['id']?.toString() ?? '',
      customerName: map['customer_name']?.toString() ?? 'Customer',
      orderDate: parsedDate,
      items: items,
      orderType: _parseOrderType(map['order_type']?.toString()),
      paymentMethod: _parsePaymentMethod(map['payment_method']?.toString()),
      paymentStatus: _parsePaymentStatus(map['payment_status']?.toString()),
      deliveryAddress: map['delivery_address']?.toString(),
      subtotal: (map['subtotal'] as num?)?.toDouble() ??
          (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: _parseOrderStatus(map['status']?.toString(), map['order_notes']?.toString()),
      userId: map['user_id']?.toString(),
    );
  }
}

OrderStatus _parseOrderStatus(String? status, [String? orderNotes]) {
  if (orderNotes != null && orderNotes.contains('[status:')) {
    final match = RegExp(r'\[status:([a-zA-Z]+)\]').firstMatch(orderNotes);
    if (match != null && match.group(1) != null) {
      final parsed = _matchStatusString(match.group(1)!);
      if (parsed != null) return parsed;
    }
  }
  return _matchStatusString(status) ?? OrderStatus.pending;
}

OrderStatus? _matchStatusString(String? status) {
  if (status == null) return null;
  final s = status.toLowerCase().replaceAll('_', '');
  switch (s) {
    case 'pending': return OrderStatus.pending;
    case 'confirmed': return OrderStatus.confirmed;
    case 'preparing': return OrderStatus.preparing;
    case 'processing': return OrderStatus.preparing;
    case 'readyforshipment': return OrderStatus.readyForShipment;
    case 'readyforpickup': return OrderStatus.readyForPickup;
    case 'outfordelivery': return OrderStatus.outForDelivery;
    case 'delivered': return OrderStatus.delivered;
    case 'completed': return OrderStatus.completed;
    case 'cancelled': return OrderStatus.cancelled;
    case 'refunded': return OrderStatus.cancelled;
    case 'voided': return OrderStatus.cancelled;
    default: return null;
  }
}

OrderType _parseOrderType(String? type) {
  if (type == null) return OrderType.pickup;
  final t = type.toLowerCase();
  if (t == 'delivery') return OrderType.delivery;
  return OrderType.pickup;
}

PaymentMethod _parsePaymentMethod(String? method) {
  if (method == null) return PaymentMethod.cashOnDelivery;
  final m = method.toLowerCase();
  if (m.contains('gcash')) return PaymentMethod.gCash;
  return PaymentMethod.cashOnDelivery;
}

PaymentStatus _parsePaymentStatus(String? status) {
  if (status == null) return PaymentStatus.unpaid;
  final s = status.toLowerCase();
  if (s == 'paid') return PaymentStatus.paid;
  if (s.contains('partially')) return PaymentStatus.partiallyPaid;
  return PaymentStatus.unpaid;
}

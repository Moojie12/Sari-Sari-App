import 'package:flutter/foundation.dart';
import '../../employee_db/employee_inventory_controller.dart';

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
    var unitCost = (map['unit_cost'] as num?)?.toDouble() ?? 0.0;
    final prodId = map['product_id']?.toString() ?? '';

    // Fallback: If unitCost is 0, look up product in inventory to get its capital
    if (unitCost <= 0.0 && prodId.isNotEmpty) {
      final invProduct = EmployeeInventoryController.instance.findById(prodId);
      if (invProduct != null && invProduct.capital > 0) {
        unitCost = invProduct.capital;
      }
    }

    final totalPrice = (map['total_price'] as num?)?.toDouble() ?? (qty * unitPrice);

    return CustomerOrderItem(
      productId: prodId,
      productName: map['product_name']?.toString() ?? 'Product',
      price: unitPrice,
      capital: unitCost,
      quantity: qty.round() > 0 ? qty.round() : 1,
      subtotal: totalPrice,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'capital': capital,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  factory CustomerOrderItem.fromMap(Map<dynamic, dynamic> map) {
    return CustomerOrderItem(
      productId: map['productId']?.toString() ?? map['product_id']?.toString() ?? '',
      productName: map['productName']?.toString() ?? map['product_name']?.toString() ?? 'Product',
      price: (map['price'] as num?)?.toDouble() ?? (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      capital: (map['capital'] as num?)?.toDouble() ?? (map['unit_cost'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? (map['total_price'] as num?)?.toDouble() ?? 0.0,
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
    this.processedBy,
    this.deliveryPersonId,
    this.deliveryPersonName,
    this.deliveryPersonRole,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.cancellationReason,
    this.paymentReferenceNumber,
    this.gcashRefundName,
    this.gcashRefundNumber,
    this.refundProofUrl,
    this.refundStatus,
    this.paymentProofUrl,
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
  final String? processedBy;
  final String? deliveryPersonId;
  final String? deliveryPersonName;
  final String? deliveryPersonRole;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? cancellationReason;
  final String? paymentReferenceNumber;
  final String? gcashRefundName;
  final String? gcashRefundNumber;
  final String? refundProofUrl;
  final String? refundStatus;
  final String? paymentProofUrl;

  String get formattedDate => '${orderDate.day}/${orderDate.month}/${orderDate.year}';

  String get displayOrderId {
    final clean = orderId.replaceAll('#', '').trim();
    if (clean.length > 12) {
      if (clean.startsWith('SS-')) {
        final parts = clean.split('-');
        if (parts.length >= 3) {
          return 'SS-${parts.last}';
        }
        return 'SS-${clean.substring(clean.length - 6)}';
      }
      if (clean.startsWith('RC-')) {
        final parts = clean.split('-');
        if (parts.length >= 3) {
          return 'RC-${parts.last}';
        }
        return 'RC-${clean.substring(clean.length - 6)}';
      }
      if (clean.startsWith('ORD-')) {
        final parts = clean.split('-');
        if (parts.length >= 2) {
          return 'ORD-${parts.last}';
        }
        return 'ORD-${clean.substring(clean.length - 6).toUpperCase()}';
      }
      return 'ORD-${clean.substring(0, 6).toUpperCase()}';
    }
    return clean;
  }

  double get totalCapital => items.fold(0.0, (sum, item) => sum + item.totalCapital);
  double get totalProfit => subtotal - totalCapital;

  CustomerOrder copyWith({
    String? orderId,
    String? customerName,
    DateTime? orderDate,
    List<CustomerOrderItem>? items,
    OrderType? orderType,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    String? deliveryAddress,
    double? subtotal,
    double? deliveryFee,
    double? totalAmount,
    OrderStatus? status,
    String? userId,
    String? dbId,
    String? processedBy,
    String? deliveryPersonId,
    String? deliveryPersonName,
    String? deliveryPersonRole,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? cancellationReason,
    String? paymentReferenceNumber,
    String? gcashRefundName,
    String? gcashRefundNumber,
    String? refundProofUrl,
    String? refundStatus,
    String? paymentProofUrl,
  }) {
    return CustomerOrder(
      orderId: orderId ?? this.orderId,
      customerName: customerName ?? this.customerName,
      orderDate: orderDate ?? this.orderDate,
      items: items ?? this.items,
      orderType: orderType ?? this.orderType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      userId: userId ?? this.userId,
      dbId: dbId ?? this.dbId,
      processedBy: processedBy ?? this.processedBy,
      deliveryPersonId: deliveryPersonId ?? this.deliveryPersonId,
      deliveryPersonName: deliveryPersonName ?? this.deliveryPersonName,
      deliveryPersonRole: deliveryPersonRole ?? this.deliveryPersonRole,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      paymentReferenceNumber: paymentReferenceNumber ?? this.paymentReferenceNumber,
      gcashRefundName: gcashRefundName ?? this.gcashRefundName,
      gcashRefundNumber: gcashRefundNumber ?? this.gcashRefundNumber,
      refundProofUrl: refundProofUrl ?? this.refundProofUrl,
      refundStatus: refundStatus ?? this.refundStatus,
      paymentProofUrl: paymentProofUrl ?? this.paymentProofUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'customerName': customerName,
      'orderDate': orderDate.toIso8601String(),
      'orderType': orderType.name,
      'paymentMethod': paymentMethod.name,
      'paymentStatus': paymentStatus.name,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'totalAmount': totalAmount,
      'status': status.name,
      'userId': userId,
      'deliveryAddress': deliveryAddress,
      'itemsCount': items.length,
      'items': items.map((i) => i.toMap()).toList(),
      'dbId': dbId,
      'processedBy': processedBy,
      'deliveryPersonId': deliveryPersonId,
      'deliveryPersonName': deliveryPersonName,
      'deliveryPersonRole': deliveryPersonRole,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'cancellationReason': cancellationReason,
      'paymentReferenceNumber': paymentReferenceNumber,
      'gcashRefundName': gcashRefundName,
      'gcashRefundNumber': gcashRefundNumber,
      'refundProofUrl': refundProofUrl,
      'refundStatus': refundStatus,
      'paymentProofUrl': paymentProofUrl,
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'order_id': orderId,
      'user_id': userId ?? '',
      'customer_name': customerName,
      'order_date': orderDate.toIso8601String(),
      'order_type': orderType.name,
      'payment_method': paymentMethod.name,
      'payment_status': paymentStatus.name,
      'subtotal': subtotal,
      'delivery_fee': deliveryFee,
      'total_amount': totalAmount,
      'status': status.name,
      'delivery_address': deliveryAddress ?? '',
      'cancellation_reason': cancellationReason ?? '',
      'payment_reference_number': paymentReferenceNumber ?? '',
      'gcash_refund_name': gcashRefundName ?? '',
      'gcash_refund_number': gcashRefundNumber ?? '',
      'refund_proof_url': refundProofUrl ?? '',
      'refund_status': refundStatus ?? '',
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory CustomerOrder.fromMap(Map<dynamic, dynamic> map) {
    final rawItems = map['items'];
    final itemsList = <CustomerOrderItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          itemsList.add(CustomerOrderItem.fromMap(item));
        }
      }
    } else if (rawItems is Map) {
      for (final item in rawItems.values) {
        if (item is Map) {
          itemsList.add(CustomerOrderItem.fromMap(item));
        }
      }
    }

    final dateStr = map['orderDate']?.toString() ?? map['placed_at']?.toString() ?? map['createdAt']?.toString();
    final parsedDate = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();

    final deliveryPerson = _parseDeliveryPerson(
      map['deliveryPersonId']?.toString() ?? map['delivery_person_id']?.toString(),
      map['deliveryPersonName']?.toString() ?? map['delivery_person_name']?.toString(),
      map['deliveryPersonRole']?.toString() ?? map['delivery_person_role']?.toString(),
      map['order_notes']?.toString(),
    );

    final coords = _parseCoords(
      (map['deliveryLatitude'] as num?)?.toDouble() ?? (map['delivery_latitude'] as num?)?.toDouble(),
      (map['deliveryLongitude'] as num?)?.toDouble() ?? (map['delivery_longitude'] as num?)?.toDouble(),
      map['order_notes']?.toString(),
    );

    final notes = map['order_notes']?.toString();

    return CustomerOrder(
      orderId: map['orderId']?.toString() ?? map['order_number']?.toString() ?? map['id']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? map['customer_name']?.toString() ?? 'Customer',
      orderDate: parsedDate,
      items: itemsList,
      orderType: _parseOrderType(
        map['orderType']?.toString() ?? map['order_type']?.toString(),
        map['deliveryAddress']?.toString() ?? map['delivery_address']?.toString(),
      ),
      paymentMethod: _parsePaymentMethod(
        map['paymentMethod']?.toString() ?? map['payment_method']?.toString(),
        notes,
      ),
      paymentStatus: _parsePaymentStatus(map['paymentStatus']?.toString() ?? map['payment_status']?.toString()),
      deliveryAddress: map['deliveryAddress']?.toString() ?? map['delivery_address']?.toString(),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble() ?? (map['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: _parseOrderStatus(map['status']?.toString(), notes),
      userId: map['userId']?.toString() ?? map['user_id']?.toString(),
      dbId: map['dbId']?.toString() ?? map['id']?.toString(),
      processedBy: _parseProcessedBy(map['processedBy']?.toString(), notes),
      deliveryPersonId: deliveryPerson.id,
      deliveryPersonName: deliveryPerson.name,
      deliveryPersonRole: deliveryPerson.role,
      deliveryLatitude: coords.lat,
      deliveryLongitude: coords.lng,
      cancellationReason: _parseCancellationReason(
        map['cancellationReason']?.toString() ?? map['cancellation_reason']?.toString(),
        notes,
      ),
      paymentReferenceNumber: _parsePaymentReferenceNumber(
        map['paymentReferenceNumber']?.toString() ?? map['payment_reference_number']?.toString(),
        notes,
      ),
      gcashRefundName: _parseGcashRefundName(
        map['gcashRefundName']?.toString() ?? map['gcash_refund_name']?.toString(),
        notes,
      ),
      gcashRefundNumber: _parseGcashRefundNumber(
        map['gcashRefundNumber']?.toString() ?? map['gcash_refund_number']?.toString(),
        notes,
      ),
      refundProofUrl: _parseRefundProofUrl(
        map['refundProofUrl']?.toString() ?? map['refund_proof_url']?.toString(),
        notes,
      ),
      refundStatus: _parseRefundStatus(
        map['refundStatus']?.toString() ?? map['refund_status']?.toString(),
        notes,
      ),
      paymentProofUrl: _parsePaymentProofUrl(
        map['paymentProofUrl']?.toString() ?? map['payment_proof_url']?.toString(),
        notes,
      ),
    );
  }

  factory CustomerOrder.fromSupabase(Map<String, dynamic> map, [List<CustomerOrderItem>? itemsList]) {
    final items = itemsList != null ? List<CustomerOrderItem>.from(itemsList) : <CustomerOrderItem>[];
    if (items.isEmpty && map['order_items'] != null && map['order_items'] is List) {
      for (var itemMap in map['order_items']) {
        if (itemMap is Map) {
          items.add(CustomerOrderItem.fromSupabase(Map<String, dynamic>.from(itemMap)));
        }
      }
    }

    final placedAtStr = map['placed_at']?.toString() ?? map['created_at']?.toString();
    final parsedDate = placedAtStr != null ? DateTime.tryParse(placedAtStr) ?? DateTime.now() : DateTime.now();

    final dbSubtotal = (map['subtotal'] as num?)?.toDouble() ??
        (map['total_amount'] as num?)?.toDouble() ?? 0.0;
    final itemsSubtotal = items.fold(0.0, (sum, item) => sum + item.subtotal);
    final finalSubtotal = dbSubtotal > 0 ? dbSubtotal : itemsSubtotal;
    final totalAmt = (map['total_amount'] as num?)?.toDouble() ?? finalSubtotal;

    final deliveryPerson = _parseDeliveryPerson(
      map['delivery_person_id']?.toString(),
      map['delivery_person_name']?.toString(),
      map['delivery_person_role']?.toString(),
      map['order_notes']?.toString(),
    );

    final coords = _parseCoords(
      (map['delivery_latitude'] as num?)?.toDouble(),
      (map['delivery_longitude'] as num?)?.toDouble(),
      map['order_notes']?.toString(),
    );

    final notes = map['order_notes']?.toString();

    return CustomerOrder(
      dbId: map['id']?.toString(),
      orderId: map['order_number']?.toString() ?? map['id']?.toString() ?? '',
      customerName: map['customer_name']?.toString() ?? 'Customer',
      orderDate: parsedDate,
      items: items,
      orderType: _parseOrderType(
        map['order_type']?.toString() ?? map['orderType']?.toString(),
        map['delivery_address']?.toString() ?? map['deliveryAddress']?.toString(),
      ),
      paymentMethod: _parsePaymentMethod(
        map['payment_method']?.toString() ?? map['paymentMethod']?.toString(),
        notes,
      ),
      paymentStatus: _parsePaymentStatus(map['payment_status']?.toString()),
      deliveryAddress: map['delivery_address']?.toString(),
      subtotal: finalSubtotal,
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      totalAmount: totalAmt,
      status: _parseOrderStatus(map['status']?.toString(), notes),
      userId: map['user_id']?.toString(),
      processedBy: _parseProcessedBy(map['processed_by']?.toString(), notes),
      deliveryPersonId: deliveryPerson.id,
      deliveryPersonName: deliveryPerson.name,
      deliveryPersonRole: deliveryPerson.role,
      deliveryLatitude: coords.lat,
      deliveryLongitude: coords.lng,
      cancellationReason: _parseCancellationReason(
        map['cancellation_reason']?.toString() ?? map['cancellationReason']?.toString(),
        notes,
      ),
      paymentReferenceNumber: _parsePaymentReferenceNumber(
        map['payment_reference_number']?.toString() ?? map['paymentReferenceNumber']?.toString(),
        notes,
      ),
      gcashRefundName: _parseGcashRefundName(
        map['gcash_refund_name']?.toString() ?? map['gcashRefundName']?.toString(),
        notes,
      ),
      gcashRefundNumber: _parseGcashRefundNumber(
        map['gcash_refund_number']?.toString() ?? map['gcashRefundNumber']?.toString(),
        notes,
      ),
      refundProofUrl: _parseRefundProofUrl(
        map['refund_proof_url']?.toString() ?? map['refundProofUrl']?.toString(),
        notes,
      ),
      refundStatus: _parseRefundStatus(
        map['refund_status']?.toString() ?? map['refundStatus']?.toString(),
        notes,
      ),
      paymentProofUrl: _parsePaymentProofUrl(
        map['payment_proof_url']?.toString() ?? map['paymentProofUrl']?.toString(),
        notes,
      ),
    );
  }
}

class _DeliveryPersonInfo {
  final String? id;
  final String? name;
  final String? role;
  const _DeliveryPersonInfo({this.id, this.name, this.role});
}

_DeliveryPersonInfo _parseDeliveryPerson(
  String? rawId,
  String? rawName,
  String? rawRole,
  String? orderNotes,
) {
  if (rawName != null && rawName.trim().isNotEmpty) {
    return _DeliveryPersonInfo(
      id: rawId?.trim(),
      name: rawName.trim(),
      role: rawRole?.trim() ?? 'Employee',
    );
  }
  if (orderNotes != null && orderNotes.contains('[delivery_person:')) {
    final match = RegExp(r'\[delivery_person:\s*([^|\]]+)\|([^|\]]+)(?:\|([^|\]]+))?\]').firstMatch(orderNotes);
    if (match != null) {
      return _DeliveryPersonInfo(
        id: match.group(1)?.trim(),
        name: match.group(2)?.trim(),
        role: match.group(3)?.trim() ?? 'Employee',
      );
    }
  }
  return const _DeliveryPersonInfo();
}

class _CoordsInfo {
  final double? lat;
  final double? lng;
  const _CoordsInfo({this.lat, this.lng});
}

_CoordsInfo _parseCoords(double? lat, double? lng, String? orderNotes) {
  if (lat != null && lng != null) {
    return _CoordsInfo(lat: lat, lng: lng);
  }
  if (orderNotes != null && orderNotes.contains('[coords:')) {
    final match = RegExp(r'\[coords:\s*([0-9.-]+),\s*([0-9.-]+)\]').firstMatch(orderNotes);
    if (match != null) {
      return _CoordsInfo(
        lat: double.tryParse(match.group(1)!),
        lng: double.tryParse(match.group(2)!),
      );
    }
  }
  return const _CoordsInfo();
}

String? _parseProcessedBy(String? rawProcessedBy, String? orderNotes) {
  if (rawProcessedBy != null && rawProcessedBy.trim().isNotEmpty) {
    return rawProcessedBy.trim();
  }
  if (orderNotes != null && orderNotes.contains('Sold by:')) {
    final match = RegExp(r'Sold by:\s*([^\n;]+)').firstMatch(orderNotes);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
  }
  return null;
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

OrderType _parseOrderType(String? type, [String? deliveryAddress]) {
  if (type != null) {
    final t = type.toLowerCase();
    if (t == 'delivery') return OrderType.delivery;
    if (t == 'pickup') return OrderType.pickup;
  }
  if (deliveryAddress != null && deliveryAddress.trim().isNotEmpty) {
    return OrderType.delivery;
  }
  return OrderType.pickup;
}

PaymentMethod _parsePaymentMethod(String? method, [String? orderNotes]) {
  if (method != null && method.trim().isNotEmpty) {
    final m = method.toLowerCase();
    if (m.contains('gcash')) return PaymentMethod.gCash;
    if (m.contains('cash')) return PaymentMethod.cashOnDelivery;
  }
  if (orderNotes != null && orderNotes.contains('[payment_method:')) {
    final match = RegExp(r'\[payment_method:\s*([^\]]+)\]').firstMatch(orderNotes);
    if (match != null && match.group(1) != null) {
      final m = match.group(1)!.trim().toLowerCase();
      if (m.contains('gcash')) return PaymentMethod.gCash;
    }
  }
  return PaymentMethod.cashOnDelivery;
}

PaymentStatus _parsePaymentStatus(String? status) {
  if (status == null) return PaymentStatus.unpaid;
  final s = status.toLowerCase();
  if (s == 'paid') return PaymentStatus.paid;
  if (s.contains('partially')) return PaymentStatus.partiallyPaid;
  return PaymentStatus.unpaid;
}

String? _parseCancellationReason(String? rawReason, String? orderNotes) {
  if (rawReason != null && rawReason.trim().isNotEmpty) {
    return rawReason.trim();
  }
  if (orderNotes != null && orderNotes.contains('[cancellation_reason:')) {
    final match = RegExp(r'\[cancellation_reason:\s*([^\]]+)\]').firstMatch(orderNotes);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
  }
  return null;
}

String? _parseGcashRefundName(String? raw, String? orderNotes) {
  if (raw != null && raw.trim().isNotEmpty) return raw.trim();
  if (orderNotes != null && orderNotes.contains('[gcash_refund_name:')) {
    final match = RegExp(r'\[gcash_refund_name:\s*([^\]]+)\]').firstMatch(orderNotes);
    if (match != null && match.group(1) != null) return match.group(1)!.trim();
  }
  return null;
}

String? _parseGcashRefundNumber(String? raw, String? orderNotes) {
  if (raw != null && raw.trim().isNotEmpty) return raw.trim();
  if (orderNotes != null && orderNotes.contains('[gcash_refund_number:')) {
    final match = RegExp(r'\[gcash_refund_number:\s*([^\]]+)\]').firstMatch(orderNotes);
    if (match != null && match.group(1) != null) return match.group(1)!.trim();
  }
  return null;
}

String? _parseRefundProofUrl(String? raw, String? orderNotes) {
  if (raw != null && raw.trim().isNotEmpty) return raw.trim();
  if (orderNotes != null && orderNotes.contains('[refund_proof_url:')) {
    final match = RegExp(r'\[refund_proof_url:\s*([^\]]+)\]').firstMatch(orderNotes);
    if (match != null && match.group(1) != null) return match.group(1)!.trim();
  }
  return null;
}

String? _parseRefundStatus(String? raw, String? orderNotes) {
  if (raw != null && raw.trim().isNotEmpty) return raw.trim();
  if (orderNotes != null && orderNotes.contains('[refund_status:')) {
    final match = RegExp(r'\[refund_status:\s*([^\]]+)\]').firstMatch(orderNotes);
    if (match != null && match.group(1) != null) return match.group(1)!.trim();
  }
  return null;
}

String? _parsePaymentReferenceNumber(String? raw, String? orderNotes) {
  if (raw != null && raw.trim().isNotEmpty) return raw.trim();
  if (orderNotes != null && orderNotes.contains('[payment_ref:')) {
    final match = RegExp(r'\[payment_ref:\s*([^\]]+)\]').firstMatch(orderNotes);
    if (match != null && match.group(1) != null) return match.group(1)!.trim();
  }
  return null;
}

String? _parsePaymentProofUrl(String? raw, String? orderNotes) {
  if (raw != null && raw.trim().isNotEmpty) return raw.trim();
  if (orderNotes != null && orderNotes.contains('[payment_proof_url:')) {
    final match = RegExp(r'\[payment_proof_url:\s*([^\]]+)\]').firstMatch(orderNotes);
    if (match != null && match.group(1) != null) return match.group(1)!.trim();
  }
  return null;
}



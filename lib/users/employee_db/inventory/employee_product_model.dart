import 'package:flutter/foundation.dart';

/// Stock status derived from a product's current quantity versus its
/// configured low-stock threshold. Unlike the customer-facing model,
/// employees see the exact [quantity] on hand — not just a coarse label.
enum EmployeeStockStatus {
  inStock,
  lowStock,
  outOfStock,
}

extension EmployeeStockStatusLabel on EmployeeStockStatus {
  String get label {
    switch (this) {
      case EmployeeStockStatus.inStock:
        return 'In Stock';
      case EmployeeStockStatus.lowStock:
        return 'Low Stock';
      case EmployeeStockStatus.outOfStock:
        return 'Out of Stock';
    }
  }
}

/// A sari-sari store product as seen by store staff (Cashier / Inventory
/// Staff), used by both the POS and Inventory tabs.
///
/// Carries the details an employee needs day-to-day — exact quantity,
/// barcode, and expiry — per the Product Information and Inventory and
/// Stock Management features in the system feature spec.
@immutable
class EmployeeProduct {
  const EmployeeProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.barcode,
    required this.quantity,
    this.lowStockThreshold = 10,
    this.expiryDate,
  });

  final String id;
  final String name;
  final String category;
  final double price;
  final String barcode;
  final int quantity;
  final int lowStockThreshold;
  final DateTime? expiryDate;

  EmployeeStockStatus get stockStatus {
    if (quantity <= 0) return EmployeeStockStatus.outOfStock;
    if (quantity <= lowStockThreshold) return EmployeeStockStatus.lowStock;
    return EmployeeStockStatus.inStock;
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  bool get isExpiringSoon {
    if (expiryDate == null || isExpired) return false;
    final daysLeft = expiryDate!.difference(DateTime.now()).inDays;
    return daysLeft <= 7;
  }

  EmployeeProduct copyWith({int? quantity}) {
    return EmployeeProduct(
      id: id,
      name: name,
      category: category,
      price: price,
      barcode: barcode,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: lowStockThreshold,
      expiryDate: expiryDate,
    );
  }
}
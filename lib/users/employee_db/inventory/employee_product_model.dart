import 'package:flutter/foundation.dart';

import 'employee_batch_model.dart';

/// Stock status derived from a product's *sellable* quantity versus its
/// configured low-stock threshold. Unlike the customer-facing model,
/// employees see the exact quantity on hand — not just a coarse label.
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
/// Batch-Aware Selling: stock no longer lives on a single flat `quantity`
/// field. Instead each product owns a list of [ProductBatch]es (its own
/// id, quantity, and expiry date), and `quantity` below is a *computed*
/// sum over them.
@immutable
class EmployeeProduct {
  const EmployeeProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.barcode,
    required this.batches,
    this.image,
    this.lowStockThreshold = 10,
  });

  final String id;
  final String name;
  final String category;
  final double price;
  final String barcode;
  final String? image;

  /// Every received lot of this product. Source of truth for stock —
  /// nothing else on this class stores a quantity directly.
  final List<ProductBatch> batches;
  final int lowStockThreshold;

  /// Total physical quantity on hand — sum of *every* batch, expired or
  /// not. This is what Inventory/POS display as "quantity" (a computed
  /// value now, rather than a stored field).
  int get quantity => batches.fold(0, (sum, b) => sum + b.quantity);

  /// The price shown in the POS. If the next batch to be sold (per FEFO)
  /// is expiring soon, the product is automatically discounted (20% off).
  double get currentPrice {
    final nextBatch = validBatches.isNotEmpty ? validBatches.first : null;
    if (nextBatch != null && nextBatch.isExpiringSoon) {
      return price * 0.8;
    }
    return price;
  }

  /// Batches that can actually be sold right now — stock left and not
  /// expired — sorted nearest-expiry-first (FEFO). Batches with no expiry
  /// date sort last, since they're never the "most urgent" pick.
  List<ProductBatch> get validBatches {
    final valid = batches.where((b) => b.isSellable).toList()
      ..sort((a, b) {
        final aDate = a.expiryDate;
        final bDate = b.expiryDate;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });
    return valid;
  }

  /// Sellable quantity — sum of [validBatches] only. A product whose only
  /// remaining stock sits in an expired batch has a [sellableQuantity] of
  /// 0 even though [quantity] is still positive; per the Batch-Aware
  /// Selling flow, that makes it out-of-stock for selling purposes.
  int get sellableQuantity => validBatches.fold(0, (sum, b) => sum + b.quantity);

  EmployeeStockStatus get stockStatus {
    if (sellableQuantity <= 0) return EmployeeStockStatus.outOfStock;
    if (sellableQuantity <= lowStockThreshold) return EmployeeStockStatus.lowStock;
    return EmployeeStockStatus.inStock;
  }

  /// Whether any batch still holding stock is already expired — feeds the
  /// manual-tap path (Path B) of the Expiration Notification flow, which
  /// surfaces every batch, not just sellable ones.
  bool get hasExpiredBatch => batches.any((b) => b.quantity > 0 && b.isExpired);

  /// Whether any batch still holding stock is inside the notification
  /// window but not expired yet — checked on both the POS scan path
  /// (Path A) and the manual-tap path (Path B).
  bool get hasExpiringSoonBatch => batches.any((b) => b.quantity > 0 && b.isExpiringSoon);

  // Kept under their original names for existing call sites (Home's
  // "Expiring Soon" stat card, Inventory's badge) — same meaning as the
  // batch-aware getters above, just aggregated across all batches.
  bool get isExpired => hasExpiredBatch;
  bool get isExpiringSoon => hasExpiringSoonBatch;

  EmployeeProduct copyWith({
    List<ProductBatch>? batches,
    String? name,
    String? category,
    double? price,
    String? barcode,
    String? image,
    int? lowStockThreshold,
  }) {
    return EmployeeProduct(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      barcode: barcode ?? this.barcode,
      batches: batches ?? this.batches,
      image: image ?? this.image,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    );
  }
}
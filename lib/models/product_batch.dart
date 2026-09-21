import 'package:flutter/foundation.dart';

/// A single received lot of a product — its own id, quantity, and expiry date.
@immutable
class ProductBatch {
  const ProductBatch({
    required this.id,
    required this.productId,
    required this.quantity,
    this.expiryDate,
    this.supplier,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String productId;
  final double quantity;
  final DateTime? expiryDate;
  final String? supplier;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Batch identifier shown to staff (e.g. "B001"). Carried onto the POS
  /// cart line and, optionally, the receipt so a sale can be traced back
  /// to the exact lot it came from.
  String get displayId => id.substring(0, 8); // First 8 chars of UUID

  /// Whether this batch can still be rung up in a sale: has stock left and
  /// isn't expired. Expired stock stays on record (for Inventory/Home
  /// visibility) but is never sellable.
  bool get isSellable => quantity > 0 && !isExpired;

  /// Whether this batch is expired (expiry date has passed)
  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  /// Whether this batch is expiring soon (within 5 days)
  bool get isExpiringSoon =>
      expiryDate != null &&
      expiryDate!.isAfter(DateTime.now()) &&
      expiryDate!.isBefore(DateTime.now().add(const Duration(days: 5)));

  /// Whether this batch is expiring within 2 weeks
  bool get isExpiringWithinTwoWeeks =>
      expiryDate != null &&
      expiryDate!.isAfter(DateTime.now()) &&
      expiryDate!.isBefore(DateTime.now().add(const Duration(days: 14)));

  /// Factory method to create a ProductBatch from Supabase JSON response
  factory ProductBatch.fromJson(Map<String, dynamic> json) => ProductBatch(
        id: json['id'] as String,
        productId: json['product_id'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        expiryDate: json['expiry_date'] != null
            ? DateTime.parse(json['expiry_date'] as String)
            : null,
        supplier: json['supplier'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  /// Converts the ProductBatch to a JSON map suitable for Supabase
  Map<String, dynamic> toJson() => {
        'id': id,
        'product_id': productId,
        'quantity': quantity,
        'expiry_date': expiryDate?.toIso8601String(),
        'supplier': supplier,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  /// Creates a copy of this product batch with optional field replacements
  ProductBatch copyWith({
    String? id,
    String? productId,
    double? quantity,
    DateTime? expiryDate,
    String? supplier,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductBatch(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      expiryDate: expiryDate ?? this.expiryDate,
      supplier: supplier ?? this.supplier,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductBatch &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          productId == other.productId &&
          quantity == other.quantity &&
          expiryDate == other.expiryDate &&
          supplier == other.supplier &&
          notes == other.notes &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      productId.hashCode ^
      quantity.hashCode ^
      expiryDate.hashCode ^
      supplier.hashCode ^
      notes.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() {
    return 'ProductBatch(id: $id, productId: $productId, quantity: $quantity)';
  }
}
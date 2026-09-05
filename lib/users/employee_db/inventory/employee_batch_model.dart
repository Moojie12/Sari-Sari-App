import 'package:flutter/foundation.dart';

import '../../../core/expiry/expiry_checker.dart';

/// A single received lot of a product — its own id, quantity, and expiry
/// date.
///
/// This is the new concept behind Batch-Aware Selling: instead of one flat
/// `quantity` per [EmployeeProduct], stock now lives on a list of these.
/// Everything downstream — FEFO selection, batch deduction on checkout,
/// and the Expiration Notification flow — operates per batch.
@immutable
class ProductBatch {
  const ProductBatch({
    required this.id,
    required this.quantity,
    this.expiryDate,
    this.supplier,
    this.notes,
  });

  /// Batch identifier shown to staff (e.g. "B001"). Carried onto the POS
  /// cart line and, optionally, the receipt so a sale can be traced back
  /// to the exact lot it came from.
  final String id;

  final int quantity;

  /// Null means this batch isn't tracked for expiry (e.g. household goods
  /// that don't spoil) — it never shows as expiring/expired and is never
  /// prioritized by FEFO.
  final DateTime? expiryDate;

  /// Optional supplier info captured on the Stock Receiving screen when
  /// this batch was (most recently) received. Purely informational.
  final String? supplier;

  /// Optional free-text note captured on the Stock Receiving screen.
  final String? notes;

  /// Runs this batch's [expiryDate] through the shared [ExpiryChecker] —
  /// the same check used on both the POS scan path and the manual-tap
  /// path, so status is always consistent between them.
  ExpiryStatus expiryStatus({ExpiryChecker checker = ExpiryChecker.standard}) {
    return checker.statusOf(expiryDate);
  }

  bool get isExpired => expiryStatus() == ExpiryStatus.expired;
  bool get isExpiringSoon => expiryStatus() == ExpiryStatus.expiringSoon;

  /// Whether this batch can still be rung up in a sale: has stock left and
  /// isn't expired. Expired stock stays on record (for Inventory/Home
  /// visibility) but is never sellable.
  bool get isSellable => quantity > 0 && !isExpired;

  ProductBatch copyWith({int? quantity, String? supplier, String? notes}) {
    return ProductBatch(
      id: id,
      quantity: quantity ?? this.quantity,
      expiryDate: expiryDate,
      supplier: supplier ?? this.supplier,
      notes: notes ?? this.notes,
    );
  }
}
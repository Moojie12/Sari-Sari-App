import 'package:flutter/foundation.dart';

import 'inventory/employee_batch_model.dart';
import 'inventory/employee_dummy_products.dart';
import 'inventory/employee_product_model.dart';

/// Owns the live inventory list shared across the employee experience —
/// the Home tab's alert counts, the POS tab (which deducts from a specific
/// batch on checkout), and the Inventory tab (which displays batches and
/// lets staff adjust stock manually).
class EmployeeInventoryController extends ChangeNotifier {
  final List<EmployeeProduct> _products = List.of(kEmployeeDummyProducts);

  List<EmployeeProduct> get products => List.unmodifiable(_products);

  List<EmployeeProduct> get lowStockProducts =>
      _products.where((p) => p.stockStatus == EmployeeStockStatus.lowStock).toList();

  List<EmployeeProduct> get outOfStockProducts =>
      _products.where((p) => p.stockStatus == EmployeeStockStatus.outOfStock).toList();

  /// Products with at least one batch inside the notification window —
  /// backs the Home tab's "Expiring Soon" stat card and list. Same signal
  /// the POS (Path A) and Inventory/Home (Path B) screens check per batch;
  /// this is just that same logic aggregated up to product level.
  List<EmployeeProduct> get expiringSoonProducts =>
      _products.where((p) => p.hasExpiringSoonBatch).toList();

  /// Products with at least one already-expired batch still holding stock.
  List<EmployeeProduct> get expiredProducts =>
      _products.where((p) => p.hasExpiredBatch).toList();

  EmployeeProduct? findByBarcode(String barcode) {
    for (final product in _products) {
      if (product.barcode == barcode) return product;
    }
    return null;
  }

  EmployeeProduct? findById(String productId) {
    for (final product in _products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  /// Deducts [quantity] from one specific batch — the Batch-Aware Selling
  /// flow's checkout step. The product's total `quantity` is a computed
  /// sum over its batches, so it updates automatically once the batch
  /// itself is deducted; nothing else needs to be recalculated by hand.
  ///
  /// Returns false if the product/batch doesn't exist, or the batch no
  /// longer has enough left (e.g. deducted elsewhere in the meantime).
  bool deductFromBatch(String productId, String batchId, int quantity) {
    final productIndex = _products.indexWhere((p) => p.id == productId);
    if (productIndex < 0) return false;
    final product = _products[productIndex];

    final batchIndex = product.batches.indexWhere((b) => b.id == batchId);
    if (batchIndex < 0) return false;
    final batch = product.batches[batchIndex];
    if (batch.quantity < quantity) return false;

    final updatedBatches = List<ProductBatch>.of(product.batches);
    updatedBatches[batchIndex] = batch.copyWith(quantity: batch.quantity - quantity);
    _products[productIndex] = product.copyWith(batches: updatedBatches);
    notifyListeners();
    return true;
  }

  /// Manually adjusts stock up or down — the Inventory tab's "Add stock" /
  /// "Remove stock" feature. Since stock now lives on batches:
  ///  - adding (`delta > 0`) tops up an existing no-expiry batch, or opens
  ///    a new one if the product doesn't have one yet;
  ///  - removing (`delta < 0`) follows the same FEFO order a sale would —
  ///    nearest-expiry valid batches first, then already-expired ones —
  ///    so no batch is ever left with a negative quantity.
  void adjustStock(String productId, int delta) {
    if (delta == 0) return;
    final productIndex = _products.indexWhere((p) => p.id == productId);
    if (productIndex < 0) return;
    final product = _products[productIndex];

    if (delta > 0) {
      final batches = List<ProductBatch>.of(product.batches);
      final noExpiryIndex = batches.indexWhere((b) => b.expiryDate == null);
      if (noExpiryIndex >= 0) {
        batches[noExpiryIndex] =
            batches[noExpiryIndex].copyWith(quantity: batches[noExpiryIndex].quantity + delta);
      } else {
        batches.add(ProductBatch(id: _nextBatchId(product), quantity: delta));
      }
      _products[productIndex] = product.copyWith(batches: batches);
      notifyListeners();
      return;
    }

    var remaining = -delta;
    final batches = List<ProductBatch>.of(product.batches);
    final deductionOrder = [
      ...product.validBatches,
      ...product.batches.where((b) => b.isExpired && b.quantity > 0),
    ];
    for (final target in deductionOrder) {
      if (remaining <= 0) break;
      final index = batches.indexWhere((b) => b.id == target.id);
      if (index < 0) continue;
      final take = remaining < batches[index].quantity ? remaining : batches[index].quantity;
      batches[index] = batches[index].copyWith(quantity: batches[index].quantity - take);
      remaining -= take;
    }
    _products[productIndex] = product.copyWith(batches: batches);
    notifyListeners();
  }

  String _nextBatchId(EmployeeProduct product) {
    final existingNumbers = product.batches
        .map((b) => int.tryParse(b.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final next = (existingNumbers.isEmpty ? 0 : existingNumbers.reduce((a, b) => a > b ? a : b)) + 1;
    return 'B${next.toString().padLeft(3, '0')}';
  }
}
import 'package:flutter/foundation.dart';

import 'inventory/employee_dummy_products.dart';
import 'inventory/employee_product_model.dart';

/// Owns the live inventory list shared across the employee experience —
/// the Home tab's alert counts, the POS tab (which deducts stock on
/// checkout), and the Inventory tab (which displays stock and lets staff
/// adjust it manually).
class EmployeeInventoryController extends ChangeNotifier {
  final List<EmployeeProduct> _products = List.of(kEmployeeDummyProducts);

  List<EmployeeProduct> get products => List.unmodifiable(_products);

  List<EmployeeProduct> get lowStockProducts => _products
      .where((p) => p.stockStatus == EmployeeStockStatus.lowStock)
      .toList();

  List<EmployeeProduct> get outOfStockProducts => _products
      .where((p) => p.stockStatus == EmployeeStockStatus.outOfStock)
      .toList();

  List<EmployeeProduct> get expiringSoonProducts =>
      _products.where((p) => p.isExpiringSoon).toList();

  EmployeeProduct? findByBarcode(String barcode) {
    for (final product in _products) {
      if (product.barcode == barcode) return product;
    }
    return null;
  }

  /// Deducts [quantity] from [productId]'s stock (e.g. after a POS sale).
  /// Returns false if there isn't enough stock to deduct.
  bool deductStock(String productId, int quantity) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index < 0) return false;
    final product = _products[index];
    if (product.quantity < quantity) return false;

    _products[index] = product.copyWith(quantity: product.quantity - quantity);
    notifyListeners();
    return true;
  }

  /// Manually adjusts stock up or down — the Inventory tab's "Add stock" /
  /// "Remove stock" / manual stock adjustment feature.
  void adjustStock(String productId, int delta) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index < 0) return;
    final product = _products[index];
    final newQuantity = product.quantity + delta;
    _products[index] = product.copyWith(quantity: newQuantity < 0 ? 0 : newQuantity);
    notifyListeners();
  }
}
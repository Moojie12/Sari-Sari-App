import 'package:flutter/foundation.dart';

import '../employee_inventory_controller.dart';
import '../inventory/employee_product_model.dart';

enum EmployeePaymentMethod { cash, gCash }

/// A single line item in the current POS transaction.
class EmployeePosCartItem {
  EmployeePosCartItem({required this.product, this.quantity = 1});

  final EmployeeProduct product;
  int quantity;

  double get subtotal => product.price * quantity;
}

/// A completed walk-in sale, shown on the receipt screen
/// (Receipt Generation feature).
class EmployeeReceipt {
  const EmployeeReceipt({
    required this.receiptNumber,
    required this.dateTime,
    required this.items,
    required this.totalAmount,
    required this.amountPaid,
    required this.paymentMethod,
  });

  final String receiptNumber;
  final DateTime dateTime;
  final List<EmployeePosCartItem> items;
  final double totalAmount;
  final double amountPaid;
  final EmployeePaymentMethod paymentMethod;

  double get change => amountPaid - totalAmount;
}

/// Drives the POS tab: adding products to a walk-in sale cart (by search
/// or barcode), calculating totals, and completing the transaction —
/// which deducts sold quantities from the shared inventory automatically
/// (POS and Sales Management / Payment Management features).
class EmployeePosController extends ChangeNotifier {
  EmployeePosController({required EmployeeInventoryController inventory})
      : _inventory = inventory;

  final EmployeeInventoryController _inventory;

  final List<EmployeePosCartItem> _cart = [];
  int _receiptCounter = 1;

  List<EmployeePosCartItem> get cart => List.unmodifiable(_cart);

  int get itemCount => _cart.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount => _cart.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Adds a product to the cart. Returns false if it's out of stock.
  bool addToCart(EmployeeProduct product) {
    if (product.stockStatus == EmployeeStockStatus.outOfStock) return false;

    final index = _cart.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      _cart[index].quantity++;
    } else {
      _cart.add(EmployeePosCartItem(product: product));
    }
    notifyListeners();
    return true;
  }

  void incrementQuantity(String productId) {
    final index = _cart.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _cart[index].quantity++;
      notifyListeners();
    }
  }

  void decrementQuantity(String productId) {
    final index = _cart.indexWhere((item) => item.product.id == productId);
    if (index >= 0 && _cart[index].quantity > 1) {
      _cart[index].quantity--;
      notifyListeners();
    }
  }

  void removeFromCart(String productId) {
    _cart.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  /// Voids the current, not-yet-paid transaction.
  void voidTransaction() {
    _cart.clear();
    notifyListeners();
  }

  /// Completes the sale: deducts every cart item from inventory, clears
  /// the cart, and returns the resulting [EmployeeReceipt]. Returns null
  /// if the cart is empty or any item no longer has enough stock.
  EmployeeReceipt? checkout({
    required EmployeePaymentMethod paymentMethod,
    required double amountPaid,
  }) {
    if (_cart.isEmpty) return null;

    for (final item in _cart) {
      if (item.product.quantity < item.quantity) return null;
    }

    for (final item in _cart) {
      _inventory.deductStock(item.product.id, item.quantity);
    }

    final receipt = EmployeeReceipt(
      receiptNumber: 'RC-${_receiptCounter.toString().padLeft(5, '0')}',
      dateTime: DateTime.now(),
      items: List.of(_cart),
      totalAmount: totalAmount,
      amountPaid: amountPaid,
      paymentMethod: paymentMethod,
    );

    _receiptCounter++;
    _cart.clear();
    notifyListeners();
    return receipt;
  }
}
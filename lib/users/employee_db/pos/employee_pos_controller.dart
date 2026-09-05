import 'package:flutter/foundation.dart';

import '../../../core/expiry/expiry_checker.dart';
import '../employee_inventory_controller.dart';
import '../inventory/employee_batch_model.dart';
import '../inventory/employee_product_model.dart';

enum EmployeePaymentMethod { cash, gCash }

/// A single line item in the current POS transaction.
///
/// Batch-Aware Selling: each line is pinned to the exact [batchId] it was
/// rung up from (resolved via the batch-selection sheet — CONTINUE/FEFO or
/// CHOOSE BATCH), not just the product. [batchExpiryDate] is captured at
/// add-to-cart time so the cart/receipt can show it without re-looking up
/// a batch that may since have been fully sold out.
class EmployeePosCartItem {
  EmployeePosCartItem({
    required this.product,
    required this.batchId,
    required this.unitPrice,
    this.batchExpiryDate,
    this.quantity = 1,
  });

  final EmployeeProduct product;
  final String batchId;

  /// The price per unit at the time it was added to the cart, capturing
  /// any automatic discounts (e.g. for expiring stock).
  final double unitPrice;

  final DateTime? batchExpiryDate;
  int quantity;

  /// Whether this item was sold at a discount because it was expiring soon.
  bool get isOnSale => unitPrice < product.price;

  double get subtotal => unitPrice * quantity;
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

ProductBatch? _findBatch(EmployeeProduct product, String batchId) {
  for (final batch in product.batches) {
    if (batch.id == batchId) return batch;
  }
  return null;
}

/// Drives the POS tab: adding products to a walk-in sale cart from a
/// resolved batch, calculating totals, and completing the transaction —
/// which deducts sold quantities from the correct batch in the shared
/// inventory automatically (POS and Sales Management / Payment Management
/// features, batch-aware).
class EmployeePosController extends ChangeNotifier {
  EmployeePosController({required EmployeeInventoryController inventory})
      : _inventory = inventory;

  final EmployeeInventoryController _inventory;

  final List<EmployeePosCartItem> _cart = [];
  int _receiptCounter = 1;

  List<EmployeePosCartItem> get cart => List.unmodifiable(_cart);

  int get itemCount => _cart.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount => _cart.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Adds [quantity] of [product] to the cart from a specific [batch] —
  /// called once the cashier resolves the Batch Selection UI (CONTINUE for
  /// FEFO, or CHOOSE BATCH). The quantity is capped to what's left in that
  /// batch, even if the product's overall stock across other batches is
  /// higher. Returns false if the batch can't cover the requested amount.
  bool addBatchToCart(EmployeeProduct product, ProductBatch batch, {int quantity = 1}) {
    if (quantity <= 0) return false;

    final index =
    _cart.indexWhere((item) => item.product.id == product.id && item.batchId == batch.id);
    final alreadyInCart = index >= 0 ? _cart[index].quantity : 0;
    if (alreadyInCart + quantity > batch.quantity) return false;

    if (index >= 0) {
      _cart[index].quantity += quantity;
    } else {
      // Automatic discount: 20% off if the batch is expiring soon.
      double price = product.price;
      if (batch.isExpiringSoon) {
        price *= 0.8;
      }

      _cart.add(EmployeePosCartItem(
        product: product,
        batchId: batch.id,
        unitPrice: price,
        batchExpiryDate: batch.expiryDate,
        quantity: quantity,
      ));
    }
    notifyListeners();
    return true;
  }

  /// Increments a cart line, capped to that specific batch's current stock
  /// (looked up fresh from inventory, in case it changed since add-to-cart).
  void incrementQuantity(String productId, String batchId) {
    final index =
    _cart.indexWhere((item) => item.product.id == productId && item.batchId == batchId);
    if (index < 0) return;

    final liveProduct = _inventory.findById(productId);
    final liveBatch = liveProduct != null ? _findBatch(liveProduct, batchId) : null;
    final cap = liveBatch?.quantity ?? _cart[index].quantity;
    if (_cart[index].quantity + 1 > cap) return;

    _cart[index].quantity++;
    notifyListeners();
  }

  void decrementQuantity(String productId, String batchId) {
    final index =
    _cart.indexWhere((item) => item.product.id == productId && item.batchId == batchId);
    if (index >= 0 && _cart[index].quantity > 1) {
      _cart[index].quantity--;
      notifyListeners();
    }
  }

  void removeFromCart(String productId, String batchId) {
    _cart.removeWhere((item) => item.product.id == productId && item.batchId == batchId);
    notifyListeners();
  }

  /// Voids the current, not-yet-paid transaction.
  void voidTransaction() {
    _cart.clear();
    notifyListeners();
  }

  /// Completes the sale: deducts every cart line from its *specific* batch
  /// (not just the product's overall stock), clears the cart, and returns
  /// the resulting [EmployeeReceipt]. Returns null if the cart is empty or
  /// any line's batch no longer has enough stock left.
  EmployeeReceipt? checkout({
    required EmployeePaymentMethod paymentMethod,
    required double amountPaid,
  }) {
    if (_cart.isEmpty) return null;

    // Re-validate against the live batch, not the snapshot captured when
    // the item was added — another sale may have used up that batch since.
    for (final item in _cart) {
      final liveProduct = _inventory.findById(item.product.id);
      final liveBatch = liveProduct != null ? _findBatch(liveProduct, item.batchId) : null;
      if (liveBatch == null || liveBatch.quantity < item.quantity) return null;
    }

    for (final item in _cart) {
      _inventory.deductFromBatch(item.product.id, item.batchId, item.quantity);
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

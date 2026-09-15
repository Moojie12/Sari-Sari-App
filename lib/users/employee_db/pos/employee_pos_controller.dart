import 'package:flutter/foundation.dart';

import '../employee_inventory_controller.dart';
import '../inventory/employee_batch_model.dart';
import '../inventory/employee_product_model.dart';

enum EmployeePaymentMethod { cash, gCash }

/// A single line item in the current POS transaction.
class EmployeePosCartItem {
  EmployeePosCartItem({
    required this.product,
    required this.batchId,
    required this.unitPrice,
    this.batchExpiryDate,
    this.quantity = 1.0,
  });

  final EmployeeProduct product;
  final String batchId;

  /// The price per unit at the time it was added to the cart, capturing
  /// any automatic discounts (e.g. for expiring stock).
  final double unitPrice;

  final DateTime? batchExpiryDate;
  double quantity;

  /// Whether this item was sold at a discount because it was expiring soon.
  bool get isOnSale => unitPrice < product.price;

  double get subtotal => ((unitPrice * quantity) * 100).round() / 100;
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
/// resolved batch, calculating totals, and completing the transaction.
class EmployeePosController extends ChangeNotifier {
  EmployeePosController({required this.inventory});

  final EmployeeInventoryController inventory;

  final List<EmployeePosCartItem> _cart = [];
  int _receiptCounter = 1;

  /// Store's GCash QR code image.
  String? _gcashQrCode = 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/QR_code_for_mobile_English_Wikipedia.svg/1200px-QR_code_for_mobile_English_Wikipedia.svg.png';

  List<EmployeePosCartItem> get cart => List.unmodifiable(_cart);
  String? get gcashQrCode => _gcashQrCode;

  void updateGcashQrCode(String? value) {
    _gcashQrCode = value;
    notifyListeners();
  }

  /// Returns the number of distinct distinct lines/items in the cart.
  int get itemCount => _cart.length;

  /// Total amount of the transaction rounded to two decimal places.
  double get totalAmount {
    final rawTotal = _cart.fold(0.0, (sum, item) => sum + item.subtotal);
    return (rawTotal * 100).round() / 100;
  }

  /// Total physical quantity sum across all items.
  double get totalQuantity => _cart.fold(0.0, (sum, item) => sum + item.quantity);

  /// Adds [quantity] of [product] to the cart from a specific [batch].
  bool addBatchToCart(EmployeeProduct product, ProductBatch batch, {double quantity = 1.0}) {
    if (quantity <= 0) return false;

    final index =
    _cart.indexWhere((item) => item.product.id == product.id && item.batchId == batch.id);
    final alreadyInCart = index >= 0 ? _cart[index].quantity : 0.0;
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

  /// Increments a cart line, capped to that specific batch's current stock.
  void incrementQuantity(String productId, String batchId) {
    final index =
    _cart.indexWhere((item) => item.product.id == productId && item.batchId == batchId);
    if (index < 0) return;

    final liveProduct = inventory.findById(productId);
    final liveBatch = liveProduct != null ? _findBatch(liveProduct, batchId) : null;
    final cap = liveBatch?.quantity ?? _cart[index].quantity;
    
    final step = _cart[index].product.isWeightBased ? 0.25 : 1.0;
    if (_cart[index].quantity + step > cap) return;

    _cart[index].quantity += step;
    notifyListeners();
  }

  void decrementQuantity(String productId, String batchId) {
    final index =
    _cart.indexWhere((item) => item.product.id == productId && item.batchId == batchId);
    if (index >= 0) {
      final step = _cart[index].product.isWeightBased ? 0.25 : 1.0;
      if (_cart[index].quantity > step) {
        _cart[index].quantity -= step;
        notifyListeners();
      }
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

  /// Completes the sale.
  EmployeeReceipt? checkout({
    required EmployeePaymentMethod paymentMethod,
    required double amountPaid,
  }) {
    if (_cart.isEmpty) return null;

    for (final item in _cart) {
      final liveProduct = inventory.findById(item.product.id);
      final liveBatch = liveProduct != null ? _findBatch(liveProduct, item.batchId) : null;
      if (liveBatch == null || liveBatch.quantity < item.quantity) return null;
    }

    for (final item in _cart) {
      inventory.deductFromBatch(item.product.id, item.batchId, item.quantity);
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
import 'package:flutter/foundation.dart';
import '../../models/sale_deal_model.dart';
import 'home/customer_product_model.dart';

/// Represents a single item in the shopping cart.
class CartItem {
  CartItem({
    required this.product,
    this.quantity = 1,
    this.customPrice,
    this.saleDealTitle,
  });

  final CustomerProduct product;
  int quantity;
  final double? customPrice;
  final String? saleDealTitle;

  double get unitPrice => customPrice ?? product.price;
  double get subtotal => unitPrice * quantity;
  bool get isOnSalePromo => customPrice != null;
}

/// Manages the shopping cart state.
class CustomerCartController extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount => _items.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Adds [quantity] of [product] to the cart.
  /// If the product is already in the cart with the same pricing mode, it increments its quantity.
  /// The total quantity for a single product is capped at its [sellableQuantity].
  bool addToCart(
    CustomerProduct product, {
    int quantity = 1,
    double? customPrice,
    String? saleDealTitle,
  }) {
    if (product.isOutOfStock) return false;

    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id && item.customPrice == customPrice,
    );
    final maxAvailable = product.sellableQuantity.toInt();

    if (existingIndex >= 0) {
      final newQuantity = _items[existingIndex].quantity + quantity;
      _items[existingIndex].quantity = newQuantity > maxAvailable ? maxAvailable : newQuantity;
    } else {
      final cappedQuantity = quantity > maxAvailable ? maxAvailable : quantity;
      _items.add(
        CartItem(
          product: product,
          quantity: cappedQuantity,
          customPrice: customPrice,
          saleDealTitle: saleDealTitle,
        ),
      );
    }

    notifyListeners();
    return true;
  }

  /// Adds an entire customized on-sale deal/bundle into the cart at the promo price.
  bool addSaleDeal(SaleDealModel deal, List<CustomerProduct> availableProducts) {
    if (deal.items.isEmpty) return false;

    // 1. Verify stock availability for all items in deal
    for (final item in deal.items) {
      final product = availableProducts.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => CustomerProduct(
          id: item.productId,
          name: item.productName,
          category: '',
          price: item.originalPrice,
          capital: 0,
          sellableQuantity: 0,
          image: '',
          availability: CustomerProductAvailability.outOfStock,
        ),
      );
      if (product.sellableQuantity < item.quantity) {
        return false; // Insufficient stock
      }
    }

    // 2. Compute proportional pricing so that total item sum equals deal.salePrice exactly
    final originalTotal = deal.originalTotalPrice;
    final ratio = originalTotal > 0 ? (deal.salePrice / originalTotal) : 1.0;

    for (final item in deal.items) {
      final product = availableProducts.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => CustomerProduct(
          id: item.productId,
          name: item.productName,
          category: '',
          price: item.originalPrice,
          capital: 0,
          sellableQuantity: item.quantity.toDouble(),
          image: '',
          availability: CustomerProductAvailability.inStock,
        ),
      );

      final discountedPrice = double.parse((item.originalPrice * ratio).toStringAsFixed(2));

      _items.add(
        CartItem(
          product: product,
          quantity: item.quantity,
          customPrice: discountedPrice,
          saleDealTitle: deal.title,
        ),
      );
    }

    notifyListeners();
    return true;
  }

  void incrementQuantity(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      final maxAvailable = _items[index].product.sellableQuantity.toInt();
      if (_items[index].quantity < maxAvailable) {
        _items[index].quantity++;
        notifyListeners();
      }
    }
  }

  void decrementQuantity(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0 && _items[index].quantity > 1) {
      _items[index].quantity--;
      notifyListeners();
    }
  }

  void removeFromCart(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}

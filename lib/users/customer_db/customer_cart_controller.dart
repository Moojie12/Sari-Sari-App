import 'package:flutter/foundation.dart';

import 'home/customer_product_model.dart';

/// Represents a single item in the shopping cart.
class CartItem {
  CartItem({
    required this.product,
    this.quantity = 1,
  });

  final CustomerProduct product;
  int quantity;

  double get subtotal => product.price * quantity;
}

/// Manages the shopping cart state.
class CustomerCartController extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount => _items.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Adds [quantity] of [product] to the cart.
  /// If the product is already in the cart, it increments its quantity.
  bool addToCart(CustomerProduct product, {int quantity = 1}) {
    if (product.isOutOfStock) return false;

    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }

    notifyListeners();
    return true;
  }

  void incrementQuantity(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _items[index].quantity++;
      notifyListeners();
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

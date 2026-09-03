import 'package:flutter/foundation.dart';

import 'customer_product_model.dart';

/// Simple in-memory mock cart shared by the Home page and Product Details
/// page.
///
/// This intentionally has no persistence, database, or API integration —
/// it only tracks a running item count so the cart badge and "Added to
/// cart" feedback can be demonstrated end-to-end.
///
/// TODO: Replace with a real cart (persisted items, per-product
/// quantities, totals) once checkout is implemented.
class CustomerCartController extends ChangeNotifier {
  int _itemCount = 0;

  int get itemCount => _itemCount;

  /// Adds [quantity] of [product] to the mock cart.
  ///
  /// Returns `false` (and does nothing) if the product is out of stock —
  /// callers should not show "Added to cart" feedback in that case.
  bool addToCart(CustomerProduct product, {int quantity = 1}) {
    if (product.isOutOfStock) return false;
    _itemCount += quantity;
    notifyListeners();
    return true;
  }
}
import 'package:flutter/foundation.dart';

/// Stock/availability status shown to customers.
///
/// Customers never see exact inventory quantities — only one of these
/// three coarse statuses. `outOfStock` disables "Add to Cart" wherever
/// this product is shown.
enum CustomerProductAvailability {
  inStock,
  lowStock,
  outOfStock,
}

extension CustomerProductAvailabilityLabel on CustomerProductAvailability {
  String get label {
    switch (this) {
      case CustomerProductAvailability.inStock:
        return 'In Stock';
      case CustomerProductAvailability.lowStock:
        return 'Low Stock';
      case CustomerProductAvailability.outOfStock:
        return 'Out of Stock';
    }
  }
}

/// A single sari-sari store product, as shown to customers.
///
/// Currently populated from local dummy data (see
/// `customer_dummy_products.dart`). The Home page UI only depends on this
/// model, so swapping the dummy list for real database/API data later
/// should not require changing any widget that consumes it.
@immutable
class CustomerProduct {
  const CustomerProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.image,
    required this.availability,
    this.isOnSale = false,
  });

  final String id;
  final String name;
  final String category;
  final double price;

  /// Placeholder image reference (e.g. a future asset path or network
  /// URL). Not rendered yet — the UI currently shows a plain placeholder
  /// icon instead, since there are no product image assets or an image
  /// dependency yet. Kept on the model so real images can be wired in
  /// later without changing the model shape.
  final String image;

  final CustomerProductAvailability availability;
  final bool isOnSale;

  bool get isOutOfStock =>
      availability == CustomerProductAvailability.outOfStock;
}
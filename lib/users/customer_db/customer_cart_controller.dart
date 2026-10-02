import 'package:flutter/foundation.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/local_database_service.dart';
import '../../models/sale_deal_model.dart';
import 'home/customer_product_model.dart';

/// Represents a single item or bundled deal item in the shopping cart.
class CartItem {
  CartItem({
    required this.product,
    this.quantity = 1,
    this.customPrice,
    this.saleDealTitle,
    this.deal,
  });

  final CustomerProduct product;
  int quantity;
  final double? customPrice;
  final String? saleDealTitle;
  final SaleDealModel? deal;

  bool get isDeal => deal != null;
  String get id => isDeal ? 'deal_${deal!.id}' : product.id;
  String get displayName => isDeal ? deal!.title : product.name;
  String? get image => isDeal ? deal!.effectiveImage : product.image;

  double get unitPrice => isDeal ? deal!.salePrice : (customPrice ?? product.price);
  double get originalUnitPrice => isDeal ? deal!.originalTotalPrice : product.price;
  double get subtotal => unitPrice * quantity;
  bool get isOnSalePromo => isDeal || customPrice != null;

  String? get dealInclusions {
    if (!isDeal) return null;
    return deal!.items.map((i) => '${i.quantity * quantity}x ${i.productName}').join(', ');
  }
}

/// Manages the shopping cart state.
class CustomerCartController extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount => _items.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Adds [quantity] of [product] to the cart.
  bool addToCart(
    CustomerProduct product, {
    int quantity = 1,
    double? customPrice,
    String? saleDealTitle,
  }) {
    if (product.isOutOfStock) return false;

    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id && item.customPrice == customPrice && !item.isDeal,
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

  /// Adds an entire customized on-sale deal/bundle into the cart as ONE bundled CartItem.
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

    // 2. Add or increment deal as a single bundled CartItem
    final dealCartId = 'deal_${deal.id}';
    final existingIndex = _items.indexWhere((item) => item.id == dealCartId);

    final anchorProduct = CustomerProduct(
      id: dealCartId,
      name: deal.title,
      category: 'Promotions',
      price: deal.salePrice,
      capital: 0,
      sellableQuantity: 999,
      image: deal.effectiveImage ?? '',
      availability: CustomerProductAvailability.inStock,
      isOnSale: true,
    );

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += 1;
    } else {
      _items.add(
        CartItem(
          product: anchorProduct,
          quantity: 1,
          customPrice: deal.salePrice,
          saleDealTitle: deal.title,
          deal: deal,
        ),
      );
    }

    notifyListeners();
    return true;
  }

  void incrementQuantity(String id) {
    final index = _items.indexWhere((item) => item.id == id || item.product.id == id);
    if (index >= 0) {
      final item = _items[index];
      if (item.isDeal) {
        item.quantity++;
        notifyListeners();
      } else {
        final maxAvailable = item.product.sellableQuantity.toInt();
        if (item.quantity < maxAvailable) {
          item.quantity++;
          notifyListeners();
        }
      }
    }
  }

  void decrementQuantity(String id) {
    final index = _items.indexWhere((item) => item.id == id || item.product.id == id);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  void removeFromCart(String id) {
    _items.removeWhere((item) => item.id == id || item.product.id == id);
    notifyListeners();
    _saveCartToLocalAndQueueSync();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
    _saveCartToLocalAndQueueSync();
  }

  void _saveCartToLocalAndQueueSync() {
    final userId = AuthService().currentUser?.uid ?? 'guest';
    final payload = {
      'items': _items.map((i) => {
        'id': i.id,
        'productName': i.displayName,
        'unitPrice': i.unitPrice,
        'quantity': i.quantity,
        'subtotal': i.subtotal,
      }).toList(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    LocalDatabaseService.instance.queueOfflineAction(
      userId: userId,
      action: 'UPDATE_CART',
      payload: payload,
    );
  }
}

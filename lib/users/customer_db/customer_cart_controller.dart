import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/local_database_service.dart';
import 'package:sari_sari/models/sale_deal_model.dart';
import '../employee_db/employee_inventory_controller.dart';
import '../employee_db/inventory/employee_product_model.dart';
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
  static final CustomerCartController _instance = CustomerCartController._internal();
  static CustomerCartController get instance => _instance;
  factory CustomerCartController() => _instance;

  String? _currentLoadedUserId;

  CustomerCartController._internal() {
    _initAuthListener();
    _loadCartFromPrefs();
  }

  void _initAuthListener() {
    try {
      AuthService().authStateChanges.listen((user) {
        final activeUserId = user?.uid ?? 'guest';
        if (_currentLoadedUserId != activeUserId) {
          _loadCartFromPrefs(activeUserId);
        }
      });
    } catch (_) {}
  }

  /// Ensures that the in-memory cart corresponds to the currently logged-in user.
  void ensureCartForActiveUser() {
    final activeUserId = AuthService().currentUser?.uid ?? 'guest';
    if (_currentLoadedUserId != activeUserId) {
      _loadCartFromPrefs(activeUserId);
    }
  }

  final List<CartItem> _items = [];

  List<CartItem> get items {
    ensureCartForActiveUser();
    return List.unmodifiable(_items);
  }

  int get itemCount {
    ensureCartForActiveUser();
    return _items.fold(0, (sum, item) => sum + item.quantity);
  }

  double get totalAmount {
    ensureCartForActiveUser();
    return _items.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  /// Adds [quantity] of [product] to the cart.
  bool addToCart(
    CustomerProduct product, {
    int quantity = 1,
    double? customPrice,
    String? saleDealTitle,
  }) {
    ensureCartForActiveUser();
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
    _saveCartToLocalAndQueueSync();
    return true;
  }

  /// Calculates how many bundles of this deal can be purchased, respecting
  /// BOTH the owner's promo quota limit and live inventory of each included item.
  int getAvailableDealStock(SaleDealModel deal) {
    if (deal.items.isEmpty) return 0;
    final products = EmployeeInventoryController.instance.products;
    int maxFromStock = 999999;
    for (final item in deal.items) {
      final prod = products.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => EmployeeProduct(
          id: item.productId,
          name: item.productName,
          barcode: '',
          category: '',
          price: item.originalPrice,
          capital: 0,
          batches: const [],
        ),
      );
      if (item.quantity <= 0) continue;
      final possible = prod.sellableQuantity.toInt() ~/ item.quantity;
      if (possible < maxFromStock) {
        maxFromStock = possible;
      }
    }
    final quota = deal.remainingSaleLimit;
    return max(0, min(maxFromStock, quota));
  }

  /// Adds an entire customized on-sale deal/bundle into the cart as ONE bundled CartItem.
  /// Strictly checks against live product stock and owner-defined promo sale limit.
  bool addSaleDeal(
    SaleDealModel deal,
    List<CustomerProduct> availableProducts, {
    void Function(String message)? onError,
  }) {
    ensureCartForActiveUser();
    if (deal.items.isEmpty) {
      onError?.call('This sale promo has no included products.');
      return false;
    }

    final maxAvailable = getAvailableDealStock(deal);
    if (maxAvailable <= 0) {
      onError?.call('Sorry, promo deal "${deal.title}" is currently sold out.');
      return false;
    }

    final dealCartId = 'deal_${deal.id}';
    final existingIndex = _items.indexWhere((item) => item.id == dealCartId);
    final currentQty = existingIndex >= 0 ? _items[existingIndex].quantity : 0;

    if (currentQty + 1 > maxAvailable) {
      onError?.call('Cannot add more. Only $maxAvailable available on sale.');
      return false;
    }

    final anchorProduct = CustomerProduct(
      id: dealCartId,
      name: deal.title,
      category: 'Promotions',
      price: deal.salePrice,
      capital: 0,
      sellableQuantity: maxAvailable.toDouble(),
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
    _saveCartToLocalAndQueueSync();
    return true;
  }

  void incrementQuantity(String id, {void Function(String message)? onError}) {
    ensureCartForActiveUser();
    final index = _items.indexWhere((item) => item.id == id || item.product.id == id);
    if (index >= 0) {
      final item = _items[index];
      if (item.isDeal && item.deal != null) {
        final maxAvailable = getAvailableDealStock(item.deal!);
        if (item.quantity >= maxAvailable) {
          onError?.call('Cannot add more. Limit is $maxAvailable for this promo.');
          return;
        }
        item.quantity++;
        notifyListeners();
        _saveCartToLocalAndQueueSync();
      } else {
        final maxAvailable = item.product.sellableQuantity.toInt();
        if (item.quantity < maxAvailable) {
          item.quantity++;
          notifyListeners();
          _saveCartToLocalAndQueueSync();
        } else {
          onError?.call('Cannot add more. Only $maxAvailable available in stock.');
        }
      }
    }
  }

  void decrementQuantity(String id) {
    ensureCartForActiveUser();
    final index = _items.indexWhere((item) => item.id == id || item.product.id == id);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
        notifyListeners();
        _saveCartToLocalAndQueueSync();
      }
    }
  }

  void removeFromCart(String id) {
    ensureCartForActiveUser();
    _items.removeWhere((item) => item.id == id || item.product.id == id);
    notifyListeners();
    _saveCartToLocalAndQueueSync();
  }

  void clearCart() {
    ensureCartForActiveUser();
    _items.clear();
    notifyListeners();
    _saveCartToLocalAndQueueSync();
  }

  Map<String, dynamic> _cartItemToJson(CartItem item) {
    return {
      'product': {
        'id': item.product.id,
        'name': item.product.name,
        'category': item.product.category,
        'price': item.product.price,
        'capital': item.product.capital,
        'sellableQuantity': item.product.sellableQuantity,
        'image': item.product.image,
        'availability': item.product.availability.name,
        'isOnSale': item.product.isOnSale,
        'isFeatured': item.product.isFeatured,
      },
      'quantity': item.quantity,
      'customPrice': item.customPrice,
      'saleDealTitle': item.saleDealTitle,
      'deal': item.deal?.toMap(),
    };
  }

  CartItem _cartItemFromJson(Map<String, dynamic> map) {
    final pMap = (map['product'] as Map<String, dynamic>?) ?? {};
    final availabilityStr = pMap['availability'] as String? ?? 'inStock';
    final availability = CustomerProductAvailability.values.firstWhere(
      (a) => a.name == availabilityStr,
      orElse: () => CustomerProductAvailability.inStock,
    );
    final product = CustomerProduct(
      id: pMap['id'] as String? ?? '',
      name: pMap['name'] as String? ?? '',
      category: pMap['category'] as String? ?? '',
      price: (pMap['price'] as num?)?.toDouble() ?? 0.0,
      capital: (pMap['capital'] as num?)?.toDouble() ?? 0.0,
      sellableQuantity: (pMap['sellableQuantity'] as num?)?.toDouble() ?? 0.0,
      image: pMap['image'] as String? ?? '',
      availability: availability,
      isOnSale: pMap['isOnSale'] as bool? ?? false,
      isFeatured: pMap['isFeatured'] as bool? ?? false,
    );

    SaleDealModel? deal;
    if (map['deal'] != null && map['deal'] is Map) {
      try {
        deal = SaleDealModel.fromMap(map['deal'] as Map<dynamic, dynamic>);
      } catch (_) {}
    }

    return CartItem(
      product: product,
      quantity: map['quantity'] as int? ?? 1,
      customPrice: (map['customPrice'] as num?)?.toDouble(),
      saleDealTitle: map['saleDealTitle'] as String?,
      deal: deal,
    );
  }

  Future<void> _loadCartFromPrefs([String? userIdOverride]) async {
    try {
      final activeUserId = userIdOverride ?? AuthService().currentUser?.uid ?? 'guest';
      _currentLoadedUserId = activeUserId;

      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('cached_customer_cart_$activeUserId');
      _items.clear();
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        for (final itemMap in decoded) {
          if (itemMap is Map<String, dynamic>) {
            _items.add(_cartItemFromJson(itemMap));
          }
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveCartToLocalAndQueueSync() async {
    final activeUserId = _currentLoadedUserId ?? AuthService().currentUser?.uid ?? 'guest';

    try {
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = _items.map((i) => _cartItemToJson(i)).toList();
      await prefs.setString('cached_customer_cart_$activeUserId', jsonEncode(itemsJson));
    } catch (_) {}

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
      userId: activeUserId,
      action: 'UPDATE_CART',
      payload: payload,
    );
  }
}

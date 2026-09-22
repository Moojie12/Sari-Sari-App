import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_models.dart';
import '../../core/services/supabase_service.dart';

/// Service for handling product operations using Supabase as the data source
class AdminProductService extends ChangeNotifier {
  AdminProductService({
    SupabaseService? supabaseService,
  }) : _supabaseService = supabaseService ?? SupabaseService() {
    initialize();
  }

  final SupabaseService _supabaseService;

  // Cached data
  List<AdminProduct> _products = [];
  List<AdminCategory> _categories = [];

  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _realtimeChannel;

  // ==================== GETTERS ====================

  List<AdminProduct> get allProducts => List.unmodifiable(_products);

  List<AdminProduct> get activeProducts =>
      _products.where((p) => !p.isArchived).toList();

  List<AdminProduct> get archivedProducts =>
      _products.where((p) => p.isArchived).toList();

  List<AdminCategory> get allCategories => List.unmodifiable(_categories);

  List<AdminCategory> get activeCategories =>
      _categories.where((c) => !c.isArchived).toList();

  List<AdminCategory> get archivedCategories =>
      _categories.where((c) => c.isArchived).toList();

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ==================== INITIALIZATION ====================

  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load products and categories in parallel
      await Future.wait([
        _loadProducts(),
        _loadCategories(),
      ]);

      _subscribeToRealtime();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeToRealtime() {
    if (_realtimeChannel != null) return;
    try {
      _realtimeChannel = _supabaseService.client
          .channel('public:admin_inventory')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'products',
            callback: (payload) {
              _loadProducts().then((_) => notifyListeners()).catchError((e) {
                debugPrint('Realtime product reload failed: $e');
              });
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'product_batches',
            callback: (payload) {
              _loadProducts().then((_) => notifyListeners()).catchError((e) {
                debugPrint('Realtime batch reload failed: $e');
              });
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'categories',
            callback: (payload) {
              _loadCategories().then((_) => notifyListeners()).catchError((e) {
                debugPrint('Realtime category reload failed: $e');
              });
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Failed to subscribe to Supabase realtime in AdminProductService: $e');
    }
  }

  Future<void> _loadProducts() async {
    try {
      final supabaseProducts = await _supabaseService.getProductsWithInventory();
      _products = supabaseProducts.map(_fromSupabaseProduct).toList();
    } catch (e) {
      _error = 'Failed to load products: $e';
      rethrow;
    }
  }

  Future<void> _loadCategories() async {
    try {
      final supabaseCategories = await _supabaseService.getActiveCategories();
      _categories = supabaseCategories.map(_fromSupabaseCategory).toList();
    } catch (e) {
      _error = 'Failed to load categories: $e';
      rethrow;
    }
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadProducts(),
        _loadCategories(),
      ]);
      _subscribeToRealtime();
      _isInitialized = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== PRODUCT OPERATIONS ====================

  AdminProduct productById(String id) {
    return _products.firstWhere((p) => p.id == id, orElse: () => throw StateError('Product with id $id not found'));
}

  Future<String?> createProduct({
    required String name,
    required String categoryId,
    required String description,
    required double price,
    required double cost,
    required double quantity,
    required String unit,
    required String barcode,
    DateTime? expirationDate,
    double lowStockThreshold = kDefaultLowStockThreshold,
  }) async {
    try {
      // Validate inputs
      if (name.trim().isEmpty) return 'Enter a product name.';
      if (categoryId.isEmpty) return 'Pick a category for this product.';

      final category = maybeCategoryById(categoryId);
      if (category == null) return 'That category no longer exists.';
      if (category.isArchived) return 'That category is archived. Restore it first or pick another.';

      if (price < 0) return 'Selling price cannot be negative.';
      if (cost < 0) return 'Cost cannot be negative.';
      if (quantity < 0) return 'Stock cannot be negative.';

      final productData = {
        'name': name.trim(),
        'category': category.name, // Link by Name to match your SQL constraint
        'description': description.trim(),
        'price': price,
        'capital': cost, // Map 'cost' to your 'capital' column
        'barcode': barcode.trim(),
        'unit': unit, // Added missing unit field
        'low_stock_threshold': lowStockThreshold,
        'is_archived': false,
      };

      // 1. Create the product record
      final productResult = await _supabaseService.addProduct(productData);
      final productId = productResult['id']?.toString() ?? '';
      
      if (productId.isEmpty) {
        return 'Failed to add product: No ID returned from database.';
      }

      // 2. Create the initial inventory batch for the stock
      if (quantity > 0) {
        try {
          await _supabaseService.addProductBatch(productId, {
            'quantity': quantity,
            'notes': 'Initial stock creation',
            'received_date': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          // Non-fatal error for the user but good to know
          debugPrint('Warning: Initial stock batch failed: $e');
        }
      }

      // 3. Record the creation in the inventory audit trail
      try {
        await _supabaseService.recordInventoryTransaction({
          'product_id': productId,
          'transaction_type': 'adjustment',
          'quantity': quantity,
          'unit_price': price,
          'total_amount': quantity * price,
          'notes': 'Initial stock from Admin Dashboard',
        });
      } catch (e) {
        debugPrint('Warning: Inventory transaction log failed: $e');
      }

      // 4. Force a full reload and notify all UI listeners
      await _loadProducts();
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to create product: $e';
    }
  }

  Future<String?> updateProduct({
    required String id,
    required String name,
    required String categoryId,
    required String description,
    required double price,
    required double cost,
    required double quantity,
    required String unit,
    required String barcode,
    DateTime? expirationDate,
    bool clearExpiration = false,
    double? lowStockThreshold,
  }) async {
    try {
      final index = _products.indexWhere((p) => p.id == id);
      if (index == -1) return 'That product no longer exists.';

      final existingProduct = _products[index];

      // Validate inputs
      if (name.trim().isEmpty) return 'Enter a product name.';
      if (categoryId.isEmpty) return 'Pick a category for this product.';

      final category = maybeCategoryById(categoryId);
      if (category == null) return 'That category no longer exists.';
      if (category.isArchived) return 'That category is archived.';

      // Prepare product update data (mapped to your schema)
      final updateData = {
        'name': name.trim(),
        'category': category.name,
        'description': description.trim(),
        'price': price,
        'capital': cost,
        'unit': unit,
        'barcode': barcode.trim(),
        'low_stock_threshold': lowStockThreshold,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // 1. Update the product table
      await _supabaseService.updateProduct(id, updateData);

      // 2. If quantity was changed manually in the form, create a correction batch
      final quantityDiff = quantity - existingProduct.quantity;
      if (quantityDiff != 0) {
        await adjustStock(id, quantityDiff, reason: 'Manual update from edit form');
      }

      // 3. Refresh and notify
      await _loadProducts();
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to update product: $e';
    }
  }

  Future<String?> archiveProduct(String id) async {
    try {
      final index = _products.indexWhere((p) => p.id == id);
      if (index == -1) return 'That product no longer exists.';

      final product = _products[index];
      if (product.isArchived) return 'That product is already archived.';

      await _supabaseService.updateProduct(id, {
        'is_archived': true,
        'archived_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      final updatedProduct = product.copyWith(
        isArchived: true,
        archivedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _products[index] = updatedProduct;
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to archive product: $e';
    }
  }

  Future<String?> restoreProduct(String id) async {
    try {
      final index = _products.indexWhere((p) => p.id == id);
      if (index == -1) return 'That product no longer exists.';

      final product = _products[index];
      if (!product.isArchived) return 'That product is already active.';

      // Check if category is still active
      final category = categoryById(product.categoryId);
      if (category.isArchived) {
        return 'Its category "${product.categoryName}" is archived.';
      }

      await _supabaseService.updateProduct(id, {
        'is_archived': false,
        'archived_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      });

      final updatedProduct = product.copyWith(
        isArchived: false,
        archivedAt: null,
        updatedAt: DateTime.now(),
      );

      _products[index] = updatedProduct;
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to restore product: $e';
    }
  }

  Future<String?> permanentlyDeleteProduct(String id) async {
    try {
      final index = _products.indexWhere((p) => p.id == id);
      if (index == -1) return 'That product no longer exists.';
      final product = _products[index];

      if (!product.isArchived) return 'Archive the product before deleting it.';

      await _supabaseService.deleteProduct(id);

      _products.removeWhere((p) => p.id == id);
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to delete product: $e';
    }
  }

  // ==================== CATEGORY OPERATIONS ====================

  AdminCategory? maybeCategoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  AdminCategory categoryById(String id) =>
    _categories.firstWhere((c) => c.id == id, orElse: () => throw StateError('Category with id $id not found'));

  Future<String?> createCategory({
    required String name,
    required String description,
  }) async {
    try {
      if (name.trim().isEmpty) return 'Enter a category name.';
      if (name.trim().length < 2) return 'Category name needs at least 2 characters.';

      // Check if category already exists
      final exists = await _supabaseService.categoryNameExists(name: name.trim());
      if (exists) return 'A category with that name already exists.';

      // Get current user ID for created_by field
      // In a real implementation, we'd get this from auth service
      final currentUserId = 'current_user_id'; // TODO: Get from auth

      final result = await _supabaseService.createCategory(
        name: name.trim(),
        description: description.trim(),
        createdByProfileId: currentUserId,
      );

      final newCategory = _fromSupabaseCategory(result);
      _categories.add(newCategory);
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to create category: $e';
    }
  }

  Future<String?> updateCategory({
    required String id,
    required String name,
    required String description,
  }) async {
    try {
      final index = _categories.indexWhere((c) => c.id == id);
      if (index == -1) return 'That category no longer exists.';

      if (name.trim().isEmpty) return 'Enter a category name.';
      if (name.trim().length < 2) return 'Category name needs at least 2 characters.';

      // Check if category name already exists (excluding current)
      final exists = await _supabaseService.categoryNameExists(
        name: name.trim(),
        excludeId: id,
      );
      if (exists) return 'A category with that name already exists.';

      // Get current user ID for updated_by field
      final currentUserId = 'current_user_id'; // TODO: Get from auth

      await _supabaseService.updateCategory(
        id: id,
        name: name.trim(),
        description: description.trim(),
        updatedByProfileId: currentUserId,
      );

      final updatedCategory = _categories[index].copyWith(
        name: name.trim(),
        description: description.trim(),
        updatedAt: DateTime.now(),
      );

      _categories[index] = updatedCategory;

      // Update categoryName in products that belong to this category
      for (var i = 0; i < _products.length; i++) {
        if (_products[i].categoryId == id) {
          _products[i] = _products[i].copyWith(categoryName: name.trim());
        }
      }

      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to update category: $e';
    }
  }

  Future<String?> archiveCategory(String id) async {
    try {
      final index = _categories.indexWhere((c) => c.id == id);
      if (index == -1) return 'That category no longer exists.';

      final category = _categories[index];
      if (category.isArchived) return 'That category is already archived.';

      // Check if any active products are in this category
      final activeProductCount = _products.where((p) =>
          !p.isArchived && p.categoryId == id).length;

      if (activeProductCount > 0) {
        return '$activeProductCount active products are still in "${category.name}".';
      }

      // Get current user ID for archived_by field
      final currentUserId = 'current_user_id'; // TODO: Get from auth

      _supabaseService.archiveCategory(
        id: id,
        archivedByProfileId: currentUserId,
      );

      final updatedCategory = category.copyWith(
        isArchived: true,
        archivedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _categories[index] = updatedCategory;
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to archive category: $e';
    }
  }

  Future<String?> restoreCategory(String id) async {
    try {
      final index = _categories.indexWhere((c) => c.id == id);
      if (index == -1) return 'That category no longer exists.';

      final category = _categories[index];
      if (!category.isArchived) return 'That category is already active.';

      // Get current user ID for restored_by field
      final currentUserId = 'current_user_id'; // TODO: Get from auth

      _supabaseService.restoreCategory(
        id: id,
        restoredByProfileId: currentUserId,
      );

      final updatedCategory = category.copyWith(
        isArchived: false,
        archivedAt: null,
        updatedAt: DateTime.now(),
      );

      _categories[index] = updatedCategory;
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to restore category: $e';
    }
  }

  Future<String?> permanentlyDeleteCategory(String id) async {
    try {
      final category = categoryById(id);

      if (!category.isArchived) return 'Archive the category before deleting it.';

      // Check if any products are assigned to this category
      final productCount = _products.where((p) => p.categoryId == id).length;
      if (productCount > 0) {
        return '$productCount products are still assigned to "${category.name}".';
      }

      // TODO: Implement category deletion in SupabaseService
// _supabaseService.deleteCategory(id);

      _categories.removeWhere((c) => c.id == id);

      // Update categoryId in products that belonged to this category
      // In a real app, we might want to set them to a default category or null
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to delete category: $e';
    }
  }

  int getActiveProductCountForCategory(String categoryId) =>
      _products.where((p) => !p.isArchived && p.categoryId == categoryId).length;

  int getProductCountForCategory(String categoryId) =>
      _products.where((p) => p.categoryId == categoryId).length;

  // ==================== DATA TRANSFORMATION ====================

  AdminProduct _fromSupabaseProduct(Map<String, dynamic> data) {
    // 1. Calculate total quantity and earliest expiry from the related batches
    double totalQuantity = 0;
    DateTime? earliestExpiry;
    
    if (data['product_batches'] != null && data['product_batches'] is List) {
      for (var batch in data['product_batches']) {
        if (batch['quantity'] != null) {
          totalQuantity += (batch['quantity'] as num).toDouble();
        }
        if (batch['expiry_date'] != null) {
          final expiry = DateTime.tryParse(batch['expiry_date'] as String);
          if (expiry != null && (earliestExpiry == null || expiry.isBefore(earliestExpiry))) {
            earliestExpiry = expiry;
          }
        }
      }
    }

    // 2. Map snake_case database fields to the AdminProduct model
    // Your SQL schema uses 'category' (text) and 'capital' (numeric)
    return AdminProduct(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? 'Unnamed Product',
      categoryId: data['category']?.toString() ?? '', 
      categoryName: data['category']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      price: (data['price'] as num? ?? 0).toDouble(),
      cost: (data['capital'] as num? ?? 0).toDouble(),
      quantity: totalQuantity,
      unit: data['unit']?.toString() ?? 'piece',
      barcode: data['barcode']?.toString() ?? '',
      expirationDate: earliestExpiry,
      lowStockThreshold: (data['low_stock_threshold'] as num?)?.toDouble() ?? kDefaultLowStockThreshold,
      image: data['image']?.toString(),
      createdAt: data['created_at'] != null ? DateTime.tryParse(data['created_at'] as String) : null,
      updatedAt: data['updated_at'] != null ? DateTime.tryParse(data['updated_at'] as String) : null,
      isArchived: data['is_archived'] as bool? ?? false,
    );
  }

  Future<String?> adjustStock(String id, double delta, {String reason = 'Manual adjustment'}) async {
    try {
      if (delta == 0) return null;

      // In your schema, stock lives in batches. 
      // We'll create a new batch for the adjustment to keep history clean.
      await _supabaseService.addProductBatch(id, {
        'quantity': delta,
        'notes': reason,
        'received_date': DateTime.now().toIso8601String(),
      });

      // Record the transaction for the audit trail
      await _supabaseService.recordInventoryAdjustment(
        productId: id,
        productBatchId: null, // General adjustment
        quantity: delta,
        unitPrice: 0, // Adjustment has no direct cost impact here
        notes: reason,
      );

      await _loadProducts();
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to adjust stock: $e';
    }
  }

  AdminCategory _fromSupabaseCategory(Map<String, dynamic> data) {
    return AdminCategory(
      id: data['id'] as String,
      name: data['name'] as String,
      description: (data['description'] as String?) ?? '',
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : null,
      updatedAt: data['updated_at'] != null
          ? DateTime.parse(data['updated_at'] as String)
          : null,
      isArchived: data['is_archived'] as bool? ?? false,
      archivedAt: data['archived_at'] != null
          ? DateTime.parse(data['archived_at'] as String)
          : null,
      archivedBy: data['archived_by'] as String?,
    );
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}
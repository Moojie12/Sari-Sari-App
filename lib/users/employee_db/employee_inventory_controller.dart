import 'package:flutter/foundation.dart';

import '../../core/expiry/expiry_checker.dart';
import 'inventory/employee_batch_model.dart';
import 'inventory/employee_dummy_products.dart';
import 'inventory/employee_product_model.dart';

/// What [EmployeeInventoryController.receiveStock] ended up doing — lets
/// the Stock Receiving screen show the right confirmation ("added to
/// B001" vs "new batch B002 created") without re-derived the same
/// same-product/same-expiry logic itself.
enum StockReceivingOutcome { newProduct, mergedIntoExistingBatch, newBatchCreated }

/// Result of a successful [EmployeeInventoryController.receiveStock] call.
@immutable
class StockReceivingResult {
  const StockReceivingResult({
    required this.outcome,
    required this.productId,
    required this.batchId,
    required this.batchQuantity,
    required this.totalStock,
  });

  final StockReceivingOutcome outcome;
  final String productId;

  /// The batch that received the stock — either the existing one it was
  /// merged into, or the newly created one.
  final String batchId;

  /// That batch's quantity *after* this receiving.
  final double batchQuantity;

  /// The product's total stock (sum of all batches) after this receiving.
  final double totalStock;
}

/// Owns the live inventory list shared across the employee experience —
/// the Home tab's alert counts, the POS tab (which deducts from a specific
/// batch on checkout), and the Inventory tab (which displays batches and
/// lets staff adjust stock manually).
class EmployeeInventoryController extends ChangeNotifier {
  EmployeeInventoryController._() {
    // Ensure initial dummy data is sorted.
    for (var i = 0; i < _products.length; i++) {
      final sortedBatches = List<ProductBatch>.from(_products[i].batches);
      sortedBatches.sort((a, b) {
        final aDate = a.expiryDate;
        final bDate = b.expiryDate;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });
      _products[i] = _products[i].copyWith(batches: sortedBatches);
    }
  }

  static final EmployeeInventoryController instance = EmployeeInventoryController._();

  factory EmployeeInventoryController() => instance;

  final List<EmployeeProduct> _products = List.of(kEmployeeDummyProducts);
  final List<String> _categories = List.of(kEmployeeProductCategories);
  final List<ArchivedStockItem> _archivedStock = [];

  List<EmployeeProduct> get products => List.unmodifiable(_products);
  List<ArchivedStockItem> get archivedStock => List.unmodifiable(_archivedStock);
  List<String> get categories => List.unmodifiable(_categories);

  List<EmployeeProduct> get lowStockProducts =>
      _products.where((p) => p.stockStatus == EmployeeStockStatus.lowStock).toList();

  List<EmployeeProduct> get outOfStockProducts =>
      _products.where((p) => p.stockStatus == EmployeeStockStatus.outOfStock).toList();

  /// Products with at least one batch inside the notification window —
  /// backs the Home tab's "Expiring Soon" stat card and list.
  List<EmployeeProduct> get expiringSoonProducts =>
      _products.where((p) => p.hasExpiringSoonBatch).toList();

  /// Products with at least one batch expiring within 5 days.
  List<EmployeeProduct> get expiringIn5DaysProducts =>
      _products.where((p) => p.batches.any((b) => b.quantity > 0 && b.expiryStatus() == ExpiryStatus.fiveDays)).toList();

  /// Products with at least one batch expiring within 2 weeks.
  List<EmployeeProduct> get expiringIn2WeeksProducts =>
      _products.where((p) => p.batches.any((b) => b.quantity > 0 && b.expiryStatus() == ExpiryStatus.twoWeeks)).toList();

  /// Products with at least one already-expired batch still holding stock.
  List<EmployeeProduct> get expiredProducts =>
      _products.where((p) => p.hasExpiredBatch).toList();

  EmployeeProduct? findByBarcode(String barcode) {
    for (final product in _products) {
      if (product.barcode == barcode) return product;
    }
    return null;
  }

  EmployeeProduct? findById(String productId) {
    for (final product in _products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  /// Simple case/whitespace-insensitive name search — backs the Stock
  /// Receiving screen's "Manual Product Search/Selection" path so staff
  /// can find a product without a working barcode.
  List<EmployeeProduct> searchProducts(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return products;
    return _products
        .where((p) =>
    p.name.toLowerCase().contains(trimmed) || p.barcode.contains(trimmed))
        .toList();
  }

  /// True if some *other* product already uses [barcode]. Blank barcodes
  /// (products with no barcode at all) are never considered a clash.
  /// Backs the "prevent accidental duplicate product records" validation
  /// rule on the Stock Receiving screen's "create new product" step.
  bool isBarcodeTaken(String barcode, {String? excludingProductId}) {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return false;
    return _products.any((p) => p.id != excludingProductId && p.barcode == trimmed);
  }

  /// Creates a brand-new product with no batches yet.
  EmployeeProduct? createProduct({
    required String name,
    required String category,
    required double price,
    required double capital,
    String unit = 'pcs',
    String barcode = '',
    String? image,
    double lowStockThreshold = 10.0,
    bool isWeightBased = false,
  }) {
    final trimmedName = name.trim();
    final trimmedBarcode = barcode.trim();
    if (trimmedName.isEmpty) return null;
    if (price < 0 || capital < 0) return null;
    if (isBarcodeTaken(trimmedBarcode)) return null;

    final product = EmployeeProduct(
      id: _nextProductId(),
      name: trimmedName,
      category: category,
      price: price,
      capital: capital,
      unit: unit,
      barcode: trimmedBarcode,
      image: image,
      batches: const [],
      lowStockThreshold: lowStockThreshold,
      isWeightBased: isWeightBased,
    );
    _products.add(product);
    notifyListeners();
    return product;
  }

  void updateProduct({
    required String productId,
    String? name,
    String? category,
    double? price,
    double? capital,
    String? unit,
    String? barcode,
    String? image,
    double? lowStockThreshold,
    bool? isWeightBased,
  }) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index < 0) return;

    _products[index] = _products[index].copyWith(
      name: name,
      category: category,
      price: price,
      capital: capital,
      unit: unit,
      barcode: barcode,
      image: image,
      lowStockThreshold: lowStockThreshold,
      isWeightBased: isWeightBased,
    );
    notifyListeners();
  }

  void archiveStock(
      String productId,
      String batchId,
      double quantity, {
        StockRemovalReason reason = StockRemovalReason.wastage,
        String? consumedBy,
      }) {
    if (quantity <= 0) return;
    final productIndex = _products.indexWhere((p) => p.id == productId);
    if (productIndex < 0) return;
    final product = _products[productIndex];

    final batchIndex = product.batches.indexWhere((b) => b.id == batchId);
    if (batchIndex < 0) return;
    final batch = product.batches[batchIndex];

    final actualQuantity = quantity > batch.quantity ? batch.quantity : quantity;

    // Deduct from batch
    final updatedBatches = List<ProductBatch>.of(product.batches);
    final newBatchQty = batch.quantity - actualQuantity;
    if (newBatchQty <= 0) {
      updatedBatches.removeAt(batchIndex);
    } else {
      updatedBatches[batchIndex] = batch.copyWith(quantity: newBatchQty);
    }

    _products[productIndex] = product.copyWith(batches: updatedBatches);

    // Consumables (personal use by owner/employee) were never sold, so
    // there's no revenue — the store simply eats the capital cost, which
    // is what should come out of profit. Wastage keeps its original
    // (sale-shaped) bookkeeping so existing wastage reports don't change.
    final isConsumable = reason == StockRemovalReason.consumable;
    final capitalCost = product.capital * actualQuantity;

    // Add to archive
    _archivedStock.add(ArchivedStockItem(
      id: 'arc_${DateTime.now().millisecondsSinceEpoch}',
      productId: product.id,
      productName: product.name,
      batchId: batchId,
      quantity: actualQuantity,
      archivedAt: DateTime.now(),
      category: product.category,
      expiryDate: batch.expiryDate,
      image: product.image,
      capital: capitalCost,
      revenue: isConsumable ? 0.0 : product.price * actualQuantity,
      profit: isConsumable ? -capitalCost : (product.price - product.capital) * actualQuantity,
      reason: reason,
      consumedBy: consumedBy,
    ));

    notifyListeners();
  }

  void archiveAllStock(
      String productId, {
        StockRemovalReason reason = StockRemovalReason.wastage,
        String? consumedBy,
      }) {
    final productIndex = _products.indexWhere((p) => p.id == productId);
    if (productIndex < 0) return;
    final product = _products[productIndex];
    if (product.batches.isEmpty) return;

    final batches = List<ProductBatch>.from(product.batches);
    for (final batch in batches) {
      if (batch.quantity > 0) {
        archiveStock(productId, batch.id, batch.quantity, reason: reason, consumedBy: consumedBy);
      }
    }
  }

  /// Records stock the owner or an employee took for their own use
  /// (Consumables) — deducts it from active stock exactly like
  /// [archiveStock], but logs it with [StockRemovalReason.consumable] so
  /// it shows up as a personal-use cost (not a sale) and is subtracted
  /// from profit in the owner's reports.
  void recordConsumable(
      String productId,
      String batchId,
      double quantity, {
        String? consumedBy,
      }) {
    archiveStock(
      productId,
      batchId,
      quantity,
      reason: StockRemovalReason.consumable,
      consumedBy: consumedBy,
    );
  }

  /// Same as [recordConsumable] but takes stock across every batch of the
  /// product (used for the "All Batches" option in the Consumables dialog).
  void recordConsumableAll(String productId, {String? consumedBy}) {
    archiveAllStock(productId, reason: StockRemovalReason.consumable, consumedBy: consumedBy);
  }

  /// Total capital cost of everything ever pulled out for personal use —
  /// what Consumables have cost the store, subtracted from profit.
  double get totalConsumablesCost => _archivedStock
      .where((a) => a.reason == StockRemovalReason.consumable)
      .fold(0.0, (sum, a) => sum + a.capital);

  void restoreArchivedStock(String archivedId) {
    final arcIndex = _archivedStock.indexWhere((a) => a.id == archivedId);
    if (arcIndex < 0) return;
    final item = _archivedStock[arcIndex];

    // Add back to product
    receiveStock(
      productId: item.productId,
      quantity: item.quantity,
      expiryDate: item.expiryDate,
    );

    _archivedStock.removeAt(arcIndex);
    notifyListeners();
  }

  void deleteArchivedStock(String archivedId) {
    _archivedStock.removeWhere((a) => a.id == archivedId);
    notifyListeners();
  }

  void deleteProduct(String productId) {
    _products.removeWhere((p) => p.id == productId);
    notifyListeners();
  }

  void addCategory(String category) {
    if (!_categories.contains(category)) {
      _categories.add(category);
      notifyListeners();
    }
  }

  void removeCategory(String category) {
    if (category != 'All') {
      _categories.remove(category);
      notifyListeners();
    }
  }

  /// Receives new stock for an *existing* product.
  StockReceivingResult? receiveStock({
    required String productId,
    required double quantity,
    DateTime? expiryDate,
    String? supplier,
    String? notes,
  }) {
    if (quantity <= 0) return null;
    final productIndex = _products.indexWhere((p) => p.id == productId);
    if (productIndex < 0) return null;
    final product = _products[productIndex];

    final wasNewProduct = product.batches.isEmpty;
    final batches = List<ProductBatch>.of(product.batches);
    final existingIndex =
    batches.indexWhere((b) => _isSameExpiryDate(b.expiryDate, expiryDate));

    final String batchId;
    final double batchQuantity;
    final StockReceivingOutcome outcome;

    if (existingIndex >= 0) {
      final existing = batches[existingIndex];
      batchQuantity = existing.quantity + quantity;
      batches[existingIndex] = existing.copyWith(
        quantity: batchQuantity,
        supplier: supplier,
        notes: notes,
      );
      batchId = existing.id;
      outcome = StockReceivingOutcome.mergedIntoExistingBatch;
    } else {
      batchId = _nextBatchId(product);
      batchQuantity = quantity;
      batches.add(ProductBatch(
        id: batchId,
        quantity: quantity,
        expiryDate: expiryDate,
        supplier: supplier,
        notes: notes,
      ));
      outcome = wasNewProduct
          ? StockReceivingOutcome.newProduct
          : StockReceivingOutcome.newBatchCreated;
    }

    // Sort batches by expiry date: nearest expiry first.
    batches.sort((a, b) {
      final aDate = a.expiryDate;
      final bDate = b.expiryDate;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });

    final updatedProduct = product.copyWith(batches: batches);
    _products[productIndex] = updatedProduct;
    notifyListeners();

    return StockReceivingResult(
      outcome: outcome,
      productId: productId,
      batchId: batchId,
      batchQuantity: batchQuantity,
      totalStock: updatedProduct.quantity,
    );
  }

  /// Receives several batches for the same product in one go.
  List<StockReceivingResult> receiveBatches({
    required String productId,
    required List<({double quantity, DateTime? expiryDate, String? notes})> batches,
    String? supplier,
  }) {
    final results = <StockReceivingResult>[];
    for (final batch in batches) {
      if (batch.quantity <= 0) continue;
      final result = receiveStock(
        productId: productId,
        quantity: batch.quantity,
        expiryDate: batch.expiryDate,
        supplier: supplier,
        notes: batch.notes,
      );
      if (result != null) results.add(result);
    }
    return results;
  }

  StockReceivingOutcome? previewOutcome(EmployeeProduct? product, DateTime? expiryDate) {
    if (product == null) return null;
    if (product.batches.isEmpty) return StockReceivingOutcome.newProduct;
    final matches = product.batches.any((b) => _isSameExpiryDate(b.expiryDate, expiryDate));
    return matches
        ? StockReceivingOutcome.mergedIntoExistingBatch
        : StockReceivingOutcome.newBatchCreated;
  }

  ProductBatch? matchingBatch(EmployeeProduct? product, DateTime? expiryDate) {
    if (product == null) return null;
    for (final batch in product.batches) {
      if (_isSameExpiryDate(batch.expiryDate, expiryDate)) return batch;
    }
    return null;
  }

  bool _isSameExpiryDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _nextProductId() {
    final existingNumbers = _products
        .map((p) => int.tryParse(p.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final next = (existingNumbers.isEmpty ? 0 : existingNumbers.reduce((a, b) => a > b ? a : b)) + 1;
    return 'p$next';
  }

  /// Deducts [quantity] from one specific batch.
  bool deductFromBatch(String productId, String batchId, double quantity) {
    final productIndex = _products.indexWhere((p) => p.id == productId);
    if (productIndex < 0) return false;
    final product = _products[productIndex];

    final batchIndex = product.batches.indexWhere((b) => b.id == batchId);
    if (batchIndex < 0) return false;
    final batch = product.batches[batchIndex];
    if (batch.quantity < quantity) return false;

    final updatedBatches = List<ProductBatch>.of(product.batches);
    final newQuantity = batch.quantity - quantity;
    if (newQuantity <= 0) {
      updatedBatches.removeAt(batchIndex);
    } else {
      updatedBatches[batchIndex] = batch.copyWith(quantity: newQuantity);
    }
    _products[productIndex] = product.copyWith(batches: updatedBatches);
    notifyListeners();
    return true;
  }

  /// Manually adjusts stock up or down.
  void adjustStock(String productId, double delta) {
    if (delta == 0) return;
    final productIndex = _products.indexWhere((p) => p.id == productId);
    if (productIndex < 0) return;
    final product = _products[productIndex];

    if (delta > 0) {
      final batches = List<ProductBatch>.of(product.batches);
      final noExpiryIndex = batches.indexWhere((b) => b.expiryDate == null);
      if (noExpiryIndex >= 0) {
        batches[noExpiryIndex] =
            batches[noExpiryIndex].copyWith(quantity: batches[noExpiryIndex].quantity + delta);
      } else {
        batches.add(ProductBatch(id: _nextBatchId(product), quantity: delta));
      }

      batches.sort((a, b) {
        final aDate = a.expiryDate;
        final bDate = b.expiryDate;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });

      _products[productIndex] = product.copyWith(batches: batches);
      notifyListeners();
      return;
    }

    var remaining = -delta;
    final batches = List<ProductBatch>.of(product.batches);
    final deductionOrder = [
      ...product.validBatches,
      ...product.batches.where((b) => b.isExpired && b.quantity > 0),
    ];
    for (final target in deductionOrder) {
      if (remaining <= 0) break;
      final index = batches.indexWhere((b) => b.id == target.id);
      if (index < 0) continue;
      final take = remaining < batches[index].quantity ? remaining : batches[index].quantity;
      final newQty = batches[index].quantity - take;

      if (newQty <= 0) {
        batches.removeAt(index);
      } else {
        batches[index] = batches[index].copyWith(quantity: newQty);
      }
      remaining -= take;
    }
    _products[productIndex] = product.copyWith(batches: batches);
    notifyListeners();
  }

  /// Records a shortage for a product by deducting it from batches following FEFO order.
  bool reportShortage(String productId, double shortageQuantity) {
    if (shortageQuantity <= 0) return false;
    final product = findById(productId);
    if (product == null || product.quantity < shortageQuantity) return false;

    // Deduct stock using adjustStock with negative delta
    adjustStock(productId, -shortageQuantity);
    return true;
  }

  String _nextBatchId(EmployeeProduct product) {
    final existingNumbers = product.batches
        .map((b) => int.tryParse(b.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final next = (existingNumbers.isEmpty ? 0 : existingNumbers.reduce((a, b) => a > b ? a : b)) + 1;
    return 'B${next.toString().padLeft(3, '0')}';
  }
}
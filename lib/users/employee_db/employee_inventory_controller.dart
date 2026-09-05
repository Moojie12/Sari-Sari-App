import 'package:flutter/foundation.dart';

import 'inventory/employee_batch_model.dart';
import 'inventory/employee_dummy_products.dart';
import 'inventory/employee_product_model.dart';

/// What [EmployeeInventoryController.receiveStock] ended up doing — lets
/// the Stock Receiving screen show the right confirmation ("added to
/// B001" vs "new batch B002 created") without re-deriving the same
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
  final int batchQuantity;

  /// The product's total stock (sum of all batches) after this receiving.
  final int totalStock;
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

  List<EmployeeProduct> get products => List.unmodifiable(_products);

  List<EmployeeProduct> get lowStockProducts =>
      _products.where((p) => p.stockStatus == EmployeeStockStatus.lowStock).toList();

  List<EmployeeProduct> get outOfStockProducts =>
      _products.where((p) => p.stockStatus == EmployeeStockStatus.outOfStock).toList();

  /// Products with at least one batch inside the notification window —
  /// backs the Home tab's "Expiring Soon" stat card and list. Same signal
  /// the POS (Path A) and Inventory/Home (Path B) screens check per batch;
  /// this is just that same logic aggregated up to product level.
  List<EmployeeProduct> get expiringSoonProducts =>
      _products.where((p) => p.hasExpiringSoonBatch).toList();

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

  /// Creates a brand-new product with no batches yet (Stock Receiving's
  /// "product does not exist" path — RULE 1's product half; the first
  /// batch is then added by a normal [receiveStock] call).
  ///
  /// Returns null instead of creating anything if [barcode] is non-blank
  /// and already belongs to another product, so callers never end up with
  /// two product records sharing one barcode.
  EmployeeProduct? createProduct({
    required String name,
    required String category,
    required double price,
    String barcode = '',
    String? image,
    int lowStockThreshold = 10,
  }) {
    final trimmedName = name.trim();
    final trimmedBarcode = barcode.trim();
    if (trimmedName.isEmpty) return null;
    if (isBarcodeTaken(trimmedBarcode)) return null;

    final product = EmployeeProduct(
      id: _nextProductId(),
      name: trimmedName,
      category: category,
      price: price,
      barcode: trimmedBarcode,
      image: image,
      batches: const [],
      lowStockThreshold: lowStockThreshold,
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
    String? barcode,
    String? image,
    int? lowStockThreshold,
  }) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index < 0) return;

    _products[index] = _products[index].copyWith(
      name: name,
      category: category,
      price: price,
      barcode: barcode,
      image: image,
      lowStockThreshold: lowStockThreshold,
    );
    notifyListeners();
  }

  /// Receives new stock for an *existing* product — the shared tail end of
  /// the Stock Receiving flow, whichever way the product was identified
  /// (barcode scan, manual search, or a product just created via
  /// [createProduct]).
  ///
  /// Implements RULE 2 / RULE 3 (and, for a just-created product with no
  /// batches yet, RULE 1's batch half) in one place:
  ///  - an existing batch with the *exact same* [expiryDate] gets the
  ///    quantity added to it (RULE 2) — this is also what guarantees no
  ///    duplicate batch is ever created for the same product + exact
  ///    expiration date;
  ///  - otherwise a brand-new batch is generated (RULE 3 / RULE 1).
  ///
  /// Returns null (and changes nothing) for invalid input: missing
  /// product, non-positive quantity.
  StockReceivingResult? receiveStock({
    required String productId,
    required int quantity,
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
    final int batchQuantity;
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
    // Batches with no expiry date sort last.
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

  /// Receives several batches for the same product in one go — the Add
  /// Product screen's "scan/enter one or more expiration dates, then hit
  /// Add Product once" flow. Each entry in [batches] is applied through
  /// the exact same [receiveStock] (RULE 1/2/3) logic, in order, so a
  /// product that ends up with three differently-expiring lots from one
  /// Add Product session is indistinguishable from three separate
  /// [receiveStock] calls.
  ///
  /// Entries with a non-positive quantity are skipped rather than
  /// aborting the whole batch (so one bad row doesn't undo the others).
  List<StockReceivingResult> receiveBatches({
    required String productId,
    required List<({int quantity, DateTime? expiryDate})> batches,
    String? supplier,
    String? notes,
  }) {
    final results = <StockReceivingResult>[];
    for (final batch in batches) {
      if (batch.quantity <= 0) continue;
      final result = receiveStock(
        productId: productId,
        quantity: batch.quantity,
        expiryDate: batch.expiryDate,
        supplier: supplier,
        notes: notes,
      );
      if (result != null) results.add(result);
    }
    return results;
  }

  /// Pure preview of what [receiveStock] *would* do for [product] and
  /// [expiryDate] — powers the Stock Receiving screen's "Existing batch
  /// found, quantity will be added to B001" / "A new batch will be
  /// created" summary before staff confirm. Returns null if there's no
  /// product selected yet.
  StockReceivingOutcome? previewOutcome(EmployeeProduct? product, DateTime? expiryDate) {
    if (product == null) return null;
    if (product.batches.isEmpty) return StockReceivingOutcome.newProduct;
    final matches = product.batches.any((b) => _isSameExpiryDate(b.expiryDate, expiryDate));
    return matches
        ? StockReceivingOutcome.mergedIntoExistingBatch
        : StockReceivingOutcome.newBatchCreated;
  }

  /// The exact batch a same-expiry receipt would land on, if any — used
  /// alongside [previewOutcome] so the summary can name the batch (e.g.
  /// "will be added to B001") before saving.
  ProductBatch? matchingBatch(EmployeeProduct? product, DateTime? expiryDate) {
    if (product == null) return null;
    for (final batch in product.batches) {
      if (_isSameExpiryDate(batch.expiryDate, expiryDate)) return batch;
    }
    return null;
  }

  /// Same-calendar-day comparison (ignoring time-of-day) so two batches
  /// received hours apart on the same expiration date are still treated
  /// as "the same expiration date". Two null dates (both "no expiry
  /// tracked") count as a match too.
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

  /// Deducts [quantity] from one specific batch — the Batch-Aware Selling
  /// flow's checkout step. The product's total `quantity` is a computed
  /// sum over its batches, so it updates automatically once the batch
  /// itself is deducted; nothing else needs to be recalculated by hand.
  ///
  /// Returns false if the product/batch doesn't exist, or the batch no
  /// longer has enough left (e.g. deducted elsewhere in the meantime).
  bool deductFromBatch(String productId, String batchId, int quantity) {
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

  /// Manually adjusts stock up or down — the Inventory tab's "Add stock" /
  /// "Remove stock" feature. Since stock now lives on batches:
  ///  - adding (`delta > 0`) tops up an existing no-expiry batch, or opens
  ///    a new one if the product doesn't have one yet;
  ///  - removing (`delta < 0`) follows the same FEFO order a sale would —
  ///    nearest-expiry valid batches first, then already-expired ones —
  ///    so no batch is ever left with a negative quantity.
  void adjustStock(String productId, int delta) {
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

      // Ensure batches stay sorted after adding stock.
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
    // FEFO order: nearest expiry first, then expired ones.
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

  String _nextBatchId(EmployeeProduct product) {
    final existingNumbers = product.batches
        .map((b) => int.tryParse(b.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final next = (existingNumbers.isEmpty ? 0 : existingNumbers.reduce((a, b) => a > b ? a : b)) + 1;
    return 'B${next.toString().padLeft(3, '0')}';
  }
}
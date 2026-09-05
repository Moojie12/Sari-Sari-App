import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/barcode_scanner_screen.dart';
import '../employee_inventory_controller.dart';
import 'employee_dummy_products.dart';
import 'employee_product_model.dart';

/// Add Product screen (replaces the old "Receive Stock" screen).
///
/// Three ways to identify what's being added, all funneling into the same
/// "fill up the details" step below:
///  1. **Barcode scanner** — scan the product barcode, its details appear.
///  2. **Search** (next to the scanner button) — find an existing product
///     by name/barcode and tap it to restock it.
///  3. **Add Product Manually** — for when the barcode can't be scanned;
///     collects the same product info a scan would have found.
///
/// Once a product is identified (scanned, searched, or just created), the
/// same "Product Details" step is shown every time: quantity + expiration
/// date, where expiration date can also be scanned or entered manually.
/// Scanning/entering more than one *different* expiration date for the
/// same product automatically builds separate batches — quantity per
/// batch stays editable, so staff don't have to scan one unit at a time.
/// Pressing "Add Product" saves every batch at once, whether the product
/// is brand new or already exists in inventory.
///
/// All the actual RULE 1/2/3 batch logic lives in
/// [EmployeeInventoryController.receiveBatches] / [createProduct] — this
/// screen only collects input, previews the outcome, and displays the
/// result.
class EmployeeAddProductPage extends StatefulWidget {
  const EmployeeAddProductPage({super.key, required this.inventory});

  final EmployeeInventoryController inventory;

  @override
  State<EmployeeAddProductPage> createState() => _EmployeeAddProductPageState();
}

/// One batch waiting to be saved — a distinct expiration date (or "no
/// expiry") plus a quantity the staff member can hand-edit instead of
/// scanning every single unit.
class _PendingBatch {
  _PendingBatch({required this.expiryDate, int quantity = 1})
      : quantityController = TextEditingController(text: quantity.toString());

  /// Null means "no expiry / not tracked" — same convention as [ProductBatch].
  final DateTime? expiryDate;
  final TextEditingController quantityController;
  String? quantityError;

  int? get quantity => int.tryParse(quantityController.text.trim());

  void dispose() => quantityController.dispose();
}

bool _isSameCalendarDay(DateTime? a, DateTime? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

class _EmployeeAddProductPageState extends State<EmployeeAddProductPage> {
  final _searchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedProductId;
  final List<_PendingBatch> _pendingBatches = [];
  String? _batchesError;

  /// Last barcode that didn't match any product — kept so the "not found"
  /// message and the "add manually with this barcode" shortcut stay in sync.
  String? _unmatchedBarcode;

  @override
  void dispose() {
    _searchController.dispose();
    for (final batch in _pendingBatches) {
      batch.dispose();
    }
    super.dispose();
  }

  List<EmployeeProduct> get _matches {
    if (_searchQuery.trim().isEmpty) return const [];
    return widget.inventory.searchProducts(_searchQuery);
  }

  void _selectProduct(EmployeeProduct product) {
    setState(() {
      _selectedProductId = product.id;
      _searchController.clear();
      _searchQuery = '';
      _unmatchedBarcode = null;
    });
  }

  void _clearSelection() {
    for (final batch in _pendingBatches) {
      batch.dispose();
    }
    setState(() {
      _selectedProductId = null;
      _pendingBatches.clear();
      _batchesError = null;
      _unmatchedBarcode = null;
    });
  }

  // ---- Identifying the product: scan / search / manual --------------------

  /// This build is frontend-only, so there's no camera/scanner package
  /// wired in yet — staff type or paste the scanned code here instead of
  /// pointing a camera at it. Looks the code up the same way a real scan
  /// would (exact barcode match).
  Future<void> _openBarcodeScanDialog() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );
    if (code == null || code.isEmpty) return;
    _handleBarcode(code);
  }

  /// Handles a barcode however it arrived (scan dialog or typed straight
  /// into the search field). A no-match just surfaces the manual/add-new
  /// path instead of dead-ending.
  void _handleBarcode(String barcode) {
    final product = widget.inventory.findByBarcode(barcode);
    if (product != null) {
      _selectProduct(product);
    } else {
      setState(() {
        _unmatchedBarcode = barcode;
        _searchController.text = barcode;
        _searchQuery = barcode;
      });
    }
  }

  Future<void> _openAddProductManuallySheet({String prefillBarcode = ''}) async {
    final created = await showModalBottomSheet<EmployeeProduct>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ManualProductInfoSheet(
        inventory: widget.inventory,
        prefillName: _unmatchedBarcode == null ? _searchQuery.trim() : '',
        prefillBarcode: prefillBarcode,
        onExpiryScan: _showExpiryScanAndReturnDate,
      ),
    );
    if (created != null) {
      // If the product was successfully created and the first batch added in the sheet,
      // we show the success dialog for that one batch.
      final lastBatch = created.batches.last;
      _showSuccessDialog(created.name, [
        StockReceivingResult(
          outcome: StockReceivingOutcome.newProduct,
          productId: created.id,
          batchId: lastBatch.id,
          batchQuantity: lastBatch.quantity,
          totalStock: created.quantity,
        )
      ]);
    }
  }

  Future<DateTime?> _showExpiryScanAndReturnDate() async {
    final input = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );
    if (input == null || input.isEmpty) return null;
    final date = DateTime.tryParse(input);
    if (date == null) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Could not read that expiration date. Try again, or enter it manually.'),
          behavior: SnackBarBehavior.floating,
        ));
      return null;
    }
    return DateTime(date.year, date.month, date.day);
  }

  // ---- Batch builder: quantity + one or more expiration dates ------------

  /// Adds a batch for [expiryDate], or — if a pending batch for that exact
  /// calendar date already exists — bumps its quantity by one instead of
  /// creating a duplicate row. This is what lets "how many times you
  /// scan" simply track "how many different expiration dates" there are.
  void _addOrBumpBatch(DateTime? expiryDate) {
    setState(() {
      final index = _pendingBatches.indexWhere((b) => _isSameCalendarDay(b.expiryDate, expiryDate));
      if (index >= 0) {
        final current = _pendingBatches[index].quantity ?? 0;
        _pendingBatches[index].quantityController.text = (current + 1).toString();
        _pendingBatches[index].quantityError = null;
      } else {
        _pendingBatches.add(_PendingBatch(expiryDate: expiryDate));
      }
      _batchesError = null;
    });
  }

  /// Frontend-only stand-in for scanning the expiration date printed on
  /// the product — staff type/paste what a real scan would have read.
  Future<void> _openExpiryScanDialog() async {
    final input = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );
    if (input == null || input.isEmpty) return;
    final date = DateTime.tryParse(input);
    if (date == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Could not read that expiration date. Try again, or enter it manually.'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }
    _addOrBumpBatch(DateTime(date.year, date.month, date.day));
  }

  Future<void> _pickExpiryManually() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 15),
    );
    if (picked != null) _addOrBumpBatch(picked);
  }

  void _addNoExpiryBatch() => _addOrBumpBatch(null);

  void _removeBatch(int index) {
    setState(() {
      _pendingBatches[index].dispose();
      _pendingBatches.removeAt(index);
    });
  }

  bool _validateBatches() {
    if (_pendingBatches.isEmpty) {
      setState(() => _batchesError =
      'Scan or enter at least one expiration date (or mark "No expiry") before adding this product.');
      return false;
    }
    var allValid = true;
    setState(() {
      for (final batch in _pendingBatches) {
        final quantity = batch.quantity;
        batch.quantityError = (quantity == null || quantity <= 0) ? 'Enter a quantity greater than 0.' : null;
        if (batch.quantityError != null) allValid = false;
      }
    });
    return allValid;
  }

  void _submit(EmployeeProduct product) {
    if (!_validateBatches()) return;

    final results = widget.inventory.receiveBatches(
      productId: product.id,
      batches: [
        for (final batch in _pendingBatches) (quantity: batch.quantity!, expiryDate: batch.expiryDate),
      ],
    );

    if (results.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Could not add this product — please check the quantities and try again.'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }

    _showSuccessDialog(product.name, results);
  }

  Future<void> _showSuccessDialog(String productName, List<StockReceivingResult> results) async {
    final totalAdded = results.fold<int>(0, (sum, r) => sum + r.batchQuantity);
    final finalTotalStock = results.last.totalStock;

    if (!mounted) return;
    final addAnother = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Product Added'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final result in results)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(switch (result.outcome) {
                    StockReceivingOutcome.newProduct =>
                    'Batch ${result.batchId} started with ${result.batchQuantity} pcs.',
                    StockReceivingOutcome.mergedIntoExistingBatch =>
                    'Added to Batch ${result.batchId}, now ${result.batchQuantity} pcs.',
                    StockReceivingOutcome.newBatchCreated =>
                    'New Batch ${result.batchId} created with ${result.batchQuantity} pcs.',
                  }),
                ),
              const SizedBox(height: 8),
              Text('Added $totalAdded pcs total. $productName now has $finalTotalStock pcs in stock.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Done'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Another Product'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (addAnother == true) {
      _clearSelection();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        foregroundColor: AppColors.darkText,
        title: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.inventory,
          builder: (context, _) {
            // Re-resolve from the live list every rebuild, so if this
            // product's stock changes elsewhere while the screen is open
            // (or, on first frame, right after we just created/selected
            // it) the screen always reflects current data.
            final selected = _selectedProductId == null
                ? null
                : widget.inventory.findById(_selectedProductId!);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: selected == null
                    ? [_buildIdentifySection()]
                    : [
                  _buildSelectedProductCard(selected),
                  const SizedBox(height: 20),
                  _buildBatchBuilderSection(selected),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---- Step 1: identify the product -------------------------------------

  Widget _buildIdentifySection() {
    final matches = _matches;
    final showNotFound = _unmatchedBarcode != null && matches.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add Product',
          style: TextStyle(color: AppColors.darkText, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Scan a barcode, search for an existing product to restock, or '
              "add a new one manually if it doesn't exist yet.",
          style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.8), fontSize: 12),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() {
                  _searchQuery = value;
                  _unmatchedBarcode = null;
                }),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search existing products by name or barcode...',
                  hintStyle:
                  TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.5), fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText),
                  filled: true,
                  fillColor: Colors.white,
                  border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderColor.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: AppColors.primaryOrange,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _openBarcodeScanDialog,
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.qr_code_scanner, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (showNotFound) _buildBarcodeNotFoundBanner(),
        if (_searchQuery.trim().isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Start typing, or tap the scanner icon, to find a product to restock.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.7), fontSize: 12),
              ),
            ),
          )
        else if (matches.isNotEmpty)
          ...matches.map((product) => _ProductResultTile(
            product: product,
            onTap: () => _selectProduct(product),
          )),
        if (!showNotFound && matches.isEmpty && _searchQuery.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No matching products.',
              style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.7), fontSize: 12),
            ),
          ),
        const SizedBox(height: 20),
        const Divider(color: AppColors.borderColor),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openAddProductManuallySheet(prefillBarcode: _unmatchedBarcode ?? ''),
            icon: const Icon(Icons.add),
            label: const Text('Add Product Manually'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryOrange,
              side: const BorderSide(color: AppColors.primaryOrange),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarcodeNotFoundBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.deepOrange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No product found for barcode "$_unmatchedBarcode". '
                  'You can add it manually with this barcode below, or '
                  'search by name instead.',
              style: const TextStyle(fontSize: 12, color: Colors.deepOrange, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Step 2: selected/created product + batch details -----------------

  Widget _buildSelectedProductCard(EmployeeProduct product) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: product.image != null
                    ? const Icon(Icons.image, color: AppColors.primaryOrange, size: 24)
                    : const Icon(Icons.image_outlined, color: AppColors.placeholderColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: const TextStyle(
                            color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      product.barcode.isEmpty ? 'No barcode' : 'Barcode: ${product.barcode}',
                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _clearSelection,
                child: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Current Total Stock', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
              Text('${product.quantity} pcs',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
            ],
          ),
          if (product.batches.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.borderColor),
            const SizedBox(height: 8),
            const Text('Existing Batches',
                style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            ...product.batches.map((batch) {
              final dateLabel = batch.expiryDate == null ? 'No expiry' : _formatDate(batch.expiryDate!);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Batch ${batch.id} — $dateLabel — ${batch.quantity} pcs',
                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// The batch-builder step, shared by every identification path (barcode
  /// match, search-select, or a product just created manually). Staff
  /// scan/enter as many *different* expiration dates as the delivery has
  /// — each one becomes its own editable batch row — then press "Add
  /// Product" once to save all of them.
  Widget _buildBatchBuilderSection(EmployeeProduct product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Details',
          style: TextStyle(color: AppColors.darkText, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Scan the expiration date, or enter it manually. Adding a '
              "different date starts a new batch automatically — you don't "
              'have to scan every single unit, just edit the quantity.',
          style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.8), fontSize: 12),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openExpiryScanDialog,
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('Scan Expiration'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryOrange,
                  side: const BorderSide(color: AppColors.primaryOrange),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickExpiryManually,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Enter Manually'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkText,
                  side: const BorderSide(color: AppColors.borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addNoExpiryBatch,
            icon: const Icon(Icons.block, size: 16),
            label: const Text("This item doesn't expire"),
            style: TextButton.styleFrom(foregroundColor: AppColors.secondaryText),
          ),
        ),
        const SizedBox(height: 8),
        if (_pendingBatches.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightBackground,
              borderRadius: BorderRadius.circular(12),
              border: _batchesError != null ? Border.all(color: Colors.red) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No batches yet — scan or enter an expiration date above.',
                  style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.8), fontSize: 12),
                ),
                if (_batchesError != null) ...[
                  const SizedBox(height: 6),
                  Text(_batchesError!, style: const TextStyle(color: Colors.red, fontSize: 11)),
                ],
              ],
            ),
          )
        else
          ...List.generate(_pendingBatches.length, (index) => _buildPendingBatchRow(product, index)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _submit(product),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  /// One editable batch row inside the builder, with a live "what will
  /// happen" preview from [EmployeeInventoryController.previewOutcome] /
  /// [matchingBatch] — the exact same RULE 1/2/3 decision
  /// [EmployeeInventoryController.receiveBatches] will make on save.
  Widget _buildPendingBatchRow(EmployeeProduct product, int index) {
    final batch = _pendingBatches[index];
    final dateLabel = batch.expiryDate == null ? 'No expiry' : _formatDate(batch.expiryDate!);

    final outcome = widget.inventory.previewOutcome(product, batch.expiryDate);
    final matching = widget.inventory.matchingBatch(product, batch.expiryDate);
    final String previewMessage = switch (outcome) {
      StockReceivingOutcome.mergedIntoExistingBatch => 'Will be added to existing Batch ${matching?.id}.',
      StockReceivingOutcome.newBatchCreated => 'New batch will be created.',
      StockReceivingOutcome.newProduct || null => 'First stock for this product — a new batch will be created.',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: AppColors.secondaryText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(dateLabel,
                    style:
                    const TextStyle(color: AppColors.darkText, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: batch.quantityController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (_) {
                    if (batch.quantityError != null) setState(() => batch.quantityError = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'Qty',
                    errorText: batch.quantityError,
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.lightPeach,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _removeBatch(index),
                icon: const Icon(Icons.close, size: 18, color: AppColors.secondaryText),
                tooltip: 'Remove batch',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 12, color: AppColors.primaryOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(previewMessage,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.primaryOrange, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500));
  }
}

class _ProductResultTile extends StatelessWidget {
  const _ProductResultTile({required this.product, required this.onTap});
  final EmployeeProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: product.image != null
                      ? const Icon(Icons.image, color: AppColors.primaryOrange, size: 20)
                      : const Icon(Icons.inventory_2_outlined, color: AppColors.placeholderColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name,
                          style: const TextStyle(
                              color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        '${product.barcode.isEmpty ? 'No barcode' : product.barcode} · '
                            'Current stock: ${product.quantity} pcs',
                        style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.placeholderColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for entering a brand-new product's basic info (Add
/// Product's "product does not exist" path). Only collects what
/// [EmployeeInventoryController.createProduct] needs; the "Product
/// Details" batch step (quantity + expiration dates) is then filled on
/// the main Add Product screen right after this closes — the exact same
/// step a barcode scan or search match would have landed on.
class _ManualProductInfoSheet extends StatefulWidget {
  const _ManualProductInfoSheet({
    required this.inventory,
    this.prefillName = '',
    this.prefillBarcode = '',
    this.onExpiryScan,
  });

  final EmployeeInventoryController inventory;
  final String prefillName;
  final String prefillBarcode;
  final Future<DateTime?> Function()? onExpiryScan;

  @override
  State<_ManualProductInfoSheet> createState() => _ManualProductInfoSheetState();
}

class _ManualProductInfoSheetState extends State<_ManualProductInfoSheet> {
  late final _nameController = TextEditingController(text: widget.prefillName);
  late final _barcodeController = TextEditingController(text: widget.prefillBarcode);
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  DateTime? _expiryDate;
  String? _imagePath;
  late String _category =
  kEmployeeProductCategories.where((c) => c != 'All').isNotEmpty
      ? kEmployeeProductCategories.firstWhere((c) => c != 'All')
      : 'Snacks';

  String? _nameError;
  String? _priceError;
  String? _barcodeError;
  String? _quantityError;

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryManually() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 15),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _scanExpiry() async {
    if (widget.onExpiryScan != null) {
      final date = await widget.onExpiryScan!();
      if (date != null) setState(() => _expiryDate = date);
    }
  }

  void _continue() {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final barcode = _barcodeController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim());

    setState(() {
      _nameError = name.isEmpty ? 'Product name is required.' : null;
      _priceError = (price == null || price < 0) ? 'Enter a valid price.' : null;
      _barcodeError = widget.inventory.isBarcodeTaken(barcode)
          ? 'This barcode is already used by another product.'
          : null;
      _quantityError = (quantity == null || quantity <= 0) ? 'Enter a quantity greater than 0.' : null;
    });
    if (_nameError != null || _priceError != null || _barcodeError != null || _quantityError != null) return;

    final product = widget.inventory.createProduct(
      name: name,
      category: _category,
      price: price!,
      barcode: barcode,
      image: _imagePath,
    );

    if (product == null) {
      setState(() => _barcodeError = 'This barcode is already used by another product.');
      return;
    }

    // Immediately receive the first batch
    widget.inventory.receiveStock(
      productId: product.id,
      quantity: quantity!,
      expiryDate: _expiryDate,
    );

    Navigator.pop(context, product);
  }

  Future<void> _pickImage() async {
    // Mock image picking
    setState(() {
      _imagePath = 'assets/products/placeholder.png';
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = kEmployeeProductCategories.where((c) => c != 'All').toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Product Manually',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText)),
              const SizedBox(height: 4),
              Text(
                "Enter the product's info — you'll add quantity and "
                    'expiration date(s) on the next step.',
                style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.8), fontSize: 12),
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.lightPeach,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: _imagePath == null
                        ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, color: AppColors.primaryOrange),
                        SizedBox(height: 4),
                        Text('Add Photo', style: TextStyle(color: AppColors.primaryOrange, fontSize: 10)),
                      ],
                    )
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: const Icon(Icons.image, size: 50, color: AppColors.primaryOrange),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Product Name *',
                  style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: _fieldDecoration('e.g. Bear Brand Milk 300ml', errorText: _nameError),
              ),
              const SizedBox(height: 14),
              const Text('Category',
                  style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _category,
                items: categories
                    .map((category) => DropdownMenuItem(value: category, child: Text(category)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
                decoration: _fieldDecoration(null),
              ),
              const SizedBox(height: 14),
              const Text('Price *',
                  style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _fieldDecoration('e.g. 45.00', prefixText: '₱ ', errorText: _priceError),
              ),
              const SizedBox(height: 14),
              const Text('Barcode (optional)',
                  style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: _barcodeController,
                decoration: _fieldDecoration('Leave blank if this product has no barcode',
                    errorText: _barcodeError),
              ),
              const SizedBox(height: 14),
              const Text('Quantity *',
                  style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: _fieldDecoration('e.g. 10', errorText: _quantityError),
              ),
              const SizedBox(height: 14),
              const Text('Expiration Date',
                  style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickExpiryManually,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.lightPeach,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _expiryDate == null ? 'No expiration date' : _formatDate(_expiryDate!),
                          style: TextStyle(
                            color: _expiryDate == null ? AppColors.secondaryText.withValues(alpha: 0.5) : AppColors.darkText,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _scanExpiry,
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.qr_code_scanner, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String? hint, {String? prefixText, String? errorText}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      errorText: errorText,
      filled: true,
      fillColor: AppColors.lightPeach,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    );
  }
}
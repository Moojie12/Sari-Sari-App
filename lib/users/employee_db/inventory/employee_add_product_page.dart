import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../../../shared/widgets/barcode_scanner_screen.dart';
import '../employee_inventory_controller.dart';
import 'employee_product_model.dart';

/// Add Product screen (replaces the old "Receive Stock" screen).
class EmployeeAddProductPage extends StatefulWidget {
  const EmployeeAddProductPage({super.key, required this.inventory});

  final EmployeeInventoryController inventory;

  @override
  State<EmployeeAddProductPage> createState() => _EmployeeAddProductPageState();
}

/// One batch waiting to be saved.
class _PendingBatch {
  _PendingBatch({required this.expiryDate, double quantity = 1.0})
      : quantityController = TextEditingController(text: quantity.toString()),
        bulkPriceController = TextEditingController(),
        pcsPerBulkController = TextEditingController(),
        numberOfBulkController = TextEditingController();

  final DateTime? expiryDate;
  final TextEditingController quantityController;
  String? quantityError;
  bool isReadingFromScale = false;

  // Bulk Entry Calculator
  bool isBulkMode = false;
  final TextEditingController bulkPriceController;
  final TextEditingController pcsPerBulkController;
  final TextEditingController numberOfBulkController;
  String? bulkPriceError;
  String? pcsPerBulkError;
  String? numberOfBulkError;

  double? get quantity => double.tryParse(quantityController.text.trim());

  void dispose() {
    quantityController.dispose();
    bulkPriceController.dispose();
    pcsPerBulkController.dispose();
    numberOfBulkController.dispose();
  }

  void recalcBulk() {
    final bulkPrice = double.tryParse(bulkPriceController.text.trim());
    final pcsPerBulk = int.tryParse(pcsPerBulkController.text.trim());
    final numberOfBulk = int.tryParse(numberOfBulkController.text.trim());

    if (pcsPerBulk != null && pcsPerBulk > 0 && numberOfBulk != null && numberOfBulk >= 0) {
      final totalQuantity = (pcsPerBulk * numberOfBulk).toDouble();
      quantityController.text = totalQuantity.toString();
    } else {
      quantityController.text = '';
    }
  }
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

  String? _unmatchedBarcode;

  @override
  void dispose() {
    _searchController.dispose();
    for (final batch in _pendingBatches) {
      batch.dispose();
    }
    super.dispose();
  }

  /// Simulation for reading from ESP32 Scale for restocking.
  Future<void> _captureWeightFromScaleForBatch(int index) async {
    setState(() => _pendingBatches[index].isReadingFromScale = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    
    final simulatedWeight = 1.0 + (DateTime.now().millisecond % 500) / 100.0;
    
    setState(() {
      _pendingBatches[index].quantityController.text = simulatedWeight.toStringAsFixed(2);
      _pendingBatches[index].isReadingFromScale = false;
      _pendingBatches[index].quantityError = null;
    });

    if (mounted) {
      TopNotification.show(context, 'Weight captured from scale: ${simulatedWeight.toStringAsFixed(2)} kg');
    }
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

  Future<void> _openBarcodeScanDialog() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );
    if (code == null || code.isEmpty) return;
    _handleBarcode(code);
  }

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
      MaterialPageRoute(builder: (context) => const ExpiryDateScannerScreen()),
    );
    if (input == null || input.isEmpty) return null;
    final date = DateTime.tryParse(input);
    if (date == null) {
      if (!mounted) return null;
      TopNotification.show(context, 'Could not read that expiration date. Try again, or enter it manually.', isError: true);
      return null;
    }
    return DateTime(date.year, date.month, date.day);
  }

  void _addOrBumpBatch(DateTime? expiryDate) {
    setState(() {
      final index = _pendingBatches.indexWhere((b) => _isSameCalendarDay(b.expiryDate, expiryDate));
      if (index >= 0) {
        final current = _pendingBatches[index].quantity ?? 0.0;
        _pendingBatches[index].quantityController.text = (current + 1.0).toString();
        _pendingBatches[index].quantityError = null;
      } else {
        _pendingBatches.add(_PendingBatch(expiryDate: expiryDate));
      }
      _batchesError = null;
    });
  }

  Future<void> _openExpiryScanDialog() async {
    final input = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const ExpiryDateScannerScreen()),
    );
    if (input == null || input.isEmpty) return;
    final date = DateTime.tryParse(input);
    if (date == null) {
      if (!mounted) return;
      TopNotification.show(context, 'Could not read that expiration date. Try again, or enter it manually.', isError: true);
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

  void _removeBatch(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Batch', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to remove this batch entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _pendingBatches[index].dispose();
        _pendingBatches.removeAt(index);
      });
      if (mounted) {
        TopNotification.show(context, 'Batch entry removed');
      }
    }
  }

  bool _validateBatches(EmployeeProduct product) {
    if (_pendingBatches.isEmpty) {
      setState(() => _batchesError =
      'Scan or enter at least one expiration date (or mark "No expiry") before adding this product.');
      return false;
    }
    var allValid = true;
    setState(() {
      for (final batch in _pendingBatches) {
        if (batch.isBulkMode && !product.isWeightBased) {
          final bulkPrice = double.tryParse(batch.bulkPriceController.text.trim());
          final pcsPerBulk = int.tryParse(batch.pcsPerBulkController.text.trim());
          final numberOfBulk = int.tryParse(batch.numberOfBulkController.text.trim());

          batch.bulkPriceError = (bulkPrice == null || bulkPrice <= 0) ? 'Bulk Price > 0.' : null;
          batch.pcsPerBulkError = (pcsPerBulk == null || pcsPerBulk <= 0) ? 'Pcs/Bulk > 0.' : null;
          batch.numberOfBulkError = (numberOfBulk == null || numberOfBulk <= 0) ? 'Qty > 0.' : null;

          if (batch.bulkPriceError != null || batch.pcsPerBulkError != null || batch.numberOfBulkError != null) {
            allValid = false;
          }
        }

        final quantity = batch.quantity;
        if (quantity == null || quantity <= 0) {
          batch.quantityError = 'Enter a quantity greater than 0.';
          allValid = false;
        } else if (!product.isWeightBased && quantity != quantity.roundToDouble()) {
          batch.quantityError = 'Regular products must use whole numbers.';
          allValid = false;
        } else {
          batch.quantityError = null;
        }
      }
    });
    return allValid;
  }

  void _submit(EmployeeProduct product) async {
    if (!_validateBatches(product)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Action', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to add these batches to "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add Product', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final results = widget.inventory.receiveBatches(
      productId: product.id,
      batches: [
        for (final batch in _pendingBatches)
          (
            quantity: batch.quantity!,
            expiryDate: batch.expiryDate,
            notes: (batch.isBulkMode && !product.isWeightBased)
                ? 'Bulk entry: ₱${batch.bulkPriceController.text.trim()} ÷ ${batch.pcsPerBulkController.text.trim()} pcs/bulk × '
                '${batch.numberOfBulkController.text.trim()} bulk(s) → Capital/pc ₱${((double.tryParse(batch.bulkPriceController.text) ?? 0) / (int.tryParse(batch.pcsPerBulkController.text) ?? 1)).toStringAsFixed(2)}'
                : null,
          ),
      ],
    );

    if (results.isEmpty) {
      TopNotification.show(context, 'Could not add this product — please check the quantities and try again.', isError: true);
      return;
    }

    _showSuccessDialog(product.name, results);
  }

  Future<void> _showSuccessDialog(String productName, List<StockReceivingResult> results) async {
    TopNotification.show(context, 'Product "$productName" added to inventory.');
    final totalAdded = results.fold<double>(0.0, (sum, r) => sum + r.batchQuantity);
    final finalTotalStock = results.last.totalStock;
    final selected = _selectedProductId == null ? null : widget.inventory.findById(_selectedProductId!);
    final unitStr = (selected?.isWeightBased ?? false) ? 'kg' : 'pcs';

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
                    'Batch ${result.batchId} started with ${result.batchQuantity.toStringAsFixed(2)} $unitStr.',
                    StockReceivingOutcome.mergedIntoExistingBatch =>
                    'Added to Batch ${result.batchId}, now ${result.batchQuantity.toStringAsFixed(2)} $unitStr.',
                    StockReceivingOutcome.newBatchCreated =>
                    'New Batch ${result.batchId} created with ${result.batchQuantity.toStringAsFixed(2)} $unitStr.',
                  }),
                ),
              const SizedBox(height: 8),
              Text('Added ${totalAdded.toStringAsFixed(2)} $unitStr total. $productName now has ${finalTotalStock.toStringAsFixed(2)} $unitStr in stock.'),
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
          'Scan a barcode, search for an existing product to restock, or add a new one manually.',
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
                  hintStyle: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.5), fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
              'No product found for barcode "$_unmatchedBarcode".',
              style: const TextStyle(fontSize: 12, color: Colors.deepOrange, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedProductCard(EmployeeProduct product) {
    final unitStr = product.isWeightBased ? 'kg' : 'pcs';
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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: product.image != null
                    ? const Icon(Icons.image, color: AppColors.primaryOrange, size: 28)
                    : const Icon(Icons.image_outlined, color: AppColors.placeholderColor, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: const TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(product.barcode.isEmpty ? 'No barcode' : 'Barcode: ${product.barcode}',
                        style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _clearSelection,
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderColor),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.category_outlined, size: 14, color: AppColors.secondaryText),
                    const SizedBox(width: 4),
                    Text(product.category,
                        style: const TextStyle(color: AppColors.secondaryText, fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(product.isWeightBased ? Icons.scale_outlined : Icons.inventory_2_outlined,
                        size: 14, color: AppColors.secondaryText),
                    const SizedBox(width: 4),
                    Text(product.isWeightBased ? 'De-Kilo' : 'Quantity',
                        style: const TextStyle(color: AppColors.secondaryText, fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Capital',
                      style: TextStyle(color: AppColors.secondaryText, fontSize: 10, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('₱${product.capital.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppColors.darkText, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selling Price',
                      style: TextStyle(color: AppColors.secondaryText, fontSize: 10, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('₱${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppColors.darkText, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Stock Alert',
                      style: TextStyle(color: AppColors.secondaryText, fontSize: 10, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('${product.lowStockThreshold.toStringAsFixed(0)} $unitStr',
                      style: const TextStyle(color: AppColors.darkText, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Current Total Stock',
                    style: TextStyle(color: AppColors.primaryOrange, fontSize: 12, fontWeight: FontWeight.bold)),
                Text('${product.quantity.toStringAsFixed(2)} $unitStr',
                    style: const TextStyle(color: AppColors.primaryOrange, fontSize: 14, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          if (product.batches.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Existing Batches',
                style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ...product.batches.take(3).map((batch) {
              final dateLabel = batch.expiryDate == null ? 'No expiry' : _formatDate(batch.expiryDate!);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Batch ${batch.id} ($dateLabel)',
                        style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                    Text('${batch.quantity.toStringAsFixed(2)} $unitStr',
                        style: const TextStyle(color: AppColors.darkText, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
            if (product.batches.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('+ ${product.batches.length - 3} more batches',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 11, fontStyle: FontStyle.italic)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildBatchBuilderSection(EmployeeProduct product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Product Details', style: TextStyle(color: AppColors.darkText, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          product.isWeightBased
              ? 'Enter quantity in kg for de-kilo product.'
              : 'Enter quantity in pcs for regular product.',
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
                Text('No batches yet — scan or enter an expiration date above.', style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.8), fontSize: 12)),
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
                child: Text(dateLabel, style: const TextStyle(color: AppColors.darkText, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                onPressed: () => _removeBatch(index),
                icon: const Icon(Icons.close, size: 18, color: AppColors.secondaryText),
                tooltip: 'Remove batch',
              ),
            ],
          ),
          if (product.isWeightBased) ...[
            const SizedBox(height: 8),
          ],
          if (!product.isWeightBased) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SwitchListTile(
                title: const Text('Received as Bulk?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: const Text(
                  'Turn on to compute Capital per Pc and Total Pcs from a bulk purchase.',
                  style: TextStyle(fontSize: 11),
                ),
                value: batch.isBulkMode,
                onChanged: (val) {
                  setState(() {
                    batch.isBulkMode = val;
                    if (val) batch.recalcBulk();
                  });
                },
                activeThumbColor: AppColors.primaryOrange,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (batch.isBulkMode && !product.isWeightBased) ...[
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: batch.bulkPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() => batch.recalcBulk()),
                      decoration: InputDecoration(
                        labelText: 'Bulk Price',
                        errorText: batch.bulkPriceError,
                        isDense: true,
                        prefixText: '₱',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: batch.pcsPerBulkController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() => batch.recalcBulk()),
                      decoration: InputDecoration(
                        labelText: 'Pcs/Bulk',
                        errorText: batch.pcsPerBulkError,
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: batch.numberOfBulkController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() => batch.recalcBulk()),
                      decoration: InputDecoration(
                        labelText: 'No. Bulk',
                        errorText: batch.numberOfBulkError,
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  batch.isBulkMode ? 'Total Pcs:' : (product.isWeightBased ? 'Quantity (kg):' : 'Quantity (pcs):'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: product.isWeightBased ? 170 : 120,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: batch.quantityController,
                        enabled: !batch.isBulkMode,
                        readOnly: batch.isBulkMode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        onChanged: (_) {
                          if (batch.quantityError != null) setState(() => batch.quantityError = null);
                        },
                        decoration: InputDecoration(
                          errorText: batch.quantityError,
                          isDense: true,
                          filled: true,
                          fillColor: batch.isBulkMode ? Colors.grey.shade200 : AppColors.lightPeach,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          suffixIcon: (!product.isWeightBased && batch.isBulkMode) ? const Icon(Icons.calculate_outlined, size: 16) : null,
                        ),
                      ),
                    ),
                    if (product.isWeightBased) ...[
                      const SizedBox(width: 8),
                      Material(
                        color: AppColors.primaryOrange,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: batch.isReadingFromScale ? null : () => _captureWeightFromScaleForBatch(index),
                          child: SizedBox(
                            width: 38,
                            height: 38,
                            child: batch.isReadingFromScale
                                ? const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                                : const Icon(Icons.scale, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 12, color: AppColors.primaryOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(previewMessage, style: const TextStyle(fontSize: 11, color: AppColors.primaryOrange, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductResultTile extends StatelessWidget {
  const _ProductResultTile({required this.product, required this.onTap});
  final EmployeeProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unitStr = product.isWeightBased ? 'kg' : 'pcs';
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: product.image != null
                      ? const Icon(Icons.image, color: AppColors.primaryOrange, size: 22)
                      : const Icon(Icons.inventory_2_outlined, color: AppColors.placeholderColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name,
                          style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(product.category,
                              style: const TextStyle(
                                  color: AppColors.primaryOrange, fontSize: 10, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          Text('·', style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.5))),
                          const SizedBox(width: 6),
                          Text(product.barcode.isEmpty ? 'No barcode' : product.barcode,
                              style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                          'Stock: ${product.quantity.toStringAsFixed(2)} $unitStr · ₱${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
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
  final _capitalController = TextEditingController();
  final _quantityController = TextEditingController(text: '1.0');
  final _newCategoryController = TextEditingController();

  // Bulk Entry Calculator
  bool _isBulkMode = false;
  final _bulkPriceController = TextEditingController();
  final _pcsPerBulkController = TextEditingController();
  final _numberOfBulkController = TextEditingController();
  String? _bulkPriceError;
  String? _pcsPerBulkError;
  String? _numberOfBulkError;

  DateTime? _expiryDate;
  String? _imagePath;
  bool _isWeightBased = false;
  bool _isReadingFromScale = false;
  late String _category =
  widget.inventory.categories.where((c) => c != 'All').isNotEmpty
      ? widget.inventory.categories.firstWhere((c) => c != 'All')
      : 'Snacks';
  bool _isAddingNewCategory = false;

  String? _nameError;
  String? _priceError;
  String? _capitalError;
  String? _barcodeError;
  String? _quantityError;

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _capitalController.dispose();
    _quantityController.dispose();
    _newCategoryController.dispose();
    _bulkPriceController.dispose();
    _pcsPerBulkController.dispose();
    _numberOfBulkController.dispose();
    super.dispose();
  }

  void _toggleBulkMode(bool? value) {
    setState(() {
      _isBulkMode = value ?? false;
      if (_isBulkMode) {
        _recalcBulk();
      } else {
        _bulkPriceError = null;
        _pcsPerBulkError = null;
        _numberOfBulkError = null;
      }
    });
  }

  void _recalcBulk() {
    final bulkPrice = double.tryParse(_bulkPriceController.text.trim());
    final pcsPerBulk = int.tryParse(_pcsPerBulkController.text.trim());
    final numberOfBulk = int.tryParse(_numberOfBulkController.text.trim());

    setState(() {
      if (bulkPrice != null && bulkPrice >= 0 && pcsPerBulk != null && pcsPerBulk > 0) {
        final capitalPerPc = bulkPrice / pcsPerBulk;
        _capitalController.text = capitalPerPc.toStringAsFixed(2);
      } else {
        _capitalController.text = '';
      }

      if (pcsPerBulk != null && pcsPerBulk > 0 && numberOfBulk != null && numberOfBulk >= 0) {
        final totalQuantity = (pcsPerBulk * numberOfBulk).toDouble();
        _quantityController.text = totalQuantity.toString();
      } else {
        _quantityController.text = '';
      }
      _capitalError = null;
      _quantityError = null;
    });
  }

  /// Simulation for reading from ESP32 Scale.
  /// Replace this with actual Bluetooth/WebSocket logic later.
  Future<void> _captureWeightFromScale() async {
    setState(() => _isReadingFromScale = true);
    
    // Simulating delay for hardware response
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // Simulate a weight reading (e.g., 2.45 kg)
    // In production, this would come from your ESP32
    final simulatedWeight = 1.0 + (DateTime.now().millisecond % 500) / 100.0;
    
    setState(() {
      _quantityController.text = simulatedWeight.toStringAsFixed(2);
      _isReadingFromScale = false;
      _quantityError = null;
    });

    if (mounted) {
      TopNotification.show(context, 'Weight captured from scale: ${simulatedWeight.toStringAsFixed(2)} kg');
    }
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

  Future<void> _continue() async {
    if (_isBulkMode && !_isWeightBased) {
      final bulkPrice = double.tryParse(_bulkPriceController.text.trim());
      final pcsPerBulk = int.tryParse(_pcsPerBulkController.text.trim());
      final numberOfBulk = int.tryParse(_numberOfBulkController.text.trim());

      setState(() {
        _bulkPriceError = (bulkPrice == null || bulkPrice <= 0) ? 'Bulk Price must be greater than 0.' : null;
        _pcsPerBulkError = (pcsPerBulk == null || pcsPerBulk <= 0) ? 'Must be a positive whole number.' : null;
        _numberOfBulkError = (numberOfBulk == null || numberOfBulk <= 0) ? 'Must be a positive whole number.' : null;
      });

      if (_bulkPriceError != null || _pcsPerBulkError != null || _numberOfBulkError != null) return;
      _recalcBulk();
    }

    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final capital = double.tryParse(_capitalController.text.trim());
    final barcode = _barcodeController.text.trim();
    final quantity = double.tryParse(_quantityController.text.trim());
    final category = _isAddingNewCategory ? _newCategoryController.text.trim() : _category;

    setState(() {
      _nameError = name.isEmpty ? 'Product name is required.' : null;
      _priceError = (price == null || price < 0) ? 'Enter a valid price.' : null;
      _capitalError = (capital == null || capital < 0) ? 'Enter a valid capital per pc.' : null;
      _barcodeError = widget.inventory.isBarcodeTaken(barcode) ? 'This barcode is already used.' : null;

      if (quantity == null || quantity <= 0) {
        _quantityError = 'Enter a quantity greater than 0.';
      } else if (!_isWeightBased && quantity != quantity.roundToDouble()) {
        _quantityError = 'Regular products must use whole-number quantities.';
      } else {
        _quantityError = null;
      }
    });
    if (_nameError != null || _priceError != null || _capitalError != null || _barcodeError != null || _quantityError != null) return;
    if (category.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Action', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to add "$name" to the inventory?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add Product')),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    if (_isAddingNewCategory) {
      widget.inventory.addCategory(category);
    }

    final product = widget.inventory.createProduct(
      name: name,
      category: category,
      price: price!,
      capital: capital!,
      unit: _isWeightBased ? 'kg' : 'pcs',
      barcode: barcode,
      image: _imagePath,
      isWeightBased: _isWeightBased,
    );

    if (product == null) {
      setState(() => _barcodeError = 'This barcode is already used by another product.');
      return;
    }

    final bulkNotes = (_isBulkMode && !_isWeightBased)
        ? 'Bulk entry: ₱${_bulkPriceController.text.trim()} ÷ ${_pcsPerBulkController.text.trim()} pcs/bulk × '
        '${_numberOfBulkController.text.trim()} bulk(s) → Capital/pc ₱${capital.toStringAsFixed(2)}'
        : null;

    widget.inventory.receiveStock(
      productId: product.id,
      quantity: quantity!,
      expiryDate: _expiryDate,
      notes: bulkNotes,
    );

    TopNotification.show(context, 'New product "$name" created.');
    Navigator.pop(context, product);
  }

  Future<void> _pickImage() async {
    setState(() {
      _imagePath = 'assets/products/placeholder.png';
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.inventory.categories.where((c) => c != 'All').toList();

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
              const Text('Add Product Manually', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText)),
              const SizedBox(height: 4),
              Text("Enter the product's info.", style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.8), fontSize: 12)),
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
              const Text('Unit Type', style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              _buildUnitTypeSelector(),
              const SizedBox(height: 12),
              if (!_isWeightBased) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SwitchListTile(
                    title: const Text('Received as Bulk?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text(
                      'Turn on to compute Capital per Pc and Total Pcs from a bulk purchase.',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: _isBulkMode,
                    onChanged: (val) => _toggleBulkMode(val),
                    activeThumbColor: AppColors.primaryOrange,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text('Product Name *', style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: _fieldDecoration('e.g. Jasmine Rice', errorText: _nameError),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Category', style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
                  GestureDetector(
                    onTap: () => setState(() => _isAddingNewCategory = !_isAddingNewCategory),
                    child: Text(_isAddingNewCategory ? 'Select Existing' : 'Add New', style: const TextStyle(color: AppColors.primaryOrange, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isAddingNewCategory)
                TextField(
                  controller: _newCategoryController,
                  decoration: _fieldDecoration('Enter new category name'),
                )
              else
                DropdownButtonFormField<String>(
                  value: _category,
                  items: categories.map((category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                  decoration: _fieldDecoration(null),
                ),
              const SizedBox(height: 14),
              if (_isBulkMode) ...[
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bulk Entry Calculator', style: TextStyle(color: AppColors.darkText, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      const Text('Bulk Price (₱) *', style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _bulkPriceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => _recalcBulk(),
                        decoration: _fieldDecoration('e.g. 720.00', prefixText: '₱ ', errorText: _bulkPriceError),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Pcs per Bulk *', style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _pcsPerBulkController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => _recalcBulk(),
                                  decoration: _fieldDecoration('e.g. 12', errorText: _pcsPerBulkError),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Number of Bulk *', style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _numberOfBulkController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => _recalcBulk(),
                                  decoration: _fieldDecoration('e.g. 5', errorText: _numberOfBulkError),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isWeightBased ? 'Capital / kg *' : 'Capital per Pc *', style: const TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _capitalController,
                          enabled: !_isBulkMode,
                          readOnly: _isBulkMode,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _fieldDecoration('e.g. 40.00', prefixText: '₱ ', errorText: _capitalError, suffixIcon: _isBulkMode ? const Icon(Icons.calculate_outlined, size: 18, color: AppColors.secondaryText) : null),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isWeightBased ? 'Price per kg *' : 'Price per pc *', style: const TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _fieldDecoration('e.g. 55.00', prefixText: '₱ ', errorText: _priceError),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(_isWeightBased ? 'Quantity (kg) *' : (_isBulkMode ? 'Total Pcs *' : 'Quantity (pcs) *'), style: const TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      enabled: !_isBulkMode,
                      readOnly: _isBulkMode,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _fieldDecoration(
                        'e.g. 10.50',
                        errorText: _quantityError,
                        suffixIcon: (!_isWeightBased && _isBulkMode) ? const Icon(Icons.calculate_outlined, size: 18, color: AppColors.secondaryText) : null,
                      ),
                    ),
                  ),
                  if (_isWeightBased) ...[
                    const SizedBox(width: 8),
                    Material(
                      color: AppColors.primaryOrange,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _isReadingFromScale ? null : _captureWeightFromScale,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: _isReadingFromScale
                              ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                              : const Icon(Icons.scale, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              const Text('Barcode (optional)', style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: _barcodeController,
                decoration: _fieldDecoration('Leave blank if none', errorText: _barcodeError),
              ),
              const SizedBox(height: 14),
              const Text('Expiration Date', style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickExpiryManually,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(color: AppColors.lightPeach, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          _expiryDate == null ? 'No expiration date' : _formatDate(_expiryDate!),
                          style: TextStyle(color: _expiryDate == null ? AppColors.secondaryText.withValues(alpha: 0.5) : AppColors.darkText, fontSize: 14),
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
                      child: const SizedBox(width: 48, height: 48, child: Icon(Icons.qr_code_scanner, color: Colors.white)),
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

  InputDecoration _fieldDecoration(String? hint, {String? prefixText, String? errorText, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      errorText: errorText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.lightPeach,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    );
  }

  Widget _buildUnitTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _unitTypeTab(
              label: 'Quantity (Pcs)',
              icon: Icons.inventory_2_outlined,
              isSelected: !_isWeightBased,
              onTap: () {
                setState(() {
                  _isWeightBased = false;
                });
              },
            ),
          ),
          Expanded(
            child: _unitTypeTab(
              label: 'De-Kilo (Kg)',
              icon: Icons.scale_outlined,
              isSelected: _isWeightBased,
              onTap: () {
                setState(() {
                  _isWeightBased = true;
                  _isBulkMode = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _unitTypeTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.secondaryText,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? Colors.white : AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
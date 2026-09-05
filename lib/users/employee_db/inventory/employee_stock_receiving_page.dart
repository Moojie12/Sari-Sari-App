import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../employee_inventory_controller.dart';
import 'employee_dummy_products.dart';
import 'employee_product_model.dart';

/// Stock Receiving screen.
///
/// Flow: identify a product (barcode scan or manual search — creating a
/// new product record if it truly doesn't exist yet), enter the received
/// quantity/expiry/supplier/notes, review a live summary of what will
/// happen, then save.
///
/// All the actual RULE 1/2/3 batch logic lives in
/// [EmployeeInventoryController.receiveStock] / [createProduct] — this
/// screen only collects input, previews the outcome, and displays the
/// result.
class EmployeeStockReceivingPage extends StatefulWidget {
  const EmployeeStockReceivingPage({super.key, required this.inventory});

  final EmployeeInventoryController inventory;

  @override
  State<EmployeeStockReceivingPage> createState() => _EmployeeStockReceivingPageState();
}

class _EmployeeStockReceivingPageState extends State<EmployeeStockReceivingPage> {
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController();
  final _supplierController = TextEditingController();
  final _notesController = TextEditingController();

  String _searchQuery = '';
  String? _selectedProductId;
  DateTime? _expiryDate;
  bool _noExpiry = false;
  String? _quantityError;
  String? _expiryError;

  /// Last barcode that didn't match any product — kept so the "not found"
  /// message and the "create with this barcode" shortcut stay in sync.
  String? _unmatchedBarcode;

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
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
    setState(() {
      _selectedProductId = null;
      _quantityController.clear();
      _supplierController.clear();
      _notesController.clear();
      _expiryDate = null;
      _noExpiry = false;
      _quantityError = null;
      _expiryError = null;
      _unmatchedBarcode = null;
    });
  }

  /// This build is frontend-only, so there's no camera/scanner package
  /// wired in yet — staff type or paste the scanned code here instead of
  /// pointing a camera at it. Looks the code up the same way a real scan
  /// would (exact barcode match).
  Future<void> _openScanDialog() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Scan Barcode'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Barcode value'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Scan'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    _handleBarcode(code);
  }

  /// Handles a barcode however it arrived (scan dialog or typed straight
  /// into the search field). Missing/unscannable barcodes are handled
  /// gracefully — a no-match just surfaces the manual/create-new path
  /// instead of crashing or dead-ending.
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

  Future<void> _openCreateProductSheet({String prefillBarcode = ''}) async {
    final created = await showModalBottomSheet<EmployeeProduct>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _NewProductSheet(
        inventory: widget.inventory,
        prefillName: _unmatchedBarcode == null ? _searchQuery.trim() : '',
        prefillBarcode: prefillBarcode,
      ),
    );
    if (created != null) _selectProduct(created);
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 15),
    );
    if (picked != null) {
      setState(() {
        _expiryDate = picked;
        _noExpiry = false;
        _expiryError = null;
      });
    }
  }

  bool _validate() {
    final quantity = int.tryParse(_quantityController.text.trim());
    final quantityError =
    (quantity == null || quantity <= 0) ? 'Enter a quantity greater than 0.' : null;
    final expiryError = (!_noExpiry && _expiryDate == null)
        ? 'Pick an expiration date, or mark this item as not tracked.'
        : null;

    setState(() {
      _quantityError = quantityError;
      _expiryError = expiryError;
    });
    return quantityError == null && expiryError == null;
  }

  void _submit(EmployeeProduct product) {
    if (!_validate()) return;

    final quantity = int.parse(_quantityController.text.trim());
    final supplier = _supplierController.text.trim();
    final notes = _notesController.text.trim();

    final result = widget.inventory.receiveStock(
      productId: product.id,
      quantity: quantity,
      expiryDate: _noExpiry ? null : _expiryDate,
      supplier: supplier.isEmpty ? null : supplier,
      notes: notes.isEmpty ? null : notes,
    );

    if (result == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Could not receive stock — please check the quantity and try again.'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }

    _showSuccessDialog(product.name, result);
  }

  Future<void> _showSuccessDialog(String productName, StockReceivingResult result) async {
    final message = switch (result.outcome) {
      StockReceivingOutcome.newProduct =>
      'New product created. Batch ${result.batchId} started with ${result.batchQuantity} pcs.',
      StockReceivingOutcome.mergedIntoExistingBatch =>
      'Existing batch found. Added to Batch ${result.batchId}, now ${result.batchQuantity} pcs.',
      StockReceivingOutcome.newBatchCreated =>
      'Different expiration date — new Batch ${result.batchId} created with ${result.batchQuantity} pcs.',
    };

    if (!mounted) return;
    final receiveAnother = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stock Received'),
        content: Text('$message\n\nTotal stock for $productName: ${result.totalStock} pcs.'),
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
            child: const Text('Receive Another'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (receiveAnother == true) {
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
        title: const Text('Receive Stock', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  _buildStockForm(selected),
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
          'Identify Product',
          style: TextStyle(color: AppColors.darkText, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Scan a barcode or search by name — or add a new product if it '
              "doesn't exist yet.",
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
                  hintText: 'Search by name or barcode...',
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
                onTap: _openScanDialog,
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
                'Start typing, or tap the scanner icon, to find a product.',
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
            onPressed: () => _openCreateProductSheet(prefillBarcode: _unmatchedBarcode ?? ''),
            icon: const Icon(Icons.add),
            label: const Text('Create New Product'),
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
                  'You can create a new product with this barcode below, or '
                  'search by name instead.',
              style: const TextStyle(fontSize: 12, color: Colors.deepOrange, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Step 2: selected product + stock info form ------------------------

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
              final dateLabel = batch.expiryDate == null
                  ? 'No expiry'
                  : '${batch.expiryDate!.day}/${batch.expiryDate!.month}/${batch.expiryDate!.year}';
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

  Widget _buildStockForm(EmployeeProduct product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stock Information',
          style: TextStyle(color: AppColors.darkText, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildLabel('Quantity Received *'),
        const SizedBox(height: 8),
        TextField(
          controller: _quantityController,
          keyboardType: TextInputType.number,
          onChanged: (_) {
            if (_quantityError != null) setState(() => _quantityError = null);
          },
          decoration: InputDecoration(
            hintText: 'e.g. 20',
            errorText: _quantityError,
            filled: true,
            fillColor: AppColors.lightPeach,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 18),
        _buildLabel('Expiration Date *'),
        const SizedBox(height: 8),
        InkWell(
          onTap: _noExpiry ? null : _pickExpiryDate,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: _noExpiry ? AppColors.lightBackground : AppColors.lightPeach,
              borderRadius: BorderRadius.circular(8),
              border: _expiryError != null ? Border.all(color: Colors.red) : null,
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.secondaryText),
                const SizedBox(width: 10),
                Text(
                  _noExpiry
                      ? 'Not tracked'
                      : (_expiryDate == null
                      ? 'Select expiration date'
                      : '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'),
                  style: TextStyle(
                    color: _expiryDate == null && !_noExpiry
                        ? AppColors.secondaryText.withValues(alpha: 0.6)
                        : AppColors.darkText,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expiryError != null) ...[
          const SizedBox(height: 4),
          Text(_expiryError!, style: const TextStyle(color: Colors.red, fontSize: 11)),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _noExpiry,
                activeColor: AppColors.primaryOrange,
                onChanged: (value) => setState(() {
                  _noExpiry = value ?? false;
                  if (_noExpiry) {
                    _expiryDate = null;
                    _expiryError = null;
                  }
                }),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "This item doesn't expire / expiry isn't tracked.",
                style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildLabel('Supplier (optional)'),
        const SizedBox(height: 8),
        TextField(
          controller: _supplierController,
          decoration: InputDecoration(
            hintText: 'e.g. ABC Distributors',
            filled: true,
            fillColor: AppColors.lightPeach,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 18),
        _buildLabel('Notes (optional)'),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Any additional details about this delivery...',
            filled: true,
            fillColor: AppColors.lightPeach,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 20),
        _buildOutcomePreview(product),
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
            child: const Text('Receive Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500));
  }

  /// Live "what will happen" summary — recomputed on every keystroke/date
  /// pick from [EmployeeInventoryController.previewOutcome] /
  /// [EmployeeInventoryController.matchingBatch], so staff see the exact
  /// same RULE 1/2/3 decision before saving that [receiveStock] will make.
  Widget _buildOutcomePreview(EmployeeProduct product) {
    final quantity = int.tryParse(_quantityController.text.trim());
    final effectiveExpiry = _noExpiry ? null : _expiryDate;
    final hasEnoughInfo = quantity != null && quantity > 0 && (_noExpiry || effectiveExpiry != null);

    if (!hasEnoughInfo) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.lightBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Enter quantity and expiration date to see a summary.',
          style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
        ),
      );
    }

    final outcome = widget.inventory.previewOutcome(product, effectiveExpiry);
    final matching = widget.inventory.matchingBatch(product, effectiveExpiry);

    final String message;
    switch (outcome) {
      case StockReceivingOutcome.mergedIntoExistingBatch:
        message = 'Existing batch found. Quantity will be added to Batch ${matching?.id}.';
        break;
      case StockReceivingOutcome.newBatchCreated:
        message = 'Different expiration date. A new batch will be created.';
        break;
      case StockReceivingOutcome.newProduct:
      default:
        message = 'First stock for this product — a new batch will be created.';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Product: ${product.name}', style: const TextStyle(fontSize: 12, color: AppColors.darkText)),
          Text('Quantity Received: $quantity pcs', style: const TextStyle(fontSize: 12, color: AppColors.darkText)),
          Text(
            'Expiration Date: ${_noExpiry ? 'Not tracked' : '${effectiveExpiry!.day}/${effectiveExpiry.month}/${effectiveExpiry.year}'}',
            style: const TextStyle(fontSize: 12, color: AppColors.darkText),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 14, color: AppColors.primaryOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(message,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.primaryOrange, fontWeight: FontWeight.w600)),
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
                  child: const Icon(Icons.inventory_2_outlined, color: AppColors.placeholderColor, size: 20),
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

/// Bottom sheet for creating a brand-new product record (Stock Receiving's
/// "product does not exist" path). Only collects what
/// [EmployeeInventoryController.createProduct] needs; the first batch is
/// then entered on the main Stock Receiving form right after this closes.
class _NewProductSheet extends StatefulWidget {
  const _NewProductSheet({
    required this.inventory,
    this.prefillName = '',
    this.prefillBarcode = '',
  });

  final EmployeeInventoryController inventory;
  final String prefillName;
  final String prefillBarcode;

  @override
  State<_NewProductSheet> createState() => _NewProductSheetState();
}

class _NewProductSheetState extends State<_NewProductSheet> {
  late final _nameController = TextEditingController(text: widget.prefillName);
  late final _barcodeController = TextEditingController(text: widget.prefillBarcode);
  final _priceController = TextEditingController();
  late String _category =
  kEmployeeProductCategories.where((c) => c != 'All').isNotEmpty
      ? kEmployeeProductCategories.firstWhere((c) => c != 'All')
      : 'Snacks';

  String? _nameError;
  String? _priceError;
  String? _barcodeError;

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _create() {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final barcode = _barcodeController.text.trim();

    setState(() {
      _nameError = name.isEmpty ? 'Product name is required.' : null;
      _priceError = (price == null || price < 0) ? 'Enter a valid price.' : null;
      _barcodeError = widget.inventory.isBarcodeTaken(barcode)
          ? 'This barcode is already used by another product.'
          : null;
    });
    if (_nameError != null || _priceError != null || _barcodeError != null) return;

    final product = widget.inventory.createProduct(
      name: name,
      category: _category,
      price: price!,
      barcode: barcode,
    );

    if (product == null) {
      setState(() => _barcodeError = 'This barcode is already used by another product.');
      return;
    }

    Navigator.pop(context, product);
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
              const Text('Create New Product',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText)),
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _create,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Create Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../../../shared/widgets/barcode_scanner_screen.dart';
import '../employee_inventory_controller.dart';
import 'employee_product_model.dart';

class EmployeeEditProductPage extends StatefulWidget {
  const EmployeeEditProductPage({
    super.key,
    required this.inventory,
    required this.product,
  });

  final EmployeeInventoryController inventory;
  final EmployeeProduct product;

  @override
  State<EmployeeEditProductPage> createState() => _EmployeeEditProductPageState();
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

class _EmployeeEditProductPageState extends State<EmployeeEditProductPage> {
  late final _nameController = TextEditingController(text: widget.product.name);
  late final _barcodeController = TextEditingController(text: widget.product.barcode);
  late final _sellingPriceController = TextEditingController(text: widget.product.price.toString());
  late final _capitalController = TextEditingController(text: widget.product.capital.toString());
  late final _thresholdController = TextEditingController(text: widget.product.lowStockThreshold.toString());
  final _newCategoryController = TextEditingController();

  // ---- Add Stock (pcs) — optional, ADDS to current stock as a new batch;
  // it never overwrites the product's existing (batch-derived) quantity.
  final _quantityController = TextEditingController();
  String? _quantityError;

  // ---- Set / Bulk Entry Calculator (Retail (Pcs) only) -------------------
  // When bulk mode is on, `_priceController` (Capital Price per pc) and
  // `_quantityController` (Add Stock, pcs) become read-only and are
  // auto-filled from these three inputs.
  bool _isBulkMode = false;
  final _setPriceController = TextEditingController();
  final _pcsPerSetController = TextEditingController();
  final _numberOfSetsController = TextEditingController();
  String? _setPriceError;
  String? _pcsPerSetError;
  String? _numberOfSetsError;

  String? _imagePath;
  late String _category = widget.product.category;
  bool _isAddingNewCategory = false;
  bool _isWeightBased = false;

  String? _nameError;
  String? _priceError;
  String? _barcodeError;
  bool _isBarcodeEditingEnabled = false;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.product.image;
    _isWeightBased = widget.product.isWeightBased;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _sellingPriceController.dispose();
    _capitalController.dispose();
    _thresholdController.dispose();
    _newCategoryController.dispose();
    _quantityController.dispose();
    _setPriceController.dispose();
    _pcsPerSetController.dispose();
    _numberOfSetsController.dispose();
    super.dispose();
  }

  /// Unit mode changed (Retail (Pcs) <-> De-Kilo (Kg)). Bulk/Set mode only
  /// makes sense for Retail (Pcs), so switching to De-Kilo turns it off.
  void _setWeightBased(bool value) {
    setState(() {
      _isWeightBased = value;
      if (value) {
        _isBulkMode = false;
        _setPriceError = null;
        _pcsPerSetError = null;
        _numberOfSetsError = null;
      }
    });
  }

  void _toggleBulkMode(bool value) {
    setState(() {
      _isBulkMode = value;
      if (value) {
        _recalcBulk();
      } else {
        _setPriceError = null;
        _pcsPerSetError = null;
        _numberOfSetsError = null;
      }
    });
  }

  /// Recomputes Capital Price (per Pc) and Total Stock Quantity (Pcs) from
  /// the Set Price / Pcs per Set / Number of Sets inputs, writing the
  /// results into the (now read-only) `_priceController` /
  /// `_quantityController`. Guards against divide-by-zero and invalid
  /// input by leaving the computed field blank until the inputs check out.
  void _recalcBulk() {
    final setPrice = double.tryParse(_setPriceController.text.trim());
    final pcsPerSet = int.tryParse(_pcsPerSetController.text.trim());
    final numberOfSets = int.tryParse(_numberOfSetsController.text.trim());

    setState(() {
      if (setPrice != null && setPrice >= 0 && pcsPerSet != null && pcsPerSet > 0) {
        final capitalPerPc = setPrice / pcsPerSet;
        _capitalController.text = capitalPerPc.toStringAsFixed(2);
      } else {
        _capitalController.text = '';
      }

      if (pcsPerSet != null && pcsPerSet > 0 && numberOfSets != null && numberOfSets >= 0) {
        final totalQuantity = pcsPerSet * numberOfSets;
        _quantityController.text = totalQuantity.toString();
      } else {
        _quantityController.text = '';
      }

      _priceError = null;
      _quantityError = null;
    });
  }

  Future<void> _pickImage() async {
    setState(() {
      _imagePath = 'assets/products/placeholder.png';
    });
  }

  Future<void> _onScanBarcode() async {
    if (!_isBarcodeEditingEnabled) {
      final confirmed = await _showBarcodeEditConfirmation();
      if (confirmed != true) return;
      setState(() => _isBarcodeEditingEnabled = true);
    }

    if (!mounted) return;
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );
    if (code != null && code.isNotEmpty) {
      setState(() {
        _barcodeController.text = code;
      });
    }
  }

  Future<bool?> _showBarcodeEditConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Barcode?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Changing the barcode might affect how this product is identified. Are you sure you want to edit it?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Edit')),
        ],
      ),
    );
  }

  void _save() async {
    final name = _nameController.text.trim();
    final barcode = _barcodeController.text.trim();
    final threshold = double.tryParse(_thresholdController.text.trim()) ?? 10.0;
    final category = _isAddingNewCategory ? _newCategoryController.text.trim() : _category;

    if (!_isWeightBased && widget.product.quantity != widget.product.quantity.roundToDouble()) {
      TopNotification.show(context, 'Cannot turn off De-Kilo because existing stock has a decimal value.', isError: true);
      return;
    }

    if (_isBulkMode && !_isWeightBased) {
      final setPrice = double.tryParse(_setPriceController.text.trim());
      final pcsPerSet = int.tryParse(_pcsPerSetController.text.trim());
      final numberOfSets = int.tryParse(_numberOfSetsController.text.trim());

      setState(() {
        _setPriceError = (setPrice == null || setPrice < 0) ? 'Enter a valid set price.' : null;
        _pcsPerSetError = (pcsPerSet == null || pcsPerSet <= 0) ? 'Must be greater than 0.' : null;
        _numberOfSetsError = (numberOfSets == null || numberOfSets <= 0) ? 'Must be greater than 0.' : null;
      });

      if (_setPriceError != null || _pcsPerSetError != null || _numberOfSetsError != null) return;

      // Make sure the read-only outputs reflect the latest inputs before saving.
      _recalcBulk();
    }

    final price = double.tryParse(_sellingPriceController.text.trim());
    final capital = double.tryParse(_capitalController.text.trim());
    final addQuantityText = _quantityController.text.trim();
    final addQuantity = addQuantityText.isEmpty ? 0.0 : double.tryParse(addQuantityText);

    setState(() {
      _nameError = name.isEmpty ? 'Product name is required.' : null;
      _priceError = (price == null || price < 0 || capital == null || capital < 0) ? 'Enter valid prices.' : null;
      _barcodeError = widget.inventory.isBarcodeTaken(barcode, excludingProductId: widget.product.id)
          ? 'This barcode is already used by another product.'
          : null;
      if (addQuantity == null || addQuantity < 0) {
        _quantityError = 'Enter a valid quantity (0 or more).';
      } else if (!_isWeightBased && addQuantity != addQuantity.roundToDouble()) {
        _quantityError = 'Retail (Pcs) stock must use whole numbers.';
      } else {
        _quantityError = null;
      }
    });
    if (_nameError != null || _priceError != null || _barcodeError != null || _quantityError != null) return;
    if (category.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Changes', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          addQuantity! > 0
              ? 'Are you sure you want to save these changes and add $addQuantity ${_isWeightBased ? 'kg' : 'pcs'} of new stock?'
              : 'Are you sure you want to save the changes to this product?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    if (_isAddingNewCategory) {
      widget.inventory.addCategory(category, 'dummy-profile-id');
    }

    widget.inventory.updateProduct(
      productId: widget.product.id,
      name: name,
      category: category,
      price: price!,
      capital: capital!,
      barcode: barcode,
      image: _imagePath,
      lowStockThreshold: threshold,
      isWeightBased: _isWeightBased,
    );

    // Bulk/Set entry (or a manually-entered "Add Stock" amount) registers
    // as a new no-expiry batch — this only ever adds to existing stock,
    // it never overwrites the product's current (batch-derived) quantity.
    if (addQuantity! > 0) {
      final bulkNotes = (_isBulkMode && !_isWeightBased)
          ? 'Bulk/Set entry: ₱${_setPriceController.text.trim()} ÷ ${_pcsPerSetController.text.trim()} pcs/set × '
          '${_numberOfSetsController.text.trim()} set(s) → Capital/pc ₱${capital.toStringAsFixed(2)}'
          : null;
      widget.inventory.receiveStock(
        productId: widget.product.id,
        quantity: addQuantity,
        expiryDate: null,
        notes: bulkNotes,
      );
    }

    TopNotification.show(context, 'Product updated successfully');
    Navigator.pop(context);
  }

  Widget _buildFinancialSummary() {
    final addQty = double.tryParse(_quantityController.text) ?? 0.0;
    final totalQty = widget.product.quantity + addQty;
    final sellingPrice = double.tryParse(_sellingPriceController.text) ?? 0.0;
    final capitalPrice = double.tryParse(_capitalController.text) ?? 0.0;

    final totalCapital = capitalPrice * totalQty;
    final totalRevenue = sellingPrice * totalQty;
    final totalProfit = totalRevenue - totalCapital;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightPeach.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stock Value Summary', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkText)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Total Capital', '₱${totalCapital.toStringAsFixed(2)}'),
              _buildStat('Total Revenue', '₱${totalRevenue.toStringAsFixed(2)}'),
              _buildStat('Total Profit', '₱${totalProfit.toStringAsFixed(2)}', isProfit: true),
            ],
          ),
          if (addQty > 0) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                '* Includes newly added stock',
                style: TextStyle(fontSize: 10, color: AppColors.secondaryText.withValues(alpha: 0.7), fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, {bool isProfit = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 10, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: isProfit ? Colors.green.shade700 : AppColors.darkText,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.inventory.categories.where((c) => c != 'All').toList();

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Edit Product', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        foregroundColor: AppColors.darkText,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderColor),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
                    ],
                  ),
                  child: _imagePath == null
                      ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, color: AppColors.primaryOrange, size: 30),
                      SizedBox(height: 8),
                      Text('Add Photo', style: TextStyle(color: AppColors.primaryOrange, fontSize: 12)),
                    ],
                  )
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const Icon(Icons.image, size: 60, color: AppColors.primaryOrange),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.edit, size: 16, color: AppColors.primaryOrange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Unit Type', style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _unitTypeOption(
                    label: 'Retail (Pcs)',
                    icon: Icons.inventory_2_outlined,
                    selected: !_isWeightBased,
                    onTap: () => _setWeightBased(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _unitTypeOption(
                    label: 'De-Kilo (Kg)',
                    icon: Icons.scale_outlined,
                    selected: _isWeightBased,
                    onTap: () => _setWeightBased(true),
                  ),
                ),
              ],
            ),
            if (!_isWeightBased) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SwitchListTile(
                  title: const Text('Received / Bought as Bulk / Set?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                    'Turn on to compute Capital Price and stock to add from a set/bulk/case purchase automatically.',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: _isBulkMode,
                  onChanged: _toggleBulkMode,
                  activeThumbColor: AppColors.primaryOrange,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text('Product Name *', style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: _fieldDecoration('e.g. Bear Brand Milk 300ml', errorText: _nameError),
            ),
            const SizedBox(height: 16),
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
                initialValue: _category,
                items: categories.map((category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
                decoration: _fieldDecoration(null),
              ),
            const SizedBox(height: 16),
            if (_isBulkMode && !_isWeightBased) ...[
              const Text('Set / Bulk Entry Calculator', style: TextStyle(color: AppColors.darkText, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Enter what was paid for the whole set/case — Capital Price and stock to add below fill in automatically.',
                style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.8), fontSize: 11),
              ),
              const SizedBox(height: 10),
              const Text('Set Price (₱) *', style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: _setPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _recalcBulk(),
                decoration: _fieldDecoration('e.g. 500.00', prefixText: '₱ ', errorText: _setPriceError),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pcs per Set *', style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _pcsPerSetController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _recalcBulk(),
                          decoration: _fieldDecoration('e.g. 50', errorText: _pcsPerSetError),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Number of Sets *', style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _numberOfSetsController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _recalcBulk(),
                          decoration: _fieldDecoration('e.g. 2', errorText: _numberOfSetsError),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isWeightBased ? 'Capital / kg *' : 'Capital / pc *', style: const TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _capitalController,
                        enabled: !(_isBulkMode && !_isWeightBased),
                        readOnly: _isBulkMode && !_isWeightBased,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: _fieldDecoration(
                          '0.00',
                          prefixText: '₱ ',
                          errorText: _priceError,
                          suffixIcon: (_isBulkMode && !_isWeightBased) ? const Icon(Icons.calculate_outlined, size: 18, color: AppColors.secondaryText) : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isWeightBased ? 'Selling / kg *' : 'Selling / pc *', style: const TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _sellingPriceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: _fieldDecoration(
                          '0.00',
                          prefixText: '₱ ',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Low Stock Alert', style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _thresholdController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _fieldDecoration('e.g. 10'),
            ),
            const SizedBox(height: 16),
            _buildFinancialSummary(),
            const SizedBox(height: 16),
            if (widget.product.batches.isNotEmpty) ...[
              const Text('Existing Batches', style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.product.batches.map((batch) {
                    final dateLabel = batch.expiryDate == null ? 'No expiry' : _formatDate(batch.expiryDate!);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Batch ${batch.id} — $dateLabel — ${batch.quantity.toStringAsFixed(2)} ${_isWeightBased ? 'kg' : 'pcs'}',
                        style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              _isBulkMode && !_isWeightBased ? 'Total Stock Quantity (Pcs) *' : 'Add Stock (${_isWeightBased ? 'kg' : 'pcs'}, optional)',
              style: const TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'Current stock: ${widget.product.quantity} ${_isWeightBased ? 'kg' : 'pcs'}. Anything entered here is ADDED as a new batch — it never replaces existing stock.',
              style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.8), fontSize: 11),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _quantityController,
              enabled: !(_isBulkMode && !_isWeightBased),
              readOnly: _isBulkMode && !_isWeightBased,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: _fieldDecoration(
                'e.g. 0',
                errorText: _quantityError,
                suffixIcon: (_isBulkMode && !_isWeightBased) ? const Icon(Icons.calculate_outlined, size: 18, color: AppColors.secondaryText) : null,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Barcode', style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    readOnly: !_isBarcodeEditingEnabled,
                    onTap: _isBarcodeEditingEnabled ? null : () async {
                      final confirmed = await _showBarcodeEditConfirmation();
                      if (confirmed == true) {
                        setState(() => _isBarcodeEditingEnabled = true);
                      }
                    },
                    decoration: _fieldDecoration(
                      'Barcode value',
                      errorText: _barcodeError,
                      suffixIcon: _isBarcodeEditingEnabled ? null : const Icon(Icons.lock_outline, size: 20, color: AppColors.placeholderColor),
                    ),
                  ),
                ),
                if (_isBarcodeEditingEnabled) ...[
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _onScanBarcode,
                      child: const SizedBox(width: 48, height: 48, child: Icon(Icons.qr_code_scanner, color: Colors.white)),
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.placeholderColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _onScanBarcode,
                      child: const SizedBox(width: 48, height: 48, child: Icon(Icons.qr_code_scanner, color: AppColors.secondaryText)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
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
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderColor)),
    );
  }

  /// One "Retail (Pcs)" / "De-Kilo (Kg)" choice in the Unit Type selector.
  Widget _unitTypeOption({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AppColors.primaryOrange : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? AppColors.primaryOrange : AppColors.borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : AppColors.secondaryText),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : AppColors.darkText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
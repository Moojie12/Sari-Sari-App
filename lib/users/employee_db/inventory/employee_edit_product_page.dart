import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../../../shared/widgets/barcode_scanner_screen.dart';
import '../employee_inventory_controller.dart';
import 'employee_dummy_products.dart';
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

class _EmployeeEditProductPageState extends State<EmployeeEditProductPage> {
  late final _nameController = TextEditingController(text: widget.product.name);
  late final _barcodeController = TextEditingController(text: widget.product.barcode);
  late final _priceController = TextEditingController(text: widget.product.price.toString());
  late final _thresholdController = TextEditingController(text: widget.product.lowStockThreshold.toString());
  final _newCategoryController = TextEditingController();

  String? _imagePath;
  late String _category = widget.product.category;
  bool _isAddingNewCategory = false;

  String? _nameError;
  String? _priceError;
  String? _barcodeError;
  bool _isBarcodeEditingEnabled = false;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.product.image;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _thresholdController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Mock image picking
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
        content: const Text(
          'Changing the barcode might affect how this product is identified. Are you sure you want to edit it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Yes, Edit'),
          ),
        ],
      ),
    );
  }

  void _save() async {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final barcode = _barcodeController.text.trim();
    final threshold = int.tryParse(_thresholdController.text.trim()) ?? 10;
    final category = _isAddingNewCategory ? _newCategoryController.text.trim() : _category;

    setState(() {
      _nameError = name.isEmpty ? 'Product name is required.' : null;
      _priceError = (price == null || price < 0) ? 'Enter a valid price.' : null;
      _barcodeError = widget.inventory.isBarcodeTaken(barcode, excludingProductId: widget.product.id)
          ? 'This barcode is already used by another product.'
          : null;
    });
    if (_nameError != null || _priceError != null || _barcodeError != null) return;
    if (category.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Changes', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to save the changes to this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (_isAddingNewCategory) {
      widget.inventory.addCategory(category);
    }

    widget.inventory.updateProduct(
      productId: widget.product.id,
      name: name,
      category: category,
      price: price!,
      barcode: barcode,
      image: _imagePath,
      lowStockThreshold: threshold,
    );

    TopNotification.show(context, 'Product updated successfully');
    Navigator.pop(context);
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
            const Text('Product Name *',
                style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: _fieldDecoration('e.g. Bear Brand Milk 300ml', errorText: _nameError),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Category',
                    style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
                GestureDetector(
                  onTap: () => setState(() => _isAddingNewCategory = !_isAddingNewCategory),
                  child: Text(
                    _isAddingNewCategory ? 'Select Existing' : 'Add New',
                    style: const TextStyle(
                        color: AppColors.primaryOrange, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
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
                items: categories
                    .map((category) => DropdownMenuItem(value: category, child: Text(category)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
                decoration: _fieldDecoration(null),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Price *',
                          style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _fieldDecoration('0.00', prefixText: '₱ ', errorText: _priceError),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Low Stock Alert',
                          style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _thresholdController,
                        keyboardType: TextInputType.number,
                        decoration: _fieldDecoration('e.g. 10'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Barcode',
                style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    readOnly: !_isBarcodeEditingEnabled,
                    onTap: _isBarcodeEditingEnabled
                        ? null
                        : () async {
                            final confirmed = await _showBarcodeEditConfirmation();
                            if (confirmed == true) {
                              setState(() => _isBarcodeEditingEnabled = true);
                            }
                          },
                    decoration: _fieldDecoration(
                      'Barcode value',
                      errorText: _barcodeError,
                      suffixIcon: _isBarcodeEditingEnabled
                          ? null
                          : const Icon(Icons.lock_outline, size: 20, color: AppColors.placeholderColor),
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
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.qr_code_scanner, color: Colors.white),
                      ),
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
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.qr_code_scanner, color: AppColors.secondaryText),
                      ),
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
}

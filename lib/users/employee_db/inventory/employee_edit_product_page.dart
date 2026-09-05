import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
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
  
  String? _imagePath;
  late String _category = widget.product.category;

  String? _nameError;
  String? _priceError;
  String? _barcodeError;

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
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Mock image picking
    setState(() {
      _imagePath = 'assets/products/placeholder.png';
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final barcode = _barcodeController.text.trim();
    final threshold = int.tryParse(_thresholdController.text.trim()) ?? 10;

    setState(() {
      _nameError = name.isEmpty ? 'Product name is required.' : null;
      _priceError = (price == null || price < 0) ? 'Enter a valid price.' : null;
      _barcodeError = widget.inventory.isBarcodeTaken(barcode, excludingProductId: widget.product.id)
          ? 'This barcode is already used by another product.'
          : null;
    });
    if (_nameError != null || _priceError != null || _barcodeError != null) return;

    widget.inventory.updateProduct(
      productId: widget.product.id,
      name: name,
      category: _category,
      price: price!,
      barcode: barcode,
      image: _imagePath,
      lowStockThreshold: threshold,
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product updated successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = kEmployeeProductCategories.where((c) => c != 'All').toList();

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
            const Text('Category',
                style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
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
            TextField(
              controller: _barcodeController,
              decoration: _fieldDecoration('Barcode value', errorText: _barcodeError),
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

  InputDecoration _fieldDecoration(String? hint, {String? prefixText, String? errorText}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      errorText: errorText,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderColor)),
    );
  }
}

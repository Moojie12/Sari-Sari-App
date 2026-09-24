import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/barcode_validator.dart';
import '../../../shared/utils/top_notification.dart';
import '../../../shared/widgets/barcode_scanner_screen.dart';
import '../../../shared/widgets/product_image.dart';
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

  String? _imagePath;
  late String _category = widget.product.category;
  bool _isAddingNewCategory = false;
  bool _isWeightBased = false;

  String? _nameError;
  String? _priceError;
  String? _capitalError;
  String? _barcodeError;
  bool _isBarcodeEditingEnabled = false;

  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

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
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Product Photo',
                    style: TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primaryOrange),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _processImagePick(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primaryOrange),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _processImagePick(ImageSource.gallery);
                },
              ),
              if (_imagePath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    setState(() => _imagePath = null);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processImagePick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        final file = File(picked.path);
        final fileSize = await file.length();
        const maxBytes = 5 * 1024 * 1024; // 5 MB maximum validation
        if (fileSize > maxBytes) {
          if (mounted) {
            final mb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
            TopNotification.show(
              context,
              'Image exceeds 5MB limit ($mb MB). Please choose a smaller image.',
              isError: true,
            );
          }
          return;
        }

        setState(() {
          _imagePath = picked.path;
        });
      }
    } catch (_) {
      if (mounted) {
        TopNotification.show(context, "Couldn't access image. Please check app permissions.", isError: true);
      }
    }
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

    final price = double.tryParse(_sellingPriceController.text.trim());
    final capital = double.tryParse(_capitalController.text.trim());

    setState(() {
      _nameError = name.isEmpty ? 'Product name is required.' : null;
      _priceError = (price == null || price < 0) ? 'Enter a valid selling price.' : null;
      _capitalError = (capital == null || capital < 0) ? 'Enter a valid capital price.' : null;
      _barcodeError = BarcodeValidator.validate(
        barcode: _barcodeController.text,
        currentProductId: widget.product.id,
        isBarcodeTaken: widget.inventory.isBarcodeTaken,
      );
    });
    if (_nameError != null || _priceError != null || _capitalError != null || _barcodeError != null) return;
    if (category.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Changes', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to save the changes to this product?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isSaving = true);
    String? finalImageUrl = _imagePath;
    if (_imagePath != null && _imagePath != widget.product.image && !_imagePath!.startsWith('http') && !_imagePath!.startsWith('data:image')) {
      try {
        final file = File(_imagePath!);
        if (file.existsSync()) {
          final uploadedUrl = await SupabaseService().uploadProductImage(
            widget.product.id,
            file,
          );
          if (uploadedUrl != null) {
            finalImageUrl = uploadedUrl;
          }
        }
      } catch (e) {
        debugPrint('Error uploading edited product photo: $e');
      }
    }

    if (_isAddingNewCategory) {
      final currentUserId = AuthService().currentUser?.uid ?? 'system';
      widget.inventory.addCategory(category, currentUserId);
    }

    widget.inventory.updateProduct(
      productId: widget.product.id,
      name: name,
      category: category,
      price: price!,
      capital: capital!,
      barcode: barcode,
      image: finalImageUrl,
      lowStockThreshold: threshold,
      isWeightBased: _isWeightBased,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
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
                        ProductImage(
                          image: _imagePath,
                          width: 120,
                          height: 120,
                          borderRadius: 20,
                        ),
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isWeightBased ? 'Capital per kg *' : 'Capital per pc *', style: const TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _capitalController,
                        enabled: false,
                        readOnly: true,
                        decoration: _fieldDecoration(
                          'e.g. 40',
                          prefixText: '₱ ',
                          errorText: _capitalError,
                          suffixIcon: const Icon(Icons.lock_outline, size: 18, color: AppColors.placeholderColor),
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
                      Text(_isWeightBased ? 'Price per kg *' : 'Price per pc *', style: const TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _sellingPriceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: _fieldDecoration(
                          'e.g. 50',
                          prefixText: '₱ ',
                          errorText: _priceError,
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
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

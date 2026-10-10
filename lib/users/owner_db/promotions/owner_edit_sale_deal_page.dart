import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import 'package:sari_sari/models/sale_deal_model.dart';
import 'package:sari_sari/core/services/sale_deal_controller.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/utils/top_notification.dart';
import '../../../shared/widgets/product_image.dart';
import '../../../shared/widgets/product_image_crop_dialog.dart';
import '../../employee_db/employee_inventory_controller.dart';
import '../../employee_db/inventory/employee_product_model.dart';

class OwnerEditSaleDealPage extends StatefulWidget {
  final SaleDealModel? initialDeal;

  const OwnerEditSaleDealPage({super.key, this.initialDeal});

  @override
  State<OwnerEditSaleDealPage> createState() => _OwnerEditSaleDealPageState();
}

class _OwnerEditSaleDealPageState extends State<OwnerEditSaleDealPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _titleController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _limitController;

  String? _imagePath;

  // Key: productId, Value: quantity selected per deal bundle
  final Map<String, int> _selectedProductQuantities = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final deal = widget.initialDeal;
    _titleController = TextEditingController(text: deal?.title ?? '');
    _priceController = TextEditingController(
      text: deal != null ? deal.salePrice.toStringAsFixed(0) : '',
    );
    _descriptionController = TextEditingController(text: deal?.description ?? '');
    _limitController = TextEditingController(
      text: deal?.saleLimit != null ? deal!.saleLimit.toString() : '',
    );
    _imagePath = deal?.image;

    if (deal != null) {
      for (final item in deal.items) {
        _selectedProductQuantities[item.productId] = item.quantity;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  /// Calculates maximum deals that can be constructed based on current physical inventory
  int _calculateMaxPossibleDeals(List<EmployeeProduct> products) {
    if (_selectedProductQuantities.isEmpty) return 0;
    int maxDeals = 999999;
    for (final entry in _selectedProductQuantities.entries) {
      final prod = products.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => EmployeeProduct(
          id: entry.key,
          name: '',
          barcode: '',
          category: '',
          price: 0,
          capital: 0,
          batches: const [],
        ),
      );
      final needed = entry.value;
      if (needed <= 0) continue;
      final stockAvailable = (prod.isExpired ? prod.quantity : prod.sellableQuantity).toInt();
      final possible = stockAvailable ~/ needed;
      if (possible < maxDeals) {
        maxDeals = possible;
      }
    }
    return maxDeals == 999999 ? 0 : maxDeals;
  }

  /// Calculates total regular price of currently selected items
  double _calculateRegularTotal(List<EmployeeProduct> products) {
    double total = 0.0;
    for (final entry in _selectedProductQuantities.entries) {
      final prod = products.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => EmployeeProduct(
          id: entry.key,
          name: '',
          barcode: '',
          category: '',
          price: 0,
          capital: 0,
          batches: const [],
        ),
      );
      total += prod.price * entry.value;
    }
    return total;
  }

  /// Auto-generates a descriptive deal title based on chosen products
  void _suggestTitle(List<EmployeeProduct> allProducts) {
    if (_selectedProductQuantities.isEmpty) return;

    final parts = <String>[];
    for (final entry in _selectedProductQuantities.entries) {
      final prod = allProducts.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => EmployeeProduct(id: entry.key, name: 'Item', barcode: '', category: '', price: 0, capital: 0, batches: const []),
      );
      parts.add('${entry.value}x ${prod.name}');
    }

    final suggestion = parts.length == 1
        ? '${parts.first} Special Promo'
        : 'Combo Deal: ${parts.join(' + ')}';

    setState(() {
      _titleController.text = suggestion;
    });
  }

  @override
  Widget build(BuildContext context) {
    final allProducts = EmployeeInventoryController.instance.products;

    // Sort products with Priority: Expired first, Near-Expiry second, Fresh last
    final sortedProducts = List<EmployeeProduct>.from(allProducts)..sort((a, b) {
      // 1. Expired has top urgency
      if (a.isExpired && !b.isExpired) return -1;
      if (!a.isExpired && b.isExpired) return 1;

      // 2. Near expiry comes next
      if (a.isExpiringSoon && !b.isExpiringSoon) return -1;
      if (!a.isExpiringSoon && b.isExpiringSoon) return 1;

      // 3. Fallback to name alphabetical
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    final filteredProducts = sortedProducts.where((p) {
      if (_searchQuery.trim().isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery.trim().toLowerCase()) ||
          p.category.toLowerCase().contains(_searchQuery.trim().toLowerCase());
    }).toList();

    final regularTotal = _calculateRegularTotal(allProducts);
    final salePrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final savings = regularTotal > salePrice ? regularTotal - salePrice : 0.0;
    final discountPercent = regularTotal > 0 ? ((savings / regularTotal) * 100).round() : 0;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          widget.initialDeal == null ? 'Create On-Sale Deal' : 'Edit On-Sale Deal',
          style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(allProducts, regularTotal),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Pricing & Title Configuration Card
            _buildDealConfigCard(allProducts, regularTotal, salePrice, savings, discountPercent),
            const SizedBox(height: 20),

            // Products Header & Expiry Priority Badge Note
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Products for this Sale',
                  style: TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_selectedProductQuantities.length} selected',
                  style: const TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Near-expiry and expired products are prioritized at the top to help clear inventory.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 12),

            // Search Bar
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search products to include...',
                prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Product List
            if (filteredProducts.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: const Text('No matching products found.', style: TextStyle(color: AppColors.secondaryText)),
              )
            else
              ...filteredProducts.map((product) => _buildProductSelectTile(product, allProducts)),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDealConfigCard(
    List<EmployeeProduct> allProducts,
    double regularTotal,
    double salePrice,
    double savings,
    int discountPercent,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Deal Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.darkText)),
              if (_selectedProductQuantities.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _suggestTitle(allProducts),
                  icon: const Icon(Icons.auto_fix_high, size: 16, color: AppColors.primaryOrange),
                  label: const Text('Auto Title', style: TextStyle(fontSize: 12, color: AppColors.primaryOrange)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Promo Photo Picker Section
          _buildPhotoPickerSection(),
          const SizedBox(height: 14),

          // Sale Deal Title (Max 50 characters, Live Validation)
          TextFormField(
            controller: _titleController,
            maxLength: 50,
            inputFormatters: [
              LengthLimitingTextInputFormatter(50),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Sale Deal Name *',
              hintText: 'e.g. Snack Combo: 1 Piattos + 2 Sardines',
              counterText: '${_titleController.text.length}/50',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: (val) {
              final trimmed = val?.trim() ?? '';
              if (trimmed.isEmpty) return 'Please enter a name for this sale';
              if (trimmed.length > 50) return 'Name must not exceed 50 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Sale Price Input (Numbers only, Live Validation)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Sale / Promo Price *',
                    hintText: 'e.g. 50.00',
                    prefixText: '₱ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (val) {
                    final trimmed = val?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Please enter a sale price';
                    final num = double.tryParse(trimmed);
                    if (num == null) return 'Numbers only allowed';
                    if (num <= 0) return 'Sale price must be greater than ₱0';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Original Price Info Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Regular Total', style: TextStyle(fontSize: 10, color: AppColors.secondaryText)),
                    Text(
                      '₱${regularTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Sale Promo Limit Section (Quota for how many to put on sale)
          const SizedBox(height: 14),
          _buildSaleLimitSection(allProducts),

          // Live Discount Savings Preview
          if (regularTotal > 0 && salePrice > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: savings > 0 ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    savings > 0 ? Icons.check_circle_outline : Icons.info_outline,
                    size: 16,
                    color: savings > 0 ? Colors.green[700] : Colors.orange[800],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      savings > 0
                          ? 'Customer saves ₱${savings.toStringAsFixed(2)} ($discountPercent% OFF)'
                          : 'Promo price is not discounted from regular total.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: savings > 0 ? Colors.green[800] : Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaleLimitSection(List<EmployeeProduct> allProducts) {
    final maxPossibleDeals = _calculateMaxPossibleDeals(allProducts);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.primaryOrange),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Sale Promo Limit (Max Units / Deals)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.darkText),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_selectedProductQuantities.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Max: $maxPossibleDeals deals',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _limitController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'e.g. 10 (units/deals to sell on sale)',
            suffixText: 'deals',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            helperText: _selectedProductQuantities.isEmpty
                ? 'Select products below to determine maximum stock.'
                : 'Sets how many will be sold on promo. Regular stock remains protected.',
            helperMaxLines: 2,
          ),
          validator: (val) {
            final trimmed = val?.trim() ?? '';
            if (trimmed.isEmpty) return null;
            final parsed = int.tryParse(trimmed);
            if (parsed == null || parsed <= 0) return 'Limit must be at least 1 deal';
            if (_selectedProductQuantities.isNotEmpty) {
              final maxAllowed = _calculateMaxPossibleDeals(allProducts);
              if (parsed > maxAllowed) {
                return 'Cannot exceed available stock (max $maxAllowed deals based on stock)';
              }
            }
            return null;
          },
        ),

        // Quick Preset Chips
        if (maxPossibleDeals > 0) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Quick limits: ', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                const SizedBox(width: 4),
                for (final preset in [5, 10, 20])
                  if (preset < maxPossibleDeals)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          setState(() {
                            _limitController.text = preset.toString();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _limitController.text == preset.toString()
                                ? AppColors.primaryOrange
                                : AppColors.lightBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _limitController.text == preset.toString()
                                  ? AppColors.primaryOrange
                                  : AppColors.borderColor,
                            ),
                          ),
                          child: Text(
                            '$preset',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _limitController.text == preset.toString()
                                  ? Colors.white
                                  : AppColors.darkText,
                            ),
                          ),
                        ),
                      ),
                    ),
                // Max Stock Chip
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      _limitController.text = maxPossibleDeals.toString();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _limitController.text == maxPossibleDeals.toString()
                          ? AppColors.primaryOrange
                          : AppColors.lightBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _limitController.text == maxPossibleDeals.toString()
                            ? AppColors.primaryOrange
                            : AppColors.borderColor,
                      ),
                    ),
                    child: Text(
                      'Max Stock ($maxPossibleDeals)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _limitController.text == maxPossibleDeals.toString()
                            ? Colors.white
                            : AppColors.darkText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _adjustSaleLimitAfterProductChange(List<EmployeeProduct> allProducts) {
    final maxDeals = _calculateMaxPossibleDeals(allProducts);
    final currentLimit = int.tryParse(_limitController.text.trim());
    if (maxDeals > 0) {
      if (currentLimit == null || currentLimit <= 0) {
        _limitController.text = (maxDeals < 10 ? maxDeals : 10).toString();
      } else if (currentLimit > maxDeals) {
        _limitController.text = maxDeals.toString();
        TopNotification.show(
          context,
          'Sale limit adjusted to $maxDeals (maximum available from inventory)',
        );
      }
    }
  }

  Widget _buildProductSelectTile(EmployeeProduct product, List<EmployeeProduct> allProducts) {
    final qty = _selectedProductQuantities[product.id] ?? 0;
    final isSelected = qty > 0;
    final maxStock = (product.isExpired ? product.quantity : product.sellableQuantity).toInt();
    final isOutOfStock = maxStock <= 0;

    // Expiry tag indicator
    Widget? expiryBadge;
    if (product.isExpired) {
      expiryBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red.shade400, width: 0.8),
        ),
        child: const Text(
          'EXPIRED STOCK',
          style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold),
        ),
      );
    } else if (product.isExpiringSoon) {
      expiryBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.orange.shade400, width: 0.8),
        ),
        child: const Text(
          'NEAR EXPIRY',
          style: TextStyle(color: Colors.deepOrange, fontSize: 9, fontWeight: FontWeight.bold),
        ),
      );
    } else if (isOutOfStock) {
      expiryBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red.shade400, width: 0.8),
        ),
        child: const Text(
          'OUT OF STOCK',
          style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      expiryBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Fresh ($maxStock left)',
          style: TextStyle(color: Colors.green[700], fontSize: 9, fontWeight: FontWeight.w500),
        ),
      );
    }

    return Opacity(
      opacity: isOutOfStock ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryOrange.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : AppColors.borderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (isOutOfStock) {
              TopNotification.show(context, '"${product.name}" is out of stock', isError: true);
              return;
            }
            setState(() {
              if (qty == 0) {
                _selectedProductQuantities[product.id] = 1;
              } else {
                _selectedProductQuantities.remove(product.id);
              }
              _adjustSaleLimitAfterProductChange(allProducts);
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Checkbox indicator
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText,
                  size: 22,
                ),
                const SizedBox(width: 12),

                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: TextStyle(
                                color: AppColors.darkText,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          expiryBadge,
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₱${product.price.toStringAsFixed(2)} each • ${product.category}',
                        style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Quantity Stepper (if selected)
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 22),
                        color: AppColors.secondaryText,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            if (qty > 1) {
                              _selectedProductQuantities[product.id] = qty - 1;
                            } else {
                              _selectedProductQuantities.remove(product.id);
                            }
                            _adjustSaleLimitAfterProductChange(allProducts);
                          });
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$qty',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryOrange),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 22),
                        color: qty < maxStock ? AppColors.primaryOrange : Colors.grey.shade400,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (qty < maxStock) {
                            setState(() {
                              _selectedProductQuantities[product.id] = qty + 1;
                              _adjustSaleLimitAfterProductChange(allProducts);
                            });
                          } else {
                            TopNotification.show(
                              context,
                              'Cannot exceed available stock ($maxStock left for ${product.name})',
                              isError: true,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPickerSection() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.lightBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _imagePath != null ? AppColors.primaryOrange : AppColors.borderColor,
            width: _imagePath != null ? 1.5 : 1.0,
          ),
        ),
        child: _imagePath == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_a_photo, color: AppColors.primaryOrange, size: 24),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add Promotional Photo (Optional)',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Max 5MB • Crop & Preview available',
                    style: TextStyle(color: AppColors.secondaryText, fontSize: 11),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductImage(
                      image: _imagePath,
                      width: double.infinity,
                      height: 120,
                      borderRadius: 11,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit, size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('Change', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() => _imagePath = null),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.85),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.delete_outline, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
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
                    'Promotional Deal Photo',
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
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked != null) {
        if (!mounted) return;
        final confirmedPath = await showProductImageCropDialog(
          context: context,
          xfile: picked,
        );

        if (confirmedPath != null && mounted) {
          setState(() {
            _imagePath = confirmedPath;
          });
          TopNotification.show(
            context,
            'Promo photo updated',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        TopNotification.show(
          context,
          "Couldn't access image. Please check app permissions.",
          isError: true,
        );
      }
    }
  }

  Widget _buildBottomBar(List<EmployeeProduct> allProducts, double regularTotal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _saveDeal(allProducts),
            child: Text(
              widget.initialDeal == null ? 'Publish Sale Deal' : 'Save Changes',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showPreviewConfirmationDialog(SaleDealModel deal) {
    final isNew = widget.initialDeal == null;
    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_offer, color: AppColors.primaryOrange, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isNew ? 'Preview & Confirm Deal' : 'Preview Changes',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Review the sale deal details before publishing to customers.',
                    style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
                  ),
                  const SizedBox(height: 12),

                  // Promotional Photo Preview (if set or fallback to item photo)
                  if (deal.effectiveImage != null && deal.effectiveImage!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ProductImage(
                        image: deal.effectiveImage,
                        width: 320,
                        height: 140,
                        borderRadius: 12,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                // Deal Name Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DEAL NAME',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryText,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        deal.title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkText),
                      ),
                      if (deal.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          deal.description,
                          style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Products List Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Included Products',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkText),
                    ),
                    Text(
                      '${deal.totalItemQuantity} item${deal.totalItemQuantity > 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryOrange),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Column(
                    children: deal.items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final itemSubtotal = item.originalPrice * item.quantity;
                      final isLast = index == deal.items.length - 1;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.borderColor, width: 0.8)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryOrange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item.quantity}x',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.productName,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.darkText),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '₱${itemSubtotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Promo Sale Limit Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.production_quantity_limits, size: 18, color: AppColors.primaryOrange),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SALE PROMO LIMIT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondaryText,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${deal.saleLimit ?? "Full stock"} deals available on promo',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkText),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Only this promo quota will be sold at sale price. Regular inventory is protected.',
                              style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Pricing Summary Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Regular Total:', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                          Text(
                            '₱${deal.originalTotalPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              decoration: deal.discountSavings > 0 ? TextDecoration.lineThrough : null,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Promo Sale Price:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkText),
                          ),
                          Text(
                            '₱${deal.salePrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ],
                      ),
                      if (deal.discountSavings > 0) ...[
                        const Divider(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Customer Savings:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green)),
                            Flexible(
                              child: Text(
                                'Save ₱${deal.discountSavings.toStringAsFixed(2)} (${deal.discountPercentage}% OFF)',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Back to Edit', style: TextStyle(color: AppColors.secondaryText)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(
                isNew ? 'Confirm & Publish' : 'Confirm & Save',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveDeal(List<EmployeeProduct> allProducts) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProductQuantities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one product for this sale deal!')),
      );
      return;
    }

    final salePrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
    if (salePrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid sale price!')),
      );
      return;
    }

    final maxPossible = _calculateMaxPossibleDeals(allProducts);
    final rawLimit = _limitController.text.trim();
    int? saleLimit = rawLimit.isNotEmpty ? int.tryParse(rawLimit) : null;
    if (saleLimit == null && maxPossible > 0) {
      saleLimit = maxPossible;
    }
    if (saleLimit != null && maxPossible > 0 && saleLimit > maxPossible) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sale limit cannot exceed available stock (max $maxPossible deals)!')),
      );
      return;
    }

    final items = <SaleDealItem>[];
    for (final entry in _selectedProductQuantities.entries) {
      final prod = allProducts.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => EmployeeProduct(id: entry.key, name: 'Product', barcode: '', category: '', price: 0, capital: 0, batches: const []),
      );
      items.add(SaleDealItem(
        productId: prod.id,
        productName: prod.name,
        quantity: entry.value,
        originalPrice: prod.price,
        image: prod.image,
        unit: prod.unit,
      ));
    }

    final dealId = widget.initialDeal?.id ?? 'deal-${DateTime.now().millisecondsSinceEpoch}';
    final previewDeal = SaleDealModel(
      id: dealId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      image: _imagePath,
      salePrice: salePrice,
      items: items,
      isActive: widget.initialDeal?.isActive ?? true,
      createdAt: widget.initialDeal?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      saleLimit: saleLimit,
      soldCount: widget.initialDeal?.soldCount ?? 0,
    );

    // Show Preview & Confirmation Dialog before proceeding
    final confirmed = await _showPreviewConfirmationDialog(previewDeal);
    if (confirmed != true) return;
    if (!mounted) return;

    // Show quick feedback that deal is being processed
    TopNotification.show(context, 'Saving sale deal...');

    String? finalImageUrl;
    if (_imagePath != null && _imagePath!.trim().isNotEmpty) {
      final trimmedPath = _imagePath!.trim();
      if (trimmedPath.startsWith('http://') ||
          trimmedPath.startsWith('https://') ||
          trimmedPath.startsWith('data:image/')) {
        finalImageUrl = trimmedPath;
      } else {
        try {
          final uploadedUrl = await SupabaseService().uploadProductImageFromPathOrBytes(
            productId: 'deal_$dealId',
            filePath: trimmedPath,
          );
          if (uploadedUrl != null &&
              uploadedUrl.isNotEmpty &&
              !uploadedUrl.startsWith('/') &&
              !uploadedUrl.startsWith('file://')) {
            finalImageUrl = uploadedUrl;
            debugPrint('Sale deal promo image uploaded: $finalImageUrl');
          } else {
            // Absolute safety fallback: convert file bytes directly to Base64 data URI
            String cleanPath = trimmedPath;
            if (cleanPath.startsWith('file://')) cleanPath = cleanPath.substring(7);
            final file = File(cleanPath);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              final ext = cleanPath.endsWith('.png') ? 'png' : 'jpg';
              finalImageUrl = 'data:image/$ext;base64,${base64Encode(bytes)}';
            }
          }
        } catch (e) {
          debugPrint('Error uploading deal image: $e');
        }
      }
    }

    final finalDeal = previewDeal.copyWith(image: finalImageUrl);
    final success = await SaleDealController.instance.saveDeal(finalDeal);
    if (mounted) {
      if (success) {
        Navigator.pop(context, true);
        TopNotification.show(
          context,
          widget.initialDeal == null
              ? 'On-Sale Deal created successfully!'
              : 'On-Sale Deal updated successfully!',
        );
      } else {
        TopNotification.show(
          context,
          'Failed to save deal to backend. Please check connection.',
          isError: true,
        );
      }
    }
  }
}

import 'package:flutter/material.dart';

import '../../../core/expiry/expiry_checker.dart';
import '../../../core/theme/app_colors.dart';
import '../employee_inventory_controller.dart';
import 'employee_batch_detail_sheet.dart';
import 'employee_product_model.dart';
import 'employee_edit_product_page.dart';
import 'employee_add_product_page.dart';
import 'employee_archive_stock_dialog.dart';
import 'employee_consume_stock_dialog.dart';
import '../../../shared/widgets/barcode_scanner_screen.dart';
import '../../../shared/widgets/product_image.dart';

/// Employee "Inventory" tab: view current stock and adjust it manually
/// (Inventory and Stock Management feature).
class EmployeeInventoryPage extends StatefulWidget {
  const EmployeeInventoryPage({super.key, required this.inventory});
  final EmployeeInventoryController inventory;

  @override
  State<EmployeeInventoryPage> createState() => _EmployeeInventoryPageState();
}

class _EmployeeInventoryPageState extends State<EmployeeInventoryPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _lowStockOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<EmployeeProduct> _filter(List<EmployeeProduct> products) {
    final query = _searchQuery.trim().toLowerCase();
    return products.where((product) {
      final matchesCategory =
          _selectedCategory == 'All' || product.category == _selectedCategory;
      final matchesSearch = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.barcode.contains(query);
      final matchesLowStock = !_lowStockOnly ||
          product.stockStatus == EmployeeStockStatus.lowStock ||
          product.stockStatus == EmployeeStockStatus.outOfStock;
      return matchesCategory && matchesSearch && matchesLowStock;
    }).toList();
  }

  void _openEditProduct(EmployeeProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeEditProductPage(
          inventory: widget.inventory,
          product: product,
        ),
      ),
    );
  }

  /// Opens the Add Product screen (barcode scan, search-to-restock, or
  /// add manually, then quantity/expiration-date/supplier/notes entry) —
  /// the primary way new stock gets added, separate from the quick +/- of
  /// [EmployeeStockAdjustSheet].
  void _openAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeAddProductPage(inventory: widget.inventory),
      ),
    );
  }

  /// Path B of the Expiration Notification flow: tapping a product card
  /// directly (not via a sale) opens the full batch breakdown — every
  /// batch, not just sellable ones — for proactive monitoring.
  void _openBatchDetail(EmployeeProduct product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => EmployeeBatchDetailSheet(
        product: product,
        inventory: widget.inventory,
        onEditProduct: () {
          Navigator.pop(sheetContext);
          _openEditProduct(product);
        },
        onArchiveProduct: () {
          Navigator.pop(sheetContext);
          _showArchiveDialog(product);
        },
        onConsumeProduct: () {
          Navigator.pop(sheetContext);
          _showConsumeDialog(product);
        },
      ),
    );
  }

  void _showArchiveDialog(EmployeeProduct product) {
    showDialog(
      context: context,
      builder: (context) => EmployeeArchiveStockDialog(
        product: product,
        inventory: widget.inventory,
      ),
    );
  }

  /// Opens the Consumables dialog — used when the owner or an employee
  /// takes stock for their own use rather than selling it.
  void _showConsumeDialog(EmployeeProduct product) {
    showDialog(
      context: context,
      builder: (context) => EmployeeConsumeStockDialog(
        product: product,
        inventory: widget.inventory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.inventory,
          builder: (context, _) {
            final products = _filter(widget.inventory.products);
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Inventory',
                          style: TextStyle(
                              color: AppColors.darkText, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          onPressed: _openAddProduct,
                          icon: const Icon(Icons.add_box_outlined, size: 18),
                          label: const Text('Add Product'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _buildSearchBar()),
                SliverToBoxAdapter(child: _buildFilters()),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                if (products.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyState())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    sliver: SliverList.separated(
                      itemCount: products.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return _InventoryItemCard(
                          product: product,
                          onTap: () => _openBatchDetail(product),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by name or barcode...',
          hintStyle: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.5), fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText),
          suffixIcon: IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.primaryOrange),
            onPressed: () async {
              final code = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
              );
              if (code != null && code.isNotEmpty) {
                if (!mounted) return;
                final existing = widget.inventory.findByBarcode(code);
                if (existing != null) {
                  _openBatchDetail(existing);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmployeeAddProductPage(
                        inventory: widget.inventory,
                        initialBarcode: code,
                      ),
                    ),
                  );
                }
              }
            },
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.borderColor.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          FilterChip(
            label: const Text('Low / Out of Stock'),
            selected: _lowStockOnly,
            onSelected: (value) => setState(() => _lowStockOnly = value),
            showCheckmark: false,
            labelStyle: TextStyle(
              color: _lowStockOnly ? Colors.white : AppColors.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            selectedColor: AppColors.primaryOrange,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: _lowStockOnly
                    ? AppColors.primaryOrange
                    : AppColors.borderColor.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ...widget.inventory.categories.map((category) {
            final isSelected = category == _selectedCategory;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category),
                selected: isSelected,
                showCheckmark: false,
                onSelected: (_) => setState(() => _selectedCategory = category),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.secondaryText,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                selectedColor: AppColors.primaryOrange,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primaryOrange
                        : AppColors.borderColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 40, color: AppColors.secondaryText.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('No products found',
              style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

class _InventoryItemCard extends StatelessWidget {
  const _InventoryItemCard({required this.product, required this.onTap});
  final EmployeeProduct product;
  final VoidCallback onTap;

  Color get _statusColor {
    switch (product.stockStatus) {
      case EmployeeStockStatus.inStock:
        return Colors.green;
      case EmployeeStockStatus.lowStock:
        return Colors.orange;
      case EmployeeStockStatus.outOfStock:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            ProductImage(
              image: product.image,
              width: 56,
              height: 56,
              borderRadius: 12,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(color: AppColors.darkText, fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text('₱${product.price.toStringAsFixed(2)} · ${product.category}',
                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(
                        '${product.stockStatus.label} · Qty: ${product.quantity.toInt()} ${product.unit}',
                        style: TextStyle(fontSize: 11, color: _statusColor, fontWeight: FontWeight.w600),
                      ),
                      if (product.expiryStatus != ExpiryStatus.none) ...[
                        const SizedBox(width: 8),
                        _buildExpiryMarker(product.expiryStatus),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.placeholderColor),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiryMarker(ExpiryStatus status) {
    Color color;
    IconData icon;
    switch (status) {
      case ExpiryStatus.expired:
        color = Colors.red;
        icon = Icons.block;
        break;
      case ExpiryStatus.fiveDays:
        color = Colors.deepOrange;
        icon = Icons.event_busy;
        break;
      case ExpiryStatus.twoWeeks:
        color = Colors.orange;
        icon = Icons.event_note;
        break;
      case ExpiryStatus.none:
        return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          status.label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
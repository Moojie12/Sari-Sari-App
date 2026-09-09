import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../employee_db/employee_inventory_controller.dart';
import '../../employee_db/inventory/employee_batch_model.dart';
import '../../employee_db/inventory/employee_expiry_badge.dart';
import '../../employee_db/inventory/employee_product_model.dart';
import '../../employee_db/inventory/employee_edit_product_page.dart';
import '../../employee_db/inventory/employee_add_product_page.dart';
import '../../employee_db/inventory/employee_archive_stock_dialog.dart';

class OwnerInventoryPage extends StatefulWidget {
  const OwnerInventoryPage({super.key, required this.inventory});
  final EmployeeInventoryController inventory;

  @override
  State<OwnerInventoryPage> createState() => _OwnerInventoryPageState();
}

class _OwnerInventoryPageState extends State<OwnerInventoryPage> {
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
      final matchesCategory = _selectedCategory == 'All' || product.category == _selectedCategory;
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

  void _openAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeAddProductPage(inventory: widget.inventory),
      ),
    );
  }

  void _openBatchDetail(EmployeeProduct product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _OwnerBatchDetailSheet(
        product: product,
        onEditProduct: () {
          Navigator.pop(sheetContext);
          _openEditProduct(product);
        },
        onArchiveProduct: () {
          Navigator.pop(sheetContext);
          _showArchiveDialog(product);
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
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: AppColors.lightBackground, borderRadius: BorderRadius.circular(12)),
              child: product.image != null
                  ? const Icon(Icons.image, color: AppColors.primaryOrange, size: 26)
                  : const Icon(Icons.image_outlined, color: AppColors.placeholderColor, size: 26),
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
                        '${product.stockStatus.label} · Qty: ${product.quantity}',
                        style: TextStyle(fontSize: 11, color: _statusColor, fontWeight: FontWeight.w600),
                      ),
                      if (product.hasExpiredBatch) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.block, size: 12, color: Colors.red),
                        const SizedBox(width: 2),
                        const Text('Expired batch',
                            style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
                      ] else if (product.isExpiringSoon) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.event_busy, size: 12, color: Colors.deepOrange),
                        const SizedBox(width: 2),
                        const Text('Expiring soon',
                            style: TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.w600)),
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
}

class _OwnerBatchDetailSheet extends StatelessWidget {
  const _OwnerBatchDetailSheet({
    required this.product,
    required this.onEditProduct,
    required this.onArchiveProduct,
  });

  final EmployeeProduct product;
  final VoidCallback onEditProduct;
  final VoidCallback onArchiveProduct;

  @override
  Widget build(BuildContext context) {
    final batches = product.batches;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
          ),
          const SizedBox(height: 4),
          Text(
            'Barcode: ${product.barcode} · Total on hand: ${product.quantity} pcs',
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 16),
          const Text('All Batches',
              style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          if (batches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No batches on record.',
                style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.7)),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: batches.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _BatchDetailRow(batch: batches[index]),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onEditProduct,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryOrange,
                    side: const BorderSide(color: AppColors.primaryOrange),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onArchiveProduct,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Archive', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BatchDetailRow extends StatelessWidget {
  const _BatchDetailRow({required this.batch});
  final ProductBatch batch;

  @override
  Widget build(BuildContext context) {
    final dateLabel = batch.expiryDate == null
        ? 'No expiry date'
        : '${batch.expiryDate!.day}/${batch.expiryDate!.month}/${batch.expiryDate!.year}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Batch ${batch.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText, fontSize: 13)),
                const SizedBox(height: 2),
                Text('Expiry: $dateLabel', style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
                Text('${batch.quantity} pcs', style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
              ],
            ),
          ),
          ExpiryBadge(status: batch.expiryStatus()),
        ],
      ),
    );
  }
}

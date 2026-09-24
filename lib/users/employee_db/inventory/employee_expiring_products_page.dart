import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../employee_inventory_controller.dart';
import 'employee_batch_detail_sheet.dart';
import 'employee_expiry_badge.dart';
import 'employee_product_model.dart';
import 'employee_edit_product_page.dart';
import 'employee_archive_stock_dialog.dart';
import 'employee_consume_stock_dialog.dart';

enum ExpiryFilterTab { all, expired, fiveDays, twoWeeks }

class EmployeeExpiringProductsPage extends StatefulWidget {
  const EmployeeExpiringProductsPage({
    super.key,
    required this.inventory,
    this.initialFilter = ExpiryFilterTab.all,
  });

  final EmployeeInventoryController inventory;
  final ExpiryFilterTab initialFilter;

  @override
  State<EmployeeExpiringProductsPage> createState() => _EmployeeExpiringProductsPageState();
}

class _EmployeeExpiringProductsPageState extends State<EmployeeExpiringProductsPage> {
  late ExpiryFilterTab _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialFilter;
  }

  void _openBatchDetail(BuildContext context, EmployeeProduct product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => EmployeeBatchDetailSheet(
        product: product,
        inventory: widget.inventory,
        onEditProduct: () {
          Navigator.pop(sheetContext);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmployeeEditProductPage(
                inventory: widget.inventory,
                product: product,
              ),
            ),
          );
        },
        onArchiveProduct: () {
          Navigator.pop(sheetContext);
          _showArchiveDialog(context, product);
        },
        onConsumeProduct: () {
          Navigator.pop(sheetContext);
          _showConsumeDialog(context, product);
        },
      ),
    );
  }

  void _showArchiveDialog(BuildContext context, EmployeeProduct product) {
    showDialog(
      context: context,
      builder: (context) => EmployeeArchiveStockDialog(
        product: product,
        inventory: widget.inventory,
      ),
    );
  }

  void _showConsumeDialog(BuildContext context, EmployeeProduct product) {
    showDialog(
      context: context,
      builder: (context) => EmployeeConsumeStockDialog(
        product: product,
        inventory: widget.inventory,
      ),
    );
  }

  List<EmployeeProduct> _getFilteredProducts() {
    final inv = widget.inventory;
    switch (_selectedTab) {
      case ExpiryFilterTab.expired:
        return inv.expiredProducts;
      case ExpiryFilterTab.fiveDays:
        return inv.expiringIn5DaysProducts;
      case ExpiryFilterTab.twoWeeks:
        return inv.expiringIn2WeeksProducts;
      case ExpiryFilterTab.all:
        final Set<String> ids = {};
        final combined = <EmployeeProduct>[];
        for (final p in [
          ...inv.expiredProducts,
          ...inv.expiringIn5DaysProducts,
          ...inv.expiringIn2WeeksProducts,
          ...inv.expiringSoonProducts,
        ]) {
          if (ids.add(p.id)) {
            combined.add(p);
          }
        }
        return combined;
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
        title: const Text('Expiring Products', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListenableBuilder(
        listenable: widget.inventory,
        builder: (context, _) {
          final expiringList = _getFilteredProducts();

          return Column(
            children: [
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    _FilterChipItem(
                      label: 'All (${widget.inventory.expiredProducts.length + widget.inventory.expiringSoonProducts.length})',
                      isSelected: _selectedTab == ExpiryFilterTab.all,
                      onTap: () => setState(() => _selectedTab = ExpiryFilterTab.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipItem(
                      label: 'Expired (${widget.inventory.expiredProducts.length})',
                      isSelected: _selectedTab == ExpiryFilterTab.expired,
                      color: Colors.red,
                      onTap: () => setState(() => _selectedTab = ExpiryFilterTab.expired),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipItem(
                      label: '5 Days (${widget.inventory.expiringIn5DaysProducts.length})',
                      isSelected: _selectedTab == ExpiryFilterTab.fiveDays,
                      color: Colors.deepOrange,
                      onTap: () => setState(() => _selectedTab = ExpiryFilterTab.fiveDays),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipItem(
                      label: '2 Weeks (${widget.inventory.expiringIn2WeeksProducts.length})',
                      isSelected: _selectedTab == ExpiryFilterTab.twoWeeks,
                      color: Colors.orange,
                      onTap: () => setState(() => _selectedTab = ExpiryFilterTab.twoWeeks),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: expiringList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_available, size: 64, color: AppColors.borderColor),
                            const SizedBox(height: 16),
                            const Text('No expiring products found in this category',
                                style: TextStyle(color: AppColors.secondaryText)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        itemCount: expiringList.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final product = expiringList[index];
                          return GestureDetector(
                            onTap: () => _openBatchDetail(context, product),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.lightBackground,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: product.image != null
                                        ? const Icon(Icons.image, color: AppColors.primaryOrange)
                                        : const Icon(Icons.inventory_2_outlined, color: AppColors.placeholderColor),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: const TextStyle(
                                            color: AppColors.darkText,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${product.isWeightBased ? product.quantity.toStringAsFixed(2) : product.quantity.round()} pcs remaining',
                                          style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ExpiryBadge(status: product.expiryStatus),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
    required this.label,
    required this.isSelected,
    this.color = AppColors.primaryOrange,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: color,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.darkText,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? color : AppColors.borderColor),
      ),
      showCheckmark: false,
    );
  }
}
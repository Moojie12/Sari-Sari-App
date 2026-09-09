import 'package:flutter/material.dart';
import '../../../core/expiry/expiry_checker.dart';
import '../../../core/theme/app_colors.dart';
import '../employee_inventory_controller.dart';
import 'employee_batch_detail_sheet.dart';
import 'employee_expiry_badge.dart';
import 'employee_product_model.dart';
import 'employee_edit_product_page.dart';
import 'employee_archive_stock_dialog.dart';

class EmployeeExpiringProductsPage extends StatelessWidget {
  const EmployeeExpiringProductsPage({super.key, required this.inventory});

  final EmployeeInventoryController inventory;

  void _openBatchDetail(BuildContext context, EmployeeProduct product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => EmployeeBatchDetailSheet(
        product: product,
        onEditProduct: () {
          Navigator.pop(sheetContext);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmployeeEditProductPage(
                inventory: inventory,
                product: product,
              ),
            ),
          );
        },
        onArchiveProduct: () {
          Navigator.pop(sheetContext);
          _showArchiveDialog(context, product);
        },
      ),
    );
  }

  void _showArchiveDialog(BuildContext context, EmployeeProduct product) {
    showDialog(
      context: context,
      builder: (context) => EmployeeArchiveStockDialog(
        product: product,
        inventory: inventory,
      ),
    );
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
        listenable: inventory,
        builder: (context, _) {
          final expiringList = [
            ...inventory.expiredProducts,
            ...inventory.expiringSoonProducts,
          ];

          if (expiringList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available, size: 64, color: AppColors.borderColor),
                  const SizedBox(height: 16),
                  const Text('No expiring products found', style: TextStyle(color: AppColors.secondaryText)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24),
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
                              '${product.quantity} pcs remaining',
                              style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      ExpiryBadge(
                        status: product.hasExpiredBatch
                            ? ExpiryStatus.expired
                            : ExpiryStatus.expiringSoon,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

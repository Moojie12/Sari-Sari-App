import 'package:flutter/material.dart';

import '../../../core/expiry/expiry_checker.dart';
import '../../../core/theme/app_colors.dart';
import '../employee_inventory_controller.dart';
import '../inventory/employee_batch_detail_sheet.dart';
import '../inventory/employee_expiry_badge.dart';
import '../inventory/employee_product_model.dart';
import '../inventory/employee_stock_adjust_sheet.dart';
import '../pos/employee_pos_controller.dart';

/// Employee "Home" tab: a quick dashboard overview for staff (Dashboard
/// feature) — stock alerts at a glance, with shortcuts into the POS and
/// Inventory tabs.
class EmployeeHomePage extends StatelessWidget {
  const EmployeeHomePage({
    super.key,
    required this.inventory,
    required this.posController,
    required this.onOpenPos,
    required this.onOpenInventory,
  });

  final EmployeeInventoryController inventory;
  final EmployeePosController posController;
  final VoidCallback onOpenPos;
  final VoidCallback onOpenInventory;

  /// Path B of the Expiration Notification flow, reached from Home: tapping
  /// an entry in "Expiring Products" opens the same full batch breakdown
  /// used from the Inventory tab — one shared sheet, another entry point.
  void _openBatchDetail(BuildContext context, EmployeeProduct product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => EmployeeBatchDetailSheet(
        product: product,
        onAdjustStock: () {
          Navigator.pop(sheetContext);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => EmployeeStockAdjustSheet(
              product: product,
              onAdjust: (delta) => inventory.adjustStock(product.id, delta),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([inventory, posController]),
          builder: (context, _) {
            final restockList = [
              ...inventory.outOfStockProducts,
              ...inventory.lowStockProducts,
            ];
            final expiringList = [
              ...inventory.expiredProducts,
              ...inventory.expiringSoonProducts,
            ];
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Home',
                      style: TextStyle(color: AppColors.darkText, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    "Here's what needs attention today.",
                    style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.7), fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Low Stock',
                          value: '${inventory.lowStockProducts.length}',
                          icon: Icons.trending_down,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Out of Stock',
                          value: '${inventory.outOfStockProducts.length}',
                          icon: Icons.remove_shopping_cart_outlined,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: onOpenInventory,
                          child: _StatCard(
                            label: 'Expiring Soon',
                            value: '${inventory.expiringSoonProducts.length}',
                            icon: Icons.event_busy,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Items in Current Sale',
                          value: '${posController.itemCount}',
                          icon: Icons.point_of_sale,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text('Quick Actions',
                      style: TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionButton(
                            label: 'New Sale', icon: Icons.point_of_sale, onTap: onOpenPos),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickActionButton(
                            label: 'Check Inventory', icon: Icons.inventory_2_outlined, onTap: onOpenInventory),
                      ),
                    ],
                  ),
                  if (restockList.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const Text('Needs Restocking',
                        style: TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...restockList.take(5).map(
                          (product) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration:
                          BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product.name,
                                  style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${product.quantity} left',
                                style: TextStyle(
                                  color: product.quantity == 0 ? Colors.red : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (expiringList.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const Text('Expiring Products',
                        style: TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...expiringList.take(5).map(
                          (product) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => _openBatchDetail(context, product),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration:
                            BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    product.name,
                                    style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(color: AppColors.darkText, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryOrange.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primaryOrange),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(color: AppColors.primaryOrange, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
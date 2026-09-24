import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../employee_inventory_controller.dart';
import '../inventory/employee_product_model.dart';
import 'employee_profile_controller.dart';

/// Shows the signed-in account's own Consumables (Personal Use) records —
/// filtered from the shared archived-stock log by the auto-recorded
/// "Name (Role)" label, so an owner or employee can see what they
/// personally took without digging through the full Archived Products list.
class EmployeeMyConsumablesPage extends StatelessWidget {
  const EmployeeMyConsumablesPage({super.key, required this.role});

  /// 'Owner' or 'Employee' — must match the role passed to
  /// EmployeeConsumeStockDialog on this dashboard, so the label lines up.
  final String role;

  @override
  Widget build(BuildContext context) {
    final inventory = EmployeeInventoryController.instance;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('My Consumables',
            style: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkText),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([inventory, EmployeeProfileController.instance]),
        builder: (context, _) {
          final profile = EmployeeProfileController.instance.profile;
          final name = '${profile.firstName} ${profile.lastName}'.trim();
          final myLabel = '${name.isEmpty ? profile.role : name} ($role)';

          final mine = inventory.archivedStock
              .where((item) =>
          item.reason == StockRemovalReason.consumable && item.consumedBy == myLabel)
              .toList()
            ..sort((a, b) => b.archivedAt.compareTo(a.archivedAt));

          if (mine.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.set_meal_outlined,
                      size: 64, color: AppColors.secondaryText.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text('No personal-use records yet',
                      style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.6))),
                ],
              ),
            );
          }

          final totalCost = mine.fold<double>(0.0, (sum, item) => sum - item.profit);

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: mine.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Personal-Use Cost',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkText)),
                      Text('₱${totalCost.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                    ],
                  ),
                );
              }
              return _MyConsumableCard(item: mine[index - 1]);
            },
          );
        },
      ),
    );
  }
}

class _MyConsumableCard extends StatelessWidget {
  const _MyConsumableCard({required this.item});
  final ArchivedStockItem item;

  @override
  Widget build(BuildContext context) {
    final dateStr = '${item.archivedAt.day}/${item.archivedAt.month}/${item.archivedAt.year}';

    return Container(
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.lightBackground, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.set_meal_outlined, color: AppColors.primaryOrange, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(color: AppColors.darkText, fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text('Qty: ${item.quantity.toInt()} · ${item.displayBatchLabel}',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                const SizedBox(height: 2),
                Text('Cost: ₱${item.capital.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 12, fontWeight: FontWeight.w600)),
                Text('Taken on: $dateStr',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 11, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../../employee_db/employee_inventory_controller.dart';
import '../../employee_db/inventory/employee_product_model.dart';

class OwnerArchivedProductsPage extends StatelessWidget {
  const OwnerArchivedProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final inventory = EmployeeInventoryController.instance;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Archived Products',
            style: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkText),
      ),
      body: ListenableBuilder(
        listenable: inventory,
        builder: (context, _) {
          final archived = inventory.archivedStock;

          if (archived.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined,
                      size: 64, color: AppColors.secondaryText.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text('No archived stock records',
                      style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.6))),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: archived.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = archived[index];
              return _ArchivedStockCard(
                item: item,
                onRestore: () => _showRestoreConfirmation(context, inventory, item),
                onDelete: () => _showDeleteConfirmation(context, inventory, item),
              );
            },
          );
        },
      ),
    );
  }

  void _showRestoreConfirmation(
      BuildContext context, EmployeeInventoryController inventory, ArchivedStockItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Stock'),
        content: Text('Are you sure you want to restore ${item.quantity} pcs of "${item.productName}" (Batch ${item.batchId}) to the active inventory?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              inventory.restoreArchivedStock(item.id);
              Navigator.pop(context);
              TopNotification.show(context, 'Stock restored to active inventory.');
            },
            child: const Text('Restore', style: TextStyle(color: AppColors.primaryOrange)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, EmployeeInventoryController inventory, ArchivedStockItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permanently'),
        content: Text(
            'Are you sure you want to permanently delete this archive record for "${item.productName}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              inventory.deleteArchivedStock(item.id);
              Navigator.pop(context);
              TopNotification.show(context, 'Archived record deleted permanently.');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ArchivedStockCard extends StatelessWidget {
  const _ArchivedStockCard({
    required this.item,
    required this.onRestore,
    required this.onDelete,
  });

  final ArchivedStockItem item;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateStr = item.expiryDate == null
        ? 'No Expiry'
        : '${item.expiryDate!.day}/${item.expiryDate!.month}/${item.expiryDate!.year}';
    final archivedDate = '${item.archivedAt.day}/${item.archivedAt.month}/${item.archivedAt.year}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration:
                BoxDecoration(color: AppColors.lightBackground, borderRadius: BorderRadius.circular(12)),
            child: item.image != null
                ? const Icon(Icons.image, color: AppColors.primaryOrange, size: 24)
                : const Icon(Icons.image_outlined, color: AppColors.placeholderColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                      color: AppColors.darkText, fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('Qty: ${item.quantity} · Batch: ${item.batchId}',
                    style: const TextStyle(color: AppColors.darkText, fontSize: 12, fontWeight: FontWeight.w600)),
                Text('Expiry: $dateStr',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
                Text('Archived on: $archivedDate',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 10, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onRestore,
                icon: const Icon(Icons.unarchive, color: AppColors.primaryOrange, size: 20),
                tooltip: 'Restore',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                tooltip: 'Delete Permanently',
              ),
            ],
          ),
        ],
      ),
    );
  }
}


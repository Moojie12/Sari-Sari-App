import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../employee_inventory_controller.dart';
import 'employee_batch_model.dart';
import 'employee_expiry_badge.dart';
import 'employee_product_model.dart';

/// Detailed batch breakdown shown when staff tap a product card directly
/// in the Inventory tab.
class EmployeeBatchDetailSheet extends StatefulWidget {
  const EmployeeBatchDetailSheet({
    super.key,
    required this.product,
    required this.inventory,
    required this.onEditProduct,
    required this.onArchiveProduct,
    required this.onConsumeProduct,
  });

  final EmployeeProduct product;
  final EmployeeInventoryController inventory;
  final VoidCallback onEditProduct;
  final VoidCallback onArchiveProduct;
  final VoidCallback onConsumeProduct;

  @override
  State<EmployeeBatchDetailSheet> createState() => _EmployeeBatchDetailSheetState();
}

class _EmployeeBatchDetailSheetState extends State<EmployeeBatchDetailSheet> {
  void _showShortageDialog() {
    final shortageController = TextEditingController();
    final reasonController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Report Shortage', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Product: ${widget.product.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Current Stock: ${widget.product.quantity.toStringAsFixed(2)} ${widget.product.isWeightBased ? 'kg' : 'pcs'}'),
                const SizedBox(height: 12),
                TextField(
                  controller: shortageController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: widget.product.isWeightBased ? 'Shortage Quantity (kg)' : 'Shortage Quantity (pcs)',
                    errorText: errorText,
                    filled: true,
                    fillColor: AppColors.lightPeach,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: 'Reason (Optional)',
                    filled: true,
                    fillColor: AppColors.lightPeach,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
            ),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(shortageController.text.trim());
                if (qty == null || qty <= 0) {
                  setStateDialog(() => errorText = 'Enter a valid quantity greater than 0.');
                  return;
                }
                if (!widget.product.isWeightBased && qty != qty.roundToDouble()) {
                  setStateDialog(() => errorText = 'Regular products must use whole numbers.');
                  return;
                }
                if (qty > widget.product.quantity) {
                  setStateDialog(() => errorText = 'Shortage cannot exceed available stock.');
                  return;
                }

                final success = widget.inventory.reportShortage(widget.product.id, qty);
                if (success) {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(this.context); // close sheet
                  TopNotification.show(this.context, 'Shortage recorded successfully.\n${widget.product.name}\nShortage: $qty ${widget.product.isWeightBased ? 'kg' : 'pcs'}\nRemaining: ${(widget.product.quantity - qty).toStringAsFixed(2)} ${widget.product.isWeightBased ? 'kg' : 'pcs'}');
                } else {
                  setStateDialog(() => errorText = 'Failed to record shortage.');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, {bool isProfit = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 10, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: isProfit ? Colors.green.shade700 : AppColors.darkText,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final batches = widget.product.batches;
    final unitStr = widget.product.isWeightBased ? 'kg' : 'pcs';

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
            widget.product.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
          ),
          const SizedBox(height: 4),
          Text(
            'Barcode: ${widget.product.barcode} · Total on hand: ${widget.product.quantity.toStringAsFixed(2)} ${widget.product.unit}',
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Capital: ₱ ${widget.product.capital.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              Text(
                'Price: ₱ ${widget.product.price.toStringAsFixed(2)}',
                style: const TextStyle(color: AppColors.primaryOrange, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightPeach.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Total Capital', '₱${widget.product.totalCapital.toStringAsFixed(2)}'),
                _buildStat('Total Revenue', '₱${widget.product.totalRevenue.toStringAsFixed(2)}'),
                _buildStat('Total Profit', '₱${widget.product.totalProfit.toStringAsFixed(2)}', isProfit: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('All Batches', style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
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
                itemBuilder: (context, index) => _BatchDetailRow(batch: batches[index], unit: widget.product.unit),
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showShortageDialog,
              icon: const Icon(Icons.assignment_late_outlined, size: 18),
              label: const Text('Report Shortage', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onConsumeProduct,
              icon: const Icon(Icons.set_meal_outlined, size: 18),
              label: const Text('Consumables (Personal Use)', style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                side: const BorderSide(color: Colors.deepPurple),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onEditProduct,
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
                  onPressed: widget.onArchiveProduct,
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
  const _BatchDetailRow({required this.batch, required this.unit});
  final ProductBatch batch;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final dateLabel = batch.expiryDate == null
        ? 'No expiry date'
        : '${batch.expiryDate!.day}/${batch.expiryDate!.month}/${batch.expiryDate!.year}';
    final isDecimalUnit = unit == 'kg';

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
                Text('Batch ${batch.id}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText, fontSize: 13)),
                const SizedBox(height: 2),
                Text('Expiry: $dateLabel', style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
                Text('${isDecimalUnit ? batch.quantity.toStringAsFixed(2) : batch.quantity.toStringAsFixed(0)} $unit', style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
              ],
            ),
          ),
          ExpiryBadge(status: batch.expiryStatus()),
        ],
      ),
    );
  }
}
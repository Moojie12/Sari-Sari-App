import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
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
    //final unitStr = widget.product.isWeightBased ? 'kg' : 'pcs';

    final barcodeStr = widget.product.barcode.trim().isEmpty ? 'No barcode' : widget.product.barcode;

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
          Row(
            children: [
              const Text('Barcode: ', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
              Text(
                barcodeStr,
                style: TextStyle(
                  color: barcodeStr == 'No barcode' ? Colors.red.shade400 : AppColors.darkText,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' · Total on hand: ${widget.product.quantity.toInt()} ${widget.product.unit}',
                style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
              ),
            ],
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
                itemBuilder: (context, index) => _BatchDetailRow(
                  batch: batches[index],
                  batchNumber: index + 1,
                  unit: widget.product.unit,
                ),
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onConsumeProduct,
              icon: const Icon(Icons.set_meal_outlined, size: 18, color: Colors.white),
              label: const Text('Consumables / Product Loss', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
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
  const _BatchDetailRow({required this.batch, required this.batchNumber, required this.unit});
  final ProductBatch batch;
  final int batchNumber;
  final String unit;

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
                Text('Batch $batchNumber', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText, fontSize: 13)),
                const SizedBox(height: 2),
                Text('Expiry: $dateLabel', style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
                Text('${batch.quantity.toInt()} $unit', style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
              ],
            ),
          ),
          ExpiryBadge(status: batch.expiryStatus()),
        ],
      ),
    );
  }
}
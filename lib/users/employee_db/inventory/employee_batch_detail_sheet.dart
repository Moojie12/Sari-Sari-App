import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'employee_batch_model.dart';
import 'employee_expiry_badge.dart';
import 'employee_product_model.dart';

/// Detailed batch breakdown shown when staff tap a product card directly
/// in the Inventory tab, or an entry in Home's "Expiring Products" list —
/// Path B of the Expiration Notification flow.
///
/// Unlike the POS batch-selection sheet (Path A, which only lists
/// sellable batches), this shows *every* batch on record — including
/// empty or fully-expired ones — since the point here is proactive
/// monitoring by staff, not ringing up a sale.
class EmployeeBatchDetailSheet extends StatelessWidget {
  const EmployeeBatchDetailSheet({
    super.key,
    required this.product,
    required this.onAdjustStock,
  });

  final EmployeeProduct product;

  /// Called when staff tap "Adjust Stock" — the caller is responsible for
  /// closing this sheet and opening [EmployeeStockAdjustSheet].
  final VoidCallback onAdjustStock;

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
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onAdjustStock,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryOrange,
                side: const BorderSide(color: AppColors.primaryOrange),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Adjust Stock', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
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
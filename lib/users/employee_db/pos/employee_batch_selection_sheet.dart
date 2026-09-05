import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../inventory/employee_batch_model.dart';
import '../inventory/employee_expiry_badge.dart';
import '../inventory/employee_product_model.dart';

enum _BatchSelectionMode { continueFefo, chooseBatch }

/// Bottom sheet shown when a cashier picks a product on the POS tab —
/// Path A of the Expiration Notification flow (fires on scan/search) and
/// the batch-selection step of the Batch-Aware Selling flow.
///
/// - Lists only *sellable* batches ([EmployeeProduct.validBatches]) —
///   expired batches never appear here, they're out of scope for a sale.
/// - Shows a warning banner if any batch (sellable or not) is expiring
///   soon or expired, so the cashier is warned before continuing.
/// - CONTINUE auto-picks the batch with the nearest expiry (FEFO); CHOOSE
///   BATCH lets the cashier pick manually. If there's only one valid
///   batch, selection is skipped entirely.
/// - Quantity is capped to the selected batch's remaining stock, not the
///   product's overall stock.
class EmployeeBatchSelectionSheet extends StatefulWidget {
  const EmployeeBatchSelectionSheet({
    super.key,
    required this.product,
    required this.onConfirm,
  });

  final EmployeeProduct product;

  /// Called once the cashier confirms, with the chosen batch and quantity.
  final void Function(ProductBatch batch, int quantity) onConfirm;

  @override
  State<EmployeeBatchSelectionSheet> createState() => _EmployeeBatchSelectionSheetState();
}

class _EmployeeBatchSelectionSheetState extends State<EmployeeBatchSelectionSheet> {
  late final List<ProductBatch> _validBatches = widget.product.validBatches;
  _BatchSelectionMode _mode = _BatchSelectionMode.continueFefo;
  late ProductBatch _selected = _validBatches.first; // FEFO default
  int _quantity = 1;

  bool get _skipSelection => _validBatches.length <= 1;

  void _selectBatch(ProductBatch batch) {
    setState(() {
      _selected = batch;
      _quantity = 1;
    });
  }

  void _confirm() {
    widget.onConfirm(_selected, _quantity);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasWarning = widget.product.batches
        .any((b) => b.quantity > 0 && (b.isExpiringSoon || b.isExpired));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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
              '₱${widget.product.price.toStringAsFixed(2)} · Barcode: ${widget.product.barcode}',
              style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
            ),
            if (hasWarning) ...[
              const SizedBox(height: 14),
              _ExpiryWarningBanner(product: widget.product),
            ],
            const SizedBox(height: 18),
            if (!_skipSelection) ...[
              const Text('Batch Selection',
                  style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ModeChip(
                      label: 'CONTINUE (FEFO)',
                      isSelected: _mode == _BatchSelectionMode.continueFefo,
                      onTap: () => setState(() {
                        _mode = _BatchSelectionMode.continueFefo;
                        _selected = _validBatches.first;
                        _quantity = 1;
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ModeChip(
                      label: 'CHOOSE BATCH',
                      isSelected: _mode == _BatchSelectionMode.chooseBatch,
                      onTap: () => setState(() => _mode = _BatchSelectionMode.chooseBatch),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            if (_skipSelection || _mode == _BatchSelectionMode.continueFefo)
              _BatchTile(batch: _selected, isSelected: true, onTap: null)
            else
              ..._validBatches.map(
                    (batch) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _BatchTile(
                    batch: batch,
                    isSelected: batch.id == _selected.id,
                    onTap: () => _selectBatch(batch),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Quantity',
                    style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
                Row(
                  children: [
                    _StepButton(
                      icon: Icons.remove,
                      onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '$_quantity',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
                      ),
                    ),
                    _StepButton(
                      icon: Icons.add,
                      onPressed: _quantity < _selected.quantity ? () => setState(() => _quantity++) : null,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Max ${_selected.quantity} pcs available in this batch',
              style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.8), fontSize: 11),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Add to Cart', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiryWarningBanner extends StatelessWidget {
  const _ExpiryWarningBanner({required this.product});
  final EmployeeProduct product;

  @override
  Widget build(BuildContext context) {
    final isExpired = product.hasExpiredBatch;
    final color = isExpired ? Colors.red : Colors.deepOrange;
    final message = isExpired
        ? 'One or more batches of this product are already expired and are excluded from sale.'
        : 'This product has a batch expiring soon — consider prioritizing it in this sale.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.isSelected, required this.onTap});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryOrange.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : AppColors.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _BatchTile extends StatelessWidget {
  const _BatchTile({required this.batch, required this.isSelected, this.onTap});
  final ProductBatch batch;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dateLabel =
    batch.expiryDate == null ? 'No expiry' : '${batch.expiryDate!.day}/${batch.expiryDate!.month}/${batch.expiryDate!.year}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryOrange.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryOrange : AppColors.borderColor.withValues(alpha: 0.5),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (onTap != null) ...[
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.primaryOrange : AppColors.placeholderColor,
                  size: 18,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Batch ${batch.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('Expiry: $dateLabel · ${batch.quantity} pcs left',
                        style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
                  ],
                ),
              ),
              ExpiryBadge(status: batch.expiryStatus()),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.borderColor.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.primaryOrange : AppColors.placeholderColor.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

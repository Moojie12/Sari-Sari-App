import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'employee_product_model.dart';

/// Bottom sheet for manually adjusting a product's stock
/// (Add stock / Remove stock / Manual stock adjustment features).
class EmployeeStockAdjustSheet extends StatefulWidget {
  const EmployeeStockAdjustSheet({
    super.key,
    required this.product,
    required this.onAdjust,
  });

  final EmployeeProduct product;

  /// Called with the signed quantity delta once staff confirms.
  final ValueChanged<int> onAdjust;

  @override
  State<EmployeeStockAdjustSheet> createState() => _EmployeeStockAdjustSheetState();
}

class _EmployeeStockAdjustSheetState extends State<EmployeeStockAdjustSheet> {
  int _delta = 0;

  int get _resultingQuantity {
    final result = widget.product.quantity + _delta;
    return result < 0 ? 0 : result;
  }

  @override
  Widget build(BuildContext context) {
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
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
            ),
            const SizedBox(height: 4),
            Text('Barcode: ${widget.product.barcode}',
                style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Current Stock (all batches)', style: TextStyle(color: AppColors.secondaryText)),
                Text(
                  '${widget.product.quantity}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.darkText, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Adding tops up (or opens) a no-expiry batch. Removing deducts '
                  'the earliest-expiring batch first, same as a sale.',
              style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.7), fontSize: 11),
            ),
            const SizedBox(height: 20),
            const Text('Adjustment',
                style: TextStyle(
                    color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepButton(icon: Icons.remove, onPressed: () => setState(() => _delta--)),
                SizedBox(
                  width: 80,
                  child: Text(
                    _delta > 0 ? '+$_delta' : '$_delta',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.darkText),
                  ),
                ),
                _StepButton(icon: Icons.add, onPressed: () => setState(() => _delta++)),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Text('New stock: $_resultingQuantity',
                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _delta == 0
                    ? null
                    : () {
                  widget.onAdjust(_delta);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.borderColor.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Adjustment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
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
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: AppColors.primaryOrange),
        ),
      ),
    );
  }
}
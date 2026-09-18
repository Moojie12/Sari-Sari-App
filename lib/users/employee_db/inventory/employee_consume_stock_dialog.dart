import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../employee_inventory_controller.dart';
import '../profile/employee_profile_controller.dart';
import 'employee_batch_model.dart';
import 'employee_product_model.dart';

/// Lets staff pull stock out for personal use — e.g. the owner or an
/// employee taking a product for themselves to use or eat — instead of
/// selling it. Unlike a POS sale, nothing is paid for this, so it's
/// recorded as a Consumables cost: the capital value comes off profit
/// instead of counting as revenue.
class EmployeeConsumeStockDialog extends StatefulWidget {
  const EmployeeConsumeStockDialog({
    super.key,
    required this.product,
    required this.inventory,
    this.role = 'Employee',
  });

  final EmployeeProduct product;
  final EmployeeInventoryController inventory;

  /// Which dashboard opened this dialog ('Owner' or 'Employee') — combined
  /// with the signed-in profile's name to auto-fill who took the stock.
  final String role;

  @override
  State<EmployeeConsumeStockDialog> createState() => _EmployeeConsumeStockDialogState();
}

class _EmployeeConsumeStockDialogState extends State<EmployeeConsumeStockDialog> {
  ProductBatch? _selectedBatch;
  final _quantityController = TextEditingController();
  double _maxQuantity = 0.0;
  bool _isAllSelected = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selectedBatch = null;
    _isAllSelected = true;
    _maxQuantity = widget.product.quantity;
    _quantityController.text = _maxQuantity.toString();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  /// The signed-in account's name and role, e.g. "Juan Dela Cruz (Owner)" —
  /// recorded automatically so no one has to type who took the stock.
  String _currentUserLabel() {
    final profile = EmployeeProfileController.instance.profile;
    final name = '${profile.firstName} ${profile.lastName}'.trim();
    return '${name.isEmpty ? profile.role : name} (${widget.role})';
  }

  void _onBatchChanged(ProductBatch? batch) {
    setState(() {
      _selectedBatch = batch;
      _isAllSelected = batch == null;
      _errorText = null;
      if (_isAllSelected) {
        _maxQuantity = widget.product.quantity;
        _quantityController.text = _maxQuantity.toString();
      } else {
        _maxQuantity = batch!.quantity;
        _quantityController.text = _maxQuantity.toString();
      }
    });
  }

  void _submit() {
    final consumedBy = _currentUserLabel();

    if (_isAllSelected) {
      if (widget.product.quantity <= 0) return;
      widget.inventory.recordConsumableAll(widget.product.id, consumedBy: consumedBy);
      Navigator.pop(context);
      TopNotification.show(context, 'All stock for ${widget.product.name} logged as Consumables.');
      return;
    }

    final qty = double.tryParse(_quantityController.text);
    if (qty == null || qty <= 0) {
      setState(() => _errorText = 'Enter a valid quantity greater than 0.');
      return;
    }
    if (!widget.product.isWeightBased && qty != qty.roundToDouble()) {
      setState(() => _errorText = 'Regular products must use whole numbers.');
      return;
    }
    if (_selectedBatch == null || qty > _maxQuantity) {
      setState(() => _errorText = 'Quantity cannot exceed the selected batch.');
      return;
    }

    widget.inventory.recordConsumable(
      widget.product.id,
      _selectedBatch!.id,
      qty,
      consumedBy: consumedBy,
    );
    Navigator.pop(context);
    final unitStr = widget.product.isWeightBased ? 'kg' : 'pcs';
    TopNotification.show(
      context,
      '${qty.toStringAsFixed(2)} $unitStr of ${widget.product.name} logged as Consumables.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final unitStr = widget.product.isWeightBased ? 'kg' : 'pcs';

    return AlertDialog(
      title: const Text('Consumables (Personal Use)', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'For stock the owner or an employee takes for themselves to use or eat. '
                  'This removes it from stock and its cost is deducted from profit — it is not counted as a sale.',
              style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 16),
            const Text('Batch',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.labelText)),
            const SizedBox(height: 8),
            DropdownButtonFormField<ProductBatch?>(
              initialValue: _selectedBatch,
              isExpanded: true,
              items: [
                const DropdownMenuItem<ProductBatch?>(
                  value: null,
                  child: Text('All Batches', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                ),
                ...widget.product.batches.map((b) {
                  final dateStr = b.expiryDate == null
                      ? 'No Expiry'
                      : '${b.expiryDate!.day}/${b.expiryDate!.month}/${b.expiryDate!.year}';
                  return DropdownMenuItem<ProductBatch?>(
                    value: b,
                    child: Text('Batch ${b.id} ($dateStr) - ${b.quantity.toStringAsFixed(2)} $unitStr',
                        style: const TextStyle(fontSize: 14)),
                  );
                }),
              ],
              onChanged: _onBatchChanged,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Quantity Taken',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.labelText)),
            const SizedBox(height: 8),
            TextField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !_isAllSelected,
              onChanged: (_) => setState(() => _errorText = null),
              decoration: InputDecoration(
                hintText: _isAllSelected ? 'All quantity will be taken' : 'Max: ${_maxQuantity.toStringAsFixed(2)}',
                errorText: _errorText,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: _isAllSelected,
                fillColor: _isAllSelected ? Colors.grey.shade100 : null,
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
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
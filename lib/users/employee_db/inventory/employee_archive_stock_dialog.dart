import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../employee_inventory_controller.dart';
import 'employee_batch_model.dart';
import 'employee_product_model.dart';

class EmployeeArchiveStockDialog extends StatefulWidget {
  const EmployeeArchiveStockDialog({
    super.key,
    required this.product,
    required this.inventory,
  });

  final EmployeeProduct product;
  final EmployeeInventoryController inventory;

  @override
  State<EmployeeArchiveStockDialog> createState() => _EmployeeArchiveStockDialogState();
}

class _EmployeeArchiveStockDialogState extends State<EmployeeArchiveStockDialog> {
  ProductBatch? _selectedBatch;
  final _quantityController = TextEditingController();
  double _maxQuantity = 0.0;
  bool _isAllSelected = false;

  @override
  void initState() {
    super.initState();
    _selectedBatch = null;
    _isAllSelected = true;
    _maxQuantity = widget.product.quantity;
    _quantityController.text = widget.product.isWeightBased
        ? _maxQuantity.toString()
        : _maxQuantity.toInt().toString();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _onBatchChanged(ProductBatch? batch) {
    setState(() {
      _selectedBatch = batch;
      _isAllSelected = batch == null;
      if (_isAllSelected) {
        _maxQuantity = widget.product.quantity;
      } else {
        _maxQuantity = batch!.quantity;
      }
      _quantityController.text = widget.product.isWeightBased
          ? _maxQuantity.toString()
          : _maxQuantity.toInt().toString();
    });
  }

  void _onArchivePressed() {
    final unitStr = widget.product.isWeightBased ? 'kg' : 'pcs';

    if (_isAllSelected) {
      _showConfirmationDialog(_maxQuantity, unitStr);
      return;
    }

    final qtyText = _quantityController.text.trim();
    final qty = double.tryParse(qtyText) ?? 0.0;

    if (qty <= 0 || _selectedBatch == null) {
      TopNotification.show(context, 'Please enter a valid quantity to archive.', isError: true);
      return;
    }
    if (qty > _maxQuantity) {
      final maxDisplay = widget.product.isWeightBased ? _maxQuantity : _maxQuantity.toInt();
      TopNotification.show(context, 'Quantity cannot exceed available stock ($maxDisplay $unitStr).', isError: true);
      return;
    }
    if (!widget.product.isWeightBased && qty != qty.roundToDouble()) {
      TopNotification.show(context, 'Regular products must use whole numbers.', isError: true);
      return;
    }

    _showConfirmationDialog(qty, unitStr);
  }

  void _showConfirmationDialog(double qty, String unitStr) {
    final displayQty = widget.product.isWeightBased ? qty : qty.toInt();
    final message = _isAllSelected
        ? 'Are you sure you want to archive all stock for "${widget.product.name}"?'
        : 'Are you sure you want to archive $displayQty $unitStr of "${widget.product.name}"?';

    showDialog(
      context: context,
      builder: (confirmContext) => AlertDialog(
        title: const Text('Confirm Archive', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmContext),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(confirmContext);
              _performArchive(qty, unitStr);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _performArchive(double qty, String unitStr) {
    if (_isAllSelected) {
      widget.inventory.archiveAllStock(widget.product.id);
      TopNotification.show(context, 'All stock archived for ${widget.product.name}');
    } else {
      widget.inventory.archiveStock(widget.product.id, _selectedBatch!.id, qty);
      final displayQty = widget.product.isWeightBased ? qty : qty.toInt();
      TopNotification.show(context, '$displayQty $unitStr archived for ${widget.product.name}');
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final unitStr = widget.product.isWeightBased ? 'kg' : 'pcs';
    final barcodeStr = widget.product.barcode.trim().isEmpty ? 'No barcode' : widget.product.barcode;
    final maxDisplay = widget.product.isWeightBased ? _maxQuantity : _maxQuantity.toInt();

    return AlertDialog(
      title: const Text('Archive Stock', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select batch and quantity to archive for "${widget.product.name}" (Barcode: $barcodeStr).',
              style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
          const SizedBox(height: 16),
          const Text('Batch (Expiry Date)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.labelText)),
          const SizedBox(height: 8),
          DropdownButtonFormField<ProductBatch?>(
            initialValue: _selectedBatch,
            isExpanded: true,
            items: [
              const DropdownMenuItem<ProductBatch?>(
                value: null,
                child: Text('All Batches', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
              ),
              ...widget.product.batches.asMap().entries.map((entry) {
                final index = entry.key;
                final b = entry.value;
                final dateStr = b.expiryDate == null
                    ? 'No Expiry'
                    : '${b.expiryDate!.day}/${b.expiryDate!.month}/${b.expiryDate!.year}';
                final batchQtyDisplay = widget.product.isWeightBased ? b.quantity : b.quantity.toInt();
                return DropdownMenuItem<ProductBatch?>(
                  value: b,
                  child: Text('Batch ${index + 1} ($dateStr) - $batchQtyDisplay $unitStr',
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
          const Text('Quantity to Archive',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.labelText)),
          const SizedBox(height: 8),
          TextField(
            controller: _quantityController,
            keyboardType: widget.product.isWeightBased
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            inputFormatters: [
              if (widget.product.isWeightBased)
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              else
                FilteringTextInputFormatter.digitsOnly,
            ],
            enabled: !_isAllSelected,
            decoration: InputDecoration(
              hintText: _isAllSelected ? 'All quantity will be archived' : 'Max: $maxDisplay',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: _isAllSelected,
              fillColor: _isAllSelected ? Colors.grey.shade100 : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
        ),
        ElevatedButton(
          onPressed: _onArchivePressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Archive'),
        ),
      ],
    );
  }
}

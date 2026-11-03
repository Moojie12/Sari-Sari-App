import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/scale_bluetooth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../../../shared/widgets/scale_bluetooth_modal.dart';
import '../inventory/employee_batch_model.dart';
import '../inventory/employee_expiry_badge.dart';
import '../inventory/employee_product_model.dart';

enum _BatchSelectionMode { continueFefo, chooseBatch }

/// Bottom sheet shown when a cashier picks a product on the POS tab.
class EmployeeBatchSelectionSheet extends StatefulWidget {
  const EmployeeBatchSelectionSheet({
    super.key,
    required this.product,
    required this.onConfirm,
  });

  final EmployeeProduct product;

  /// Called once the cashier confirms, with the chosen batch and quantity.
  final void Function(ProductBatch batch, double quantity) onConfirm;

  @override
  State<EmployeeBatchSelectionSheet> createState() => _EmployeeBatchSelectionSheetState();
}

class _EmployeeBatchSelectionSheetState extends State<EmployeeBatchSelectionSheet> {
  late final List<ProductBatch> _validBatches = widget.product.validBatches;
  _BatchSelectionMode _mode = _BatchSelectionMode.continueFefo;
  late ProductBatch _selected = _validBatches.first; // FEFO default
  late final TextEditingController _quantityController;

  bool get _skipSelection => _validBatches.length <= 1;

  bool _isReadingFromScale = false;
  bool _isTaringScale = false;
  Timer? _scaleTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.product.isWeightBased ? '1.0' : '1',
    );
    if (widget.product.isWeightBased) {
      _initScale();
    }
  }

  void _initScale() {
    final scale = ScaleBluetoothService.instance;
    scale.onWeightReceived = (weight, isLocked) {
      _scaleTimeoutTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _quantityController.text = weight.toStringAsFixed(2);
        _isReadingFromScale = false;
      });
      TopNotification.show(
        context,
        'Weight captured: ${weight.toStringAsFixed(2)} kg ${isLocked ? "[LOCKED]" : ""}',
      );
    };

    scale.onTared = () {
      _scaleTimeoutTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _quantityController.text = '0.00';
        _isTaringScale = false;
      });
      TopNotification.show(context, 'Scale tared to 0.00 kg');
    };

    scale.onConnectionChanged = (connected) {
      if (!mounted) return;
      setState(() {});
    };
  }

  Future<void> _captureWeightFromScale() async {
    final scale = ScaleBluetoothService.instance;
    if (!scale.isConnected) {
      TopNotification.show(context, 'Please connect to the scale via Bluetooth first!');
      await showScaleBluetoothModal(context, onConnectionChanged: () => setState(() {}));
      return;
    }

    setState(() => _isReadingFromScale = true);

    _scaleTimeoutTimer?.cancel();
    _scaleTimeoutTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isReadingFromScale) {
        setState(() => _isReadingFromScale = false);
        TopNotification.show(context, 'Scale did not respond. Check Bluetooth connection.');
      }
    });

    final sent = await scale.requestWeight();
    if (!sent && mounted) {
      _scaleTimeoutTimer?.cancel();
      setState(() => _isReadingFromScale = false);
      TopNotification.show(context, 'Failed to request weight from scale.');
    }
  }

  Future<void> _tareScale() async {
    final scale = ScaleBluetoothService.instance;
    if (!scale.isConnected) {
      TopNotification.show(context, 'Please connect to the scale via Bluetooth first!');
      await showScaleBluetoothModal(context, onConnectionChanged: () => setState(() {}));
      return;
    }

    setState(() => _isTaringScale = true);

    _scaleTimeoutTimer?.cancel();
    _scaleTimeoutTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isTaringScale) {
        setState(() => _isTaringScale = false);
        TopNotification.show(context, 'Scale did not respond to Tare command.');
      }
    });

    final sent = await scale.sendTare();
    if (!sent && mounted) {
      _scaleTimeoutTimer?.cancel();
      setState(() => _isTaringScale = false);
      TopNotification.show(context, 'Failed to tare scale. Please try again.');
    }
  }

  @override
  void dispose() {
    _scaleTimeoutTimer?.cancel();
    final scale = ScaleBluetoothService.instance;
    scale.onWeightReceived = null;
    scale.onTared = null;
    scale.onConnectionChanged = null;
    _quantityController.dispose();
    super.dispose();
  }

  void _selectBatch(ProductBatch batch) {
    setState(() {
      _selected = batch;
      if (!widget.product.isWeightBased) {
        _quantityController.text = '1';
      }
    });
  }

  void _confirm() {
    final text = _quantityController.text.trim();
    final qty = double.tryParse(text);
    if (text.isEmpty || qty == null || qty <= 0) {
      TopNotification.show(context, 'Please enter a valid quantity.', isError: true);
      return;
    }
    if (qty > _selected.quantity) {
      final unitStr = widget.product.isWeightBased ? 'kg' : 'pcs';
      final maxStr = widget.product.isWeightBased
          ? _selected.quantity.toStringAsFixed(2)
          : _selected.quantity.toInt().toString();
      TopNotification.show(context, 'Only $maxStr $unitStr available in this batch.', isError: true);
      return;
    }
    if (!widget.product.isWeightBased && qty != qty.roundToDouble()) {
      TopNotification.show(context, 'Regular products must use whole numbers.', isError: true);
      return;
    }
    
    widget.onConfirm(_selected, qty);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasWarning = widget.product.batches
        .any((b) => b.quantity > 0 && (b.isExpiringSoon || b.isExpired));
    final unitStr = widget.product.isWeightBased ? 'kg' : 'pcs';
    final barcodeStr = widget.product.barcode.trim().isEmpty ? 'No barcode' : widget.product.barcode;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
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
                '₱${widget.product.price.toStringAsFixed(2)} / $unitStr · Barcode: $barcodeStr',
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
                Builder(
                  builder: (context) {
                    final idx = widget.product.batches.indexWhere((b) => b.id == _selected.id);
                    return _BatchTile(
                      batch: _selected,
                      batchNumber: idx != -1 ? idx + 1 : 1,
                      isSelected: true,
                      unitStr: unitStr,
                      onTap: null,
                    );
                  },
                )
              else
                ..._validBatches.map(
                  (batch) {
                    final idx = widget.product.batches.indexWhere((b) => b.id == batch.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _BatchTile(
                        batch: batch,
                        batchNumber: idx != -1 ? idx + 1 : 1,
                        isSelected: batch.id == _selected.id,
                        unitStr: unitStr,
                        onTap: () => _selectBatch(batch),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Quantity',
                      style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
                  if (widget.product.isWeightBased)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Bluetooth Connection Button
                        Tooltip(
                          message: ScaleBluetoothService.instance.isConnected ? 'Scale Connected' : 'Connect to Scale',
                          child: Material(
                            color: ScaleBluetoothService.instance.isConnected ? Colors.teal : AppColors.primaryOrange,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => showScaleBluetoothModal(context, onConnectionChanged: () => setState(() {})),
                              child: SizedBox(
                                width: 38,
                                height: 42,
                                child: Icon(
                                  ScaleBluetoothService.instance.isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 2. Tare (Zero) Button
                        Tooltip(
                          message: 'Tare (Zero)',
                          child: Material(
                            color: AppColors.primaryOrange,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: _isTaringScale ? null : _tareScale,
                              child: SizedBox(
                                width: 38,
                                height: 42,
                                child: _isTaringScale
                                    ? const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                                    : const Center(
                                        child: Text(
                                          'T',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 3. Weight Capture Button
                        Tooltip(
                          message: 'Get Weight from Scale',
                          child: Material(
                            color: AppColors.primaryOrange,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: _isReadingFromScale ? null : _captureWeightFromScale,
                              child: SizedBox(
                                width: 38,
                                height: 42,
                                child: _isReadingFromScale
                                    ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                                    : const Icon(Icons.scale, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 105,
                          child: TextField(
                            controller: _quantityController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              suffixText: ' kg',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        _StepButton(
                          icon: Icons.remove,
                          onPressed: () {
                             final val = double.tryParse(_quantityController.text) ?? 1.0;
                             if (val > 1) {
                               _quantityController.text = (val - 1).toInt().toString();
                             }
                          },
                        ),
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                          ),
                        ),
                        _StepButton(
                          icon: Icons.add,
                          onPressed: () {
                            final val = double.tryParse(_quantityController.text) ?? 0.0;
                            if (val < _selected.quantity) {
                              _quantityController.text = (val + 1).toInt().toString();
                            }
                          },
                        ),
                      ],
                    ),
                ],
              ),
              if (widget.product.isWeightBased) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => showScaleBluetoothModal(context, onConnectionChanged: () => setState(() {})),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ScaleBluetoothService.instance.isConnected ? Colors.teal : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        ScaleBluetoothService.instance.isConnected
                            ? 'Scale Connected: ${ScaleBluetoothService.instance.connectedDeviceName ?? "Timbangan Ni Eca"}'
                            : 'Scale Disconnected (Tap Bluetooth to connect)',
                        style: TextStyle(
                          fontSize: 11,
                          color: ScaleBluetoothService.instance.isConnected ? Colors.teal.shade700 : AppColors.secondaryText,
                          fontWeight: ScaleBluetoothService.instance.isConnected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Max ${widget.product.isWeightBased ? _selected.quantity.toStringAsFixed(2) : _selected.quantity.toInt()} $unitStr available in this batch',
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
        ? 'One or more batches are expired and excluded from sale.'
        : 'This product has a batch expiring soon — prioritize it.';

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
            child: Text(message, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
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
  const _BatchTile({
    required this.batch,
    required this.batchNumber,
    required this.isSelected,
    required this.unitStr,
    this.onTap,
  });

  final ProductBatch batch;
  final int batchNumber;
  final bool isSelected;
  final String unitStr;
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
                    Text('Batch $batchNumber',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('Expiry: $dateLabel · ${batch.quantity.toInt()} $unitStr left',
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
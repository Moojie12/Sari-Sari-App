import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../profile/employee_profile_controller.dart';
import 'employee_shift_controller.dart';

String _currentUserName() {
  final profile = EmployeeProfileController.instance.profile;
  final name = '${profile.firstName} ${profile.lastName}'.trim();
  return name.isEmpty ? profile.role : name;
}

/// Blocking view shown on the POS tab whenever no shift is open yet.
/// Requires a Starting Cash Float before the cashier can ring up sales.
class EmployeeStartShiftView extends StatefulWidget {
  const EmployeeStartShiftView({super.key});

  @override
  State<EmployeeStartShiftView> createState() => _EmployeeStartShiftViewState();
}

class _EmployeeStartShiftViewState extends State<EmployeeStartShiftView> {
  final _floatController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _startShift() async {
    final rawText = _floatController.text;
    final trimmedText = rawText.trim();

    if (trimmedText.isEmpty) {
      setState(() => _error = 'Please enter a starting cash float.');
      return;
    }

    if (rawText.contains(' ')) {
      setState(() => _error = 'Spaces are not allowed.');
      return;
    }

    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(trimmedText)) {
      setState(() => _error = 'Please enter a valid amount (e.g. 1000 or 1000.00).');
      return;
    }

    final amount = double.tryParse(trimmedText);
    if (amount == null || amount < 0) {
      setState(() => _error = 'Enter a valid starting cash float amount.');
      return;
    }

    if (amount > 10000) {
      setState(() => _error = 'Maximum starting cash float allowed is ₱10,000.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Start Shift'),
        content: Text(
          'Are you sure you want to start your shift with a starting cash float of ₱${amount.toStringAsFixed(2)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryOrange),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    EmployeeShiftController.instance.openShift(
      startingFloat: amount,
      openedBy: _currentUserName(),
    );
    if (context.mounted) {
      TopNotification.show(context, 'Shift started with ₱${amount.toStringAsFixed(2)} starting float.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.point_of_sale_rounded, color: AppColors.primaryOrange, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Start Your Shift',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkText),
            ),
            const SizedBox(height: 6),
            Text(
              "Enter the starting cash float (panukli) in the drawer before you begin selling. This won't be counted as sales.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.8), fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _floatController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'e.g. 1000.00',
                prefixText: '₱ ',
                errorText: _error,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderColor.withValues(alpha: 0.5)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startShift,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Start Shift', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the "Cash Adjustment" (Cash In / Cash Out) modal.
Future<void> showCashAdjustmentSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _CashAdjustmentSheet(),
  );
}

class _CashAdjustmentSheet extends StatefulWidget {
  const _CashAdjustmentSheet();

  @override
  State<_CashAdjustmentSheet> createState() => _CashAdjustmentSheetState();
}

class _CashAdjustmentSheetState extends State<_CashAdjustmentSheet> {
  CashAdjustmentType _type = CashAdjustmentType.cashIn;
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _amountError;
  String? _reasonError;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rawAmount = _amountController.text;
    final trimmedAmount = rawAmount.trim();
    final rawReason = _reasonController.text;
    final trimmedReason = rawReason.trim();

    String? amountErr;
    String? reasonErr;

    // Validate Amount
    if (trimmedAmount.isEmpty) {
      amountErr = 'Please enter an amount.';
    } else if (rawAmount.contains(' ')) {
      amountErr = 'Spaces are not allowed in amount.';
    } else if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(trimmedAmount)) {
      amountErr = 'Please enter a valid amount (e.g. 500 or 500.00).';
    } else {
      final amountVal = double.tryParse(trimmedAmount);
      if (amountVal == null || amountVal <= 0) {
        amountErr = 'Amount must be greater than ₱0.00.';
      } else if (amountVal > 10000) {
        amountErr = 'Maximum cash adjustment amount is ₱10,000.';
      }
    }

    // Validate Reason / Note
    if (trimmedReason.isEmpty) {
      reasonErr = 'A reason/note is required.';
    } else if (rawReason.length > 100) {
      reasonErr = 'Note must not exceed 100 characters.';
    } else if (RegExp(r'\s{2,}').hasMatch(rawReason)) {
      reasonErr = 'Double spaces are not allowed in the note.';
    }

    setState(() {
      _amountError = amountErr;
      _reasonError = reasonErr;
    });

    if (_amountError != null || _reasonError != null) return;

    final amount = double.parse(trimmedAmount);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Cash Adjustment'),
        content: Text(
          'Are you sure you want to record a ${_type.label} of ₱${amount.toStringAsFixed(2)}?\n\nNote: $trimmedReason',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryOrange),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final saved = EmployeeShiftController.instance.addCashAdjustment(
      type: _type,
      amount: amount,
      reason: trimmedReason,
    );
    if (saved) {
      Navigator.pop(context);
      if (context.mounted) {
        TopNotification.show(
          context,
          '${_type.label} of ₱${amount.toStringAsFixed(2)} recorded.',
        );
      }
    }
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
            const Text('Cash Adjustment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText)),
            const SizedBox(height: 4),
            Text(
              'Record non-sales cash added to or removed from the drawer.',
              style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.8), fontSize: 12),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _AdjustmentTypeChip(
                    label: 'Cash In',
                    icon: Icons.add_circle_outline,
                    color: Colors.green,
                    isSelected: _type == CashAdjustmentType.cashIn,
                    onTap: () => setState(() => _type = CashAdjustmentType.cashIn),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AdjustmentTypeChip(
                    label: 'Cash Out',
                    icon: Icons.remove_circle_outline,
                    color: Colors.red,
                    isSelected: _type == CashAdjustmentType.cashOut,
                    onTap: () => setState(() => _type = CashAdjustmentType.cashOut),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Amount *', style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
              decoration: _fieldDecoration('e.g. 500.00', prefixText: '₱ ', errorText: _amountError),
            ),
            const SizedBox(height: 14),
            const Text('Reason / Note *', style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              maxLength: 100,
              onChanged: (_) {
                if (_reasonError != null) setState(() => _reasonError = null);
              },
              decoration: _fieldDecoration('e.g. Added ₱500 coins for change', errorText: _reasonError),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Adjustment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustmentTypeChip extends StatelessWidget {
  const _AdjustmentTypeChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : AppColors.borderColor, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : AppColors.secondaryText),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the End of Shift / Drawer Balancing sheet.
Future<void> showEndShiftSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _EndShiftSheet(),
  );
}

class _EndShiftSheet extends StatefulWidget {
  const _EndShiftSheet();

  @override
  State<_EndShiftSheet> createState() => _EndShiftSheetState();
}

class _EndShiftSheetState extends State<_EndShiftSheet> {
  final _actualCashController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _actualCashController.dispose();
    super.dispose();
  }

  Future<void> _confirmEndShift(Shift shift) async {
    final rawText = _actualCashController.text;
    final trimmedText = rawText.trim();

    if (trimmedText.isEmpty) {
      setState(() => _error = 'Please enter actual cash counted.');
      return;
    }

    if (rawText.contains(' ')) {
      setState(() => _error = 'Spaces are not allowed.');
      return;
    }

    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(trimmedText)) {
      setState(() => _error = 'Please enter a valid amount (e.g. 5000 or 5000.00).');
      return;
    }

    final actual = double.tryParse(trimmedText);
    if (actual == null || actual < 0) {
      setState(() => _error = 'Enter a valid actual cash amount.');
      return;
    }

    final discrepancy = actual - shift.expectedCash;
    final discrepancyText = discrepancy == 0
        ? 'Balanced (₱0.00)'
        : (discrepancy < 0
            ? 'Short by ₱${(-discrepancy).toStringAsFixed(2)}'
            : 'Over by ₱${discrepancy.toStringAsFixed(2)}');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm End Shift'),
        content: Text(
          'Are you sure you want to end this shift?\n\nActual Cash Counted: ₱${actual.toStringAsFixed(2)}\nExpected Cash: ₱${shift.expectedCash.toStringAsFixed(2)}\nDiscrepancy: $discrepancyText\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryOrange),
            child: const Text('Confirm & End Shift'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final report = EmployeeShiftController.instance.closeShift(
      actualCash: actual,
      closedBy: _currentUserName(),
    );
    if (report == null) return;

    Navigator.pop(context); // close the end-shift sheet
    if (context.mounted) {
      _showResultDialog(context, report);
    }
  }

  void _showResultDialog(BuildContext context, ShiftReport report) {
    final Color color = report.isBalanced
        ? Colors.green
        : (report.isShort ? Colors.red : Colors.blue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Shift Closed — ${report.discrepancyLabel}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expected Cash: ₱${report.expectedCash.toStringAsFixed(2)}'),
            Text('Actual Cash Counted: ₱${report.actualCash.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text(
              'Discrepancy: ${report.discrepancy >= 0 ? '+' : ''}₱${report.discrepancy.toStringAsFixed(2)} (${report.discrepancyLabel})',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shift = EmployeeShiftController.instance.currentShift;
    if (shift == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('End of Shift — Drawer Balancing',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText)),
              const SizedBox(height: 16),
              _SummaryRow(label: 'Starting Change (Float)', value: shift.startingFloat),
              _SummaryRow(label: 'Total Cash Sales', value: shift.cashSalesTotal),
              _SummaryRow(
                label: 'Cash In / Cash Out Adjustments',
                value: shift.netAdjustments,
                signed: true,
              ),
              const Divider(height: 24, color: AppColors.borderColor),
              _SummaryRow(label: 'Expected Total Cash in Drawer', value: shift.expectedCash, isBold: true),
              const SizedBox(height: 20),
              const Text('Actual Cash Counted *',
                  style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: _actualCashController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                onChanged: (_) {
                  setState(() {
                    if (_error != null) _error = null;
                  });
                },
                decoration: _fieldDecoration('e.g. 5000.00', prefixText: '₱ ', errorText: _error),
              ),
              const SizedBox(height: 16),
              _buildLiveDiscrepancy(shift),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _confirmEndShift(shift),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('End Shift', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveDiscrepancy(Shift shift) {
    final actual = double.tryParse(_actualCashController.text.trim());
    if (actual == null) return const SizedBox.shrink();

    final discrepancy = actual - shift.expectedCash;
    final isBalanced = discrepancy.abs() < 0.005;
    final isShort = discrepancy < -0.005;
    final label = isBalanced ? 'Balanced' : (isShort ? 'Short' : 'Over');
    final color = isBalanced ? Colors.green : (isShort ? Colors.red : Colors.blue);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Discrepancy', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          Text(
            '${discrepancy >= 0 ? '+' : ''}₱${discrepancy.toStringAsFixed(2)} ($label)',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.signed = false,
    this.isBold = false,
  });

  final String label;
  final double value;
  final bool signed;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final prefix = signed && value >= 0 ? '+' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isBold ? AppColors.darkText : AppColors.secondaryText,
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '$prefix₱${value.toStringAsFixed(2)}',
            style: TextStyle(
              color: AppColors.darkText,
              fontSize: isBold ? 16 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint, {String? prefixText, String? errorText}) {
  return InputDecoration(
    hintText: hint,
    prefixText: prefixText,
    errorText: errorText,
    filled: true,
    fillColor: AppColors.lightPeach,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
  );
}
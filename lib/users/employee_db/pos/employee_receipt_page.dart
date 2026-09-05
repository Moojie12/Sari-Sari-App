import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'employee_pos_controller.dart';

/// Shown after a POS sale is completed (Receipt Generation feature).
class EmployeeReceiptPage extends StatelessWidget {
  const EmployeeReceiptPage({super.key, required this.receipt});
  final EmployeeReceipt receipt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'Sale Completed',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.darkText),
              ),
              const SizedBox(height: 4),
              Text('Receipt #${receipt.receiptNumber}',
                  style: const TextStyle(color: AppColors.secondaryText)),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...receipt.items.map(
                              (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item.product.name} x${item.quantity}',
                                        style: const TextStyle(color: AppColors.darkText),
                                      ),
                                      // Optional batch/expiry detail on the
                                      // receipt (Receipt Generation, step 8).
                                      Text(
                                        'Batch ${item.batchId}'
                                            '${item.batchExpiryDate != null ? " · Exp ${item.batchExpiryDate!.day}/${item.batchExpiryDate!.month}/${item.batchExpiryDate!.year}" : ""}',
                                        style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Text('₱${item.subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 24),
                        _ReceiptRow(
                            label: 'Total',
                            value: '₱${receipt.totalAmount.toStringAsFixed(2)}',
                            isBold: true),
                        _ReceiptRow(
                          label: 'Payment Method',
                          value: receipt.paymentMethod == EmployeePaymentMethod.cash
                              ? 'Cash'
                              : 'GCash',
                        ),
                        _ReceiptRow(
                            label: 'Amount Received',
                            value: '₱${receipt.amountPaid.toStringAsFixed(2)}'),
                        _ReceiptRow(
                            label: 'Change', value: '₱${receipt.change.toStringAsFixed(2)}'),
                        _ReceiptRow(
                          label: 'Date',
                          value:
                          '${receipt.dateTime.day}/${receipt.dateTime.month}/${receipt.dateTime.year} '
                              '${receipt.dateTime.hour.toString().padLeft(2, '0')}:${receipt.dateTime.minute.toString().padLeft(2, '0')}',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('New Sale', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value, this.isBold = false});
  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isBold ? AppColors.darkText : AppColors.secondaryText,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isBold ? AppColors.primaryOrange : AppColors.darkText,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
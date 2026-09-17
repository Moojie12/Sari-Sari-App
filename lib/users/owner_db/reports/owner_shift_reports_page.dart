import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../employee_db/pos/employee_shift_controller.dart';

/// Owner-facing audit list of past closed shifts — lets the owner review
/// discrepancies (Short / Over / Balanced) and drill into any shift's
/// full cash-in/cash-out log.
class OwnerShiftReportsPage extends StatelessWidget {
  const OwnerShiftReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        title: const Text('Shift Reports',
            style: TextStyle(color: AppColors.darkText, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.darkText),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: EmployeeShiftController.instance,
          builder: (context, _) {
            final reports = EmployeeShiftController.instance.history;
            return reports.isEmpty
                ? Center(
              child: Text(
                'No closed shifts yet.',
                style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.7)),
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: reports.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _ShiftReportCard(report: reports[index]),
            );
          },
        ),
      ),
    );
  }
}

class _ShiftReportCard extends StatelessWidget {
  const _ShiftReportCard({required this.report});
  final ShiftReport report;

  Color get _statusColor {
    if (report.isBalanced) return Colors.green;
    return report.isShort ? Colors.red : Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => OwnerShiftReportDetailPage(report: report)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  report.isBalanced
                      ? Icons.check_circle_outline
                      : (report.isShort ? Icons.trending_down : Icons.trending_up),
                  color: _statusColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Shift ${report.id}',
                        style: const TextStyle(
                            color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDate(report.openedAt)} · ${report.transactionCount} txn(s)',
                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${report.discrepancy >= 0 ? '+' : ''}₱${report.discrepancy.toStringAsFixed(2)}',
                    style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(report.discrepancyLabel,
                      style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

/// Full breakdown of one closed shift — for the owner to audit exactly
/// where a discrepancy might have come from.
class OwnerShiftReportDetailPage extends StatelessWidget {
  const OwnerShiftReportDetailPage({super.key, required this.report});
  final ShiftReport report;

  @override
  Widget build(BuildContext context) {
    final color = report.isBalanced ? Colors.green : (report.isShort ? Colors.red : Colors.blue);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        title: Text('Shift ${report.id}',
            style: const TextStyle(color: AppColors.darkText, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.darkText),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(report.discrepancyLabel,
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    '${report.discrepancy >= 0 ? '+' : ''}₱${report.discrepancy.toStringAsFixed(2)}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildDetailCard(
              title: 'Summary',
              children: [
                _DetailRow('Opened', _formatDate(report.openedAt)),
                _DetailRow('Closed', _formatDate(report.closedAt)),
                if (report.openedBy != null) _DetailRow('Opened by', report.openedBy!),
                if (report.closedBy != null) _DetailRow('Closed by', report.closedBy!),
                _DetailRow('Transactions', '${report.transactionCount}'),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailCard(
              title: 'Cash Reconciliation',
              children: [
                _DetailRow('Starting Change (Float)', '₱${report.startingFloat.toStringAsFixed(2)}'),
                _DetailRow('Total Cash Sales', '₱${report.cashSalesTotal.toStringAsFixed(2)}'),
                _DetailRow('Total Non-Cash Sales', '₱${report.nonCashSalesTotal.toStringAsFixed(2)}'),
                _DetailRow(
                  'Cash In / Cash Out Adjustments',
                  '${report.netAdjustments >= 0 ? '+' : ''}₱${report.netAdjustments.toStringAsFixed(2)}',
                ),
                _DetailRow('Expected Cash in Drawer', '₱${report.expectedCash.toStringAsFixed(2)}', isBold: true),
                _DetailRow('Actual Cash Counted', '₱${report.actualCash.toStringAsFixed(2)}', isBold: true),
              ],
            ),
            if (report.adjustments.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDetailCard(
                title: 'Cash Adjustment Log',
                children: [
                  for (final adj in report.adjustments)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            adj.type == CashAdjustmentType.cashIn
                                ? Icons.add_circle_outline
                                : Icons.remove_circle_outline,
                            size: 16,
                            color: adj.type == CashAdjustmentType.cashIn ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(adj.reason,
                                    style: const TextStyle(color: AppColors.darkText, fontSize: 13)),
                                Text(_formatDate(adj.timestamp),
                                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
                              ],
                            ),
                          ),
                          Text(
                            '${adj.type == CashAdjustmentType.cashIn ? '+' : '-'}₱${adj.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: adj.type == CashAdjustmentType.cashIn ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, {this.isBold = false});
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
          Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: AppColors.darkText,
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
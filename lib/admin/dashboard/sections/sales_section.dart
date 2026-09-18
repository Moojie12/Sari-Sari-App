import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/admin_models.dart';
import '../../controllers/admin_controller.dart';
import '../widgets/dashboard_shared.dart';

class SalesSection extends StatefulWidget {
  final AdminController controller;
  final String searchQuery;
  final int rowsPerPage;
  final Map<String, int> pages;
  final String storeName;
  final void Function(String, int) onPageChange;
  final void Function(AdminSale) onShowReceipt;
  final void Function(AdminSale) onVoidSale;
  final void Function(String, String) onCopyText;
  final void Function() onClearFilters;

  const SalesSection({
    super.key,
    required this.controller,
    required this.searchQuery,
    required this.rowsPerPage,
    required this.pages,
    required this.storeName,
    required this.onPageChange,
    required this.onShowReceipt,
    required this.onVoidSale,
    required this.onCopyText,
    required this.onClearFilters,
  });

  @override
  State<SalesSection> createState() => _SalesSectionState();
}

class _SalesSectionState extends State<SalesSection> {
  String _saleStatusFilter = 'All';

  List<AdminSale> _filteredSales() {
    final query = widget.searchQuery.toLowerCase().trim();
    return widget.controller.allSales.where((sale) {
      final matchesQuery = query.isEmpty ||
          sale.receiptNumber.toLowerCase().contains(query) ||
          sale.cashierName.toLowerCase().contains(query) ||
          sale.customerName.toLowerCase().contains(query);
      final matchesStatus = _saleStatusFilter == 'All' ||
          sale.status.label == _saleStatusFilter;
      return matchesQuery && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final sales = _filteredSales();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        toolbar(
          filters: [
            dropdownFilter(
              label: 'Status',
              value: _saleStatusFilter,
              options: const ['All', 'Completed', 'Voided'],
              onChanged: (value) => setState(() {
                _saleStatusFilter = value;
                widget.onPageChange('sales', 1);
              }),
            ),
          ],
          action: OutlinedButton.icon(
            onPressed: sales.isEmpty ? null : () {},
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Export CSV'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (sales.isEmpty)
          emptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No sales recorded',
            message: 'Issuing receipts at the register will populate this list.',
            actionLabel: widget.searchQuery.isNotEmpty ? 'Clear search' : null,
            onAction: widget.searchQuery.isNotEmpty ? widget.onClearFilters : null,
          )
        else
          _buildTable(sales),
      ],
    );
  }

  Widget _buildTable(List<AdminSale> sales) {
    final paged = paginate(sales, 'sales', widget.rowsPerPage, widget.pages);

    return tableShell(
      minWidth: 1000,
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(1.5),
        4: FlexColumnWidth(1.5),
        5: FlexColumnWidth(1.5),
        6: FixedColumnWidth(120),
      },
      header: [
        header('Receipt #'),
        header('Date & Time'),
        header('Cashier'),
        header('Total'),
        header('Status'),
        header('Actions'),
      ],
      rows: [
        for (final sale in paged.items)
          [
            cell(Text(sale.receiptNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
            cell(Text(formatDateTime(sale.timestamp), style: const TextStyle(fontSize: 13))),
            cell(Text(sale.cashierName, style: const TextStyle(fontSize: 13))),
            cell(Text(formatPeso(sale.total), style: const TextStyle(fontWeight: FontWeight.bold))),
            cell(statusPill(sale.status.label, sale.isCompleted ? Colors.green : Colors.red)),
            cell(
              Row(
                children: [
                  iconAction(Icons.receipt_outlined, 'View Receipt', Colors.blueGrey,
                          () => widget.onShowReceipt(sale)),
                  if (sale.isCompleted)
                    iconAction(Icons.block_outlined, 'Void', Colors.red,
                            () => widget.onVoidSale(sale)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ],
      ],
      footer: paginationBar(paged, 'sales', 'receipts', widget.pages, widget.onPageChange),
    );
  }
}

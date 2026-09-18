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
  String _saleRangeFilter = 'Last 7 days';
  String _saleSort = 'date';
  bool _saleAsc = false;

  bool _saleInRange(DateTime timestamp) {
    final now = DateTime.now();
    switch (_saleRangeFilter) {
      case 'Today':
        return isSameDay(timestamp, now);
      case 'Last 7 days':
        return timestamp
            .isAfter(DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6)));
      case 'Last 30 days':
        return timestamp
            .isAfter(DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 29)));
      default:
        return true;
    }
  }

  List<AdminSale> _filteredSales() {
    final query = widget.searchQuery.toLowerCase().trim();
    final list = widget.controller.allSales.where((sale) {
      final matchesQuery = query.isEmpty ||
          sale.receiptNumber.toLowerCase().contains(query) ||
          sale.cashierName.toLowerCase().contains(query) ||
          sale.customerName.toLowerCase().contains(query) ||
          sale.items.any((i) => i.productName.toLowerCase().contains(query));
      final matchesStatus = _saleStatusFilter == 'All' ||
          sale.status.label == _saleStatusFilter;
      return matchesQuery && matchesStatus && _saleInRange(sale.timestamp);
    }).toList();

    int compare(AdminSale a, AdminSale b) {
      switch (_saleSort) {
        case 'total':
          return a.total.compareTo(b.total);
        case 'cashier':
          return a.cashierName
              .toLowerCase()
              .compareTo(b.cashierName.toLowerCase());
        default:
          return a.timestamp.compareTo(b.timestamp);
      }
    }

    list.sort((a, b) => _saleAsc ? compare(a, b) : compare(b, a));
    return list;
  }

  void _onSort(String key) {
    setState(() {
      if (_saleSort == key) {
        _saleAsc = !_saleAsc;
      } else {
        _saleSort = key;
        _saleAsc = key != 'date';
      }
      widget.onPageChange('sales', 1);
    });
  }

  String _salesSummaryText(List<AdminSale> sales) {
    final completed = sales.where((s) => s.isCompleted).toList();
    final buffer = StringBuffer()
      ..writeln('${widget.storeName} — sales summary')
      ..writeln('Period: $_saleRangeFilter')
      ..writeln('Generated: ${formatDateTime(DateTime.now())}')
      ..writeln('')
      ..writeln('Receipts: ${completed.length}')
      ..writeln(
          'Gross sales: ${formatPeso(completed.fold<double>(0, (sum, s) => sum + s.total))}')
      ..writeln(
          'Estimated profit: ${formatPeso(completed.fold<double>(0, (sum, s) => sum + s.profit))}')
      ..writeln('Voided: ${sales.length - completed.length}')
      ..writeln('')
      ..writeln('Receipt\tDate\tCashier\tTotal\tStatus');

    for (final sale in sales) {
      buffer.writeln('${sale.receiptNumber}\t${formatDateTime(sale.timestamp)}'
          '\t${sale.cashierName}\t${sale.total.toStringAsFixed(2)}\t${sale.status.label}');
    }
    return buffer.toString();
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
              label: 'Period',
              value: _saleRangeFilter,
              options: const [
                'Today',
                'Last 7 days',
                'Last 30 days',
                'All time',
              ],
              onChanged: (value) => setState(() {
                _saleRangeFilter = value;
                widget.onPageChange('sales', 1);
              }),
            ),
            dropdownFilter(
              label: 'Status',
              value: _saleStatusFilter,
              options: const ['All', 'Completed', 'Voided', 'Refunded'],
              onChanged: (value) => setState(() {
                _saleStatusFilter = value;
                widget.onPageChange('sales', 1);
              }),
            ),
          ],
          action: OutlinedButton.icon(
            onPressed: sales.isEmpty
                ? null
                : () => widget.onCopyText(
              _salesSummaryText(sales),
              'Sales summary copied to the clipboard.',
            ),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Copy summary'),
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
            title: 'No receipts in this period',
            message: 'Sales made at the till show up here, with the full receipt and who rang it up.',
            actionLabel: 'Show all time',
            onAction: () {
              setState(() {
                _saleRangeFilter = 'All time';
                _saleStatusFilter = 'All';
              });
              widget.onClearFilters();
            },
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
        0: FlexColumnWidth(1.8),
        1: FlexColumnWidth(1.8),
        2: FlexColumnWidth(1.6),
        3: FlexColumnWidth(1.8),
        4: FlexColumnWidth(1.4),
        5: FlexColumnWidth(1.3),
        6: FixedColumnWidth(110),
      },
      header: [
        header('Receipt'),
        sortableHeader('Date', 'date', _saleSort, _saleAsc, _onSort),
        sortableHeader('Cashier', 'cashier', _saleSort, _saleAsc, _onSort),
        header('Items'),
        sortableHeader('Total', 'total', _saleSort, _saleAsc, _onSort),
        header('Status'),
        header('Actions'),
      ],
      rows: [
        for (final sale in paged.items)
          [
            cell(InkWell(
              onTap: () => widget.onShowReceipt(sale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sale.receiptNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    sale.customerName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.placeholderColor,
                    ),
                  ),
                ],
              ),
            )),
            cell(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDate(sale.timestamp),
                  style: const TextStyle(fontSize: 13, color: AppColors.darkText),
                ),
                Text(
                  formatTime(sale.timestamp),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.placeholderColor,
                  ),
                ),
              ],
            )),
            cell(Text(
              sale.cashierName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
            )),
            cell(Text(
              '${sale.lineCount} ${sale.lineCount == 1 ? 'line' : 'lines'} · ${sale.paymentMethod.label}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
            )),
            cell(Text(
              formatPeso(sale.total),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: sale.isCompleted ? AppColors.darkText : AppColors.placeholderColor,
                decoration: sale.isCompleted ? null : TextDecoration.lineThrough,
              ),
            )),
            cell(statusPill(
              sale.status.label,
              sale.isCompleted ? Colors.green : Colors.red,
            )),
            cell(
              Row(
                children: [
                  iconAction(Icons.receipt_outlined, 'View receipt', Colors.blueGrey,
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

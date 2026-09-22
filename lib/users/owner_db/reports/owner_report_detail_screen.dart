import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../employee_db/employee_inventory_controller.dart';
import '../../employee_db/orders/employee_orders_controller.dart';
import '../../employee_db/inventory/employee_product_model.dart';
import '../../customer_db/purchases/customer_order_model.dart';
import '../../../shared/utils/top_notification.dart';

enum OwnerReportType {
  dailyRevenue,
  paymentReconciliation,
  salesChannelComparison,
  inventoryValue,
  restockChecklist,
  wastageLog,
  consumablesLog,
  bestSellers,
  slowMoving,
  categoryPerformance,
}

class OwnerReportDetailScreen extends StatelessWidget {
  const OwnerReportDetailScreen({super.key, required this.type});

  final OwnerReportType type;

  String get _title {
    switch (type) {
      case OwnerReportType.dailyRevenue: return 'Daily Revenue Summary';
      case OwnerReportType.paymentReconciliation: return 'Payment Reconciliation';
      case OwnerReportType.salesChannelComparison: return 'Sales Channel Comparison';
      case OwnerReportType.inventoryValue: return 'Total Inventory Value';
      case OwnerReportType.restockChecklist: return 'Restock Checklist';
      case OwnerReportType.wastageLog: return 'Wastage & Expiry Log';
      case OwnerReportType.consumablesLog: return 'Consumables (Personal Use) Log';
      case OwnerReportType.bestSellers: return 'Best Selling Products';
      case OwnerReportType.slowMoving: return 'Slow-Moving Inventory';
      case OwnerReportType.categoryPerformance: return 'Category Performance';
    }
  }

  void _simulatePrint(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primaryOrange),
                SizedBox(height: 16),
                Text('Generating PDF Report...', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Please wait a moment', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (context.mounted) {
        Navigator.pop(context);
        TopNotification.show(context, 'Report saved to downloads as PDF');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        foregroundColor: AppColors.darkText,
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            onPressed: () => _simulatePrint(context),
            icon: const Icon(Icons.print_outlined, color: AppColors.primaryOrange),
            tooltip: 'Print Report',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryHeader(),
              const SizedBox(height: 24),
              _buildReportContent(context),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    // Shared KPI styles
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('REPORT SUMMARY',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.secondaryText, letterSpacing: 1)),
              Text(DateTime.now().toString().split(' ')[0],
                  style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
            ],
          ),
          const SizedBox(height: 16),
          _getSummaryData(),
        ],
      ),
    );
  }

  Widget _getSummaryData() {
    final inventory = EmployeeInventoryController.instance;
    final orders = EmployeeOrderController.instance.orders;

    switch (type) {
      case OwnerReportType.dailyRevenue:
        final completed = orders.where((o) => o.status == OrderStatus.completed).toList();
        final revenue = completed.fold(0.0, (sum, o) => sum + o.subtotal);
        final capital = completed.fold(0.0, (sum, o) => sum + o.totalCapital);
        final consumablesCost = inventory.totalConsumablesCost;
        final profit = revenue - capital - consumablesCost;
        return Column(
          children: [
            _KpiRow(label: 'Total Revenue', value: '₱ ${revenue.toStringAsFixed(2)}', icon: Icons.payments, color: Colors.blue),
            const SizedBox(height: 12),
            _KpiRow(label: 'Total Capital', value: '₱ ${capital.toStringAsFixed(2)}', icon: Icons.shopping_bag, color: Colors.blueGrey),
            const SizedBox(height: 12),
            _KpiRow(label: 'Consumables (Personal Use)', value: '₱ ${consumablesCost.toStringAsFixed(2)}', icon: Icons.set_meal_outlined, color: Colors.deepPurple),
            const SizedBox(height: 12),
            _KpiRow(label: 'Net Profit', value: '₱ ${profit.toStringAsFixed(2)}', icon: Icons.trending_up, color: Colors.green),
          ],
        );
      case OwnerReportType.inventoryValue:
        final totalRev = inventory.products.fold(0.0, (sum, p) => sum + p.totalRevenue);
        final totalCap = inventory.products.fold(0.0, (sum, p) => sum + p.totalCapital);
        final totalProf = totalRev - totalCap;
        return Column(
          children: [
            _KpiRow(label: 'Potential Revenue', value: '₱ ${totalRev.toStringAsFixed(2)}', icon: Icons.monetization_on, color: Colors.orange),
            const SizedBox(height: 12),
            _KpiRow(label: 'Capital Tied Up', value: '₱ ${totalCap.toStringAsFixed(2)}', icon: Icons.account_balance_wallet, color: Colors.blueGrey),
            const SizedBox(height: 12),
            _KpiRow(label: 'Potential Profit', value: '₱ ${totalProf.toStringAsFixed(2)}', icon: Icons.show_chart, color: Colors.green),
          ],
        );
      case OwnerReportType.wastageLog:
        final totalLoss = inventory.archivedStock
            .where((a) => a.reason == StockRemovalReason.wastage)
            .fold(0.0, (sum, a) => sum + a.capital);
        return _KpiRow(label: 'Total Capital Loss', value: '₱ ${totalLoss.toStringAsFixed(2)}', icon: Icons.delete_forever, color: Colors.red);
      case OwnerReportType.consumablesLog:
        final totalCost = inventory.totalConsumablesCost;
        return _KpiRow(label: 'Total Consumables Cost', value: '₱ ${totalCost.toStringAsFixed(2)}', icon: Icons.set_meal_outlined, color: Colors.deepPurple);
      case OwnerReportType.restockChecklist:
        final count = inventory.lowStockProducts.length + inventory.outOfStockProducts.length;
        return _KpiRow(label: 'Items to Restock', value: '$count items', icon: Icons.warning_amber, color: Colors.red);
      default:
        return _KpiRow(label: 'Overall Status', value: 'Healthy', icon: Icons.check_circle_outline, color: AppColors.primaryOrange);
    }
  }

  Widget _buildReportContent(BuildContext context) {
    final inventory = EmployeeInventoryController.instance;
    final orders = EmployeeOrderController.instance.orders;

    switch (type) {
      case OwnerReportType.restockChecklist:
        final items = [...inventory.outOfStockProducts, ...inventory.lowStockProducts];
        return _ReportTable(
          title: 'Items Requiring Attention',
          columns: const ['Product', 'Stock', 'Threshold'],
          rows: items.map((p) => [
            p.name,
            '${p.quantity} pcs',
            '${p.lowStockThreshold} pcs',
          ]).toList(),
        );
      case OwnerReportType.inventoryValue:
        return _ReportTable(
          title: 'Value Breakdown by Product',
          columns: const ['Product', 'Capital', 'Revenue', 'Profit'],
          rows: inventory.products.map((p) => [
            p.name,
            '₱${p.totalCapital.toStringAsFixed(2)}',
            '₱${p.totalRevenue.toStringAsFixed(2)}',
            '₱${p.totalProfit.toStringAsFixed(2)}',
          ]).toList(),
        );
      case OwnerReportType.dailyRevenue:
        final completed = orders.where((o) => o.status == OrderStatus.completed).toList();
        return _ReportTable(
          title: 'Completed Transactions',
          columns: const ['Order ID', 'Capital', 'Revenue', 'Profit'],
          rows: completed.map((o) => [
            '#${o.orderId}',
            '₱${o.totalCapital.toStringAsFixed(2)}',
            '₱${o.subtotal.toStringAsFixed(2)}',
            '₱${o.totalProfit.toStringAsFixed(2)}',
          ]).toList(),
        );
      case OwnerReportType.wastageLog:
        final archived =
        inventory.archivedStock.where((a) => a.reason == StockRemovalReason.wastage).toList();
        return _ReportTable(
          title: 'Archive & Loss History',
          columns: const ['Item', 'Qty', 'Loss (Cap)'],
          rows: archived.map((a) => [
            a.productName,
            '${a.quantity} pcs',
            '₱${a.capital.toStringAsFixed(2)}',
          ]).toList(),
        );
      case OwnerReportType.consumablesLog:
        final consumed = inventory.archivedStock
            .where((a) => a.reason == StockRemovalReason.consumable)
            .toList();
        return _ReportTable(
          title: 'Consumables History',
          columns: const ['Item', 'Qty', 'Taken By', 'Cost'],
          rows: consumed.map((a) => [
            a.productName,
            '${a.quantity} pcs',
            a.consumedBy ?? '—',
            '₱${a.capital.toStringAsFixed(2)}',
          ]).toList(),
        );
      default:
        return Center(
          child: Column(
            children: [
              const Icon(Icons.bar_chart, size: 64, color: AppColors.borderColor),
              const SizedBox(height: 16),
              Text('Detailed data for "$_title"', style: const TextStyle(color: AppColors.secondaryText)),
              const Text('will be populated as sales occur.', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
            ],
          ),
        );
    }
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12, fontWeight: FontWeight.w500)),
            Text(value, style: const TextStyle(color: AppColors.darkText, fontSize: 24, fontWeight: FontWeight.w900)),
          ],
        ),
      ],
    );
  }
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({required this.title, required this.columns, required this.rows});
  final String title;
  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: columns.map((c) => Expanded(
                    child: Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.secondaryText)),
                  )).toList(),
                ),
              ),
              // Body
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No records found for this period.', style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
                )
              else
                ...List.generate(rows.length, (index) {
                  final row = rows[index];
                  final isLast = index == rows.length - 1;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: isLast ? null : Border(bottom: BorderSide(color: AppColors.borderColor.withValues(alpha: 0.3))),
                    ),
                    child: Row(
                      children: row.map((cell) => Expanded(
                        child: Text(cell, style: const TextStyle(fontSize: 13, color: AppColors.darkText, fontWeight: FontWeight.w500)),
                      )).toList(),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}
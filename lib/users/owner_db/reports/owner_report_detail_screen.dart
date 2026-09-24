import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../employee_db/employee_inventory_controller.dart';
import '../../employee_db/orders/employee_orders_controller.dart';
import '../../employee_db/inventory/employee_product_model.dart';
import '../../customer_db/purchases/customer_order_model.dart';

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

class OwnerReportDetailScreen extends StatefulWidget {
  const OwnerReportDetailScreen({
    super.key,
    required this.type,
    this.initialDate,
  });

  final OwnerReportType type;
  final DateTime? initialDate;

  @override
  State<OwnerReportDetailScreen> createState() => _OwnerReportDetailScreenState();
}

class _OwnerReportDetailScreenState extends State<OwnerReportDetailScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String get _title {
    switch (widget.type) {
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

  @override
  Widget build(BuildContext context) {
    final inventory = EmployeeInventoryController.instance;
    final orderController = EmployeeOrderController.instance;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        foregroundColor: AppColors.darkText,
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([inventory, orderController]),
          builder: (context, _) {
            return SingleChildScrollView(
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final dateFormatted =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final isToday = _isSameDay(_selectedDate, DateTime.now());

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
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Today', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // --- Date Picker Navigation Bar ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.lightBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.chevron_left, size: 22, color: AppColors.darkText),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                    });
                  },
                  tooltip: 'Previous Day',
                ),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primaryOrange),
                        const SizedBox(width: 8),
                        Text(
                          dateFormatted,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkText),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, color: AppColors.secondaryText, size: 20),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.chevron_right, size: 22, color: AppColors.darkText),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.add(const Duration(days: 1));
                    });
                  },
                  tooltip: 'Next Day',
                ),
              ],
            ),
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

    switch (widget.type) {
      case OwnerReportType.dailyRevenue:
        final completed = orders.where((o) =>
          o.status == OrderStatus.completed &&
          _isSameDay(o.orderDate, _selectedDate)
        ).toList();
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

      case OwnerReportType.paymentReconciliation:
        final completed = orders.where((o) =>
          o.status == OrderStatus.completed &&
          _isSameDay(o.orderDate, _selectedDate)
        ).toList();
        final cashTotal = completed.where((o) => o.paymentMethod == PaymentMethod.cashOnDelivery).fold(0.0, (sum, o) => sum + o.subtotal);
        final gcashTotal = completed.where((o) => o.paymentMethod == PaymentMethod.gCash).fold(0.0, (sum, o) => sum + o.subtotal);
        return Column(
          children: [
            _KpiRow(label: 'Cash Sales', value: '₱ ${cashTotal.toStringAsFixed(2)}', icon: Icons.money, color: Colors.green),
            const SizedBox(height: 12),
            _KpiRow(label: 'GCash Sales', value: '₱ ${gcashTotal.toStringAsFixed(2)}', icon: Icons.account_balance_wallet, color: Colors.blue),
          ],
        );

      case OwnerReportType.salesChannelComparison:
        final completed = orders.where((o) =>
          o.status == OrderStatus.completed &&
          _isSameDay(o.orderDate, _selectedDate)
        ).toList();
        final posSales = completed.where((o) => o.customerName == 'Walk-in' || o.orderId.startsWith('RC-')).fold(0.0, (sum, o) => sum + o.subtotal);
        final onlineSales = completed.where((o) => o.customerName != 'Walk-in' && !o.orderId.startsWith('RC-')).fold(0.0, (sum, o) => sum + o.subtotal);
        return Column(
          children: [
            _KpiRow(label: 'In-Store (POS) Sales', value: '₱ ${posSales.toStringAsFixed(2)}', icon: Icons.point_of_sale, color: Colors.indigo),
            const SizedBox(height: 12),
            _KpiRow(label: 'Online Orders Sales', value: '₱ ${onlineSales.toStringAsFixed(2)}', icon: Icons.shopping_bag, color: Colors.orange),
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

      case OwnerReportType.bestSellers:
        final Map<String, int> qtyMap = {};
        for (final o in orders.where((o) => o.status == OrderStatus.completed)) {
          for (final item in o.items) {
            qtyMap[item.productName] = (qtyMap[item.productName] ?? 0) + item.quantity;
          }
        }
        final sorted = qtyMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final topName = sorted.isNotEmpty ? sorted.first.key : 'None yet';
        return _KpiRow(label: 'Top Selling Item', value: topName, icon: Icons.star, color: Colors.teal);

      default:
        return _KpiRow(label: 'Overall Status', value: 'Healthy', icon: Icons.check_circle_outline, color: AppColors.primaryOrange);
    }
  }

  Widget _buildReportContent(BuildContext context) {
    final inventory = EmployeeInventoryController.instance;
    final orders = EmployeeOrderController.instance.orders;

    switch (widget.type) {
      case OwnerReportType.dailyRevenue:
        final completed = orders.where((o) =>
          o.status == OrderStatus.completed &&
          _isSameDay(o.orderDate, _selectedDate)
        ).toList();
        return _TransactionCardList(
          title: 'Completed Transactions',
          orders: completed,
        );

      case OwnerReportType.paymentReconciliation:
        final completed = orders.where((o) =>
          o.status == OrderStatus.completed &&
          _isSameDay(o.orderDate, _selectedDate)
        ).toList();
        return _TransactionCardList(
          title: 'Payment Breakdown',
          orders: completed,
        );

      case OwnerReportType.salesChannelComparison:
        final completed = orders.where((o) =>
          o.status == OrderStatus.completed &&
          _isSameDay(o.orderDate, _selectedDate)
        ).toList();
        return _TransactionCardList(
          title: 'Channel Sales History',
          orders: completed,
        );

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

      case OwnerReportType.bestSellers:
        final Map<String, int> qtyMap = {};
        final Map<String, double> revMap = {};
        for (final o in orders.where((o) => o.status == OrderStatus.completed)) {
          for (final item in o.items) {
            qtyMap[item.productName] = (qtyMap[item.productName] ?? 0) + item.quantity;
            revMap[item.productName] = (revMap[item.productName] ?? 0.0) + item.subtotal;
          }
        }
        final sorted = qtyMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        return _ReportTable(
          title: 'Best Selling Products',
          columns: const ['Product', 'Units Sold', 'Total Revenue'],
          rows: sorted.map((e) => [
            e.key,
            '${e.value} pcs',
            '₱${(revMap[e.key] ?? 0.0).toStringAsFixed(2)}',
          ]).toList(),
        );

      case OwnerReportType.slowMoving:
        final soldNames = orders.where((o) => o.status == OrderStatus.completed)
            .expand((o) => o.items)
            .map((i) => i.productName)
            .toSet();
        final slow = inventory.products.where((p) => !soldNames.contains(p.name)).toList();
        return _ReportTable(
          title: 'Slow-Moving / Unsold Items',
          columns: const ['Product', 'Stock', 'Price'],
          rows: slow.map((p) => [
            p.name,
            '${p.quantity} pcs',
            '₱${p.price.toStringAsFixed(2)}',
          ]).toList(),
        );

      case OwnerReportType.categoryPerformance:
        final Map<String, double> catRev = {};
        for (final o in orders.where((o) => o.status == OrderStatus.completed)) {
          for (final item in o.items) {
            final prod = inventory.findById(item.productId);
            final cat = prod?.category ?? 'General';
            catRev[cat] = (catRev[cat] ?? 0.0) + item.subtotal;
          }
        }
        final sorted = catRev.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        return _ReportTable(
          title: 'Sales by Category',
          columns: const ['Category', 'Total Revenue'],
          rows: sorted.map((e) => [
            e.key,
            '₱${e.value.toStringAsFixed(2)}',
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

class _TransactionCardList extends StatelessWidget {
  const _TransactionCardList({required this.title, required this.orders});

  final String title;
  final List<CustomerOrder> orders;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText)),
        const SizedBox(height: 16),
        if (orders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
            ),
            child: const Center(
              child: Text('No records found for this period.', style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
            ),
          )
        else
          ...orders.map((o) {
            final productsText = o.items.isNotEmpty
                ? o.items.map((i) => '${i.productName} (${i.quantity}x)').join(', ')
                : 'Walk-in Sale';
            final timeStr = '${o.orderDate.hour.toString().padLeft(2, '0')}:${o.orderDate.minute.toString().padLeft(2, '0')}';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Order ID & Revenue Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '#${o.orderId}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.darkText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${o.customerName} · $timeStr',
                                style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '₱${o.subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.lightBackground),
                    const SizedBox(height: 12),

                    // Middle Row: Products List
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 16, color: AppColors.primaryOrange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            productsText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Bottom Row: Capital & Profit breakdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('Capital: ', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                              Text('₱${o.totalCapital.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.darkText)),
                            ],
                          ),
                          Row(
                            children: [
                              const Text('Net Profit: ', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                              Text('₱${o.totalProfit.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({
    required this.title,
    required this.columns,
    required this.rows,
    this.flexes,
  });

  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  final List<int>? flexes;

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
                  children: List.generate(columns.length, (i) {
                    final flex = (flexes != null && i < flexes!.length) ? flexes![i] : 1;
                    return Expanded(
                      flex: flex,
                      child: Text(
                        columns[i],
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.secondaryText),
                      ),
                    );
                  }),
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
                      children: List.generate(row.length, (i) {
                        final flex = (flexes != null && i < flexes!.length) ? flexes![i] : 1;
                        return Expanded(
                          flex: flex,
                          child: Text(
                            row[i],
                            style: const TextStyle(fontSize: 13, color: AppColors.darkText, fontWeight: FontWeight.w500),
                          ),
                        );
                      }),
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
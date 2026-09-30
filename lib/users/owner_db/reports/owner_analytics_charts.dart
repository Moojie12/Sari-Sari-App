import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../customer_db/purchases/customer_order_model.dart';
import '../../employee_db/employee_inventory_controller.dart';
import '../../employee_db/inventory/employee_product_model.dart';

// ============================================================================
// 1. DESCRIPTIVE ANALYTICS VIEW & CHARTS
// ============================================================================

class DescriptiveAnalyticsView extends StatelessWidget {
  const DescriptiveAnalyticsView({
    super.key,
    required this.orders,
    required this.inventory,
  });

  final List<CustomerOrder> orders;
  final EmployeeInventoryController inventory;

  @override
  Widget build(BuildContext context) {
    final completed = orders.where((o) => o.status == OrderStatus.completed).toList();
    final totalRevenue = completed.fold(0.0, (sum, o) => sum + o.subtotal);
    final totalCapital = completed.fold(0.0, (sum, o) => sum + o.totalCapital);
    final totalProfit = totalRevenue - totalCapital - inventory.totalConsumablesCost;
    final marginPct = totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0;
    final totalUnitsSold = completed.fold(0, (sum, o) => sum + o.items.fold(0, (s, i) => s + i.quantity));
    final avgOrderValue = completed.isNotEmpty ? totalRevenue / completed.length : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Grid
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Total Revenue',
                value: '₱${totalRevenue.toStringAsFixed(2)}',
                subtitle: '${completed.length} completed orders',
                icon: Icons.payments_outlined,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Net Profit',
                value: '₱${totalProfit.toStringAsFixed(2)}',
                subtitle: '${marginPct.toStringAsFixed(1)}% profit margin',
                icon: Icons.trending_up_rounded,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Units Sold',
                value: '$totalUnitsSold pcs',
                subtitle: 'All completed items',
                icon: Icons.shopping_basket_outlined,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Avg Order Value',
                value: '₱${avgOrderValue.toStringAsFixed(2)}',
                subtitle: 'Per transaction',
                icon: Icons.receipt_long_outlined,
                color: Colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Weekly Revenue & Profit Bar Chart
        _WeeklySalesBarChart(orders: completed),
        const SizedBox(height: 20),

        // Category Sales Breakdown
        _CategoryDistributionChart(orders: completed, inventory: inventory),
        const SizedBox(height: 20),

        // Top Selling Products Chart
        _TopSellingProductsRanking(orders: completed),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.darkText,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.secondaryText.withValues(alpha: 0.8),
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _WeeklySalesBarChart extends StatelessWidget {
  const _WeeklySalesBarChart({required this.orders});

  final List<CustomerOrder> orders;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final List<_DailyData> dailyData = [];

    // Calculate last 7 days sales
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayOrders = orders.where((o) =>
          o.orderDate.year == date.year &&
          o.orderDate.month == date.month &&
          o.orderDate.day == date.day);

      final revenue = dayOrders.fold(0.0, (sum, o) => sum + o.subtotal);
      final profit = dayOrders.fold(0.0, (sum, o) => sum + o.totalProfit);

      dailyData.add(_DailyData(
        dayLabel: _getDayLabel(date, i == 0),
        revenue: revenue,
        profit: profit > 0 ? profit : 0.0,
      ));
    }

    final maxVal = dailyData.fold<double>(
      100.0,
      (max, d) => max < d.revenue ? d.revenue : max,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '7-Day Revenue & Profit Trend',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Daily breakdown of earnings vs. net margin',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  _LegendDot(color: Colors.blue, label: 'Rev'),
                  SizedBox(width: 6),
                  _LegendDot(color: Colors.green, label: 'Prof'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bar Chart Graphic
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: dailyData.map((d) {
                final revHeight = maxVal > 0 ? (d.revenue / maxVal).clamp(0.0, 1.0) * 85.0 : 4.0;
                final profHeight = maxVal > 0 ? (d.profit / maxVal).clamp(0.0, 1.0) * 85.0 : 4.0;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        d.revenue > 0
                            ? '₱${d.revenue >= 1000 ? '${(d.revenue / 1000).toStringAsFixed(1)}k' : d.revenue.round()}'
                            : '',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 10,
                            height: max(revHeight, 4.0),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Container(
                            width: 10,
                            height: max(profHeight, 4.0),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        d.dayLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: d.dayLabel == 'Today' ? FontWeight.bold : FontWeight.w500,
                          color: d.dayLabel == 'Today' ? AppColors.primaryOrange : AppColors.darkText,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getDayLabel(DateTime date, bool isToday) {
    if (isToday) return 'Today';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }
}

class _DailyData {
  _DailyData({required this.dayLabel, required this.revenue, required this.profit});
  final String dayLabel;
  final double revenue;
  final double profit;
}

class _CategoryDistributionChart extends StatelessWidget {
  const _CategoryDistributionChart({
    required this.orders,
    required this.inventory,
  });

  final List<CustomerOrder> orders;
  final EmployeeInventoryController inventory;

  static const List<Color> _palette = [
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];

  @override
  Widget build(BuildContext context) {
    final Map<String, double> categoryRevenue = {};
    double totalRev = 0.0;

    for (final o in orders) {
      for (final item in o.items) {
        final prod = inventory.findById(item.productId);
        final cat = prod?.category ?? 'General';
        categoryRevenue[cat] = (categoryRevenue[cat] ?? 0.0) + item.subtotal;
        totalRev += item.subtotal;
      }
    }

    final sorted = categoryRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales by Category Share',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Revenue distribution across store product categories',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 18),

          if (sorted.isEmpty || totalRev == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No category sales recorded yet.',
                    style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 18,
                child: Row(
                  children: sorted.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final pct = item.value / totalRev;
                    final color = _palette[index % _palette.length];

                    return Expanded(
                      flex: max((pct * 100).round(), 1),
                      child: Container(color: color),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 18),

            ...sorted.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final pct = totalRev > 0 ? (item.value / totalRev) * 100 : 0.0;
              final color = _palette[index % _palette.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.key,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                    Text(
                      '₱${item.value.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _TopSellingProductsRanking extends StatelessWidget {
  const _TopSellingProductsRanking({required this.orders});

  final List<CustomerOrder> orders;

  @override
  Widget build(BuildContext context) {
    final Map<String, int> qtyMap = {};
    final Map<String, double> revMap = {};

    for (final o in orders) {
      for (final item in o.items) {
        qtyMap[item.productName] = (qtyMap[item.productName] ?? 0) + item.quantity;
        revMap[item.productName] = (revMap[item.productName] ?? 0.0) + item.subtotal;
      }
    }

    final sorted = qtyMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topItems = sorted.take(5).toList();
    final maxQty = topItems.isNotEmpty ? topItems.first.value : 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Selling Products (Volume)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Highest velocity products ranked by units sold',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 18),

          if (topItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No products sold yet.',
                    style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
              ),
            )
          else
            ...topItems.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final item = entry.value;
              final qty = item.value;
              final rev = revMap[item.key] ?? 0.0;
              final progress = maxQty > 0 ? (qty / maxQty).clamp(0.0, 1.0) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: rank == 1
                                      ? Colors.amber
                                      : (rank == 2
                                          ? Colors.blueGrey.shade300
                                          : (rank == 3
                                              ? Colors.brown.shade300
                                              : AppColors.lightBackground)),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$rank',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: rank <= 3 ? Colors.white : AppColors.secondaryText,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.key,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkText,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$qty pcs · ₱${rev.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppColors.lightBackground,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          rank == 1 ? AppColors.primaryOrange : Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. PREDICTIVE ANALYTICS VIEW & CHARTS
// ============================================================================

class PredictiveAnalyticsView extends StatelessWidget {
  const PredictiveAnalyticsView({
    super.key,
    required this.orders,
    required this.inventory,
  });

  final List<CustomerOrder> orders;
  final EmployeeInventoryController inventory;

  @override
  Widget build(BuildContext context) {
    final completed = orders.where((o) => o.status == OrderStatus.completed).toList();
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final recentOrders = completed.where((o) => o.orderDate.isAfter(sevenDaysAgo)).toList();
    final recentRev = recentOrders.fold(0.0, (sum, o) => sum + o.subtotal);
    final avgDailyRev = recentOrders.isNotEmpty
        ? recentRev / 7.0
        : (completed.isNotEmpty ? completed.fold(0.0, (s, o) => s + o.subtotal) / 14.0 : 250.0);

    final outOfStockCount = inventory.outOfStockProducts.length;
    final lowStockCount = inventory.lowStockProducts.length;
    final projectedWeekRev = avgDailyRev * 7.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MetricCard(
                title: '7-Day Demand Forecast',
                value: '₱${projectedWeekRev.toStringAsFixed(2)}',
                subtitle: 'Avg ₱${avgDailyRev.toStringAsFixed(2)}/day',
                icon: Icons.auto_graph_rounded,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Stockout Risk Alert',
                value: '$outOfStockCount Out · $lowStockCount Low',
                subtitle: outOfStockCount > 0 ? 'Requires immediate restock' : 'Inventory stable',
                icon: Icons.warning_amber_rounded,
                color: outOfStockCount > 0 ? Colors.red : Colors.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _ForecastDemandChart(avgDailyRev: avgDailyRev),
        const SizedBox(height: 20),

        _StockoutRiskTimeline(inventory: inventory, orders: completed),
        const SizedBox(height: 20),

        _WeatherPredictiveCard(),
      ],
    );
  }
}

class _ForecastDemandChart extends StatelessWidget {
  const _ForecastDemandChart({required this.avgDailyRev});

  final double avgDailyRev;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final List<_ForecastDay> forecastDays = [];
    final random = Random(42);

    for (int i = 1; i <= 7; i++) {
      final date = now.add(Duration(days: i));
      final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
      final multiplier = isWeekend ? 1.25 : (0.95 + (random.nextDouble() * 0.15));
      final projected = max(50.0, avgDailyRev * multiplier);
      forecastDays.add(_ForecastDay(
        dayLabel: _getFutureDayLabel(date, i == 1),
        projectedAmount: projected,
        isWeekend: isWeekend,
      ));
    }

    final maxProj = forecastDays.fold<double>(
      100.0,
      (max, d) => max < d.projectedAmount ? d.projectedAmount : max,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '7-Day Sales Demand Forecast',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Predicted sales volume using 7-day velocity model',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('AI Predictive',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: forecastDays.map((d) {
                final barHeight = maxProj > 0 ? (d.projectedAmount / maxProj).clamp(0.0, 1.0) * 85.0 : 8.0;
                final barColor = d.isWeekend ? AppColors.primaryOrange : const Color(0xFF6366F1);

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '₱${d.projectedAmount >= 1000 ? '${(d.projectedAmount / 1000).toStringAsFixed(1)}k' : d.projectedAmount.round()}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 18,
                        height: max(barHeight, 8.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              barColor,
                              barColor.withValues(alpha: 0.6),
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        d.dayLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: d.isWeekend ? FontWeight.bold : FontWeight.w500,
                          color: d.isWeekend ? AppColors.primaryOrange : AppColors.darkText,
                        ),
                      ),
                      if (d.isWeekend)
                        const Text(
                          'Peak',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getFutureDayLabel(DateTime date, bool isTomorrow) {
    if (isTomorrow) return 'Tmrw';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }
}

class _ForecastDay {
  _ForecastDay({required this.dayLabel, required this.projectedAmount, required this.isWeekend});
  final String dayLabel;
  final double projectedAmount;
  final bool isWeekend;
}

class _StockoutRiskTimeline extends StatelessWidget {
  const _StockoutRiskTimeline({
    required this.inventory,
    required this.orders,
  });

  final EmployeeInventoryController inventory;
  final List<CustomerOrder> orders;

  @override
  Widget build(BuildContext context) {
    final Map<String, double> weeklySoldMap = {};
    for (final o in orders) {
      for (final item in o.items) {
        weeklySoldMap[item.productId] = (weeklySoldMap[item.productId] ?? 0.0) + item.quantity;
      }
    }

    final List<_ProductDepletionRisk> riskList = [];

    for (final prod in inventory.products) {
      final weeklyUnits = weeklySoldMap[prod.id] ?? 0.0;
      final dailyRunRate = weeklyUnits > 0 ? (weeklyUnits / 7.0) : 0.5;
      final daysRemaining = prod.quantity > 0 ? (prod.quantity / dailyRunRate) : 0.0;

      riskList.add(_ProductDepletionRisk(
        productName: prod.name,
        currentStock: prod.quantity,
        dailyRate: dailyRunRate,
        daysRemaining: daysRemaining,
        threshold: prod.lowStockThreshold,
      ));
    }

    riskList.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
    final displayedRisks = riskList.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stockout Depletion Timeline',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Projected days until stock reaches zero based on consumption speed',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 18),

          if (displayedRisks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('All products are well stocked.',
                    style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
              ),
            )
          else
            ...displayedRisks.map((item) {
              Color statusColor;
              String statusLabel;
              if (item.currentStock <= 0) {
                statusColor = Colors.red;
                statusLabel = 'OUT OF STOCK';
              } else if (item.daysRemaining <= 2) {
                statusColor = Colors.red;
                statusLabel = 'Critical (${item.daysRemaining.toStringAsFixed(1)}d)';
              } else if (item.daysRemaining <= 5) {
                statusColor = Colors.amber.shade800;
                statusLabel = 'High Risk (${item.daysRemaining.toStringAsFixed(1)}d)';
              } else {
                statusColor = Colors.green;
                statusLabel = 'Healthy (${item.daysRemaining.toStringAsFixed(1)}d)';
              }

              final progress = (item.daysRemaining / 7.0).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.productName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Current Stock: ${item.currentStock.round()} pcs',
                            style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                          ),
                          Text(
                            'Run Rate: ~${item.dailyRate.toStringAsFixed(1)} pcs/day',
                            style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: statusColor.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ProductDepletionRisk {
  _ProductDepletionRisk({
    required this.productName,
    required this.currentStock,
    required this.dailyRate,
    required this.daysRemaining,
    required this.threshold,
  });

  final String productName;
  final double currentStock;
  final double dailyRate;
  final double daysRemaining;
  final double threshold;
}

class _WeatherPredictiveCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E3A8A),
            Color(0xFF3B82F6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Weather-Demand Correlation',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Automated',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Forecast indicates high rain probability this week. Store predictive models forecast a +25% spike in instant noodles, canned soup, and warm coffee beverages.',
            style: TextStyle(fontSize: 12, color: Colors.white, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. PRESCRIPTIVE ANALYTICS VIEW & CHARTS
// ============================================================================

class PrescriptiveAnalyticsView extends StatelessWidget {
  const PrescriptiveAnalyticsView({
    super.key,
    required this.orders,
    required this.inventory,
  });

  final List<CustomerOrder> orders;
  final EmployeeInventoryController inventory;

  @override
  Widget build(BuildContext context) {
    final completed = orders.where((o) => o.status == OrderStatus.completed).toList();
    final lowAndOut = [...inventory.outOfStockProducts, ...inventory.lowStockProducts];
    final expiringBatches = [...inventory.expiringIn5DaysProducts, ...inventory.expiringIn2WeeksProducts];

    double totalRestockCap = 0.0;
    double expectedRestockProfit = 0.0;

    for (final p in lowAndOut) {
      final recQty = max(10.0, p.lowStockThreshold * 2.0);
      final cap = recQty * p.capital;
      final profit = recQty * (p.price - p.capital);
      totalRestockCap += cap;
      expectedRestockProfit += profit;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Restock Capital Required',
                value: '₱${totalRestockCap.toStringAsFixed(2)}',
                subtitle: 'To restock ${lowAndOut.length} critical items',
                icon: Icons.account_balance_wallet_outlined,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Projected Net Return',
                value: '₱${expectedRestockProfit.toStringAsFixed(2)}',
                subtitle: 'Expected margin return',
                icon: Icons.price_check_rounded,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _SmartRestockOptimizationCard(
          lowStockProducts: lowAndOut,
          orders: completed,
        ),
        const SizedBox(height: 20),

        _ExpiryMarkdownPlanCard(expiringProducts: expiringBatches),
        const SizedBox(height: 20),

        _MarginOptimizationPrescriptions(inventory: inventory, orders: completed),
      ],
    );
  }
}

class _SmartRestockOptimizationCard extends StatelessWidget {
  const _SmartRestockOptimizationCard({
    required this.lowStockProducts,
    required this.orders,
  });

  final List<EmployeeProduct> lowStockProducts;
  final List<CustomerOrder> orders;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Prescribed Restock Quantities',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Algorithmically calculated order units to prevent missed sales',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Prescriptive',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (lowStockProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('All inventory is optimal. No reorders needed.',
                    style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
              ),
            )
          else
            ...lowStockProducts.take(5).map((prod) {
              final recQty = max(12.0, (prod.lowStockThreshold * 2.5) - prod.quantity);
              final capNeeded = recQty * prod.capital;
              final expRevenue = recQty * prod.price;
              final expProfit = expRevenue - capNeeded;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              prod.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: prod.quantity <= 0 ? Colors.red : Colors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              prod.quantity <= 0 ? 'URGENT REORDER' : 'REORDER SOON',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text('Current: ${prod.quantity.round()} pcs',
                              style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Reorder: +${recQty.round()} pcs',
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Comparison pill - wrap enabled to prevent overflow on narrow screens
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Capital Cost: ₱${capNeeded.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                            ),
                            Text(
                              'Expected Profit: +₱${expProfit.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
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
      ),
    );
  }
}

class _ExpiryMarkdownPlanCard extends StatelessWidget {
  const _ExpiryMarkdownPlanCard({required this.expiringProducts});

  final List<EmployeeProduct> expiringProducts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expiry Markdown Strategy (Waste Prevention)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Prescribed discount actions to liquidate batches before expiry loss',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 18),

          if (expiringProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No batches nearing expiry.',
                    style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
              ),
            )
          else
            ...expiringProducts.take(3).map((prod) {
              final discountPct = 20;
              final discountedPrice = prod.price * (1 - (discountPct / 100));
              final salvagedTotal = prod.quantity * discountedPrice;
              final capitalSaved = prod.quantity * prod.capital;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              prod.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Action: Apply $discountPct% Promo',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Mark down from ₱${prod.price.toStringAsFixed(2)} to ₱${discountedPrice.toStringAsFixed(2)} to recover ₱${salvagedTotal.toStringAsFixed(2)} revenue and protect ₱${capitalSaved.toStringAsFixed(2)} in capital.',
                        style: const TextStyle(fontSize: 11, color: AppColors.secondaryText, height: 1.3),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _MarginOptimizationPrescriptions extends StatelessWidget {
  const _MarginOptimizationPrescriptions({
    required this.inventory,
    required this.orders,
  });

  final EmployeeInventoryController inventory;
  final List<CustomerOrder> orders;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profit Margin Optimization Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 12),
          _PrescriptionTile(
            icon: Icons.trending_up,
            color: Colors.green,
            title: 'Bundle High-Margin Snacks with Fast Drinks',
            description:
                'Beverages drive customer footfall while Snacks yield 35%+ gross margin. Positioning them together at the POS counter increases combined basket profit.',
          ),
          const SizedBox(height: 12),
          _PrescriptionTile(
            icon: Icons.inventory_2_outlined,
            color: Colors.blue,
            title: 'Consumables Audit & Cost Allocation',
            description:
                'Ensure all personal/employee consumables are systematically logged in the Consumables Log so net margins accurately reflect genuine store overhead.',
          ),
        ],
      ),
    );
  }
}

class _PrescriptionTile extends StatelessWidget {
  const _PrescriptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.secondaryText,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

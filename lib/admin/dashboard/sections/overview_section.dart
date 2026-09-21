import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/admin_models.dart';
import '../../services/admin_product_service.dart';
import '../../services/admin_user_service.dart';
import '../../services/admin_category_service.dart';
import '../../services/admin_sale_service.dart';
import '../../services/admin_audit_service.dart';
import '../../services/admin_analytics_service.dart';
import '../widgets/dashboard_shared.dart';

class OverviewSection extends StatelessWidget {
  final AdminProductService productService;
  final AdminUserService userService;
  final AdminCategoryService categoryService;
  final AdminSaleService saleService;
  final AdminAuditService auditService;
  final AdminAnalyticsService analyticsService;
  final Function(AdminSection) onGoTo;
  final Function(AdminProduct) onAdjustStock;

  const OverviewSection({
    super.key,
    required this.productService,
    required this.userService,
    required this.categoryService,
    required this.saleService,
    required this.auditService,
    required this.analyticsService,
    required this.onGoTo,
    required this.onAdjustStock,
  });

  @override
  Widget build(BuildContext context) {
    // Wait for services to initialize
    if (!productService.isInitialized ||
        !userService.isInitialized ||
        !categoryService.isInitialized ||
        !saleService.isInitialized ||
        !auditService.isInitialized ||
        !analyticsService.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryOrange,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _twoColumn(
          _buildSalesChartCard(),
          _buildTopSellersCard(),
          flexA: 3,
          flexB: 2,
        ),
        const SizedBox(height: 20),
        _threeColumn([
          _buildDailySalesCard(),
          _buildWeeklySalesCard(),
          _buildMonthlySalesCard(),
        ]),
        const SizedBox(height: 20),
        _twoColumn(
          _buildLowStockCard(),
          _buildRecentActivityCard(),
          flexA: 3,
          flexB: 2,
        ),
      ],
    );
  }

  Widget _twoColumn(Widget a, Widget b,
      {int flexA = 1, int flexB = 1, double breakpoint = 1040}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(children: [a, const SizedBox(height: 20), b]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: flexA, child: a),
            const SizedBox(width: 20),
            Expanded(flex: flexB, child: b),
          ],
        );
      },
    );
  }

  Widget _threeColumn(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // If width is zero (e.g. during initial layout), return a placeholder or empty container
        // to avoid "Cannot hit test a render box with no size" errors.
        if (width <= 0) return const SizedBox.shrink();

        final columns = width < 700 ? 1 : (width < 1180 ? 2 : 3);
        const spacing = 20.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;
        
        // Ensure cardWidth is at least a reasonable minimum
        final effectiveCardWidth = cardWidth < 100 ? width : cardWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final c in cards) SizedBox(width: effectiveCardWidth, child: c),
          ],
        );
      },
    );
  }

  Widget _buildSalesChartCard() {
    final data = analyticsService.salesByDay(7);
    final maxValue = data.fold<double>(
        0, (max, d) => d.total > max ? d.total : max);
    final weekTotal = data.fold<double>(0, (sum, d) => sum + d.total);

    return card(
      title: 'Sales this week',
      subtitle: '${formatPeso(weekTotal)} over the last 7 days',
      child: SizedBox(
        height: 190,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final day in data)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          day.total == 0
                              ? '—'
                              : formatPesoCompact(day.total),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: maxValue == 0
                            ? 2
                            : 4 + (day.total / maxValue) * 118,
                        decoration: BoxDecoration(
                          color: isSameDay(day.day, DateTime.now())
                              ? AppColors.primaryOrange
                              : AppColors.primaryOrange
                              .withValues(alpha: 0.28),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatShortDate(day.day),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.placeholderColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSellersCard() {
    final stats = analyticsService.topSellingProducts(limit: 5);
    final topRevenue = stats.isEmpty ? 0.0 : stats.first.revenue;

    return card(
      title: 'Best sellers',
      subtitle: 'By revenue, all time',
      child: stats.isEmpty
          ? _inlineEmpty('No sales recorded yet.')
          : Column(
            children: [
              for (final stat in stats)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              stat.productName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            formatPeso(stat.revenue),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (topRevenue <= 0)
                              ? 0
                              : (stat.revenue / topRevenue).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: AppColors.lightBackground,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primaryOrange),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatQuantity(stat.unitsSold, stat.unit)} sold',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.placeholderColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
    );
  }

  Widget _buildDailySalesCard() {
    final days = analyticsService.salesByDay(7);
    final now = DateTime.now();
    return _periodListCard(
      title: 'Daily sales',
      subtitle: 'Last 7 days',
      rows: [
        for (final d in days.reversed)
          _PeriodRow(
            label: formatShortDate(d.day),
            isCurrent: isSameDay(d.day, now),
            total: d.total,
            orders: d.orders,
          ),
      ],
    );
  }

  Widget _buildWeeklySalesCard() {
    final weeks = analyticsService.salesByWeek(6);
    final now = DateTime.now();
    final nowMidnight = DateTime(now.year, now.month, now.day);
    return _periodListCard(
      title: 'Weekly sales',
      subtitle: 'Last 6 weeks',
      rows: [
        for (final w in weeks.reversed)
          _PeriodRow(
            label: formatWeekRange(w.weekStart, w.weekEnd),
            isCurrent: !nowMidnight.isBefore(w.weekStart) &&
                !nowMidnight.isAfter(w.weekEnd),
            total: w.total,
            orders: w.orders,
          ),
      ],
    );
  }

  Widget _buildMonthlySalesCard() {
    final months = analyticsService.salesByMonth(6);
    final now = DateTime.now();
    return _periodListCard(
      title: 'Monthly sales',
      subtitle: 'Last 6 months',
      rows: [
        for (final m in months.reversed)
          _PeriodRow(
            label: formatMonthYear(m.year, m.month),
            isCurrent: m.year == now.year && m.month == now.month,
            total: m.total,
            orders: m.orders,
          ),
      ],
    );
  }

  Widget _periodListCard({
    required String title,
    required String subtitle,
    required List<_PeriodRow> rows,
  }) {
    final total = rows.fold<double>(0, (sum, r) => sum + r.total);
    final hasAnySales = rows.any((r) => r.total > 0);

    return card(
      title: title,
      subtitle: subtitle,
      child: !hasAnySales
          ? _inlineEmpty('No sales recorded yet.')
          : Column(
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: row.isCurrent
                              ? AppColors.primaryOrange
                              : Colors.transparent,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                            row.isCurrent ? FontWeight.w700 : FontWeight.w500,
                            color: row.isCurrent
                                ? AppColors.darkText
                                : AppColors.secondaryText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${row.orders}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.placeholderColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 78,
                        child: Text(
                          formatPeso(row.total),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: row.total == 0
                                ? AppColors.placeholderColor
                                : AppColors.darkText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondaryText,
                  ),
                ),
                Text(
                  formatPeso(total),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }

  Widget _buildLowStockCard() {
    final items = analyticsService.lowStockProducts.take(6).toList();

    return card(
      title: 'Restock list',
      subtitle: 'Products at or below their reorder level',
      trailing: items.isEmpty
          ? null
          : TextButton(
            onPressed: () => onGoTo(AdminSection.products),
            child: const Text('See all'),
          ),
      child: items.isEmpty
          ? _inlineEmpty('Everything is well stocked.')
          : Column(
            children: [
              for (final product in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkText,
                              ),
                            ),
                            Text(
                              product.categoryName,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.placeholderColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      statusPill(
                        product.isOutOfStock
                            ? 'Out of stock'
                            : formatQuantity(product.quantity, product.unit),
                        product.isOutOfStock ? Colors.red : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Adjust stock',
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        color: AppColors.primaryOrange,
                        onPressed: () => onAdjustStock(product),
                      ),
                    ],
                  ),
                ),
            ],
          ),
    );
  }

  Widget _buildRecentActivityCard() {
    final logs = auditService.allAuditLogs.take(6).toList();

    return card(
      title: 'Recent changes',
      subtitle: 'The latest edits to your records',
      trailing: TextButton(
        onPressed: () => onGoTo(AdminSection.activity),
        child: const Text('See all'),
      ),
      child: logs.isEmpty
          ? _inlineEmpty('Nothing has changed yet.')
          : Column(
            children: [
              for (final log in logs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _actionColor(log.action),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${log.action.label} ${log.entityType.toLowerCase()} "${log.entityName}"',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.darkText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${log.performedBy} · ${formatRelative(log.timestamp)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.placeholderColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
    );
  }

  Color _actionColor(AuditAction action) {
    switch (action) {
      case AuditAction.create:
        return Colors.green;
      case AuditAction.update:
        return Colors.blue;
      case AuditAction.archive:
        return Colors.orange;
      case AuditAction.restore:
        return Colors.teal;
      case AuditAction.permanentDelete:
        return Colors.red;
      case AuditAction.voidSale:
        return Colors.red[900]!;
    }
  }

  Widget _inlineEmpty(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.placeholderColor,
          ),
        ),
      ),
    );
  }
}

String formatPesoCompact(double value) {
  if (value.abs() >= 1000000) {
    return '₱${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value.abs() >= 1000) {
    return '₱${(value / 1000).toStringAsFixed(1)}k';
  }
  return '₱${value.toStringAsFixed(0)}';
}

/// One row in a daily/weekly/monthly sales list card.
class _PeriodRow {
  const _PeriodRow({
    required this.label,
    required this.total,
    required this.orders,
    this.isCurrent = false,
  });

  final String label;
  final double total;
  final int orders;
  final bool isCurrent;
}
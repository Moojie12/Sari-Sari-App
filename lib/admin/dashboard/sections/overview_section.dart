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
    return ListenableBuilder(
      listenable: Listenable.merge([
        productService,
        userService,
        categoryService,
        saleService,
        auditService,
        analyticsService,
      ]),
      builder: (context, _) {
        final anyLoading = productService.isLoading ||
            userService.isLoading ||
            categoryService.isLoading ||
            saleService.isLoading ||
            auditService.isLoading ||
            analyticsService.isLoading;

        final allInitialized = productService.isInitialized &&
            userService.isInitialized &&
            categoryService.isInitialized &&
            saleService.isInitialized &&
            auditService.isInitialized &&
            analyticsService.isInitialized;

        if (!allInitialized && anyLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryOrange,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HERO CARD: Best Sellers (Replacing old Sales this week chart)
            _buildTopSellersCard(),
            const SizedBox(height: 20),

            // SALES BREAKDOWN CARDS (Daily, Weekly, Monthlyconnected to Database)
            _threeColumn([
              _buildDailySalesCard(),
              _buildWeeklySalesCard(),
              _buildMonthlySalesCard(),
            ]),
            const SizedBox(height: 20),

            // INVENTORY RESTOCK & RECENT ACTIVITY
            _twoColumn(
              _buildLowStockCard(),
              _buildRecentActivityCard(),
              flexA: 3,
              flexB: 2,
            ),
          ],
        );
      },
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
        if (width <= 0) return const SizedBox.shrink();

        final columns = width < 700 ? 1 : (width < 1180 ? 2 : 3);
        const spacing = 20.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;
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

  Widget _buildTopSellersCard() {
    final stats = analyticsService.topSellingProducts(limit: 6);
    final topRevenue = stats.isEmpty ? 0.0 : stats.first.revenue;

    return card(
      title: 'Best Sellers',
      subtitle: 'Top products ranked by revenue and total units sold',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryOrange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.emoji_events_rounded, size: 14, color: AppColors.primaryOrange),
            SizedBox(width: 4),
            Text(
              'LIVE RANKINGS',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryOrange,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
      child: stats.isEmpty
          ? _inlineEmpty('No sales recorded yet in database.')
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                if (isWide) {
                  // Grid of 2 columns on wide screens
                  final halfLength = (stats.length / 2).ceil();
                  final col1 = stats.take(halfLength).toList();
                  final col2 = stats.skip(halfLength).toList();

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            for (var i = 0; i < col1.length; i++) ...[
                              _buildBestSellerRow(col1[i], i + 1, topRevenue),
                              if (i < col1.length - 1) const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: [
                            for (var i = 0; i < col2.length; i++) ...[
                              _buildBestSellerRow(col2[i], halfLength + i + 1, topRevenue),
                              if (i < col2.length - 1) const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                }

                // Single column on narrow screens
                return Column(
                  children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      _buildBestSellerRow(stats[i], i + 1, topRevenue),
                      if (i < stats.length - 1) const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Widget _buildBestSellerRow(ProductSalesStat stat, int rank, double topRevenue) {
    Color badgeColor;
    IconData? icon;

    if (rank == 1) {
      badgeColor = const Color(0xFFFFD700); // Gold
      icon = Icons.emoji_events_rounded;
    } else if (rank == 2) {
      badgeColor = const Color(0xFFC0C0C0); // Silver
      icon = Icons.workspace_premium_rounded;
    } else if (rank == 3) {
      badgeColor = const Color(0xFFCD7F32); // Bronze
      icon = Icons.military_tech_rounded;
    } else {
      badgeColor = AppColors.primaryOrange.withValues(alpha: 0.15);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryOrange.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Rank Badge
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                  border: Border.all(color: badgeColor, width: 1.5),
                ),
                child: icon != null
                    ? Icon(icon, size: 16, color: rank <= 3 ? AppColors.darkText : AppColors.secondaryText)
                    : Text(
                        '#$rank',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryText,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.productName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatQuantity(stat.unitsSold, stat.unit)} sold',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                analyticsService.formatPeso(stat.revenue),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (topRevenue <= 0) ? 0 : (stat.revenue / topRevenue).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.lightPeach,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
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
    final totalOrders = rows.fold<int>(0, (sum, r) => sum + r.orders);
    final hasAnySales = rows.any((r) => r.total > 0);

    return card(
      title: title,
      subtitle: subtitle,
      child: !hasAnySales
          ? _inlineEmpty('No sales recorded yet in database.')
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.lightPeach,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${row.orders} orders',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 85,
                          child: Text(
                            analyticsService.formatPeso(row.total),
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
                    Text(
                      'Total ($totalOrders orders)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    Text(
                      analyticsService.formatPeso(total),
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

  String formatQuantity(double value, String unit) {
    final isWhole = value == value.roundToDouble();
    final text = isWhole ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
    return '$text $unit';
  }

  String formatShortDate(DateTime dt) => '${dt.day} ${_kMonths[dt.month - 1]}';

  String formatMonthYear(int year, int month) => '${_kMonths[month - 1]} $year';

  String formatWeekRange(DateTime start, DateTime end) {
    if (start.month == end.month) {
      return '${start.day}–${end.day} ${_kMonths[start.month - 1]}';
    }
    return '${start.day} ${_kMonths[start.month - 1]} – ${end.day} ${_kMonths[end.month - 1]}';
  }

  String formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${dt.day} ${_kMonths[dt.month - 1]} ${dt.year}';
  }

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static const List<String> _kMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
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

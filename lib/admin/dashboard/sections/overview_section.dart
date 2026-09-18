import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/admin_models.dart';
import '../../controllers/admin_controller.dart';
import '../widgets/dashboard_shared.dart';

class OverviewSection extends StatelessWidget {
  final AdminController controller;
  final Function(AdminSection) onGoTo;

  const OverviewSection({
    super.key,
    required this.controller,
    required this.onGoTo,
  });

  @override
  Widget build(BuildContext context) {
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

  Widget _buildSalesChartCard() {
    return card(
      title: 'Sales Performance',
      subtitle: 'Revenue over the last 7 days',
      child: Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text(
          'No sales data available yet.',
          style: TextStyle(color: AppColors.placeholderColor),
        ),
      ),
    );
  }

  Widget _buildTopSellersCard() {
    return card(
      title: 'Top Products',
      subtitle: 'Highest revenue products',
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No products sold yet.',
            style: TextStyle(color: AppColors.placeholderColor),
          ),
        ),
      ),
    );
  }

  Widget _buildLowStockCard() {
    final items = controller.lowStockProducts;
    return card(
      title: 'Low Stock Alerts',
      subtitle: 'Products requiring restock',
      trailing: items.isEmpty
          ? null
          : TextButton(
        onPressed: () => onGoTo(AdminSection.products),
        child: const Text('View All'),
      ),
      child: items.isEmpty
          ? const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'All products are well stocked.',
            style: TextStyle(color: AppColors.placeholderColor),
          ),
        ),
      )
          : Column(
        children: [
          for (final product in items.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  statusPill(
                    formatQuantity(product.quantity, product.unit),
                    Colors.orange,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    final logs = controller.allAuditLogs;
    return card(
      title: 'Recent Activity',
      subtitle: 'Latest system changes',
      trailing: logs.isEmpty
          ? null
          : TextButton(
        onPressed: () => onGoTo(AdminSection.activity),
        child: const Text('View All'),
      ),
      child: logs.isEmpty
          ? const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No activity recorded yet.',
            style: TextStyle(color: AppColors.placeholderColor),
          ),
        ),
      )
          : Column(
        children: [
          for (final log in logs.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${log.action.label} ${log.entityType}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          formatRelative(log.timestamp),
                          style: const TextStyle(
                            fontSize: 11,
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
}

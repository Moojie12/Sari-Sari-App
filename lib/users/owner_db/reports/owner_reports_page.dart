import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'owner_report_detail_screen.dart';

class OwnerReportsPage extends StatelessWidget {
  const OwnerReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        title: const Text('Reports',
            style: TextStyle(color: AppColors.darkText, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.darkText),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hard data and summaries to help you manage your store's health.",
                style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.7), fontSize: 13),
              ),
              const SizedBox(height: 24),

              _ReportCategory(
                title: 'Sales & Payments',
                reports: [
                  _ReportItem(
                    title: 'Daily Revenue Summary',
                    subtitle: 'Total income across all channels',
                    icon: Icons.analytics_outlined,
                    color: Colors.blue,
                    type: OwnerReportType.dailyRevenue,
                  ),
                  _ReportItem(
                    title: 'Payment Reconciliation',
                    subtitle: 'Cash on hand vs. GCash totals',
                    icon: Icons.account_balance_wallet_outlined,
                    color: Colors.green,
                    type: OwnerReportType.paymentReconciliation,
                  ),
                  _ReportItem(
                    title: 'Sales Channel Comparison',
                    subtitle: 'In-store POS vs. Online orders',
                    icon: Icons.compare_arrows_rounded,
                    color: Colors.indigo,
                    type: OwnerReportType.salesChannelComparison,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              _ReportCategory(
                title: 'Inventory & Health',
                reports: [
                  _ReportItem(
                    title: 'Total Inventory Value',
                    subtitle: 'Current market value of all stock',
                    icon: Icons.monetization_on_outlined,
                    color: Colors.orange,
                    type: OwnerReportType.inventoryValue,
                  ),
                  _ReportItem(
                    title: 'Restock Checklist',
                    subtitle: 'Items below low-stock threshold',
                    icon: Icons.shopping_cart_checkout_outlined,
                    color: Colors.red,
                    type: OwnerReportType.restockChecklist,
                  ),
                  _ReportItem(
                    title: 'Wastage & Expiry Log',
                    subtitle: 'Loss from expired or archived items',
                    icon: Icons.delete_outline_rounded,
                    color: Colors.deepOrange,
                    type: OwnerReportType.wastageLog,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              _ReportCategory(
                title: 'Business Insights',
                reports: [
                  _ReportItem(
                    title: 'Best Selling Products',
                    subtitle: 'Top performing items by volume',
                    icon: Icons.star_outline_rounded,
                    color: Colors.teal,
                    type: OwnerReportType.bestSellers,
                  ),
                  _ReportItem(
                    title: 'Slow-Moving Inventory',
                    subtitle: 'Items with no sales in 30+ days',
                    icon: Icons.hourglass_empty_rounded,
                    color: Colors.brown,
                    type: OwnerReportType.slowMoving,
                  ),
                  _ReportItem(
                    title: 'Category Performance',
                    subtitle: 'Sales breakdown by product type',
                    icon: Icons.category_outlined,
                    color: Colors.purple,
                    type: OwnerReportType.categoryPerformance,
                  ),
                ],
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCategory extends StatelessWidget {
  const _ReportCategory({required this.title, required this.reports});
  final String title;
  final List<_ReportItem> reports;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.darkText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: List.generate(reports.length, (index) {
              final report = reports[index];
              final isLast = index == reports.length - 1;

              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: report.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(report.icon, color: report.color, size: 22),
                    ),
                    title: Text(
                      report.title,
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        report.subtitle,
                        style: TextStyle(
                          color: AppColors.secondaryText.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.secondaryText.withValues(alpha: 0.4),
                      size: 20,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OwnerReportDetailScreen(type: report.type),
                        ),
                      );
                    },
                  ),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.only(left: 64),
                      child: Divider(
                        height: 1,
                        color: AppColors.borderColor.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ReportItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final OwnerReportType type;
  _ReportItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.type,
  });
}
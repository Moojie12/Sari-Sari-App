import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class OwnerReportsPage extends StatelessWidget {
  const OwnerReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reports',
                  style: TextStyle(color: AppColors.darkText, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                "Track your store's performance.",
                style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.7), fontSize: 14),
              ),
              const SizedBox(height: 24),
              
              _ReportCategory(
                title: 'Sales Analysis',
                reports: [
                  _ReportItem(title: 'Daily Sales Report', icon: Icons.calendar_today, color: Colors.blue),
                  _ReportItem(title: 'Best Selling Products', icon: Icons.star_border, color: Colors.orange),
                  _ReportItem(title: 'Payment Method Summary', icon: Icons.payment, color: Colors.green),
                ],
              ),
              const SizedBox(height: 24),
              
              _ReportCategory(
                title: 'Inventory Reports',
                reports: [
                  _ReportItem(title: 'Stock Value Report', icon: Icons.account_balance_wallet_outlined, color: Colors.purple),
                  _ReportItem(title: 'Low Stock History', icon: Icons.trending_down, color: Colors.red),
                  _ReportItem(title: 'Expired Products Log', icon: Icons.event_busy, color: Colors.deepOrange),
                ],
              ),
              const SizedBox(height: 24),
              
              _ReportCategory(
                title: 'Customer & Orders',
                reports: [
                  _ReportItem(title: 'Order/Demand Forecast', icon: Icons.auto_graph, color: Colors.teal),
                  _ReportItem(title: 'Customer Purchase History', icon: Icons.person_search, color: Colors.indigo),
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
        Text(title, style: const TextStyle(color: AppColors.darkText, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...reports.map((report) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: report.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(report.icon, color: report.color),
              ),
              title: Text(report.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {},
            ),
          ),
        )),
      ],
    );
  }
}

class _ReportItem {
  final String title;
  final IconData icon;
  final Color color;
  _ReportItem({required this.title, required this.icon, required this.color});
}

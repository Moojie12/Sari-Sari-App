import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'owner_report_detail_screen.dart';

class OwnerOperationalLogsPage extends StatelessWidget {
  const OwnerOperationalLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        title: const Text(
          'Operational Logs & Summaries',
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.darkText),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Track daily sales reconciliations, damaged or expired stock wastage, and employee/owner consumables.",
                style: TextStyle(
                  color: AppColors.secondaryText.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              _OperationalCategoryCard(
                title: 'Operational Logs & Summaries',
                items: [
                  _OperationalLogItem(
                    title: 'Daily Revenue Summary',
                    subtitle: 'Total income, capital & net profit breakdown',
                    icon: Icons.analytics_outlined,
                    color: Colors.indigo,
                    type: OwnerReportType.dailyRevenue,
                  ),
                  _OperationalLogItem(
                    title: 'Wastage & Expiry Log',
                    subtitle: 'Loss from expired or archived items',
                    icon: Icons.delete_outline_rounded,
                    color: Colors.deepOrange,
                    type: OwnerReportType.wastageLog,
                  ),
                  _OperationalLogItem(
                    title: 'Consumables / Product Loss Log',
                    subtitle: 'Stock taken by owner/staff or loss, deducted from profit',
                    icon: Icons.set_meal_outlined,
                    color: Colors.deepPurple,
                    type: OwnerReportType.consumablesLog,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationalCategoryCard extends StatelessWidget {
  const _OperationalCategoryCard({required this.title, required this.items});

  final String title;
  final List<_OperationalLogItem> items;

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
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isLast = index == items.length - 1;

              return Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.icon, color: item.color, size: 22),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(
                          color: AppColors.darkText,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.subtitle,
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
                            builder: (context) => OwnerReportDetailScreen(type: item.type),
                          ),
                        );
                      },
                    ),
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

class _OperationalLogItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final OwnerReportType type;

  _OperationalLogItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.type,
  });
}

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../employee_db/employee_inventory_controller.dart';
import '../../employee_db/orders/employee_orders_controller.dart';
import 'owner_report_detail_screen.dart';
import 'owner_analytics_charts.dart';

enum _AnalyticsTab { descriptive, predictive, prescriptive }

class OwnerReportsPage extends StatefulWidget {
  const OwnerReportsPage({super.key});

  @override
  State<OwnerReportsPage> createState() => _OwnerReportsPageState();
}

class _OwnerReportsPageState extends State<OwnerReportsPage> {
  _AnalyticsTab _currentTab = _AnalyticsTab.descriptive;

  @override
  void initState() {
    super.initState();
    AuthService().logAnalyticsEvent('view_reports_page', {'initial_tab': _currentTab.name});
  }

  void _onTabSelected(_AnalyticsTab tab) {
    setState(() => _currentTab = tab);
    AuthService().logAnalyticsEvent('select_reports_analytics_tier', {'tier': tab.name});
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
        title: const Text(
          'Reports & Analytics',
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.darkText),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([inventory, orderController]),
          builder: (context, _) {
            final orders = orderController.orders;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Real-time database analytics, forecasting, and store health reports.",
                    style: TextStyle(
                      color: AppColors.secondaryText.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ==========================================
                  // 1. ANALYTICS TIER SWITCHER
                  // ==========================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      children: _AnalyticsTab.values.map((tab) {
                        final isSelected = tab == _currentTab;
                        String label;
                        switch (tab) {
                          case _AnalyticsTab.descriptive:
                            label = 'Descriptive';
                            break;
                          case _AnalyticsTab.predictive:
                            label = 'Predictive';
                            break;
                          case _AnalyticsTab.prescriptive:
                            label = 'Prescriptive';
                            break;
                        }

                        return Expanded(
                          child: InkWell(
                            onTap: () => _onTabSelected(tab),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primaryOrange : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? Colors.white : AppColors.darkText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ==========================================
                  // 2. ACTIVE ANALYTICS VIEW & CHARTS
                  // ==========================================
                  if (_currentTab == _AnalyticsTab.descriptive)
                    DescriptiveAnalyticsView(orders: orders, inventory: inventory)
                  else if (_currentTab == _AnalyticsTab.predictive)
                    PredictiveAnalyticsView(orders: orders, inventory: inventory)
                  else
                    PrescriptiveAnalyticsView(orders: orders, inventory: inventory),

                  const SizedBox(height: 28),

                  // ==========================================
                  // OPERATIONAL LOGS
                  // ==========================================
                  _ReportCategory(
                    title: 'Operational Logs & Summaries',
                    reports: [
                      _ReportItem(
                        title: 'Daily Revenue Summary',
                        subtitle: 'Total income, capital & net profit breakdown',
                        icon: Icons.analytics_outlined,
                        color: Colors.indigo,
                        type: OwnerReportType.dailyRevenue,
                      ),
                      _ReportItem(
                        title: 'Wastage & Expiry Log',
                        subtitle: 'Loss from expired or archived items',
                        icon: Icons.delete_outline_rounded,
                        color: Colors.deepOrange,
                        type: OwnerReportType.wastageLog,
                      ),
                      _ReportItem(
                        title: 'Consumables / Product Loss Log',
                        subtitle: 'Stock taken by owner/staff or loss, deducted from profit',
                        icon: Icons.set_meal_outlined,
                        color: Colors.deepPurple,
                        type: OwnerReportType.consumablesLog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
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
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
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
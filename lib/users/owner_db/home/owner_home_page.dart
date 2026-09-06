import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../employee_db/employee_inventory_controller.dart';

class OwnerHomePage extends StatelessWidget {
  const OwnerHomePage({
    super.key,
    required this.inventory,
    required this.onOpenPos,
    required this.onOpenInventory,
    required this.onOpenProfile,
  });

  final EmployeeInventoryController inventory;
  final VoidCallback onOpenPos;
  final VoidCallback onOpenInventory;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: inventory,
          builder: (context, _) {
            final lowStock = inventory.lowStockProducts.length;
            final outOfStock = inventory.outOfStockProducts.length;
            final expiring = inventory.expiringSoonProducts.length;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Owner Home',
                      style: TextStyle(color: AppColors.darkText, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    "Store overview and performance at a glance.",
                    style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.7), fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  
                  // Financial Overview (Owner Only)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryOrange, Color(0xFFFFB74D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryOrange.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Today's Total Sales",
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "₱ 12,450.00",
                          style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _MiniStat(label: 'Transactions', value: '48'),
                            Container(width: 1, height: 24, color: Colors.white24),
                            _MiniStat(label: 'Net Profit', value: '₱ 3,210'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  const Text('Inventory Alerts',
                      style: TextStyle(color: AppColors.darkText, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Low Stock',
                          value: '$lowStock',
                          icon: Icons.trending_down,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Out of Stock',
                          value: '$outOfStock',
                          icon: Icons.remove_shopping_cart_outlined,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _StatCardLong(
                    label: 'Products Expiring Soon',
                    value: '$expiring',
                    icon: Icons.event_busy,
                    color: Colors.deepOrange,
                    onTap: onOpenInventory,
                  ),
                  
                  const SizedBox(height: 28),
                  const Text('Owner Quick Actions',
                      style: TextStyle(color: AppColors.darkText, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _QuickActionButton(
                        label: 'New Sale (POS)',
                        icon: Icons.point_of_sale,
                        onTap: onOpenPos,
                      ),
                      _QuickActionButton(
                        label: 'Manage Products',
                        icon: Icons.inventory_2_outlined,
                        onTap: onOpenInventory,
                      ),
                      _QuickActionButton(
                        label: 'Activity Logs',
                        icon: Icons.list_alt,
                        onTap: onOpenProfile,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 28),
                  const Text('Reports',
                      style: TextStyle(color: AppColors.darkText, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
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

                  const SizedBox(height: 100), // Space for nav bar
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
        Text(title, style: TextStyle(color: AppColors.darkText.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...reports.map((report) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: report.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(report.icon, color: report.color, size: 20),
              ),
              title: Text(report.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              trailing: const Icon(Icons.chevron_right, size: 18),
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(color: AppColors.darkText, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatCardLong extends StatelessWidget {
  const _StatCardLong({required this.label, required this.value, required this.icon, required this.color, required this.onTap});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                Text(value, style: const TextStyle(color: AppColors.darkText, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.secondaryText),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primaryOrange, size: 28),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.darkText, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

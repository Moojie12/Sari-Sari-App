import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';


class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;
    
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      drawer: isMobile ? Drawer(child: _buildSidebar(isDrawer: true)) : null,
      appBar: isMobile ? AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkText),
        title: const Text('Tindahan ni Eca Admin', style: TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold)),
      ) : null,
      body: Row(
        children: [
          // Sidebar
          if (!isMobile) _buildSidebar(),
          // Main Content
          Expanded(
            child: Column(
              children: [
                if (!isMobile) _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 32),
                    child: _buildBody(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar({bool isDrawer = false}) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        border: isDrawer ? null : const Border(right: BorderSide(color: AppColors.borderColor, width: 1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tindahan ni Eca',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.darkText,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Admin Panel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SidebarItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            isSelected: _selectedIndex == 0,
            onTap: () {
              setState(() => _selectedIndex = 0);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          _SidebarItem(
            icon: Icons.inventory_2_outlined,
            label: 'Inventory',
            isSelected: _selectedIndex == 1,
            onTap: () {
              setState(() => _selectedIndex = 1);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          _SidebarItem(
            icon: Icons.receipt_long_outlined,
            label: 'Orders',
            isSelected: _selectedIndex == 2,
            onTap: () {
              setState(() => _selectedIndex = 2);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          _SidebarItem(
            icon: Icons.analytics_outlined,
            label: 'Analytics',
            isSelected: _selectedIndex == 3,
            onTap: () {
              setState(() => _selectedIndex = 3);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          _SidebarItem(
            icon: Icons.people_outline,
            label: 'Employees',
            isSelected: _selectedIndex == 4,
            onTap: () {
              setState(() => _selectedIndex = 4);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          const Spacer(),
          _SidebarItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isSelected: _selectedIndex == 5,
            onTap: () {
              setState(() => _selectedIndex = 5);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          _SidebarItem(
            icon: Icons.logout,
            label: 'Logout',
            isSelected: false,
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
                    (route) => false,
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderColor, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            _selectedIndex == 0 ? 'Dashboard Overview' : 
            _selectedIndex == 1 ? 'Inventory Management' :
            _selectedIndex == 2 ? 'Order Records' :
            _selectedIndex == 3 ? 'System Analytics' :
            _selectedIndex == 4 ? 'Employee Management' : 'Settings',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.lightBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: AppColors.placeholderColor, size: 20),
                SizedBox(width: 8),
                Text('Search anything...', style: TextStyle(color: AppColors.placeholderColor, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(width: 24),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: AppColors.secondaryText),
            onPressed: () {},
          ),
          const SizedBox(width: 16),
          const VerticalDivider(width: 1, indent: 10, endIndent: 10),
          const SizedBox(width: 24),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nico Maglente', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
              Text('Store Owner', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
            ],
          ),
          const SizedBox(width: 12),
          const CircleAvatar(
            backgroundColor: AppColors.primaryOrange,
            child: Text('N', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedIndex != 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 100),
            Icon(Icons.construction_rounded, size: 64, color: AppColors.placeholderColor.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('Feature Coming Soon', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondaryText)),
            const SizedBox(height: 8),
            const Text('This part of the management portal is currently under development.', style: TextStyle(color: AppColors.placeholderColor)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final bool isSmall = constraints.maxWidth < 1100;
          return Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              _buildSummaryCard('Total Sales', '₱ 0.00', Icons.payments_outlined, Colors.green, '0%', width: isSmall ? constraints.maxWidth / 2 - 12 : constraints.maxWidth / 4 - 18),
              _buildSummaryCard('Total Orders', '0', Icons.shopping_bag_outlined, Colors.blue, '0%', width: isSmall ? constraints.maxWidth / 2 - 12 : constraints.maxWidth / 4 - 18),
              _buildSummaryCard('Low Stock', '0', Icons.inventory_outlined, Colors.orange, '0 items', width: isSmall ? constraints.maxWidth / 2 - 12 : constraints.maxWidth / 4 - 18),
              _buildSummaryCard('Active Customers', '0', Icons.people_alt_outlined, Colors.purple, '0%', width: isSmall ? constraints.maxWidth / 2 - 12 : constraints.maxWidth / 4 - 18),
            ],
          );
        }),
        const SizedBox(height: 32),
        LayoutBuilder(builder: (context, constraints) {
           final bool isSmall = constraints.maxWidth < 1000;
           if (isSmall) {
             return Column(
               children: [
                 _buildRecentOrders(),
                 const SizedBox(height: 24),
                 _buildTopProducts(),
               ],
             );
           }
           return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildRecentOrders()),
              const SizedBox(width: 24),
              Expanded(child: _buildTopProducts()),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, String trend, {double? width}) {
    final bool isNegative = trend.startsWith('-');
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isNegative ? Colors.red : Colors.green).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    color: isNegative ? Colors.red : Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(color: AppColors.secondaryText, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.darkText,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrders() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Orders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
          ),
          SizedBox(height: 40),
          Center(
            child: Text('No recent orders found', style: TextStyle(color: AppColors.secondaryText)),
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTopProducts() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Selling Products',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
          ),
          SizedBox(height: 40),
          Center(
            child: Text('No data available', style: TextStyle(color: AppColors.secondaryText)),
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  }

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryOrange.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText,
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

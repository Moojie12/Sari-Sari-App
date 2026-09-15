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
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(),
          // Main Content
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
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

  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.borderColor, width: 1)),
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
                      'Sari-Sari',
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
            onTap: () => setState(() => _selectedIndex = 0),
          ),
          _SidebarItem(
            icon: Icons.inventory_2_outlined,
            label: 'Inventory',
            isSelected: _selectedIndex == 1,
            onTap: () => setState(() => _selectedIndex = 1),
          ),
          _SidebarItem(
            icon: Icons.receipt_long_outlined,
            label: 'Orders',
            isSelected: _selectedIndex == 2,
            onTap: () => setState(() => _selectedIndex = 2),
          ),
          _SidebarItem(
            icon: Icons.analytics_outlined,
            label: 'Analytics',
            isSelected: _selectedIndex == 3,
            onTap: () => setState(() => _selectedIndex = 3),
          ),
          _SidebarItem(
            icon: Icons.people_outline,
            label: 'Employees',
            isSelected: _selectedIndex == 4,
            onTap: () => setState(() => _selectedIndex = 4),
          ),
          const Spacer(),
          _SidebarItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isSelected: _selectedIndex == 5,
            onTap: () => setState(() => _selectedIndex = 5),
          ),
          _SidebarItem(
            icon: Icons.logout,
            label: 'Logout',
            isSelected: false,
            onTap: () {},
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
          const Text(
            'Dashboard Overview',
            style: TextStyle(
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
              Text('Admin', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
              Text('Store Owner', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
            ],
          ),
          const SizedBox(width: 12),
          const CircleAvatar(
            backgroundColor: AppColors.primaryOrange,
            child: Text('G', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildSummaryCard('Total Sales', '₱ 124,500.00', Icons.payments_outlined, Colors.green, '+12.5%')),
            const SizedBox(width: 24),
            Expanded(child: _buildSummaryCard('Total Orders', '1,240', Icons.shopping_bag_outlined, Colors.blue, '+8.2%')),
            const SizedBox(width: 24),
            Expanded(child: _buildSummaryCard('Low Stock', '12', Icons.inventory_outlined, Colors.orange, '-2 items')),
            const SizedBox(width: 24),
            Expanded(child: _buildSummaryCard('Active Customers', '856', Icons.people_alt_outlined, Colors.purple, '+5.4%')),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildRecentOrders()),
            const SizedBox(width: 24),
            Expanded(child: _buildTopProducts()),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, String trend) {
    final bool isNegative = trend.startsWith('-');
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Orders',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All', style: TextStyle(color: AppColors.primaryOrange)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.5),
              1: FlexColumnWidth(3),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2),
              4: FlexColumnWidth(2),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.borderColor, width: 1)),
                ),
                children: [
                  _tableHeader('Order ID'),
                  _tableHeader('Customer'),
                  _tableHeader('Date'),
                  _tableHeader('Amount'),
                  _tableHeader('Status'),
                ],
              ),
              ...List.generate(6, (index) => _buildOrderRow(index)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryText, fontSize: 13),
      ),
    );
  }

  TableRow _buildOrderRow(int index) {
    final List<String> statuses = ['Completed', 'Processing', 'Cancelled', 'Completed', 'Completed', 'Processing'];
    final status = statuses[index];
    final Color statusColor = status == 'Completed' 
        ? Colors.green 
        : status == 'Processing' 
            ? Colors.orange 
            : Colors.red;

    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderColor, width: 0.5)),
      ),
      children: [
        _tableCell('#ORD-00${index + 1}'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.lightPeach,
                child: Text(
                  String.fromCharCode(65 + index),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                ),
              ),
              const SizedBox(width: 12),
              Text('Customer ${index + 1}', style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        _tableCell('Oct 24, 2023'),
        _tableCell('₱ ${450.00 + (index * 120)}'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(text, style: const TextStyle(color: AppColors.darkText, fontSize: 14)),
    );
  }

  Widget _buildTopProducts() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Selling Products',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
          ),
          const SizedBox(height: 24),
          ...List.generate(5, (index) => _buildProductItem(index)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryOrange),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('View All Products', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(int index) {
    final products = ['Coke 1.5L', 'Lucky Me Noodles', 'Gardenia Bread', 'Bear Brand Milk', 'Safeguard Soap'];
    final sales = ['86', '74', '62', '58', '45'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.lightBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.image_outlined, color: AppColors.placeholderColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(products[index], style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText, fontSize: 15)),
                const SizedBox(height: 4),
                Text('${sales[index]} units sold', style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
              ],
            ),
          ),
          Text(
            '₱ ${(25.00 + (index * 15)).toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryOrange, fontSize: 15),
          ),
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

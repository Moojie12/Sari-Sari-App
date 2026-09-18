import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/skeleton.dart';
import '../controllers/admin_controller.dart';
import '../models/admin_models.dart';
import 'sections/overview_section.dart';
import 'sections/people_section.dart';
import 'sections/products_section.dart';
import 'sections/categories_section.dart';
import 'sections/sales_section.dart';
import 'sections/archive_section.dart';
import 'sections/activity_section.dart';
import 'widgets/dashboard_shared.dart';

class _NavEntry {
  const _NavEntry(this.section, this.icon, this.label);
  final AdminSection section;
  final IconData icon;
  final String label;
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  AdminSection _section = AdminSection.overview;
  bool _isSidebarCollapsed = false;
  bool _isPageLoading = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, int> _pages = {};
  final int _rowsPerPage = 8;

  final String _storeName = 'Tindahan ni Eca Admin';
  final bool _confirmBeforeArchive = true;
  final bool _showCostColumn = true;

  static const List<_NavEntry> _primaryNav = [
    _NavEntry(AdminSection.overview, Icons.space_dashboard_outlined, 'Overview'),
    _NavEntry(AdminSection.users, Icons.people_outline, 'People'),
    _NavEntry(AdminSection.products, Icons.inventory_2_outlined, 'Products'),
    _NavEntry(AdminSection.categories, Icons.sell_outlined, 'Categories'),
    _NavEntry(AdminSection.sales, Icons.receipt_long_outlined, 'Receipts'),
  ];

  static const List<_NavEntry> _recordsNav = [
    _NavEntry(AdminSection.archived, Icons.archive_outlined, 'Archive'),
    _NavEntry(AdminSection.activity, Icons.history, 'Activity'),
  ];

  @override
  void initState() {
    super.initState();
    _triggerSkeletonLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _triggerSkeletonLoad() {
    setState(() => _isPageLoading = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isPageLoading = false);
    });
  }

  void _goTo(AdminSection section) {
    if (_section == section) return;
    setState(() {
      _section = section;
      _searchController.clear();
      _searchQuery = '';
      _pages.clear();
    });
    _triggerSkeletonLoad();
  }

  bool get _sectionHasSearch =>
      _section != AdminSection.overview && _section != AdminSection.settings;

  String get _sectionTitle {
    switch (_section) {
      case AdminSection.overview: return 'Overview';
      case AdminSection.users: return 'People';
      case AdminSection.products: return 'Products';
      case AdminSection.categories: return 'Categories';
      case AdminSection.sales: return 'Receipts';
      case AdminSection.archived: return 'Archive';
      case AdminSection.activity: return 'Activity';
      case AdminSection.settings: return 'Settings';
    }
  }

  String get _sectionSubtitle {
    switch (_section) {
      case AdminSection.overview: return 'How the store is doing today';
      case AdminSection.users: return 'Owners, staff and customers';
      case AdminSection.products: return 'Stock, prices and margins';
      case AdminSection.categories: return 'How products are grouped';
      case AdminSection.sales: return 'Every receipt the store has issued';
      case AdminSection.archived: return 'Records kept out of the way but not deleted';
      case AdminSection.activity: return 'Who changed what, and when';
      case AdminSection.settings: return 'Preferences for this console';
    }
  }

  String get _searchHint {
    switch (_section) {
      case AdminSection.users: return 'Search by name, email or username';
      case AdminSection.products: return 'Search by product name or barcode';
      case AdminSection.categories: return 'Search categories';
      case AdminSection.sales: return 'Search by receipt number, cashier or customer';
      case AdminSection.archived: return 'Search archived records';
      case AdminSection.activity: return 'Search activity';
      default: return 'Search';
    }
  }

  void _toast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : AppColors.darkText,
        behavior: SnackBarBehavior.floating,
        width: 460,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
  }

  void _run(String? Function() action, String successMessage) {
    final error = action();
    if (error != null) {
      _showMessageDialog('Couldn\'t finish that', error);
    } else {
      _toast(successMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AdminController.instance;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final useDrawer = width < 840;
            final autoCollapse = width < 1180;
            final collapsed = !useDrawer && (_isSidebarCollapsed || autoCollapse);
            final pagePadding = width < 700 ? 16.0 : 32.0;

            return Scaffold(
              key: _scaffoldKey,
              backgroundColor: AppColors.lightBackground,
              drawer: useDrawer
                  ? Drawer(
                backgroundColor: Colors.white,
                child: SafeArea(
                  child: _buildSidebar(collapsed: false, inDrawer: true),
                ),
              )
                  : null,
              body: Row(
                children: [
                  if (!useDrawer)
                    _buildSidebar(
                      collapsed: collapsed,
                      showToggle: !autoCollapse,
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        _buildHeader(
                          showMenuButton: useDrawer,
                          stackSearch: width < 1100,
                          hideProfile: width < 620,
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.symmetric(horizontal: pagePadding, vertical: 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSummaryRow(controller),
                                const SizedBox(height: 28),
                                _isPageLoading
                                    ? _buildSkeletonLoader()
                                    : AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: KeyedSubtree(
                                    key: ValueKey(_section),
                                    child: _buildSectionBody(controller),
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSidebar({
    required bool collapsed,
    bool inDrawer = false,
    bool showToggle = true,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: collapsed ? 84 : 272,
      decoration: BoxDecoration(
        color: Colors.white,
        border: inDrawer
            ? null
            : const Border(right: BorderSide(color: AppColors.borderColor, width: 1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(collapsed ? 18 : 22, 28, collapsed ? 18 : 22, 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.storefront, color: Colors.white, size: 24),
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 150,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _storeName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkText,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const Text(
                            'Admin console',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showToggle && !inDrawer)
                      IconButton(
                        tooltip: 'Collapse menu',
                        icon: const Icon(Icons.menu_open, color: AppColors.placeholderColor, size: 20),
                        onPressed: () => setState(() => _isSidebarCollapsed = true),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (collapsed && showToggle && !inDrawer)
            IconButton(
              tooltip: 'Expand menu',
              icon: const Icon(Icons.menu, color: AppColors.placeholderColor, size: 20),
              onPressed: () => setState(() => _isSidebarCollapsed = false),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  for (final entry in _primaryNav)
                    _buildNavItem(entry, collapsed, inDrawer),
                  _buildNavLabel('Records', collapsed),
                  for (final entry in _recordsNav)
                    _buildNavItem(entry, collapsed, inDrawer),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, indent: 20, endIndent: 20),
          const SizedBox(height: 8),
          _buildSignOutItem(collapsed, inDrawer),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNavLabel(String text, bool collapsed) {
    if (collapsed) {
      return const Divider(height: 26, thickness: 1, indent: 22, endIndent: 22);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 22, 22, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.placeholderColor,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavEntry entry, bool collapsed, bool inDrawer) {
    final isSelected = _section == entry.section;
    final item = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (inDrawer) Navigator.of(context).pop();
          _goTo(entry.section);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryOrange.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  entry.icon,
                  size: 21,
                  color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 160,
                    child: Text(
                      entry.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? AppColors.primaryOrange : AppColors.darkText,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return collapsed ? Tooltip(message: entry.label, child: item) : item;
  }

  Widget _buildSignOutItem(bool collapsed, bool inDrawer) {
    final item = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (inDrawer) Navigator.of(context).pop();
          _showConfirmDialog(
            title: 'Sign out?',
            message: 'You\'ll need to sign in again to get back in.',
            icon: Icons.logout_rounded,
            color: AppColors.darkText,
            confirmLabel: 'Sign out',
            onConfirm: () => Navigator.pushReplacementNamed(context, '/'),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(Icons.logout_rounded, size: 21, color: Colors.red[400]),
                if (!collapsed) ...[
                  const SizedBox(width: 14),
                  const SizedBox(
                    width: 160,
                    child: Text(
                      'Sign out',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFD32F2F),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return collapsed ? Tooltip(message: 'Sign out', child: item) : item;
  }

  Widget _buildHeader({
    required bool showMenuButton,
    required bool stackSearch,
    required bool hideProfile,
  }) {
    final searchField = _buildSearchField();

    return Container(
      padding: EdgeInsets.fromLTRB(showMenuButton ? 12 : 32, 16, showMenuButton ? 16 : 32, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderColor, width: 1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (showMenuButton)
                IconButton(
                  icon: const Icon(Icons.menu, color: AppColors.darkText),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _sectionTitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _sectionSubtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              if (!stackSearch && _sectionHasSearch)
                Expanded(child: Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: searchField,
                  ),
                ))
              else
                const Spacer(),
              if (!hideProfile) ...[
                const SizedBox(width: 20),
                _buildProfileChip(),
              ],
            ],
          ),
          if (stackSearch && _sectionHasSearch) ...[
            const SizedBox(height: 14),
            searchField,
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.placeholderColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {
                _searchQuery = value;
                _pages.clear();
              }),
              style: const TextStyle(fontSize: 14, color: AppColors.darkText),
              decoration: InputDecoration(
                hintText: _searchHint,
                hintStyle: const TextStyle(color: AppColors.placeholderColor, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            InkWell(
              onTap: () => setState(() {
                _searchController.clear();
                _searchQuery = '';
                _pages.clear();
              }),
              child: const Icon(Icons.close, size: 16, color: AppColors.placeholderColor),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileChip() {
    final controller = AdminController.instance;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.currentActor,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
                fontSize: 13.5,
              ),
            ),
            const Text(
              'Owner',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryOrange, width: 2),
          ),
          child: const CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.lightPeach,
            child: Icon(Icons.person, color: AppColors.primaryOrange, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(AdminController controller) {
    switch (_section) {
      case AdminSection.overview:
        return _metricGrid([
          _metricCard('Sales today', formatPeso(controller.salesToday), '${controller.ordersToday} receipts', Icons.payments_outlined, Colors.green),
          _metricCard('Average basket', formatPeso(controller.averageBasket), 'Across all receipts', Icons.shopping_basket_outlined, Colors.indigo),
          _metricCard('Needs restocking', '${controller.lowStockProducts.length}', 'Low or out of stock', Icons.report_problem_outlined, controller.lowStockProducts.isEmpty ? Colors.teal : Colors.red),
          _metricCard('Stock on hand', formatPeso(controller.inventoryValue), 'At cost price', Icons.inventory_outlined, AppColors.primaryOrange),
        ]);
      case AdminSection.users:
        final owners = controller.activeUsers.where((u) => u.role == AdminRole.owner).length;
        final staff = controller.activeUsers.where((u) => u.role == AdminRole.employee).length;
        final customers = controller.activeUsers.where((u) => u.role == AdminRole.customer).length;
        return _metricGrid([
          _metricCard('Owners', '$owners', 'Full access', Icons.shield_outlined, Colors.purple),
          _metricCard('Staff', '$staff', 'Can use the till', Icons.badge_outlined, Colors.amber[800]!),
          _metricCard('Customers', '$customers', 'Registered buyers', Icons.people_outline, Colors.green),
        ]);
      case AdminSection.products:
        final lowStock = controller.lowStockProducts.length;
        final expiring = controller.expiringProducts.length;
        return _metricGrid([
          _metricCard('Products', '${controller.activeProducts.length}', 'On the shelves', Icons.inventory_2_outlined, Colors.blue),
          _metricCard('Low or out of stock', '$lowStock', 'Reorder these first', Icons.warning_amber_rounded, lowStock == 0 ? Colors.teal : Colors.red),
          _metricCard('Expiring soon', '$expiring', 'Within 30 days', Icons.event_busy_outlined, expiring == 0 ? Colors.teal : Colors.deepOrange),
        ]);
      case AdminSection.categories:
        return _metricGrid([
          _metricCard('Categories', '${controller.activeCategories.length}', 'In use today', Icons.sell_outlined, Colors.cyan[800]!),
          _metricCard('Archived', '${controller.archivedCategories.length}', 'Kept for history', Icons.archive_outlined, Colors.grey),
        ]);
      case AdminSection.sales:
        return _metricGrid([
          _metricCard('Sales today', formatPeso(controller.salesToday), '${controller.ordersToday} receipts', Icons.receipt_long_outlined, Colors.green),
          _metricCard('Profit today', formatPeso(controller.profitToday), 'Estimated', Icons.trending_up, Colors.indigo),
          _metricCard('Inventory value', formatPeso(controller.inventoryValue), 'At cost price', Icons.inventory_outlined, Colors.teal),
        ]);
      case AdminSection.archived:
        return _metricGrid([
          _metricCard('People', '${controller.archivedUsers.length}', 'Can be restored', Icons.person_off_outlined, Colors.deepOrange),
          _metricCard('Products', '${controller.archivedProducts.length}', 'Hidden from the till', Icons.inventory_2_outlined, Colors.brown),
          _metricCard('Categories', '${controller.archivedCategories.length}', 'No longer in use', Icons.layers_clear_outlined, Colors.grey[700]!),
        ]);
      case AdminSection.activity:
        final entries = controller.allAuditLogs.length;
        final today = controller.allAuditLogs.where((l) => isSameDay(l.timestamp, DateTime.now())).length;
        return _metricGrid([
          _metricCard('Entries', '$entries', 'Total history', Icons.history, Colors.blueGrey[800]!),
          _metricCard('Today', '$today', 'Recent changes', Icons.today_outlined, AppColors.primaryOrange),
        ]);
      case AdminSection.settings:
        return const SizedBox.shrink();
    }
  }

  Widget _metricGrid(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns = width < 620 ? 1 : (width < 1060 ? 2 : (width < 1380 && cards.length > 3 ? 3 : cards.length));
        if (columns > cards.length) columns = cards.length;
        const spacing = 20.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(spacing: spacing, runSpacing: spacing, children: [for (final card in cards) SizedBox(width: cardWidth, child: card)]);
      },
    );
  }

  Widget _metricCard(String title, String value, String caption, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
                const SizedBox(height: 6),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: AppColors.darkText, letterSpacing: -0.6))),
                const SizedBox(height: 4),
                Text(caption, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.placeholderColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Skeleton(height: 34, width: 220),
            Skeleton(height: 46, width: 150, borderRadius: 12),
          ],
        ),
        const SizedBox(height: 22),
        Container(
          height: 420,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderColor),
          ),
          padding: const EdgeInsets.all(22),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Skeleton(height: 36)),
                  SizedBox(width: 12),
                  Expanded(child: Skeleton(height: 36)),
                  SizedBox(width: 12),
                  Expanded(child: Skeleton(height: 36)),
                ],
              ),
              SizedBox(height: 22),
              Expanded(
                child: Column(
                  children: [
                    Skeleton(height: 40),
                    SizedBox(height: 16),
                    Skeleton(height: 40),
                    SizedBox(height: 16),
                    Skeleton(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionBody(AdminController controller) {
    switch (_section) {
      case AdminSection.overview:
        return OverviewSection(
          controller: controller,
          onGoTo: (AdminSection s) => _goTo(s),
          onAdjustStock: (AdminProduct p) => _showStockDialog(controller, p),
        );
      case AdminSection.users:
        return PeopleSection(
          controller: controller,
          searchQuery: _searchQuery,
          rowsPerPage: _rowsPerPage,
          pages: _pages,
          onPageChange: (String k, int p) => setState(() => _pages[k] = p),
          onShowUserForm: (AdminUser? u) => _showUserForm(controller, u),
          onShowUserDetail: (AdminUser u) => _showUserDetail(u),
          onArchiveUser: (AdminUser u) => _confirmArchive(
            what: 'person',
            name: u.fullName,
            detail: 'They\'ll be hidden from the till and from customer lists. Their past receipts stay intact.',
            onConfirm: () => _run(() => controller.archiveUser(u.id), '${u.fullName} was archived.'),
          ),
          onClearFilters: () => setState(() {
            _searchController.clear();
            _searchQuery = '';
            _pages.clear();
          }),
        );
      case AdminSection.products:
        return ProductsSection(
          controller: controller,
          searchQuery: _searchQuery,
          rowsPerPage: _rowsPerPage,
          pages: _pages,
          showCostColumn: _showCostColumn,
          onPageChange: (String k, int p) => setState(() => _pages[k] = p),
          onShowProductForm: (AdminProduct? pr) => _showProductForm(controller, pr),
          onAdjustStock: (AdminProduct pr) => _showStockDialog(controller, pr),
          onArchiveProduct: (AdminProduct pr) => _confirmArchive(
            what: 'product',
            name: pr.name,
            detail: 'It disappears from the till and from customer lists. Past receipts keep it.',
            onConfirm: () => _run(() => controller.archiveProduct(pr.id), '${pr.name} was archived.'),
          ),
          onClearFilters: () => setState(() {
            _searchController.clear();
            _searchQuery = '';
            _pages.clear();
          }),
        );
      case AdminSection.categories:
        return CategoriesSection(
          controller: controller,
          searchQuery: _searchQuery,
          rowsPerPage: _rowsPerPage,
          pages: _pages,
          onPageChange: (String k, int p) => setState(() => _pages[k] = p),
          onShowCategoryForm: (AdminCategory? c) => _showCategoryForm(controller, c),
          onArchiveCategory: (AdminCategory c) {
            final linked = controller.getActiveProductCountForCategory(c.id);
            _confirmArchive(
              what: 'category',
              name: c.name,
              detail: 'Archived categories can\'t be picked for new products.',
              blockedMessage: linked > 0 ? '$linked active products are still in "${c.name}". Move or archive them first.' : null,
              onConfirm: () => _run(() => controller.archiveCategory(c.id), '${c.name} was archived.'),
            );
          },
        );
      case AdminSection.sales:
        return SalesSection(
          controller: controller,
          searchQuery: _searchQuery,
          rowsPerPage: _rowsPerPage,
          pages: _pages,
          storeName: _storeName,
          onPageChange: (String k, int p) => setState(() => _pages[k] = p),
          onShowReceipt: (AdminSale s) => _showReceipt(controller, s),
          onVoidSale: (AdminSale s) => _showVoidDialog(controller, s),
          onCopyText: (String t, String m) => _copyText(t, m),
          onClearFilters: () => setState(() {
            _searchController.clear();
            _searchQuery = '';
            _pages.clear();
          }),
        );
      case AdminSection.archived:
        return ArchiveSection(
          controller: controller,
          searchQuery: _searchQuery,
          rowsPerPage: _rowsPerPage,
          pages: _pages,
          onPageChange: (String k, int p) => setState(() => _pages[k] = p),
          onRestoreUser: (AdminUser u) => _confirmRestore(
            what: 'person',
            name: u.fullName,
            onConfirm: () => _run(() => controller.restoreUser(u.id), '${u.fullName} is active again.'),
          ),
          onDeleteUser: (AdminUser u) => _confirmDelete(
            what: 'person',
            name: u.fullName,
            blockedMessage: controller.isUserInSales(u.id) ? 'This account rang up past sales, so it can\'t be deleted. Leaving it archived keeps your receipts intact.' : null,
            onConfirm: () => _run(() => controller.permanentlyDeleteUser(u.id), '${u.fullName} was deleted.'),
          ),
          onRestoreProduct: (AdminProduct pr) {
            final category = controller.categoryById(pr.categoryId);
            final blocked = category == null || category.isArchived;
            _confirmRestore(
              what: 'product',
              name: pr.name,
              blockedMessage: blocked ? 'Its category "${pr.categoryName}" is archived. Restore the category first, or edit the product and pick another one.' : null,
              onConfirm: () => _run(() => controller.restoreProduct(pr.id), '${pr.name} is back on the shelves.'),
            );
          },
          onDeleteProduct: (AdminProduct pr) => _confirmDelete(
            what: 'product',
            name: pr.name,
            blockedMessage: controller.isProductInSales(pr.id) ? 'This product appears on past receipts, so it can\'t be deleted. Leaving it archived keeps those receipts accurate.' : null,
            onConfirm: () => _run(() => controller.permanentlyDeleteProduct(pr.id), '${pr.name} was deleted.'),
          ),
          onRestoreCategory: (AdminCategory c) => _confirmRestore(
            what: 'category',
            name: c.name,
            onConfirm: () => _run(() => controller.restoreCategory(c.id), '${c.name} is active again.'),
          ),
          onDeleteCategory: (AdminCategory c) {
            final count = controller.getProductCountForCategory(c.id);
            _confirmDelete(
              what: 'category',
              name: c.name,
              blockedMessage: count > 0 ? '$count products are still assigned to this category. Move or delete them first.' : null,
              onConfirm: () => _run(() => controller.permanentlyDeleteCategory(c.id), '${c.name} was deleted.'),
            );
          },
        );
      case AdminSection.activity:
        return ActivitySection(
          controller: controller,
          searchQuery: _searchQuery,
          rowsPerPage: _rowsPerPage,
          pages: _pages,
          onPageChange: (String k, int p) => setState(() => _pages[k] = p),
          onShowAuditDetail: (AdminAuditLog l) => _showAuditDetail(l),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _showUserForm(AdminController controller, AdminUser? user) {
    final isEdit = user != null;
    final nameField = TextEditingController(text: user?.fullName ?? '');
    final usernameField = TextEditingController(text: user?.username ?? '');
    final emailField = TextEditingController(text: user?.email ?? '');
    final phoneField = TextEditingController(text: user?.phone ?? '');
    var role = user?.role ?? AdminRole.employee;
    var status = user?.status ?? 'Active';
    var verification = user?.verificationStatus ?? 'Unverified';
    String? errorMsg;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => dialogShell(ctx,
          width: 520, scrollable: true,
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? 'Edit ${user.fullName}' : 'Add a person', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.darkText)),
              const SizedBox(height: 4),
              Text(isEdit ? 'Changes take effect right away.' : 'Staff can use the till. Customers only appear on receipts.', style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
              if (errorMsg != null) formError(errorMsg!),
              const SizedBox(height: 20),
              field(nameField, 'Full name', hint: 'Juan Dela Cruz'),
              const SizedBox(height: 14),
              field(usernameField, 'Username', hint: 'juan.dc'),
              const SizedBox(height: 14),
              field(emailField, 'Email', hint: 'juan@example.com'),
              const SizedBox(height: 14),
              field(phoneField, 'Mobile number', hint: '0917 555 0100'),
              const SizedBox(height: 18),
              dialogRow('Role', DropdownButton<AdminRole>(value: role, underline: const SizedBox(), items: AdminRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(), onChanged: (v) => setDialogState(() => role = v ?? role))),
              dialogRow('Account status', DropdownButton<String>(value: status, underline: const SizedBox(), items: const ['Active', 'Inactive'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setDialogState(() => status = v ?? status))),
              dialogRow('Verification', DropdownButton<String>(value: verification, underline: const SizedBox(), items: const ['Verified', 'Unverified'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setDialogState(() => verification = v ?? verification))),
              const SizedBox(height: 24),
              dialogActions(ctx, confirmLabel: isEdit ? 'Save changes' : 'Add person', onConfirm: () {
                final err = isEdit ? controller.updateUser(user.id, fullName: nameField.text, username: usernameField.text, email: emailField.text, phone: phoneField.text, role: role, status: status, verificationStatus: verification)
                    : controller.createUser(fullName: nameField.text, username: usernameField.text, email: emailField.text, phone: phoneField.text, role: role, status: status, verificationStatus: verification);
                if (err != null) {
                  setDialogState(() => errorMsg = err);
                } else {
                  Navigator.pop(ctx);
                  _toast(isEdit ? 'Saved changes to ${nameField.text.trim()}.' : '${nameField.text.trim()} was added.');
                }
              }),
            ],
          ),
        ),
      ),
    ).then((_) { nameField.dispose(); usernameField.dispose(); emailField.dispose(); phoneField.dispose(); });
  }

  void _showProductForm(AdminController controller, AdminProduct? product) {
    if (controller.activeCategories.isEmpty) { _showMessageDialog('Add a category first', 'Every product belongs to a category. Create one first.'); return; }
    final isEdit = product != null;
    final nameField = TextEditingController(text: product?.name ?? '');
    final descField = TextEditingController(text: product?.description ?? '');
    final priceField = TextEditingController(text: product?.price.toStringAsFixed(2) ?? '');
    final costField = TextEditingController(text: product?.cost.toStringAsFixed(2) ?? '');
    final qtyField = TextEditingController(text: product == null ? '' : (product.quantity == product.quantity.roundToDouble() ? product.quantity.toStringAsFixed(0) : product.quantity.toStringAsFixed(2)));
    final bcField = TextEditingController(text: product?.barcode ?? '');
    final thField = TextEditingController(text: (product?.lowStockThreshold ?? kDefaultLowStockThreshold).toStringAsFixed(0));
    final catOptions = [...controller.activeCategories];
    if (isEdit && !catOptions.any((c) => c.id == product.categoryId)) { final orig = controller.categoryById(product.categoryId); if (orig != null) catOptions.insert(0, orig); }
    var catId = product?.categoryId ?? catOptions.first.id;
    var unit = product?.unit ?? 'piece';
    DateTime? expiry = product?.expirationDate;
    String? errorMsg;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => dialogShell(ctx,
          width: 560, scrollable: true,
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? 'Edit ${product.name}' : 'Add a product', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.darkText)),
              const SizedBox(height: 4),
              const Text('Products with a decimal unit (kg, gram, liter) can be sold by weight.', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
              if (errorMsg != null) formError(errorMsg!),
              const SizedBox(height: 20),
              field(nameField, 'Product name', hint: 'Lucky Me Pancit Canton'),
              const SizedBox(height: 14),
              field(descField, 'Description (optional)', hint: 'Original flavour'),
              const SizedBox(height: 18),
              dialogRow('Category', DropdownButton<String>(value: catId, underline: const SizedBox(), items: catOptions.map((c) => DropdownMenuItem(value: c.id, child: Text(c.isArchived ? '${c.name} (archived)' : c.name))).toList(), onChanged: (v) => setDialogState(() => catId = v ?? catId))),
              dialogRow('Unit', DropdownButton<String>(value: unit, underline: const SizedBox(), items: kProductUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: (v) => setDialogState(() => unit = v ?? unit))),
              const SizedBox(height: 14),
              Row(children: [Expanded(child: field(priceField, 'Selling price', hint: '0.00', prefix: '₱', numeric: true)), const SizedBox(width: 14), Expanded(child: field(costField, 'Cost price', hint: '0.00', prefix: '₱', numeric: true))]),
              const SizedBox(height: 14),
              Row(children: [Expanded(child: field(qtyField, 'Stock on hand', hint: '0', numeric: true)), const SizedBox(width: 14), Expanded(child: field(thField, 'Reorder level', hint: '5', numeric: true))]),
              const SizedBox(height: 14),
              field(bcField, 'Barcode (optional)', hint: '4800016644047'),
              const SizedBox(height: 18),
              dialogRow('Expiry date', Row(mainAxisSize: MainAxisSize.min, children: [Text(expiry == null ? 'Not set' : formatDate(expiry), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkText)), const SizedBox(width: 8), TextButton(onPressed: () async { final now = DateTime.now(); final p = await showDatePicker(context: ctx, initialDate: expiry ?? now.add(const Duration(days: 90)), firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 10)); if (p != null) setDialogState(() => expiry = p); }, child: Text(expiry == null ? 'Set' : 'Change')), if (expiry != null) TextButton(onPressed: () => setDialogState(() => expiry = null), child: const Text('Clear'))])),
              const SizedBox(height: 24),
              dialogActions(ctx, confirmLabel: isEdit ? 'Save changes' : 'Add product', onConfirm: () {
                final p = double.tryParse(priceField.text.trim()); final c = double.tryParse(costField.text.trim()); final q = double.tryParse(qtyField.text.trim()); final t = double.tryParse(thField.text.trim()) ?? kDefaultLowStockThreshold;
                if (p == null || c == null || q == null) {
                  setDialogState(() => errorMsg = 'Enter prices and quantity as numbers.');
                  return;
                }
                final err = isEdit ? controller.updateProduct(product.id, name: nameField.text, categoryId: catId, description: descField.text, price: p, cost: c, quantity: q, unit: unit, barcode: bcField.text, expirationDate: expiry, clearExpiration: expiry == null, lowStockThreshold: t)
                    : controller.createProduct(name: nameField.text, categoryId: catId, description: descField.text, price: p, cost: c, quantity: q, unit: unit, barcode: bcField.text, expirationDate: expiry, lowStockThreshold: t);
                if (err != null) {
                  setDialogState(() => errorMsg = err);
                } else {
                  Navigator.pop(ctx);
                  _toast(isEdit ? 'Saved changes to ${nameField.text.trim()}.' : '${nameField.text.trim()} was added.');
                }
              }),
            ],
          ),
        ),
      ),
    ).then((_) { nameField.dispose(); descField.dispose(); priceField.dispose(); costField.dispose(); qtyField.dispose(); bcField.dispose(); thField.dispose(); });
  }

  void _showCategoryForm(AdminController controller, AdminCategory? category) {
    final isEdit = category != null;
    final nameField = TextEditingController(text: category?.name ?? '');
    final descField = TextEditingController(text: category?.description ?? '');
    String? errorMsg;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => dialogShell(ctx,
          width: 500, scrollable: true,
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? 'Edit ${category.name}' : 'Add a category', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.darkText)),
              const SizedBox(height: 4),
              const Text('Categories decide how products are grouped at the till.', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
              if (errorMsg != null) formError(errorMsg!),
              const SizedBox(height: 20),
              field(nameField, 'Category name', hint: 'Beverages'),
              const SizedBox(height: 14),
              field(descField, 'Description (optional)', hint: 'Soft drinks, juice, bottled water'),
              const SizedBox(height: 24),
              dialogActions(ctx, confirmLabel: isEdit ? 'Save changes' : 'Add category', onConfirm: () {
                final err = isEdit ? controller.updateCategory(category.id, name: nameField.text, description: descField.text)
                    : controller.createCategory(name: nameField.text, description: descField.text);
                if (err != null) {
                  setDialogState(() => errorMsg = err);
                } else {
                  Navigator.pop(ctx);
                  _toast(isEdit ? 'Saved changes to ${nameField.text.trim()}.' : '${nameField.text.trim()} was added.');
                }
              }),
            ],
          ),
        ),
      ),
    ).then((_) { nameField.dispose(); descField.dispose(); });
  }

  void _showStockDialog(AdminController controller, AdminProduct product) {
    final amtField = TextEditingController();
    final resField = TextEditingController(text: 'Delivery received');
    var isAdding = true; String? errorMsg;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => dialogShell(ctx,
          width: 460, scrollable: true,
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Adjust stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.darkText)),
              const SizedBox(height: 4),
              Text('${product.name} — ${formatQuantity(product.quantity, product.unit)} on hand', style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
              if (errorMsg != null) formError(errorMsg!),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _segmentButton('Add stock', isAdding, () => setDialogState(() => isAdding = true))),
                const SizedBox(width: 10),
                Expanded(child: _segmentButton('Remove stock', !isAdding, () => setDialogState(() => isAdding = false))),
              ]),
              const SizedBox(height: 18),
              field(amtField, 'Amount (${product.unit})', hint: '0', numeric: true),
              const SizedBox(height: 14),
              field(resField, 'Reason', hint: 'Delivery received, recount'),
              const SizedBox(height: 24),
              dialogActions(ctx, confirmLabel: 'Save adjustment', onConfirm: () {
                final a = double.tryParse(amtField.text.trim());
                if (a == null || a <= 0) {
                  setDialogState(() => errorMsg = 'Enter a valid amount.');
                  return;
                }
                final err = controller.adjustStock(product.id, isAdding ? a : -a, reason: resField.text.trim().isEmpty ? 'Manual adjustment' : resField.text.trim());
                if (err != null) {
                  setDialogState(() => errorMsg = err);
                } else {
                  Navigator.pop(ctx);
                  _toast('${product.name} is now ${formatQuantity(isAdding ? product.quantity + a : product.quantity - a, product.unit)}.');
                }
              }),
            ],
          ),
        ),
      ),
    ).then((_) { amtField.dispose(); resField.dispose(); });
  }

  Widget _segmentButton(String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: isActive ? AppColors.primaryOrange.withValues(alpha: 0.10) : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: isActive ? AppColors.primaryOrange : AppColors.borderColor)),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? AppColors.primaryOrange : AppColors.secondaryText)),
      ),
    );
  }

  void _showReceipt(AdminController controller, AdminSale sale) {
    showDialog<void>(
      context: context,
      builder: (ctx) => dialogShell(ctx,
        width: 480, scrollable: true,
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(sale.receiptNumber, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.darkText)), Text('${formatDateTime(sale.timestamp)} · ${sale.cashierName}', style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryText))])), statusPill(sale.status.label, sale.isCompleted ? Colors.green : Colors.red)]),
            if (!sale.isCompleted && sale.voidReason != null) ...[const SizedBox(height: 14), Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)), child: Text('Voided by ${sale.voidedBy ?? 'unknown'} on ${formatDateTime(sale.voidedAt)}\nReason: ${sale.voidReason}', style: TextStyle(fontSize: 12.5, color: Colors.red[800], height: 1.5)))],
            const SizedBox(height: 18),
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20), decoration: BoxDecoration(color: AppColors.lightBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderColor)), child: SelectableText(buildReceiptText(sale, storeName: _storeName), style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.55, color: AppColors.darkText))),
            const SizedBox(height: 18),
            Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: [
              if (sale.isCompleted) OutlinedButton.icon(onPressed: () { Navigator.pop(ctx); _showVoidDialog(controller, sale); }, icon: const Icon(Icons.block_outlined, size: 17), label: const Text('Void receipt'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red[700], side: BorderSide(color: Colors.red.withValues(alpha: 0.4)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14))),
              OutlinedButton.icon(onPressed: () => _copyText(buildReceiptText(sale, storeName: _storeName), 'Receipt copied.'), icon: const Icon(Icons.copy_all_outlined, size: 17), label: const Text('Copy receipt'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.darkText, side: const BorderSide(color: AppColors.borderColor), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14))),
              ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
            ]),
          ],
        ),
      ),
    );
  }

  void _showVoidDialog(AdminController controller, AdminSale sale) {
    final resField = TextEditingController(); String? errorMsg;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => dialogShell(ctx,
          width: 460, scrollable: true,
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Void this receipt?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.darkText)),
              const SizedBox(height: 6),
              Text('${sale.receiptNumber} for ${formatPeso(sale.total)} will be voided. Items go back to stock.', style: const TextStyle(fontSize: 13, color: AppColors.secondaryText, height: 1.5)),
              if (errorMsg != null) formError(errorMsg!),
              const SizedBox(height: 18),
              field(resField, 'Reason', hint: 'Wrong item scanned, etc.'),
              const SizedBox(height: 24),
              dialogActions(ctx, confirmLabel: 'Void receipt', confirmColor: Colors.red, onConfirm: () {
                final err = controller.voidSale(sale.id, resField.text);
                if (err != null) {
                  setDialogState(() => errorMsg = err);
                } else {
                  Navigator.pop(ctx);
                  _toast('${sale.receiptNumber} was voided.');
                }
              }),
            ],
          ),
        ),
      ),
    ).then((_) => resField.dispose());
  }

  void _confirmArchive({required String what, required String name, required String detail, required VoidCallback onConfirm, String? blockedMessage}) {
    if (!_confirmBeforeArchive && blockedMessage == null) { onConfirm(); return; }
    _showConfirmDialog(title: 'Archive this $what?', message: '"$name" moves to the archive. $detail', icon: Icons.archive_outlined, color: Colors.orange, confirmLabel: 'Archive', onConfirm: onConfirm, blockedMessage: blockedMessage);
  }

  void _confirmRestore({required String what, required String name, required VoidCallback onConfirm, String? blockedMessage}) {
    _showConfirmDialog(title: 'Restore this $what?', message: '"$name" goes back to active.', icon: Icons.restore, color: Colors.green, confirmLabel: 'Restore', onConfirm: onConfirm, blockedMessage: blockedMessage);
  }

  void _confirmDelete({required String what, required String name, required VoidCallback onConfirm, String? blockedMessage}) {
    _showConfirmDialog(title: 'Delete this $what?', message: '"$name" will be removed for good.', icon: Icons.delete_forever_outlined, color: Colors.red, confirmLabel: 'Delete', onConfirm: onConfirm, blockedMessage: blockedMessage);
  }

  void _showConfirmDialog({required String title, required String message, required IconData icon, required Color color, required String confirmLabel, required VoidCallback onConfirm, String? blockedMessage}) {
    final isBlocked = blockedMessage != null;
    showDialog<void>(
      context: context,
      builder: (ctx) => dialogShell(ctx,
        width: 460, scrollable: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: (isBlocked ? Colors.grey : color).withValues(alpha: 0.10), shape: BoxShape.circle), child: Icon(isBlocked ? Icons.lock_outline : icon, color: isBlocked ? Colors.grey[700] : color, size: 34)),
            const SizedBox(height: 18),
            Text(isBlocked ? 'Not possible' : title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.darkText)),
            const SizedBox(height: 10),
            Text(blockedMessage ?? message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13.5, height: 1.5)),
            const SizedBox(height: 26),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), style: OutlinedButton.styleFrom(foregroundColor: AppColors.darkText, side: const BorderSide(color: AppColors.borderColor), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(isBlocked ? 'Close' : 'Cancel'))),
              if (!isBlocked) ...[const SizedBox(width: 12), Expanded(child: ElevatedButton(onPressed: () { Navigator.pop(ctx); onConfirm(); }, style: ElevatedButton.styleFrom(backgroundColor: color, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(confirmLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))))],
            ]),
          ],
        ),
      ),
    );
  }

  void _showMessageDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => dialogShell(ctx,
        width: 440, scrollable: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), shape: BoxShape.circle), child: const Icon(Icons.info_outline, color: Colors.red, size: 30)),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.darkText)),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13.5, height: 1.5)),
            const SizedBox(height: 22),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkText, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Got it', style: TextStyle(color: Colors.white)))),
          ],
        ),
      ),
    );
  }

  void _showUserDetail(AdminUser user) {
    showDialog<void>(
      context: context,
      builder: (ctx) => dialogShell(ctx,
        width: 460, scrollable: true,
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [CircleAvatar(radius: 24, backgroundColor: AppColors.lightPeach, child: Text(user.initials, style: const TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.w800, fontSize: 16))), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.darkText)), Text('@${user.username}', style: const TextStyle(fontSize: 13, color: AppColors.placeholderColor))])), statusPill(user.role.label, Colors.purple)]),
            const Divider(height: 32),
            detailRow('Email', user.email), detailRow('Mobile', user.phone), detailRow('Status', user.status), detailRow('Verification', user.verificationStatus), detailRow('Joined', formatDate(user.createdAt)), detailRow('Last updated', formatDateTime(user.updatedAt)), detailRow('Reference', user.id),
            const SizedBox(height: 22),
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))),
          ],
        ),
      ),
    );
  }

  void _showAuditDetail(AdminAuditLog log) {
    showDialog<void>(
      context: context,
      builder: (ctx) => dialogShell(ctx,
        width: 460, scrollable: true,
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [statusPill(log.action.label, Colors.blue), const SizedBox(width: 12), Expanded(child: Text('${log.entityType} "${log.entityName}"', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.darkText)))]),
            const Divider(height: 28),
            detailRow('Changed by', log.performedBy), detailRow('When', formatDateTime(log.timestamp)), detailRow('Before', log.previousStatus), detailRow('After', log.newStatus), if (log.note != null) detailRow('Note', log.note!), detailRow('Record', log.entityId), detailRow('Entry', log.id),
            const SizedBox(height: 22),
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))),
          ],
        ),
      ),
    );
  }

  void _copyText(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    _toast(message);
  }
}

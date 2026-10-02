import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../models/admin_models.dart';
import '../../services/admin_sale_service.dart';
import '../../utils/csv_downloader.dart';
import '../../utils/sales_csv_generator.dart';
import '../widgets/dashboard_shared.dart';

class SalesSection extends StatefulWidget {
  final AdminSaleService saleService;
  final String searchQuery;
  final int rowsPerPage;
  final Map<String, int> pages;
  final String storeName;
  final void Function(String, int) onPageChange;
  final void Function(AdminSale) onShowReceipt;
  final void Function(AdminSale) onVoidSale;
  final void Function(String, String) onCopyText;
  final void Function() onClearFilters;

  const SalesSection({
    super.key,
    required this.saleService,
    required this.searchQuery,
    required this.rowsPerPage,
    required this.pages,
    required this.storeName,
    required this.onPageChange,
    required this.onShowReceipt,
    required this.onVoidSale,
    required this.onCopyText,
    required this.onClearFilters,
  });

  @override
  State<SalesSection> createState() => _SalesSectionState();
}

class _SalesSectionState extends State<SalesSection> {
  late TextEditingController _searchController;
  String _transactionFilter = 'All Transactions';
  String _viewMode = 'active'; // 'active' | 'voided'
  bool _isRefreshing = false;
  late int _rowsPerPage;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
    _rowsPerPage = widget.rowsPerPage;
  }

  @override
  void didUpdateWidget(covariant SalesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminSale> _filteredSales() {
    if (!widget.saleService.isInitialized) {
      return [];
    }

    final query = (_searchController.text.isNotEmpty
            ? _searchController.text
            : widget.searchQuery)
        .toLowerCase()
        .trim();

    return widget.saleService.allSales.where((sale) {
      // Separate Active Sales from Voided Transactions
      if (_viewMode == 'voided') {
        if (sale.isCompleted) return false;
      } else {
        if (!sale.isCompleted) return false;
      }

      final matchesQuery = query.isEmpty ||
          sale.receiptNumber.toLowerCase().contains(query) ||
          sale.cashierName.toLowerCase().contains(query) ||
          sale.handledByDisplay.toLowerCase().contains(query) ||
          sale.customerName.toLowerCase().contains(query) ||
          (sale.voidReason?.toLowerCase().contains(query) ?? false) ||
          sale.transactionType.label.toLowerCase().contains(query);

      final matchesTransaction = _transactionFilter == 'All Transactions' ||
          _transactionFilter == 'All' ||
          sale.transactionType.label == _transactionFilter;

      return matchesQuery && matchesTransaction;
    }).toList();
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      await widget.saleService.refresh();
      if (mounted) {
        TopNotification.show(
          context,
          'Sales database refreshed and synced successfully.',
          title: 'Database Synced',
        );
      }
    } catch (e) {
      if (mounted) {
        TopNotification.show(
          context,
          'Failed to refresh sales database: $e',
          isError: true,
          title: 'Sync Error',
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.saleService,
      builder: (context, _) {
        if (!widget.saleService.isInitialized && widget.saleService.isLoading) {
          return Column(
            children: List.generate(
              6,
              (index) => const TableRowSkeleton(),
            ),
          );
        }

        final filteredSales = _filteredSales();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. SALES SUMMARY KPI CARDS (Daily, Weekly, Monthly)
            _buildSalesSummaryCards(),
            const SizedBox(height: 24),

            // 2. MAIN SALES RECORDS CARD (Search, Transaction Filter, Export CSV, Table)
            _buildSalesRecordsCard(filteredSales),
          ],
        );
      },
    );
  }

  // ============================================================
  // 1. SALES SUMMARY CARDS (DAILY, WEEKLY, MONTHLY)
  // ============================================================

  Widget _buildSalesSummaryCards() {
    final now = DateTime.now();

    // Daily summary
    final dailyTotal = widget.saleService.salesToday;
    final dailyCount = widget.saleService.ordersToday;
    final dailyInStoreCount = widget.saleService.completedSales
        .where((s) => widget.saleService.isSameDay(s.timestamp, now) && s.isInStore)
        .length;
    final dailyDeliveryCount = widget.saleService.completedSales
        .where((s) => widget.saleService.isSameDay(s.timestamp, now) && s.isDelivery)
        .length;

    // Weekly summary
    final weeklyTotal = widget.saleService.salesThisWeek;
    final weeklyCount = widget.saleService.ordersThisWeek;
    final nowMidnight = DateTime(now.year, now.month, now.day);
    final weekStart = nowMidnight.subtract(Duration(days: nowMidnight.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    final weeklyInStoreCount = widget.saleService.completedSales
        .where((s) => !s.timestamp.isBefore(weekStart) && !s.timestamp.isAfter(weekEnd) && s.isInStore)
        .length;
    final weeklyDeliveryCount = widget.saleService.completedSales
        .where((s) => !s.timestamp.isBefore(weekStart) && !s.timestamp.isAfter(weekEnd) && s.isDelivery)
        .length;

    // Monthly summary
    final monthlyTotal = widget.saleService.salesThisMonth;
    final monthlyCount = widget.saleService.ordersThisMonth;
    final monthlyInStoreCount = widget.saleService.completedSales
        .where((s) => s.timestamp.year == now.year && s.timestamp.month == now.month && s.isInStore)
        .length;
    final monthlyDeliveryCount = widget.saleService.completedSales
        .where((s) => s.timestamp.year == now.year && s.timestamp.month == now.month && s.isDelivery)
        .length;

    final cards = [
      _buildGlassMetricCard(
        title: 'Daily Sales',
        subtitle: 'Today, ${formatShortDate(now)}',
        amount: widget.saleService.formatPeso(dailyTotal),
        totalOrders: dailyCount,
        inStoreCount: dailyInStoreCount,
        deliveryCount: dailyDeliveryCount,
        icon: Icons.calendar_today_rounded,
        accentColor: AppColors.primaryOrange,
        gradientColors: [
          const Color(0xFFFFF7ED),
          Colors.white.withValues(alpha: 0.85),
        ],
      ),
      _buildGlassMetricCard(
        title: 'Weekly Sales',
        subtitle: formatWeekRange(weekStart, weekEnd),
        amount: widget.saleService.formatPeso(weeklyTotal),
        totalOrders: weeklyCount,
        inStoreCount: weeklyInStoreCount,
        deliveryCount: weeklyDeliveryCount,
        icon: Icons.date_range_rounded,
        accentColor: const Color(0xFF0D9488),
        gradientColors: [
          const Color(0xFFF0FDFA),
          Colors.white.withValues(alpha: 0.85),
        ],
      ),
      _buildGlassMetricCard(
        title: 'Monthly Sales',
        subtitle: formatMonthYear(now.year, now.month),
        amount: widget.saleService.formatPeso(monthlyTotal),
        totalOrders: monthlyCount,
        inStoreCount: monthlyInStoreCount,
        deliveryCount: monthlyDeliveryCount,
        icon: Icons.calendar_month_rounded,
        accentColor: const Color(0xFF6366F1),
        gradientColors: [
          const Color(0xFFEEF2FF),
          Colors.white.withValues(alpha: 0.85),
        ],
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 940) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 16),
              Expanded(child: cards[1]),
              const SizedBox(width: 16),
              Expanded(child: cards[2]),
            ],
          );
        } else if (constraints.maxWidth >= 600) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 16),
              cards[2],
            ],
          );
        } else {
          return Column(
            children: [
              cards[0],
              const SizedBox(height: 14),
              cards[1],
              const SizedBox(height: 14),
              cards[2],
            ],
          );
        }
      },
    );
  }

  Widget _buildGlassMetricCard({
    required String title,
    required String subtitle,
    required String amount,
    required int totalOrders,
    required int inStoreCount,
    required int deliveryCount,
    required IconData icon,
    required Color accentColor,
    required List<Color> gradientColors,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.95),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.7),
                blurRadius: 0,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkText,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.borderColor.withValues(alpha: 0.6),
                  ),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 13, color: accentColor),
                        const SizedBox(width: 4),
                        Text(
                          '$totalOrders completed',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkText,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront_outlined, size: 12, color: Color(0xFF0D9488)),
                        const SizedBox(width: 3),
                        Text(
                          '$inStoreCount in-store',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_shipping_outlined, size: 12, color: AppColors.primaryOrange),
                        const SizedBox(width: 3),
                        Text(
                          '$deliveryCount delivery',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 2. SALES RECORDS CARD & TOOLBAR
  // ============================================================

  Widget _buildSalesRecordsCard(List<AdminSale> sales) {
    final activeCount = widget.saleService.allSales.where((s) => s.isCompleted).length;
    final voidedCount = widget.saleService.allSales.where((s) => !s.isCompleted).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 640;

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 16 : 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.94),
                    Colors.white.withValues(alpha: 0.82),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.95),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.darkText.withValues(alpha: 0.05),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Responsive Header Row inside Card
                  if (isMobile) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sales Records',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Track all completed and processed in-store & delivery transactions',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.secondaryText.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildDatabaseStatusBadge(),
                      ],
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sales Records',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.darkText,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Track all completed and processed in-store & delivery transactions',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondaryText.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildDatabaseStatusBadge(),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),

                  // SINGLE LINE TOOLBAR: Search Bar, Transactions, Active/Voided Tabs, Export CSV
                  // Perfectly equal 40px height for all widgets, wraps gracefully on mobile
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // 1. Search Bar
                      _buildSearchBar(isMobile),
                      // 2. Transactions Filter Dropdown
                      _buildTransactionDropdown(),
                      // 3. Segmented Active Sales & Voided Receipts
                      _buildViewModeTabs(activeCount, voidedCount),
                      // 4. Export CSV Button
                      _buildExportCsvButton(),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Table or Empty State
                  if (sales.isEmpty)
                    emptyState(
                      icon: _viewMode == 'voided' ? Icons.check_circle_outline_rounded : Icons.receipt_long_outlined,
                      title: _viewMode == 'voided' ? 'No voided transactions found' : 'No sales records found',
                      message: _viewMode == 'voided'
                          ? (_searchController.text.isNotEmpty || _transactionFilter != 'All Transactions'
                              ? 'No voided records match your current search and filter settings.'
                              : 'There are no voided transactions. All sales records are in good standing.')
                          : (_searchController.text.isNotEmpty || _transactionFilter != 'All Transactions'
                              ? 'No sales records match your current search and filter settings.'
                              : 'Completed transactions from the POS and customer delivery orders will appear here.'),
                      actionLabel: _searchController.text.isNotEmpty || _transactionFilter != 'All Transactions'
                          ? 'Clear filters'
                          : null,
                      onAction: () {
                        setState(() {
                          _searchController.clear();
                          _transactionFilter = 'All Transactions';
                          widget.onClearFilters();
                        });
                      },
                    )
                  else
                    _buildTable(sales),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(bool isMobile) {
    return Container(
      width: isMobile ? 210 : 230,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() {
          widget.onPageChange('sales', 1);
        }),
        style: const TextStyle(fontSize: 12.5, color: AppColors.darkText, fontWeight: FontWeight.w500),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          hintText: 'Search receipt, customer...',
          hintStyle: const TextStyle(fontSize: 12, color: AppColors.placeholderColor),
          prefixIcon: const Icon(Icons.search, size: 17, color: AppColors.secondaryText),
          prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 15, color: AppColors.secondaryText),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      widget.onPageChange('sales', 1);
                    });
                  },
                )
              : null,
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildTransactionDropdown() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Transactions:',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _transactionFilter,
              isDense: true,
              borderRadius: BorderRadius.circular(12),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.secondaryText),
              items: const [
                DropdownMenuItem(value: 'All Transactions', child: Text('All Transactions')),
                DropdownMenuItem(value: 'In-Store Transaction', child: Text('In-Store Transaction')),
                DropdownMenuItem(value: 'Delivery Transaction', child: Text('Delivery Transaction')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _transactionFilter = value;
                    widget.onPageChange('sales', 1);
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeTabs(int activeCount, int voidedCount) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.lightBackground.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabButton(
            label: 'Active Sales',
            count: activeCount,
            isSelected: _viewMode == 'active',
            icon: Icons.check_circle_outline_rounded,
            activeColor: AppColors.primaryOrange,
            onTap: () {
              if (_viewMode != 'active') {
                setState(() {
                  _viewMode = 'active';
                  widget.onPageChange('sales', 1);
                });
              }
            },
          ),
          const SizedBox(width: 4),
          _buildTabButton(
            label: 'Voided Receipts',
            count: voidedCount,
            isSelected: _viewMode == 'voided',
            icon: Icons.block_flipped,
            activeColor: Colors.redAccent,
            onTap: () {
              if (_viewMode != 'voided') {
                setState(() {
                  _viewMode = 'voided';
                  widget.onPageChange('sales', 1);
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required int count,
    required bool isSelected,
    required IconData icon,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? activeColor : AppColors.secondaryText,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? AppColors.darkText : AppColors.secondaryText,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? activeColor : AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportCsvButton() {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: () => _openExportCsvDialog(context),
        icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
        label: const Text(
          'Export CSV',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 12.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildDatabaseStatusBadge() {
    final lastSync = widget.saleService.lastSyncTime;
    final syncText = lastSync != null ? formatTime(lastSync) : 'Live';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'DB Synced: $syncText',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Refresh database sales',
            icon: _isRefreshing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryOrange),
                  )
                : const Icon(Icons.refresh_rounded, size: 16, color: AppColors.secondaryText),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.zero,
            onPressed: _isRefreshing ? null : _handleRefresh,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 3. SALES RECORDS TABLE
  // ============================================================

  Widget _buildTable(List<AdminSale> sales) {
    final paged = paginate(sales, 'sales', _rowsPerPage, widget.pages);

    return tableShell(
      minWidth: 1000,
      columnWidths: const {
        0: FlexColumnWidth(1.8), // Receipt #
        1: FlexColumnWidth(1.8), // Date & Time
        2: FlexColumnWidth(2.3), // Customer / Handled By
        3: FlexColumnWidth(1.5), // Total
        4: FlexColumnWidth(2.6), // Transactions (Replaced Status)
        5: FixedColumnWidth(130), // Actions
      },
      header: [
        header('Receipt #'),
        header('Date & Time'),
        header('Customer / Handled By'),
        header('Total'),
        header('Transactions'), // Replaced Status label
        header('Actions'),
      ],
      rows: [
        for (final sale in paged.items)
          [
            // Receipt #
            cell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_outlined, size: 16, color: AppColors.secondaryText),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      sale.receiptNumber,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Date & Time
            cell(
              Text(
                formatDateTime(sale.timestamp),
                style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
              ),
            ),
            // Customer / Handled By (with Name and Role from DB)
            cell(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sale.customerName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'by ${sale.handledByDisplay}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.placeholderColor,
                    ),
                  ),
                ],
              ),
            ),
            // Total
            cell(
              Text(
                formatPeso(sale.total),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: AppColors.darkText,
                ),
              ),
            ),
            // Transactions pill badge (replacing Status column)
            cell(_buildTransactionPill(sale)),
            // Actions (View Receipt, Void Sale or Restore/Un-void Sale)
            cell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconAction(
                    Icons.receipt_long_outlined,
                    'View Receipt',
                    Colors.blueGrey,
                    () => _showReceiptDetails(context, sale),
                  ),
                  if (sale.isCompleted)
                    iconAction(
                      Icons.block_outlined,
                      'Void Sale',
                      Colors.red,
                      () => _showVoidSaleDialog(context, sale),
                    )
                  else
                    iconAction(
                      Icons.restore_rounded,
                      'Restore / Un-void Receipt',
                      const Color(0xFF10B981),
                      () => _showUnvoidSaleDialog(context, sale),
                    ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ],
      ],
      footer: paginationBar(
        paged,
        'sales',
        'transactions',
        widget.pages,
        widget.onPageChange,
        currentRowsPerPage: _rowsPerPage,
        onRowsPerPageChange: (newRows) {
          setState(() {
            _rowsPerPage = newRows;
            widget.onPageChange('sales', 1);
          });
        },
      ),
    );
  }

  Widget _buildTransactionPill(AdminSale sale) {
    final isDelivery = sale.isDelivery;
    final color = isDelivery ? const Color(0xFFF97316) : const Color(0xFF0D9488);
    final icon = isDelivery ? Icons.local_shipping_outlined : Icons.storefront_outlined;
    final label = sale.transactionType.label;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: 0.28),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        if (!sale.isCompleted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
            ),
            child: Text(
              sale.status.label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // 4. EXPORT CSV DIALOG (PERIOD SELECTION: DAILY, WEEKLY, MONTHLY)
  // ============================================================

  void _openExportCsvDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        String selectedPeriod = 'Daily'; // 'Daily', 'Weekly', 'Monthly'
        DateTime selectedDate = DateTime.now();
        String exportTransactionFilter = _transactionFilter;
        bool isExporting = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            // Calculate matching records based on selected period
            final matchingSales = widget.saleService.getSalesForPeriod(
              period: selectedPeriod,
              referenceDate: selectedDate,
              transactionTypeFilter: exportTransactionFilter,
            );
            final matchingRevenue = matchingSales
                .where((s) => s.isCompleted)
                .fold<double>(0, (sum, s) => sum + s.total);

            String periodSubtitle = '';
            if (selectedPeriod == 'Daily') {
              periodSubtitle = widget.saleService.isSameDay(selectedDate, DateTime.now())
                  ? 'Today (${formatShortDate(selectedDate)})'
                  : formatShortDate(selectedDate);
            } else if (selectedPeriod == 'Weekly') {
              final refMidnight = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
              final weekStart = refMidnight.subtract(Duration(days: refMidnight.weekday - 1));
              final weekEnd = weekStart.add(const Duration(days: 6));
              periodSubtitle = formatWeekRange(weekStart, weekEnd);
            } else {
              periodSubtitle = formatMonthYear(selectedDate.year, selectedDate.month);
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.96),
                        Colors.white.withValues(alpha: 0.90),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryOrange.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.file_download_outlined,
                                      color: AppColors.primaryOrange,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Export Sales as CSV',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.darkText,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Select a time period for exported sales records',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.secondaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () => Navigator.pop(dialogCtx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Period Selector Label
                        const Text(
                        'Select Period',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 3 Period Cards: Daily, Weekly, Monthly
                      Row(
                        children: [
                          Expanded(
                            child: _buildPeriodOptionCard(
                              label: 'Daily',
                              icon: Icons.today_rounded,
                              isSelected: selectedPeriod == 'Daily',
                              onTap: () => setModalState(() => selectedPeriod = 'Daily'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildPeriodOptionCard(
                              label: 'Weekly',
                              icon: Icons.date_range_rounded,
                              isSelected: selectedPeriod == 'Weekly',
                              onTap: () => setModalState(() => selectedPeriod = 'Weekly'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildPeriodOptionCard(
                              label: 'Monthly',
                              icon: Icons.calendar_month_rounded,
                              isSelected: selectedPeriod == 'Monthly',
                              onTap: () => setModalState(() => selectedPeriod = 'Monthly'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Date selector bar for the period
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.lightBackground.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.event_outlined, size: 16, color: AppColors.primaryOrange),
                                const SizedBox(width: 8),
                                Text(
                                  periodSubtitle,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkText,
                                  ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: AppColors.primaryOrange,
                                          onPrimary: Colors.white,
                                          onSurface: AppColors.darkText,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setModalState(() => selectedDate = picked);
                                }
                              },
                              icon: const Icon(Icons.edit_calendar_rounded, size: 14, color: AppColors.primaryOrange),
                              label: const Text(
                                'Change Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryOrange,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Filter by Transaction Type option
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          const Text(
                            'Transaction Category:',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderColor),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: exportTransactionFilter,
                                isDense: true,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkText,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'All Transactions',
                                    child: Text('All Transactions'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'In-Store Transaction',
                                    child: Text('In-Store Only'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Delivery Transaction',
                                    child: Text('Delivery Only'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() => exportTransactionFilter = val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Export Summary Preview Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primaryOrange.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Records to Export',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${matchingSales.length} Transactions',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.darkText,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Total Sales',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.saleService.formatPeso(matchingRevenue),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primaryOrange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Dialog Actions
                      Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.secondaryText,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton.icon(
                            onPressed: isExporting
                                ? null
                                : () async {
                                    setModalState(() => isExporting = true);
                                    try {
                                      final csvContent = SalesCsvGenerator.generateSalesCsv(
                                        sales: matchingSales,
                                        periodName: '$selectedPeriod - $periodSubtitle',
                                        storeName: widget.storeName,
                                      );

                                      final dateStr =
                                          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                                      final filename =
                                          'sales_report_${selectedPeriod.toLowerCase()}_$dateStr.csv';

                                      final savedPath = await exportCsvFile(csvContent, filename);

                                      if (dialogCtx.mounted) {
                                        Navigator.pop(dialogCtx);
                                      }
                                      if (mounted) {
                                        final pathMessage = (savedPath != null && savedPath != 'browser_downloaded')
                                            ? 'Saved to: $savedPath'
                                            : 'Downloaded: $filename';
                                        TopNotification.show(
                                          this.context,
                                          'Exported ${matchingSales.length} records for $selectedPeriod. $pathMessage',
                                          title: 'Export CSV Complete',
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        TopNotification.show(
                                          this.context,
                                          'Failed to export CSV: $e',
                                          isError: true,
                                          title: 'Export Error',
                                        );
                                      }
                                    } finally {
                                      setModalState(() => isExporting = false);
                                    }
                                  },
                            icon: isExporting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.download_rounded, size: 18),
                            label: Text(
                              isExporting ? 'Exporting...' : 'Export as CSV',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
  }

  Widget _buildPeriodOptionCard({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryOrange.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : AppColors.borderColor,
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryOrange.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.primaryOrange : AppColors.darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 5. RECEIPT VIEWER & VOID MODALS
  // ============================================================

  void _showReceiptDetails(BuildContext context, AdminSale sale) {
    widget.onShowReceipt(sale);

    // Also display a full modern receipt dialog
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.receipt_long_rounded, color: AppColors.primaryOrange, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Transaction Receipt',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkText,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Text(
                      widget.storeName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Pagsanjan, Laguna',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Receipt #: ${sale.receiptNumber}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDateTime(sale.timestamp),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.placeholderColor),
                    ),
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          detailRow('Customer', sale.customerName),
                          detailRow('Handled By', sale.handledByDisplay),
                          detailRow('Category', sale.transactionType.label),
                          detailRow('Payment', sale.paymentMethod.label),
                          detailRow('Status', sale.status.label),
                        ],
                      ),
                    ),
                    if (!sale.isCompleted) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.info_outline, size: 14, color: Colors.red),
                                SizedBox(width: 6),
                                Text('Void Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.red)),
                              ],
                            ),
                            if (sale.voidReason != null && sale.voidReason!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Reason: ${sale.voidReason}', style: const TextStyle(fontSize: 11, color: AppColors.darkText)),
                            ],
                            if (sale.voidedAt != null) ...[
                              const SizedBox(height: 2),
                              Text('Voided At: ${formatDateTime(sale.voidedAt!)}', style: const TextStyle(fontSize: 10.5, color: AppColors.secondaryText)),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    if (sale.items.isNotEmpty) ...[
                      const Text(
                        'Purchased Items',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: sale.items.length,
                          separatorBuilder: (_, _) => const Divider(height: 8),
                          itemBuilder: (context, idx) {
                            final item = sale.items[idx];
                            return Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${formatQuantity(item.quantity, item.unit)} ${item.productName}',
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                ),
                                Text(
                                  formatPeso(item.lineTotal),
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const Divider(height: 16),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount:',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          formatPeso(sale.total),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            final receiptText = buildReceiptText(sale, storeName: widget.storeName);
                            Clipboard.setData(ClipboardData(text: receiptText));
                            TopNotification.show(context, 'Receipt copied to clipboard');
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copy Text'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        if (!sale.isCompleted)
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogCtx);
                              _showUnvoidSaleDialog(context, sale);
                            },
                            icon: const Icon(Icons.restore_rounded, size: 16, color: Colors.white),
                            label: const Text('Restore Sale'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showVoidSaleDialog(BuildContext context, AdminSale sale) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Void Sale #${sale.receiptNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to void this ${sale.transactionType.label}? Amount: ${formatPeso(sale.total)}',
                style: const TextStyle(fontSize: 13, color: AppColors.darkText),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for voiding',
                  hintText: 'e.g. Customer cancelled, error in items',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  TopNotification.show(context, 'Please enter a void reason', isError: true);
                  return;
                }
                Navigator.pop(dialogCtx);
                widget.onVoidSale(sale);
                final err = await widget.saleService.voidSale(sale.id, reason);
                if (mounted) {
                  if (err == null) {
                    TopNotification.show(this.context, 'Receipt #${sale.receiptNumber} has been voided.');
                  } else {
                    TopNotification.show(this.context, err, isError: true);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Void Sale'),
            ),
          ],
        );
      },
    );
  }

  void _showUnvoidSaleDialog(BuildContext context, AdminSale sale) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isRestoring = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: const [
                  Icon(Icons.restore_rounded, color: Color(0xFF10B981), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Restore Voided Sale',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to restore receipt #${sale.receiptNumber}?',
                    style: const TextStyle(fontSize: 13.5, color: AppColors.darkText),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Column(
                      children: [
                        detailRow('Customer', sale.customerName),
                        detailRow('Handled By', sale.handledByDisplay),
                        detailRow('Amount', formatPeso(sale.total)),
                        if (sale.voidReason != null && sale.voidReason!.isNotEmpty)
                          detailRow('Void Reason', sale.voidReason!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This transaction will be restored to completed status, re-included in total sales analytics, and synced with the database.',
                    style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isRestoring ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isRestoring
                      ? null
                      : () async {
                          setModalState(() => isRestoring = true);
                          final error = await widget.saleService.unvoidSale(sale.id);
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);

                          if (mounted) {
                            if (error != null) {
                              TopNotification.show(
                                this.context,
                                error,
                                isError: true,
                                title: 'Restore Failed',
                              );
                            } else {
                              TopNotification.show(
                                this.context,
                                'Receipt #${sale.receiptNumber} has been successfully restored to active sales.',
                                title: 'Receipt Restored',
                              );
                            }
                          }
                        },
                  icon: isRestoring
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.restore_rounded, size: 16, color: Colors.white),
                  label: const Text(
                    'Restore Sale',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
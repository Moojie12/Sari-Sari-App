import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import 'package:sari_sari/core/services/sale_deal_controller.dart';
import 'package:sari_sari/models/sale_deal_model.dart';
import '../../models/admin_models.dart';
import '../../services/admin_product_service.dart';
import '../../services/admin_user_service.dart';
import '../../services/admin_category_service.dart';
import '../../services/admin_sale_service.dart';
import '../../services/admin_audit_service.dart';
import '../../services/admin_analytics_service.dart';
import '../widgets/dashboard_shared.dart';

class OverviewSection extends StatefulWidget {
  final AdminProductService productService;
  final AdminUserService userService;
  final AdminCategoryService categoryService;
  final AdminSaleService saleService;
  final AdminAuditService auditService;
  final AdminAnalyticsService analyticsService;
  final Function(AdminSection) onGoTo;
  final Function(AdminProduct) onAdjustStock;

  const OverviewSection({
    super.key,
    required this.productService,
    required this.userService,
    required this.categoryService,
    required this.saleService,
    required this.auditService,
    required this.analyticsService,
    required this.onGoTo,
    required this.onAdjustStock,
  });

  @override
  State<OverviewSection> createState() => _OverviewSectionState();
}

class _OverviewSectionState extends State<OverviewSection> {
  DateTime _selectedDailyDate = DateTime.now();
  DateTime _selectedWeeklyDate = DateTime.now();
  DateTime _selectedMonthlyDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final dealController = SaleDealController.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.productService,
        widget.userService,
        widget.categoryService,
        widget.saleService,
        widget.auditService,
        widget.analyticsService,
        dealController,
      ]),
      builder: (context, _) {
        final anyLoading = widget.productService.isLoading ||
            widget.userService.isLoading ||
            widget.categoryService.isLoading ||
            widget.saleService.isLoading ||
            widget.auditService.isLoading ||
            widget.analyticsService.isLoading;

        final allInitialized = widget.productService.isInitialized &&
            widget.userService.isInitialized &&
            widget.categoryService.isInitialized &&
            widget.saleService.isInitialized &&
            widget.auditService.isInitialized &&
            widget.analyticsService.isInitialized;

        if (!allInitialized && anyLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryOrange,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP HERO ROW: 2 Columns Side-by-Side (Best Sellers Top 3 on Left, On-Sale Promos on Right)
            _twoColumn(
              _buildTopSellersCard(),
              _buildOnSaleDealsCard(context),
              flexA: 1,
              flexB: 1,
            ),
            const SizedBox(height: 20),

            // SALES BREAKDOWN CARDS (Daily, Weekly, Monthly with Owner-style Date Navigation Bars)
            _threeColumn([
              _buildDailySalesCard(),
              _buildWeeklySalesCard(),
              _buildMonthlySalesCard(),
            ]),
          ],
        );
      },
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

  Widget _threeColumn(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width <= 0) return const SizedBox.shrink();

        final columns = width < 700 ? 1 : (width < 1180 ? 2 : 3);
        const spacing = 20.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;
        final effectiveCardWidth = cardWidth < 100 ? width : cardWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final c in cards) SizedBox(width: effectiveCardWidth, child: c),
          ],
        );
      },
    );
  }

  // --- BEST SELLERS CARD (TOP 3 ONLY ON CARD) ---
  Widget _buildTopSellersCard() {
    final stats = widget.analyticsService.topSellingProducts(limit: 3);
    final topRevenue = stats.isEmpty ? 0.0 : stats.first.revenue;

    return card(
      title: 'Best Sellers',
      subtitle: 'Top 3 products ranked by total sales revenue',
      trailing: TextButton.icon(
        onPressed: () => _openAllTopSellersModal(context),
        icon: const Icon(Icons.leaderboard_rounded, size: 16, color: AppColors.primaryOrange),
        label: const Text('See All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
      ),
      child: stats.isEmpty
          ? _inlineEmpty('No sales recorded yet in database.')
          : Column(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  _buildBestSellerRow(stats[i], i + 1, topRevenue),
                  if (i < stats.length - 1) const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _openAllTopSellersModal(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.format_list_bulleted_rounded, size: 15, color: AppColors.primaryOrange),
                        SizedBox(width: 6),
                        Text(
                          'View All Product Rankings',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // --- WEB MODAL: ALL BEST SELLERS RANKINGS ---
  void _openAllTopSellersModal(BuildContext context) {
    final allStats = widget.analyticsService.topSellingProducts(limit: 100);
    final topRevenue = allStats.isEmpty ? 0.0 : allStats.first.revenue;
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchController.text.trim().toLowerCase();
            final filteredStats = query.isEmpty
                ? allStats
                : allStats.where((s) => s.productName.toLowerCase().contains(query)).toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.emoji_events_rounded, color: AppColors.primaryOrange, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Best Sellers Rankings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
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
                      const SizedBox(height: 4),
                      const Text(
                        'Full ranking of all products based on completed sales revenue',
                        style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                      ),
                      const SizedBox(height: 16),

                      // Search bar
                      TextField(
                        controller: searchController,
                        onChanged: (_) => setModalState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search product name...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.primaryOrange),
                          filled: true,
                          fillColor: AppColors.lightPeach,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const Divider(height: 24),

                      Expanded(
                        child: filteredStats.isEmpty
                            ? _inlineEmpty('No matching top selling products found.')
                            : ListView.separated(
                                itemCount: filteredStats.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, idx) {
                                  final stat = filteredStats[idx];
                                  final actualRank = allStats.indexOf(stat) + 1;
                                  return _buildBestSellerRow(stat, actualRank, topRevenue);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBestSellerRow(ProductSalesStat stat, int rank, double topRevenue) {
    Color badgeColor;
    IconData? icon;

    if (rank == 1) {
      badgeColor = const Color(0xFFFFD700); // Gold
      icon = Icons.emoji_events_rounded;
    } else if (rank == 2) {
      badgeColor = const Color(0xFFC0C0C0); // Silver
      icon = Icons.workspace_premium_rounded;
    } else if (rank == 3) {
      badgeColor = const Color(0xFFCD7F32); // Bronze
      icon = Icons.military_tech_rounded;
    } else {
      badgeColor = AppColors.primaryOrange.withValues(alpha: 0.15);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryOrange.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                  border: Border.all(color: badgeColor, width: 1.5),
                ),
                child: icon != null
                    ? Icon(icon, size: 16, color: rank <= 3 ? AppColors.darkText : AppColors.secondaryText)
                    : Text(
                        '#$rank',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryText,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.productName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatQuantity(stat.unitsSold, stat.unit)} sold',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                widget.analyticsService.formatPeso(stat.revenue),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (topRevenue <= 0) ? 0 : (stat.revenue / topRevenue).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.lightPeach,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
            ),
          ),
        ],
      ),
    );
  }

  // --- ON-SALE PROMOS & DEALS CARD ---
  Widget _buildOnSaleDealsCard(BuildContext context) {
    final dealController = SaleDealController.instance;
    final deals = dealController.deals;

    return card(
      title: 'On-Sale Promos & Deals',
      subtitle: 'Manage custom promo deals and discounts for customers',
      trailing: ElevatedButton.icon(
        onPressed: () => _openAddEditDealModal(context),
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('New Promo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      child: deals.isEmpty
          ? _inlineEmpty('No on-sale promos created yet. Click "+ New Promo" to create one!')
          : Column(
              children: [
                for (var i = 0; i < deals.length; i++) ...[
                  _buildOnSaleDealRow(context, deals[i]),
                  if (i < deals.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }

  Widget _buildOnSaleDealRow(BuildContext context, SaleDealModel deal) {
    final dealController = SaleDealController.instance;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: deal.isActive
            ? AppColors.lightBackground.withValues(alpha: 0.5)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: deal.isActive
              ? AppColors.primaryOrange.withValues(alpha: 0.12)
              : AppColors.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: deal.isActive
                      ? AppColors.primaryOrange.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.local_offer_rounded,
                  size: 18,
                  color: deal.isActive ? AppColors.primaryOrange : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            deal.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: deal.isActive ? AppColors.darkText : Colors.grey[700],
                            ),
                          ),
                        ),
                        if (deal.discountPercentage > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${deal.discountPercentage}% OFF',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                        if (deal.isSoldOut) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'SOLD OUT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${deal.totalItemQuantity} items · Regular: ${widget.analyticsService.formatPeso(deal.originalTotalPrice)}${deal.saleLimit != null ? ' · Limit: ${deal.saleLimit} (${deal.remainingSaleLimit} left · ${deal.soldCount} sold)' : ''}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                widget.analyticsService.formatPeso(deal.salePrice),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: deal.isActive ? AppColors.primaryOrange : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: deal.isActive
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  deal.isActive ? 'Active' : 'Disabled',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: deal.isActive ? Colors.green[800] : Colors.grey[700],
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'View Details',
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    color: AppColors.darkText,
                    onPressed: () => _openViewDealModal(context, deal),
                  ),
                  IconButton(
                    tooltip: 'Edit / Customize Promo',
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: AppColors.primaryOrange,
                    onPressed: () => _openAddEditDealModal(context, deal),
                  ),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: deal.isActive,
                      activeColor: AppColors.primaryOrange,
                      onChanged: (val) {
                        dealController.toggleDealStatus(deal.id, val);
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete Promo',
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: Colors.red,
                    onPressed: () => _confirmDeleteDeal(context, deal),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- WEB MODAL: CREATE OR EDIT DEAL ---
  void _openAddEditDealModal(BuildContext context, [SaleDealModel? existingDeal]) {
    final titleController = TextEditingController(text: existingDeal?.title ?? '');
    final descController = TextEditingController(text: existingDeal?.description ?? '');
    final priceController = TextEditingController(
      text: existingDeal != null ? existingDeal.salePrice.toStringAsFixed(2) : '',
    );
    final limitController = TextEditingController(
      text: existingDeal?.saleLimit != null ? existingDeal!.saleLimit.toString() : '',
    );

    final Map<String, int> selectedItems = {};
    if (existingDeal != null) {
      for (final item in existingDeal.items) {
        selectedItems[item.productId] = item.quantity;
      }
    }

    final products = widget.productService.activeProducts;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double calculateOriginalTotal() {
              double total = 0;
              selectedItems.forEach((pId, qty) {
                final product = products.cast<AdminProduct?>().firstWhere(
                      (p) => p?.id == pId,
                      orElse: () => null,
                    );
                if (product != null) {
                  total += product.price * qty;
                }
              });
              return total;
            }

            int calculateMaxPossibleDeals() {
              if (selectedItems.isEmpty) return 0;
              int maxDeals = 999999;
              for (final entry in selectedItems.entries) {
                final product = products.cast<AdminProduct?>().firstWhere(
                      (p) => p?.id == entry.key,
                      orElse: () => null,
                    );
                if (product == null) continue;
                final needed = entry.value;
                if (needed <= 0) continue;
                final available = product.quantity.toInt();
                final possible = available ~/ needed;
                if (possible < maxDeals) {
                  maxDeals = possible;
                }
              }
              return maxDeals == 999999 ? 0 : maxDeals;
            }

            final maxPossibleDeals = calculateMaxPossibleDeals();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_offer_rounded, color: AppColors.primaryOrange, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                existingDeal == null ? 'Create On-Sale Promo' : 'Customize On-Sale Promo',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
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
                      const Divider(height: 24),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Promo Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.darkText)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: titleController,
                                decoration: InputDecoration(
                                  hintText: 'e.g. Merienda Bundle, Rice Special Promo',
                                  filled: true,
                                  fillColor: AppColors.lightPeach,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 16),

                              const Text('Description (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.darkText)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: descController,
                                decoration: InputDecoration(
                                  hintText: 'e.g. Save big on your daily merienda favorites!',
                                  filled: true,
                                  fillColor: AppColors.lightPeach,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 16),

                              const Text('Promo Sale Price (₱)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.darkText)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: priceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  prefixText: '₱ ',
                                  filled: true,
                                  fillColor: AppColors.lightPeach,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Sale Promo Limit (Quota) Section
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Sale Promo Limit (Max Deals to Sell)',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.darkText),
                                  ),
                                  if (selectedItems.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryOrange.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Max Stock Available: $maxPossibleDeals deals',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: limitController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: selectedItems.isEmpty
                                      ? 'Select products first to calculate limit'
                                      : 'e.g. 10 (Leave blank for unlimited up to stock)',
                                  suffixText: 'deals',
                                  helperText: selectedItems.isEmpty
                                      ? null
                                      : 'Limits promo units to prevent overselling. Cannot exceed $maxPossibleDeals deals.',
                                  helperStyle: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                  filled: true,
                                  fillColor: AppColors.lightPeach,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                              if (selectedItems.isNotEmpty && maxPossibleDeals > 0) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    for (final preset in [5, 10, 20])
                                      if (preset <= maxPossibleDeals)
                                        InkWell(
                                          onTap: () {
                                            setModalState(() {
                                              limitController.text = preset.toString();
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.lightBackground,
                                              border: Border.all(color: AppColors.borderColor),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text('$preset deals', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                          ),
                                        ),
                                    InkWell(
                                      onTap: () {
                                        setModalState(() {
                                          limitController.text = maxPossibleDeals.toString();
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryOrange.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text('Max ($maxPossibleDeals)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 20),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Select Included Products', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkText)),
                                  Text(
                                    'Regular Total: ${widget.analyticsService.formatPeso(calculateOriginalTotal())}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryOrange),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 220,
                                decoration: BoxDecoration(
                                  color: AppColors.lightBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.borderColor),
                                ),
                                child: products.isEmpty
                                    ? _inlineEmpty('No products available.')
                                    : ListView.separated(
                                        padding: const EdgeInsets.all(8),
                                        itemCount: products.length,
                                        separatorBuilder: (context, index) => const Divider(height: 10),
                                        itemBuilder: (context, idx) {
                                          final product = products[idx];
                                          final isSelected = selectedItems.containsKey(product.id);
                                          final qty = selectedItems[product.id] ?? 1;
                                          final stockInt = product.quantity.toInt();
                                          final isOutOfStock = stockInt <= 0;

                                          return Row(
                                            children: [
                                              Checkbox(
                                                value: isSelected,
                                                activeColor: AppColors.primaryOrange,
                                                onChanged: isOutOfStock
                                                    ? null
                                                    : (val) {
                                                        setModalState(() {
                                                          if (val == true) {
                                                            selectedItems[product.id] = 1;
                                                          } else {
                                                            selectedItems.remove(product.id);
                                                          }
                                                        });
                                                      },
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            product.name,
                                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkText),
                                                          ),
                                                        ),
                                                        if (isOutOfStock)
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                            decoration: BoxDecoration(
                                                              color: Colors.red.withValues(alpha: 0.1),
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: const Text('Out of Stock', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                                                          ),
                                                      ],
                                                    ),
                                                    Text(
                                                      '${widget.analyticsService.formatPeso(product.price)} · Stock: $stockInt ${product.unit}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: isOutOfStock ? Colors.red : AppColors.secondaryText,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (isSelected) ...[
                                                IconButton(
                                                  icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppColors.primaryOrange),
                                                  onPressed: () {
                                                    setModalState(() {
                                                      if (qty > 1) {
                                                        selectedItems[product.id] = qty - 1;
                                                      }
                                                    });
                                                  },
                                                ),
                                                Text('$qty', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                                IconButton(
                                                  icon: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.primaryOrange),
                                                  onPressed: () {
                                                    if (qty >= stockInt) {
                                                      TopNotification.show(
                                                        context,
                                                        'Cannot exceed available stock of $stockInt ${product.unit} for ${product.name}.',
                                                        isError: true,
                                                      );
                                                      return;
                                                    }
                                                    setModalState(() {
                                                      selectedItems[product.id] = qty + 1;
                                                    });
                                                  },
                                                ),
                                              ],
                                            ],
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              final title = titleController.text.trim();
                              final desc = descController.text.trim();
                              final salePrice = double.tryParse(priceController.text.trim()) ?? 0.0;
                              final limitStr = limitController.text.trim();

                              if (title.isEmpty) {
                                TopNotification.show(context, 'Please enter a promo title.', isError: true);
                                return;
                              }
                              if (salePrice <= 0) {
                                TopNotification.show(context, 'Please enter a valid sale price.', isError: true);
                                return;
                              }
                              if (selectedItems.isEmpty) {
                                TopNotification.show(context, 'Please select at least one product for the promo.', isError: true);
                                return;
                              }

                              for (final entry in selectedItems.entries) {
                                final p = products.cast<AdminProduct?>().firstWhere(
                                      (prod) => prod?.id == entry.key,
                                      orElse: () => null,
                                    );
                                if (p == null) continue;
                                if (entry.value > p.quantity.toInt()) {
                                  TopNotification.show(
                                    context,
                                    'Selected quantity (${entry.value}) for ${p.name} exceeds available stock (${p.quantity.toInt()} ${p.unit}).',
                                    isError: true,
                                  );
                                  return;
                                }
                              }

                              int? saleLimit;
                              if (limitStr.isNotEmpty) {
                                saleLimit = int.tryParse(limitStr);
                                if (saleLimit == null || saleLimit <= 0) {
                                  TopNotification.show(context, 'Sale limit must be a positive whole number.', isError: true);
                                  return;
                                }
                                final maxPossible = calculateMaxPossibleDeals();
                                if (saleLimit > maxPossible) {
                                  TopNotification.show(
                                    context,
                                    'Sale promo limit ($saleLimit) cannot exceed available inventory ($maxPossible deals).',
                                    isError: true,
                                  );
                                  return;
                                }
                              }

                              final List<SaleDealItem> items = [];
                              selectedItems.forEach((pId, qty) {
                                final p = products.firstWhere((prod) => prod.id == pId);
                                items.add(SaleDealItem(
                                  productId: p.id,
                                  productName: p.name,
                                  quantity: qty,
                                  originalPrice: p.price,
                                  image: p.image,
                                  unit: p.unit,
                                ));
                              });

                              final deal = SaleDealModel(
                                id: existingDeal?.id ?? 'deal-${DateTime.now().millisecondsSinceEpoch}',
                                title: title,
                                description: desc,
                                salePrice: salePrice,
                                items: items,
                                isActive: existingDeal?.isActive ?? true,
                                createdAt: existingDeal?.createdAt ?? DateTime.now(),
                                updatedAt: DateTime.now(),
                                saleLimit: saleLimit,
                                soldCount: existingDeal?.soldCount ?? 0,
                              );

                              await SaleDealController.instance.saveDeal(deal);
                              if (context.mounted) {
                                Navigator.pop(dialogCtx);
                                TopNotification.show(
                                  context,
                                  'Promo "${deal.title}" saved successfully!',
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryOrange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Save Promo', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- WEB MODAL: VIEW DEAL DETAILS ---
  void _openViewDealModal(BuildContext context, SaleDealModel deal) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          deal.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                  if (deal.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(deal.description, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                  ],
                  const Divider(height: 24),
                  const Text('Included Products', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkText)),
                  const SizedBox(height: 8),
                  for (final item in deal.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${item.quantity}x ${item.productName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          Text(widget.analyticsService.formatPeso(item.totalOriginalPrice), style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                        ],
                      ),
                    ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Regular Total:', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                      Text(widget.analyticsService.formatPeso(deal.originalTotalPrice), style: const TextStyle(fontSize: 13, decoration: TextDecoration.lineThrough, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Promo Sale Price:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkText)),
                      Text(widget.analyticsService.formatPeso(deal.salePrice), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primaryOrange)),
                    ],
                  ),
                  if (deal.discountSavings > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Savings:', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                        Text('Save ${widget.analyticsService.formatPeso(deal.discountSavings)} (${deal.discountPercentage}% OFF)', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Promo Quota Limit:', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                      Text(
                        deal.saleLimit != null ? '${deal.saleLimit} deals' : 'No Limit (Unlimited)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkText),
                      ),
                    ],
                  ),
                  if (deal.saleLimit != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Remaining Deals:', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                        Text(
                          '${deal.remainingSaleLimit} deals left',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: deal.isSoldOut ? Colors.red : Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sold Deals:', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                        Text('${deal.soldCount} deals sold', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- CONFIRM DELETE DEAL ---
  void _confirmDeleteDeal(BuildContext context, SaleDealModel deal) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Delete On-Sale Promo'),
          content: Text('Are you sure you want to delete promo "${deal.title}"? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await SaleDealController.instance.deleteDeal(deal.id);
                if (context.mounted) {
                  Navigator.pop(dialogCtx);
                  TopNotification.show(context, 'Promo "${deal.title}" deleted.');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // --- DAILY SALES CARD ---
  Widget _buildDailySalesCard() {
    final days = widget.analyticsService.salesByDay(7, referenceDate: _selectedDailyDate);
    final isTodaySelected = isSameDay(_selectedDailyDate, DateTime.now());

    return card(
      title: 'Daily sales',
      subtitle: '7 days ending on ${formatShortDate(_selectedDailyDate)}',
      trailing: _buildDateNavigationBar(
        label: '${_selectedDailyDate.day} ${_kMonths[_selectedDailyDate.month - 1]} ${_selectedDailyDate.year}',
        onPrevious: () => setState(() {
          _selectedDailyDate = _selectedDailyDate.subtract(const Duration(days: 1));
        }),
        onNext: () => setState(() {
          _selectedDailyDate = _selectedDailyDate.add(const Duration(days: 1));
        }),
        onSelectDate: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedDailyDate,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
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
            setState(() => _selectedDailyDate = picked);
          }
        },
        isCurrentPeriod: isTodaySelected,
        currentLabel: 'Today',
        onResetToday: () => setState(() => _selectedDailyDate = DateTime.now()),
      ),
      child: _buildSalesRowsList(
        rows: [
          for (final d in days.reversed)
            _PeriodRow(
              label: formatShortDate(d.day),
              isCurrent: isSameDay(d.day, _selectedDailyDate),
              total: d.total,
              orders: d.orders,
            ),
        ],
      ),
    );
  }

  // --- WEEKLY SALES CARD ---
  Widget _buildWeeklySalesCard() {
    final weeks = widget.analyticsService.salesByWeek(6, referenceDate: _selectedWeeklyDate);
    final now = DateTime.now();
    final nowMidnight = DateTime(now.year, now.month, now.day);
    final isCurrentWeekSelected = !nowMidnight.isBefore(weeks.last.weekStart) && !nowMidnight.isAfter(weeks.last.weekEnd);
    final selectedWeekStart = weeks.last.weekStart;
    final selectedWeekEnd = weeks.last.weekEnd;

    return card(
      title: 'Weekly sales',
      subtitle: '6 weeks ending on ${formatShortDate(_selectedWeeklyDate)}',
      trailing: _buildDateNavigationBar(
        label: formatWeekRange(selectedWeekStart, selectedWeekEnd),
        onPrevious: () => setState(() {
          _selectedWeeklyDate = _selectedWeeklyDate.subtract(const Duration(days: 7));
        }),
        onNext: () => setState(() {
          _selectedWeeklyDate = _selectedWeeklyDate.add(const Duration(days: 7));
        }),
        onSelectDate: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedWeeklyDate,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
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
            setState(() => _selectedWeeklyDate = picked);
          }
        },
        isCurrentPeriod: isCurrentWeekSelected,
        currentLabel: 'This Week',
        onResetToday: () => setState(() => _selectedWeeklyDate = DateTime.now()),
      ),
      child: _buildSalesRowsList(
        rows: [
          for (final w in weeks.reversed)
            _PeriodRow(
              label: formatWeekRange(w.weekStart, w.weekEnd),
              isCurrent: !DateTime(_selectedWeeklyDate.year, _selectedWeeklyDate.month, _selectedWeeklyDate.day).isBefore(w.weekStart) &&
                  !DateTime(_selectedWeeklyDate.year, _selectedWeeklyDate.month, _selectedWeeklyDate.day).isAfter(w.weekEnd),
              total: w.total,
              orders: w.orders,
            ),
        ],
      ),
    );
  }

  // --- MONTHLY SALES CARD ---
  Widget _buildMonthlySalesCard() {
    final months = widget.analyticsService.salesByMonth(6, referenceDate: _selectedMonthlyDate);
    final now = DateTime.now();
    final isCurrentMonthSelected = _selectedMonthlyDate.year == now.year && _selectedMonthlyDate.month == now.month;

    return card(
      title: 'Monthly sales',
      subtitle: '6 months ending on ${formatMonthYear(_selectedMonthlyDate.year, _selectedMonthlyDate.month)}',
      trailing: _buildDateNavigationBar(
        label: formatMonthYear(_selectedMonthlyDate.year, _selectedMonthlyDate.month),
        onPrevious: () => setState(() {
          _selectedMonthlyDate = DateTime(_selectedMonthlyDate.year, _selectedMonthlyDate.month - 1, 1);
        }),
        onNext: () => setState(() {
          _selectedMonthlyDate = DateTime(_selectedMonthlyDate.year, _selectedMonthlyDate.month + 1, 1);
        }),
        onSelectDate: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedMonthlyDate,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            initialDatePickerMode: DatePickerMode.year,
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
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
            setState(() => _selectedMonthlyDate = picked);
          }
        },
        isCurrentPeriod: isCurrentMonthSelected,
        currentLabel: 'This Month',
        onResetToday: () => setState(() => _selectedMonthlyDate = DateTime.now()),
      ),
      child: _buildSalesRowsList(
        rows: [
          for (final m in months.reversed)
            _PeriodRow(
              label: formatMonthYear(m.year, m.month),
              isCurrent: m.year == _selectedMonthlyDate.year && m.month == _selectedMonthlyDate.month,
              total: m.total,
              orders: m.orders,
            ),
        ],
      ),
    );
  }

  Widget _buildDateNavigationBar({
    required String label,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
    required VoidCallback onSelectDate,
    required bool isCurrentPeriod,
    required String currentLabel,
    required VoidCallback onResetToday,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            icon: const Icon(Icons.chevron_left, size: 20, color: AppColors.darkText),
            onPressed: onPrevious,
            tooltip: 'Previous',
          ),
          InkWell(
            onTap: onSelectDate,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 15, color: AppColors.primaryOrange),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            icon: const Icon(Icons.chevron_right, size: 20, color: AppColors.darkText),
            onPressed: onNext,
            tooltip: 'Next',
          ),
          if (!isCurrentPeriod) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onResetToday,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currentLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSalesRowsList({required List<_PeriodRow> rows}) {
    final total = rows.fold<double>(0, (sum, r) => sum + r.total);
    final totalOrders = rows.fold<int>(0, (sum, r) => sum + r.orders);
    final hasAnySales = rows.any((r) => r.total > 0);

    return !hasAnySales
        ? _inlineEmpty('No sales recorded yet in database.')
        : Column(
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: row.isCurrent
                              ? AppColors.primaryOrange
                              : Colors.transparent,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                row.isCurrent ? FontWeight.w700 : FontWeight.w500,
                            color: row.isCurrent
                                ? AppColors.darkText
                                : AppColors.secondaryText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.lightPeach,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${row.orders} orders',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 85,
                        child: Text(
                          widget.analyticsService.formatPeso(row.total),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: row.total == 0
                                ? AppColors.placeholderColor
                                : AppColors.darkText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total ($totalOrders orders)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  Text(
                    widget.analyticsService.formatPeso(total),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ],
              ),
            ],
          );
  }

  Widget _inlineEmpty(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.placeholderColor,
          ),
        ),
      ),
    );
  }

  String formatQuantity(double value, String unit) {
    final isWhole = value == value.roundToDouble();
    final text = isWhole ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
    return '$text $unit';
  }

  String formatShortDate(DateTime dt) => '${dt.day} ${_kMonths[dt.month - 1]}';

  String formatMonthYear(int year, int month) => '${_kMonths[month - 1]} $year';

  String formatWeekRange(DateTime start, DateTime end) {
    if (start.month == end.month) {
      return '${start.day}–${end.day} ${_kMonths[start.month - 1]}';
    }
    return '${start.day} ${_kMonths[start.month - 1]} – ${end.day} ${_kMonths[end.month - 1]}';
  }

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static const List<String> _kMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

/// One row in a daily/weekly/monthly sales list card.
class _PeriodRow {
  const _PeriodRow({
    required this.label,
    required this.total,
    required this.orders,
    this.isCurrent = false,
  });

  final String label;
  final double total;
  final int orders;
  final bool isCurrent;
}

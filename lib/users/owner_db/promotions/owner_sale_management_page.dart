import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:sari_sari/models/sale_deal_model.dart';
import 'package:sari_sari/core/services/sale_deal_controller.dart';
import '../../../shared/utils/top_notification.dart';
import 'owner_edit_sale_deal_page.dart';

class OwnerSaleManagementPage extends StatelessWidget {
  const OwnerSaleManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SaleDealController.instance;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Customize On-Sale Deals',
          style: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Sale Deal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _openDealEditor(context),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final deals = controller.deals;

          if (deals.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // Header Summary Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryOrange,
                      AppColors.primaryOrange.withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_offer_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${controller.activeDeals.length} Active On-Sale Promos',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Deals reflect live on customer dashboards with discounted pricing.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Deals List
              ...deals.map((deal) => _buildDealCard(context, deal, controller)),

              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_offer_outlined, color: AppColors.primaryOrange, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'No On-Sale Deals Created Yet',
              style: TextStyle(color: AppColors.darkText, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create bundles, single-item promos, or near-expiry discounts to showcase directly on the customer On-Sale feed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Create First Sale Deal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => _openDealEditor(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDealCard(BuildContext context, SaleDealModel deal, SaleDealController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: deal.isActive ? AppColors.primaryOrange.withValues(alpha: 0.3) : AppColors.borderColor,
          width: deal.isActive ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Title, Active Switch, & Actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              deal.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkText,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: deal.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              deal.isActive ? 'LIVE ON SALE' : 'PAUSED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: deal.isActive ? Colors.green[800] : Colors.grey[700],
                              ),
                            ),
                          ),
                          if (deal.isSoldOut) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'SOLD OUT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[800],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Promo Limit: ${deal.saleLimit != null ? "${deal.remainingSaleLimit} left of ${deal.saleLimit}" : "Full stock"} • ${deal.totalItemQuantity} items per deal',
                        style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                      ),
                      if (deal.soldCount > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${deal.soldCount} deal${deal.soldCount > 1 ? "s" : ""} sold at promo price',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green[800]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Inclusions summary chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: deal.items.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Text(
                    '${item.quantity}x ${item.productName}',
                    style: const TextStyle(fontSize: 12, color: AppColors.darkText, fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Pricing Row: Sale Price, Regular Total, Discount Pill
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sale Price', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                    Text(
                      '₱${deal.salePrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Regular Price', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                    Text(
                      '₱${deal.originalTotalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        decoration: TextDecoration.lineThrough,
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (deal.discountPercentage > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      '${deal.discountPercentage}% OFF',
                      style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Bottom Actions: Toggle live status, Edit button, Delete button
            Row(
              children: [
                // Active Switch
                Row(
                  children: [
                    Switch(
                      value: deal.isActive,
                      activeThumbColor: AppColors.primaryOrange,
                      onChanged: (val) async {
                        await controller.toggleDealStatus(deal.id, val);
                        if (context.mounted) {
                          TopNotification.show(
                            context,
                            val
                                ? 'Sale deal "${deal.title}" activated.'
                                : 'Sale deal "${deal.title}" deactivated.',
                          );
                        }
                      },
                    ),
                    Text(
                      deal.isActive ? 'Active' : 'Inactive',
                      style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                    ),
                  ],
                ),
                const Spacer(),

                // Edit Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkText,
                    side: const BorderSide(color: AppColors.borderColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.edit, size: 15),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                  onPressed: () => _openDealEditor(context, deal),
                ),
                const SizedBox(width: 8),

                // Delete Button
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(context, deal, controller),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openDealEditor(BuildContext context, [SaleDealModel? deal]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OwnerEditSaleDealPage(initialDeal: deal),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, SaleDealModel deal, SaleDealController controller) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sale Deal?'),
        content: Text('Are you sure you want to remove "${deal.title}"? It will no longer be visible to customers on sale.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await controller.deleteDeal(deal.id);
      if (context.mounted) {
        TopNotification.show(
          context,
          'Sale deal "${deal.title}" deleted.',
        );
      }
    }
  }
}

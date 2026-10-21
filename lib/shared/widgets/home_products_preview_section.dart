import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../users/employee_db/inventory/employee_product_model.dart';
import 'product_image.dart';

/// Clean preview section of store products and inventory displayed on Home dashboard
/// for Owner and Employee.
class HomeProductsPreviewSection extends StatelessWidget {
  const HomeProductsPreviewSection({
    super.key,
    required this.products,
    required this.isLoading,
    required this.onOpenInventory,
    required this.onSelectProduct,
  });

  final List<EmployeeProduct> products;
  final bool isLoading;
  final VoidCallback onOpenInventory;
  final ValueChanged<EmployeeProduct> onSelectProduct;

  String _formatQuantity(double qty) {
    if (qty.truncateToDouble() == qty) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final previewList = products.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Products & Stock',
                  style: TextStyle(
                    color: AppColors.darkText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (products.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${products.length}',
                      style: const TextStyle(
                        color: AppColors.primaryOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            TextButton.icon(
              onPressed: onOpenInventory,
              icon: const Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: AppColors.primaryOrange,
              ),
              label: const Text(
                'View All',
                style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: _buildBody(context, previewList),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, List<EmployeeProduct> previewList) {
    if (isLoading && products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryOrange,
          ),
        ),
      );
    }

    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.primaryOrange,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'No products in inventory yet',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add products in the inventory tab to start tracking stock.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onOpenInventory,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryOrange,
                  side: const BorderSide(color: AppColors.primaryOrange),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Go to Inventory', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < previewList.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.borderColor),
          _ProductItemTile(
            product: previewList[i],
            formattedQty: _formatQuantity(previewList[i].quantity),
            onTap: () => onSelectProduct(previewList[i]),
          ),
        ],
        if (products.length > previewList.length) ...[
          const Divider(height: 1, color: AppColors.borderColor),
          InkWell(
            onTap: onOpenInventory,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'See ${products.length - previewList.length} more in Inventory',
                    style: const TextStyle(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18, color: AppColors.primaryOrange),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProductItemTile extends StatelessWidget {
  const _ProductItemTile({
    required this.product,
    required this.formattedQty,
    required this.onTap,
  });

  final EmployeeProduct product;
  final String formattedQty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color badgeBg;
    Color badgeText;
    String badgeLabel;

    switch (product.stockStatus) {
      case EmployeeStockStatus.outOfStock:
        badgeBg = Colors.red.withValues(alpha: 0.12);
        badgeText = Colors.red.shade700;
        badgeLabel = 'Out of stock';
        break;
      case EmployeeStockStatus.lowStock:
        badgeBg = Colors.orange.withValues(alpha: 0.14);
        badgeText = Colors.orange.shade800;
        badgeLabel = 'Low: $formattedQty left';
        break;
      case EmployeeStockStatus.inStock:
        badgeBg = const Color(0xFF10B981).withValues(alpha: 0.12);
        badgeText = const Color(0xFF047857);
        badgeLabel = '$formattedQty in stock';
        break;
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 46,
                height: 46,
                child: ProductImage(
                  image: product.image,
                  width: 46,
                  height: 46,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product.category.isNotEmpty ? product.category : 'General',
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₱ ${product.currentPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      color: badgeText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.secondaryText.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

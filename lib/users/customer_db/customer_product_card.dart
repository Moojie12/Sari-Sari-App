import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'customer_product_model.dart';

/// Product card used in both the "Featured Products" horizontal list and
/// the "All Products" grid on the customer Home page.
///
/// Sizing is controlled by the parent (wrap in a `SizedBox` for a
/// fixed-width horizontal list, or let a `GridView`/`SliverGrid` size it)
/// so this widget stays reusable in both layouts.
class CustomerProductCard extends StatelessWidget {
  const CustomerProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAddToCart,
  });

  final CustomerProduct product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = product.isOutOfStock;

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.borderColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _CustomerProductImagePlaceholder(isOutOfStock: isOutOfStock),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₱${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _AvailabilityLabel(availability: product.availability),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: ElevatedButton(
                      onPressed: isOutOfStock ? null : onAddToCart,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        disabledBackgroundColor:
                            AppColors.borderColor.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!isOutOfStock)
                            const Icon(Icons.add_shopping_cart, size: 14),
                          if (!isOutOfStock) const SizedBox(width: 4),
                          Text(
                            isOutOfStock ? 'Unavailable' : 'Add',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerProductImagePlaceholder extends StatelessWidget {
  const _CustomerProductImagePlaceholder({required this.isOutOfStock});

  final bool isOutOfStock;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primaryOrange.withValues(alpha: 0.05),
      alignment: Alignment.center,
      child: Opacity(
        opacity: isOutOfStock ? 0.4 : 1,
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: AppColors.primaryOrange.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _AvailabilityLabel extends StatelessWidget {
  const _AvailabilityLabel({required this.availability});

  final CustomerProductAvailability availability;

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    switch (availability) {
      case CustomerProductAvailability.inStock:
        dotColor = Colors.green;
        break;
      case CustomerProductAvailability.lowStock:
        dotColor = Colors.orange;
        break;
      case CustomerProductAvailability.outOfStock:
        dotColor = Colors.red;
        break;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          availability.label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: dotColor),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'customer_product_model.dart';

/// Product card used in both the "On Sale Products" horizontal list and
/// the "All Products" grid on the customer Home page.
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
              child:
              _CustomerProductImagePlaceholder(isOutOfStock: isOutOfStock),
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
                  if (isOutOfStock)
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          disabledBackgroundColor:
                          AppColors.borderColor.withValues(alpha: 0.5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Unavailable',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 34,
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: onTap,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: AppColors.primaryOrange,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Purchase',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 34,
                            child: OutlinedButton(
                              onPressed: onAddToCart,
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                foregroundColor: AppColors.primaryOrange,
                                side: BorderSide(
                                  color: AppColors.primaryOrange,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Icon(
                                Icons.add_shopping_cart,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
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
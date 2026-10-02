import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/product_image.dart';
import 'customer_product_model.dart';

/// Product card used in both the "On Sale Products" horizontal list and
/// the "All Products" grid on the customer Home page.
class CustomerProductCard extends StatelessWidget {
  const CustomerProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAddToCart,
    this.onAddToCartWithPosition,
    this.addToCartKey,
  });

  final CustomerProduct product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;
  final Function(Offset position)? onAddToCartWithPosition;
  final Key? addToCartKey;

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
        child: SizedBox(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _CustomerProductImagePlaceholder(
                  isOutOfStock: isOutOfStock,
                  image: product.image,
                  isOnSale: product.isOnSale,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
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
                    const SizedBox(height: 8),
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
                            'Out of Stock',
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
                              child: Builder(
                                builder: (btnContext) {
                                  return OutlinedButton(
                                    key: addToCartKey,
                                    onPressed: () {
                                      final box = btnContext.findRenderObject() as RenderBox?;
                                      final pos = box != null
                                          ? box.localToGlobal(box.size.center(Offset.zero))
                                          : const Offset(200, 400);
                                      if (onAddToCartWithPosition != null) {
                                        onAddToCartWithPosition!(pos);
                                      } else {
                                        onAddToCart();
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      foregroundColor: AppColors.primaryOrange,
                                      side: const BorderSide(
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
                                  );
                                },
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
      ),
    );
  }
}

class _CustomerProductImagePlaceholder extends StatelessWidget {
  const _CustomerProductImagePlaceholder({
    required this.isOutOfStock,
    this.image,
    this.isOnSale = false,
  });

  final bool isOutOfStock;
  final String? image;
  final bool isOnSale;

  @override
  Widget build(BuildContext context) {
    final hasImage = image != null && image!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: BoxDecoration(
        color: AppColors.primaryOrange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            ProductImage(
              image: image,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            )
          else
            Opacity(
              opacity: isOutOfStock ? 0.4 : 1,
              child: Icon(
                Icons.image_outlined,
                size: 32,
                color: AppColors.primaryOrange.withValues(alpha: 0.4),
              ),
            ),
          if (isOnSale)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SALE',
                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

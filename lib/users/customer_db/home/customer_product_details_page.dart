import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../customer_cart_controller.dart';
import '../purchases/customer_order_controller.dart';
import '../checkout/customer_checkout_page.dart';
import 'customer_product_model.dart';

/// Full-screen product details page.
class CustomerProductDetailsPage extends StatefulWidget {
  const CustomerProductDetailsPage({
    super.key,
    required this.product,
    required this.cartController,
    required this.orderController,
  });

  final CustomerProduct product;
  final CustomerCartController cartController;
  final CustomerOrderController orderController;

  @override
  State<CustomerProductDetailsPage> createState() =>
      _CustomerProductDetailsPageState();
}

class _CustomerProductDetailsPageState
    extends State<CustomerProductDetailsPage> {
  int _quantity = 1;

  bool get _isOutOfStock => widget.product.isOutOfStock;

  void _incrementQuantity() => setState(() => _quantity++);

  void _decrementQuantity() {
    if (_quantity <= 1) return;
    setState(() => _quantity--);
  }

  void _handleAddToCart() {
    final added =
    widget.cartController.addToCart(widget.product, quantity: _quantity);
    if (!added) return;
    TopNotification.show(context, 'Added to cart');
  }

  void _handleBuyNow() {
    // Direct purchase: checkout reads from cartController.items, so make
    // sure only this product (at the chosen quantity) is in the cart
    // before handing off to checkout.
    widget.cartController.clearCart();
    final added =
    widget.cartController.addToCart(widget.product, quantity: _quantity);
    if (!added) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerCheckoutPage(
          cartController: widget.cartController,
          orderController: widget.orderController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Product Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primaryOrange,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.borderColor.withValues(alpha: 0.5),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: _isOutOfStock ? 0.4 : 1,
                    child: Icon(
                      Icons.image_outlined,
                      size: 80,
                      color: AppColors.primaryOrange.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                product.name,
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _DetailRow(label: 'Category', value: product.category),
              const SizedBox(height: 8),
              _DetailRow(
                label: 'Price',
                value: '₱${product.price.toStringAsFixed(2)}',
                valueStyle: const TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _DetailRow(
                label: 'Availability',
                value: product.availability.label,
              ),
              const SizedBox(height: 32),
              const Text(
                'Quantity',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _QuantitySelector(
                quantity: _quantity,
                enabled: !_isOutOfStock,
                onDecrement: _decrementQuantity,
                onIncrement: _incrementQuantity,
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _isOutOfStock ? null : _handleAddToCart,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryOrange,
                          side: const BorderSide(color: AppColors.primaryOrange),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.add_shopping_cart, size: 20),
                        label: const Text(
                          'Add to Cart',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isOutOfStock ? null : _handleBuyNow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          disabledBackgroundColor:
                          AppColors.borderColor.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                        label: Text(
                          _isOutOfStock ? 'Out of Stock' : 'Buy Now',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: AppColors.secondaryText.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: valueStyle ??
              const TextStyle(
                color: AppColors.darkText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.quantity,
    required this.enabled,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final bool enabled;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuantityButton(
          icon: Icons.remove,
          onPressed: enabled ? onDecrement : null,
        ),
        Flexible(
          child: SizedBox(
            width: 60,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.darkText,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        _QuantityButton(
          icon: Icons.add,
          onPressed: enabled ? onIncrement : null,
        ),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: AppColors.borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 20,
            color: onPressed == null
                ? AppColors.placeholderColor
                : AppColors.primaryOrange,
          ),
        ),
      ),
    );
  }
}
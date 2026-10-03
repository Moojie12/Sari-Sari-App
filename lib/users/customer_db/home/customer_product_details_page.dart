import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/product_image.dart';
import '../cart/customer_cart_page.dart';
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
    this.showActions = true,
  });

  final CustomerProduct product;
  final CustomerCartController cartController;
  final CustomerOrderController orderController;
  final bool showActions;

  @override
  State<CustomerProductDetailsPage> createState() =>
      _CustomerProductDetailsPageState();
}

class _CustomerProductDetailsPageState
    extends State<CustomerProductDetailsPage> with TickerProviderStateMixin {
  int _quantity = 1;
  late final TextEditingController _quantityController;
  late final FocusNode _quantityFocusNode;

  final GlobalKey _cartBadgeKey = GlobalKey();
  late AnimationController _cartPulseController;
  late Animation<double> _cartScaleAnimation;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '$_quantity');
    _quantityFocusNode = FocusNode();
    _quantityFocusNode.addListener(_onFocusChange);

    _cartPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _cartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.25), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.25, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _cartPulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _cartPulseController.dispose();
    _quantityFocusNode.removeListener(_onFocusChange);
    _quantityFocusNode.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _runFlyToCartAnimation({
    required Offset startOffset,
    String? productImage,
  }) {
    final RenderBox? cartBox = _cartBadgeKey.currentContext?.findRenderObject() as RenderBox?;
    if (cartBox == null) return;

    final Offset endOffset = cartBox.localToGlobal(cartBox.size.center(Offset.zero));
    final OverlayState? overlayState = Overlay.of(context);
    if (overlayState == null) return;

    late OverlayEntry overlayEntry;
    final AnimationController flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    final Animation<double> progress = CurvedAnimation(
      parent: flyController,
      curve: Curves.easeInOutCubic,
    );

    overlayEntry = OverlayEntry(
      builder: (context) {
        return AnimatedBuilder(
          animation: progress,
          builder: (context, child) {
            final t = progress.value;

            // Curved arc upwards
            final controlPoint = Offset(
              (startOffset.dx + endOffset.dx) / 2,
              startOffset.dy - 120,
            );

            final currentX = (1 - t) * (1 - t) * startOffset.dx +
                2 * (1 - t) * t * controlPoint.dx +
                t * t * endOffset.dx;
            final currentY = (1 - t) * (1 - t) * startOffset.dy +
                2 * (1 - t) * t * controlPoint.dy +
                t * t * endOffset.dy;

            final scale = (1.0 - (t * 0.4));
            final opacity = (t > 0.85) ? (1.0 - (t - 0.85) / 0.15) : 1.0;

            return Positioned(
              left: currentX - 22,
              top: currentY - 22,
              child: IgnorePointer(
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryOrange.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: productImage != null && productImage.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: ProductImage(
                                  image: productImage,
                                  width: 40,
                                  height: 40,
                                ),
                              )
                            : const Icon(
                                Icons.shopping_bag_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    overlayState.insert(overlayEntry);

    flyController.forward().then((_) {
      overlayEntry.remove();
      flyController.dispose();
      _cartPulseController.forward(from: 0.0);
    });
  }

  void _onFocusChange() {
    if (!_quantityFocusNode.hasFocus) {
      if (_quantityController.text.isEmpty ||
          int.tryParse(_quantityController.text) == null) {
        _quantityController.text = '$_quantity';
      }
    }
  }

  bool get _isOutOfStock => widget.product.isOutOfStock;

  bool get _isLowStock =>
      widget.product.availability == CustomerProductAvailability.lowStock;

  double get _subtotal => widget.product.price * _quantity;

  void _incrementQuantity() {
    final maxStock = widget.product.sellableQuantity.toInt();
    if (_quantity >= maxStock) return;
    setState(() {
      _quantity++;
      _quantityController.text = '$_quantity';
    });
  }

  void _decrementQuantity() {
    if (_quantity <= 1) return;
    setState(() {
      _quantity--;
      _quantityController.text = '$_quantity';
    });
  }

  void _onQuantityChanged(String value) {
    if (value.isEmpty) {
      setState(() {
        _quantity = 1;
      });
      return;
    }
    final parsed = int.tryParse(value);
    if (parsed != null) {
      final maxStock = widget.product.sellableQuantity.toInt();
      int clamped = parsed;
      if (clamped < 1) clamped = 1;
      if (clamped > maxStock && maxStock > 0) clamped = maxStock;

      if (clamped != parsed) {
        _quantityController.value = TextEditingValue(
          text: '$clamped',
          selection: TextSelection.collapsed(offset: '$clamped'.length),
        );
      }
      setState(() {
        _quantity = clamped;
      });
    }
  }

  void _handleAddToCart([Offset? startPosition]) {
    final added =
    widget.cartController.addToCart(widget.product, quantity: _quantity);
    if (!added) return;
    final pos = startPosition ?? Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height - 80);
    _runFlyToCartAnimation(
      startOffset: pos,
      productImage: widget.product.image,
    );
  }

  void _handleBuyNow() {
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
        actions: [
          ScaleTransition(
            scale: _cartScaleAnimation,
            child: KeyedSubtree(
              key: _cartBadgeKey,
              child: ListenableBuilder(
                listenable: widget.cartController,
                builder: (context, _) {
                  final count = widget.cartController.itemCount;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CustomerCartPage(
                                cartController: widget.cartController,
                                orderController: widget.orderController,
                              ),
                            ),
                          );
                        },
                      ),
                      if (count > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              count > 99 ? '99+' : '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
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
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      child: product.image.trim().isNotEmpty
                          ? ProductImage(
                              image: product.image,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              borderRadius: 20,
                            )
                          : Opacity(
                              opacity: _isOutOfStock ? 0.4 : 1,
                              child: Icon(
                                Icons.image_outlined,
                                size: 80,
                                color: AppColors.primaryOrange.withValues(alpha: 0.3),
                              ),
                            ),
                    ),
                  ),
                  if (product.isFeatured && !_isOutOfStock)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _Badge(
                        label: 'Featured',
                        color: AppColors.primaryOrange,
                        icon: Icons.star_rounded,
                      ),
                    ),
                  if (_isOutOfStock)
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.darkText.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'OUT OF STOCK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                product.name,
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (_isLowStock)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'Low stock — order soon',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _QuantityCard(
                quantity: _quantity,
                enabled: !_isOutOfStock,
                enabledQuantity: widget.product.sellableQuantity,
                subtotal: _subtotal,
                onDecrement: _decrementQuantity,
                onIncrement: _incrementQuantity,
                controller: _quantityController,
                focusNode: _quantityFocusNode,
                onChanged: _onQuantityChanged,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: widget.showActions
              ? Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: Builder(
                          builder: (btnContext) {
                            return OutlinedButton.icon(
                              onPressed: _isOutOfStock
                                  ? null
                                  : () {
                                      final box = btnContext.findRenderObject() as RenderBox?;
                                      final pos = box != null
                                          ? box.localToGlobal(box.size.center(Offset.zero))
                                          : null;
                                      _handleAddToCart(pos);
                                    },
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
                            );
                          },
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
                )
              : SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered quantity stepper card with a live subtotal and direct input.
class _QuantityCard extends StatelessWidget {
  const _QuantityCard({
    required this.quantity,
    required this.enabled,
    required this.enabledQuantity,
    required this.subtotal,
    required this.onDecrement,
    required this.onIncrement,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final int quantity;
  final bool enabled;
  final double enabledQuantity;
  final double subtotal;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final maxAvailable = quantity >= enabledQuantity.toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Text(
            'Quantity',
            style: TextStyle(
              color: AppColors.darkText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.lightPeach.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QuantityButton(
                  icon: Icons.remove,
                  onPressed: enabled && quantity > 1 ? onDecrement : null,
                ),
                SizedBox(
                  width: 64,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                    ),
                    onChanged: onChanged,
                  ),
                ),
                _QuantityButton(
                  icon: Icons.add,
                  onPressed: enabled && !maxAvailable ? onIncrement : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            maxAvailable ? 'Maximum quantity reached' : 'Only ${enabledQuantity.toInt()} items available',
            style: TextStyle(
              color: maxAvailable
                  ? AppColors.primaryOrange
                  : AppColors.secondaryText.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: maxAvailable ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: AppColors.borderColor.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtotal',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '₱${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import 'package:sari_sari/models/sale_deal_model.dart';
import 'package:sari_sari/core/services/sale_deal_controller.dart';
import '../../../shared/utils/top_notification.dart';
import '../../../shared/widgets/barcode_scanner_screen.dart';
import '../../../shared/utils/gcash_ocr_helper.dart';
import 'package:sari_sari/core/services/ocr_service.dart';
import '../../owner_db/profile/shop_settings_controller.dart';
import '../employee_inventory_controller.dart';
import '../inventory/employee_product_model.dart';
import '../profile/employee_profile_controller.dart';
import 'employee_pos_controller.dart';
import 'employee_receipt_page.dart';
import 'employee_batch_selection_sheet.dart';
import 'employee_shift_controller.dart';
import 'employee_shift_widgets.dart';
import '../../../shared/widgets/product_image.dart';

/// Employee "POS" tab: ring up a walk-in sale.
///
/// Staff search (or scan a barcode) for a product to add it to the
/// current sale, review the running cart at the bottom, then checkout to
/// record payment — which deducts the sold quantities from inventory
/// (POS and Sales Management feature).
class EmployeePosPage extends StatefulWidget {
  const EmployeePosPage({
    super.key,
    required this.inventory,
    required this.posController,
  });

  final EmployeeInventoryController inventory;
  final EmployeePosController posController;

  @override
  State<EmployeePosPage> createState() => _EmployeePosPageState();
}

class _EmployeePosPageState extends State<EmployeePosPage> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final GlobalKey _cartBadgeKey = GlobalKey();
  late AnimationController _cartPulseController;
  late Animation<double> _cartScaleAnimation;

  @override
  void initState() {
    super.initState();
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
    _searchController.dispose();
    super.dispose();
  }

  List<EmployeeProduct> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    return widget.inventory.products.where((product) {
      final matchesCategory = _selectedCategory == 'All'
          ? true
          : (_selectedCategory == 'On Sale 🔥'
              ? product.hasExpiringSoonBatch
              : product.category == _selectedCategory);
      final matchesSearch = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.barcode.contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _addSaleDealToCart(SaleDealModel deal, [Offset? startPos]) {
    String? errorMsg;
    final success = widget.posController.addSaleDealToCart(
      deal,
      onError: (err) => errorMsg = err,
    );

    if (success) {
      if (startPos != null) {
        _runFlyToCartAnimation(startOffset: startPos, productImage: deal.effectiveImage);
      }
      TopNotification.show(
        context,
        'Promo "${deal.title}" added to sale!',
      );
    } else {
      TopNotification.show(
        context,
        errorMsg ?? 'Failed to add promo deal.',
        isError: true,
      );
    }
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

  void _addToCart(EmployeeProduct product, [Offset? startPosition]) {
    if (product.stockStatus == EmployeeStockStatus.outOfStock) {
      TopNotification.show(context, 'This product is out of stock.', isError: true);
      return;
    }

    final pos = startPosition ?? const Offset(200, 400);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EmployeeBatchSelectionSheet(
        product: product,
        onConfirm: (batch, quantity) {
          widget.posController.addBatchToCart(product, batch, quantity: quantity);
          _runFlyToCartAnimation(
            startOffset: pos,
            productImage: product.image,
          );
        },
      ),
    );
  }

  Future<void> _openBarcodeScanner() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );
    if (code == null || code.isEmpty) return;

    final product = widget.inventory.findByBarcode(code);
    if (product != null) {
      _addToCart(product);
    } else {
      if (!mounted) return;
      TopNotification.show(context, 'No product found for barcode "$code".', isError: true);
    }
  }

  void _openCheckout() {
    if (widget.posController.cart.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CheckoutSheet(
        posController: widget.posController,
        onCompleted: (receipt) {
          Navigator.pop(context); // close the checkout sheet
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmployeeReceiptPage(receipt: receipt),
            ),
          );
        },
      ),
    );
  }

  void _showCartDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CartDetailsSheet(
        posController: widget.posController,
        onCheckout: _openCheckout,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            widget.inventory,
            widget.posController,
            EmployeeShiftController.instance,
            SaleDealController.instance,
          ]),
          builder: (context, _) {
            if (!EmployeeShiftController.instance.isShiftOpen) {
              return Column(
                children: [
                  _buildHeader(),
                  const Expanded(child: EmployeeStartShiftView()),
                ],
              );
            }

            final query = _searchQuery.trim().toLowerCase();
            final showDeals = _selectedCategory == 'All' || _selectedCategory == 'On Sale 🔥';
            final activeDeals = showDeals
                ? SaleDealController.instance.activeDeals.where((d) {
                    return query.isEmpty || d.title.toLowerCase().contains(query);
                  }).toList()
                : <SaleDealModel>[];

            final products = _filteredProducts;
            final totalCount = activeDeals.length + products.length;

            return Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildCategories(),
                const SizedBox(height: 8),
                Expanded(
                  child: totalCount == 0
                      ? _buildEmptyState()
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: totalCount,
                          itemBuilder: (context, index) {
                            if (index < activeDeals.length) {
                              final deal = activeDeals[index];
                              return _PosSaleDealCard(
                                deal: deal,
                                onTapWithPosition: (pos) => _addSaleDealToCart(deal, pos),
                              );
                            }

                            final product = products[index - activeDeals.length];
                            return _PosProductCard(
                              product: product,
                              onTapWithPosition: (pos) => _addToCart(product, pos),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final shift = EmployeeShiftController.instance.currentShift;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Point of Sale',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildCartSummary(),
            ],
          ),
          if (shift != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shift ${shift.id} · Cash in Drawer',
                          style: const TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₱${shift.expectedCash.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppColors.darkText,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Float ₱${shift.startingFloat.toStringAsFixed(2)}'
                              ' + Cash Sales ₱${shift.cashSalesTotal.toStringAsFixed(2)}'
                              '${shift.nonCashSalesTotal > 0 ? ' + GCash ₱${shift.nonCashSalesTotal.toStringAsFixed(2)}' : ''}'
                              '${shift.netAdjustments != 0 ? ' ${shift.netAdjustments >= 0 ? '+' : '-'} Adj ₱${shift.netAdjustments.abs().toStringAsFixed(2)}' : ''}',
                          style: TextStyle(
                            color: AppColors.secondaryText.withValues(alpha: 0.8),
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _HeaderIconButton(
                    icon: Icons.swap_horiz_rounded,
                    tooltip: 'Cash Adjustment',
                    onTap: () => showCashAdjustmentSheet(context),
                  ),
                  const SizedBox(width: 8),
                  _HeaderIconButton(
                    icon: Icons.logout_rounded,
                    tooltip: 'End Shift',
                    onTap: () => showEndShiftSheet(context),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartSummary() {
    final itemCount = widget.posController.itemCount;
    final totalAmount = widget.posController.totalAmount;

    return ScaleTransition(
      scale: _cartScaleAnimation,
      child: Material(
        key: _cartBadgeKey,
        color: itemCount > 0 ? AppColors.primaryOrange : AppColors.primaryOrange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _showCartDetails,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$itemCount item(s)',
                  style: TextStyle(
                    color: itemCount > 0 ? Colors.white : AppColors.darkText,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '₱${totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: itemCount > 0 ? Colors.white : AppColors.primaryOrange,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search or scan barcode...',
          hintStyle: TextStyle(
            color: AppColors.secondaryText.withValues(alpha: 0.5),
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText),
          suffixIcon: IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.primaryOrange),
            onPressed: _openBarcodeScanner,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
            BorderSide(color: AppColors.borderColor.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    final rawCategories = widget.inventory.categories;
    final categories = <String>[];
    if (rawCategories.isNotEmpty) {
      categories.add(rawCategories.first); // 'All'
      categories.add('On Sale 🔥');
      categories.addAll(rawCategories.skip(1));
    } else {
      categories.addAll(['All', 'On Sale 🔥']);
    }

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == _selectedCategory;
          return ChoiceChip(
            label: Text(category),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => setState(() => _selectedCategory = category),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppColors.secondaryText,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
            selectedColor: AppColors.primaryOrange,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected
                    ? AppColors.primaryOrange
                    : AppColors.borderColor.withValues(alpha: 0.5),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off,
              size: 40, color: AppColors.secondaryText.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('No products found',
              style: TextStyle(
                  color: AppColors.secondaryText.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppColors.borderColor.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: AppColors.primaryOrange),
          ),
        ),
      ),
    );
  }
}

class _PosSaleDealCard extends StatefulWidget {
  const _PosSaleDealCard({
    required this.deal,
    required this.onTapWithPosition,
  });

  final SaleDealModel deal;
  final Function(Offset position) onTapWithPosition;

  @override
  State<_PosSaleDealCard> createState() => _PosSaleDealCardState();
}

class _PosSaleDealCardState extends State<_PosSaleDealCard> {
  Offset? _tapPosition;

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    final totalOriginal = deal.items.fold(0.0, (sum, i) => sum + i.totalOriginalPrice);
    final itemsSummary = deal.items.map((i) => '${i.quantity}x ${i.productName}').join(', ');

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (details) {
          _tapPosition = details.globalPosition;
        },
        child: InkWell(
          onTap: () {
            final pos = _tapPosition ?? const Offset(200, 400);
            widget.onTapWithPosition(pos);
          },
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: ProductImage(
                          image: deal.effectiveImage,
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: 10,
                          fallbackIcon: Icons.local_offer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      deal.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      itemsSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '₱${deal.salePrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (totalOriginal > deal.salePrice) ...[
                          const SizedBox(width: 6),
                          Text(
                            '₱${totalOriginal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_offer, color: Colors.white, size: 10),
                      SizedBox(width: 4),
                      Text(
                        'PROMO DEAL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosProductCard extends StatefulWidget {
  const _PosProductCard({
    required this.product,
    required this.onTapWithPosition,
  });

  final EmployeeProduct product;
  final Function(Offset position) onTapWithPosition;

  @override
  State<_PosProductCard> createState() => _PosProductCardState();
}

class _PosProductCardState extends State<_PosProductCard> {
  Offset? _tapPosition;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isOut = product.stockStatus == EmployeeStockStatus.outOfStock;
    final originalPrice = product.price;
    final currentPrice = product.currentPrice;
    final isOnSale = currentPrice < originalPrice;

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderColor.withValues(alpha: 0.5)),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (details) {
          _tapPosition = details.globalPosition;
        },
        child: InkWell(
          onTap: isOut
              ? null
              : () {
                  final pos = _tapPosition ?? const Offset(200, 400);
                  widget.onTapWithPosition(pos);
                },
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Opacity(
                          opacity: isOut ? 0.4 : 1,
                          child: ProductImage(
                            image: product.image,
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                    Row(
                      children: [
                        Text(
                          '₱${currentPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isOnSale) ...[
                          const SizedBox(width: 4),
                          Text(
                            '₱${originalPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppColors.secondaryText.withValues(alpha: 0.5),
                              fontSize: 10,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOut
                          ? 'Out of stock'
                          : '${product.isWeightBased ? product.quantity.toStringAsFixed(2) : product.quantity.toStringAsFixed(0)} ${product.isWeightBased ? 'kg' : 'pcs'} in stock',
                      style: TextStyle(
                        fontSize: 11,
                        color: isOut
                            ? Colors.red
                            : (product.stockStatus == EmployeeStockStatus.lowStock
                                ? Colors.orange
                                : AppColors.secondaryText),
                      ),
                    ),
                  ],
                ),
              ),
              if (isOnSale && !isOut)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SALE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detailed cart view shown in a bottom sheet when clicking the top-right
/// summary. Allows staff to adjust quantities or remove items before
/// proceeding to checkout.
class _CartDetailsSheet extends StatelessWidget {
  const _CartDetailsSheet({
    required this.posController,
    required this.onCheckout,
  });

  final EmployeePosController posController;
  final VoidCallback onCheckout;

  void _confirmClearAll(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Are you sure you want to remove all items from the cart?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      posController.voidTransaction();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: posController,
        builder: (context, _) {
          final itemCount = posController.itemCount;
          final totalAmount = posController.totalAmount;

          // If cart becomes empty while sheet is open (staff removed all items),
          // close the sheet.
          if (posController.cart.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(context)) Navigator.pop(context);
            });
            return const SizedBox.shrink();
          }

          return Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Cart Details',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText)),
                    TextButton(
                      onPressed: () => _confirmClearAll(context),
                      style: TextButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.zero),
                      child: const Text('Clear All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('$itemCount item(s) in cart',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.borderColor),
                Flexible(
                  child: _CartItemsList(posController: posController),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.borderColor),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount', style: TextStyle(color: AppColors.secondaryText)),
                    Text(
                      '₱${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onCheckout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Proceed to Checkout',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        }
    );
  }
}

/// Scrollable list of every product currently added to the cart.
class _CartItemsList extends StatelessWidget {
  const _CartItemsList({required this.posController});

  final EmployeePosController posController;

  void _confirmRemove(BuildContext context, EmployeePosCartItem item) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text('Remove "${item.product.name}" from the cart?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      posController.removeFromCart(item.product.id, item.batchId);
      if (context.mounted) {
        TopNotification.show(context, 'Item removed from cart');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = posController.cart;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      shrinkWrap: true,
      itemCount: cart.length,
      separatorBuilder: (context, index) =>
      const Divider(height: 16, color: AppColors.borderColor),
      itemBuilder: (context, index) {
        final item = cart[index];
        final maxStock = posController.getAvailableStock(item.product.id, item.batchId);
        return _CartItemTile(
          item: item,
          maxStock: maxStock,
          onIncrement: () =>
              posController.incrementQuantity(item.product.id, item.batchId),
          onDecrement: () =>
              posController.decrementQuantity(item.product.id, item.batchId),
          onQuantityChanged: (newQty) =>
              posController.updateQuantity(item.product.id, item.batchId, newQty),
          onRemove: () => _confirmRemove(context, item),
        );
      },
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.maxStock,
    required this.onIncrement,
    required this.onDecrement,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final EmployeePosCartItem item;
  final double maxStock;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ValueChanged<double> onQuantityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.product.name,
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
                '₱${item.unitPrice.toStringAsFixed(2)} / ${item.product.isWeightBased ? 'kg' : 'pc'}',
                style: const TextStyle(
                    color: AppColors.secondaryText, fontSize: 11),
              ),
            ],
          ),
        ),
        _QuantityStepper(
          quantity: item.quantity,
          isWeightBased: item.product.isWeightBased,
          maxQuantity: maxStock,
          onIncrement: onIncrement,
          onDecrement: onDecrement,
          onQuantityChanged: onQuantityChanged,
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 64,
          child: Text(
            '₱${item.subtotal.toStringAsFixed(2)}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.darkText,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: onRemove,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.close, size: 18, color: AppColors.secondaryText),
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatefulWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.isWeightBased,
    required this.maxQuantity,
    required this.onIncrement,
    required this.onDecrement,
    required this.onQuantityChanged,
  });

  final double quantity;
  final bool isWeightBased;
  final double maxQuantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ValueChanged<double> onQuantityChanged;

  @override
  State<_QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<_QuantityStepper> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatQuantity(widget.quantity));
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _QuantityStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quantity != widget.quantity && !_focusNode.hasFocus) {
      _controller.text = _formatQuantity(widget.quantity);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _formatQuantity(double q) {
    if (widget.isWeightBased) {
      return q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);
    } else {
      return q.toInt().toString();
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _validateAndSubmit();
    }
  }

  void _validateAndSubmit() {
    final text = _controller.text.trim();
    final parsed = double.tryParse(text);
    if (parsed == null || parsed <= 0) {
      _controller.text = _formatQuantity(widget.quantity);
      return;
    }

    if (parsed > widget.maxQuantity) {
      final unitStr = widget.isWeightBased ? 'kg' : 'pcs';
      final maxStr = widget.isWeightBased
          ? widget.maxQuantity.toStringAsFixed(2)
          : widget.maxQuantity.toInt().toString();
      TopNotification.show(context, 'Only $maxStr $unitStr available in stock.', isError: true);
      _controller.text = _formatQuantity(widget.quantity);
      return;
    }

    if (!widget.isWeightBased && parsed != parsed.roundToDouble()) {
      TopNotification.show(context, 'Regular products must use whole numbers.', isError: true);
      _controller.text = _formatQuantity(widget.quantity);
      return;
    }

    widget.onQuantityChanged(parsed);
    _controller.text = _formatQuantity(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isWeightBased) ...[
          Tooltip(
            message: 'Arduino Weighing Scale',
            child: InkWell(
              onTap: () {
                TopNotification.show(context, 'Arduino Scale: Reading weight...');
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.lightPeach,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.scale, size: 14, color: AppColors.primaryOrange),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        _StepperButton(icon: Icons.remove, onTap: widget.onDecrement),
        const SizedBox(width: 4),
        SizedBox(
          width: widget.isWeightBased ? 56 : 42,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.numberWithOptions(decimal: widget.isWeightBased),
            inputFormatters: [
              if (widget.isWeightBased)
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              else
                FilteringTextInputFormatter.digitsOnly,
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.darkText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.primaryOrange),
              ),
            ),
            onChanged: (val) {
              final text = val.trim();
              if (text.isEmpty) return;
              final parsed = double.tryParse(text);
              if (parsed != null && parsed > 0) {
                if (parsed > widget.maxQuantity) {
                  final unitStr = widget.isWeightBased ? 'kg' : 'pcs';
                  final maxStr = widget.isWeightBased
                      ? widget.maxQuantity.toStringAsFixed(2)
                      : widget.maxQuantity.toInt().toString();
                  TopNotification.show(context, 'Only $maxStr $unitStr available in stock.', isError: true);
                  return;
                }
                if (!widget.isWeightBased && parsed != parsed.roundToDouble()) {
                  return;
                }
                widget.onQuantityChanged(parsed);
              }
            },
            onSubmitted: (_) => _validateAndSubmit(),
          ),
        ),
        const SizedBox(width: 4),
        _StepperButton(icon: Icons.add, onTap: widget.onIncrement),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.lightPeach,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: AppColors.primaryOrange),
      ),
    );
  }
}

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet({required this.posController, required this.onCompleted});
  final EmployeePosController posController;
  final ValueChanged<EmployeeReceipt> onCompleted;

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  EmployeePaymentMethod _method = EmployeePaymentMethod.cash;
  final _amountController = TextEditingController();
  String? _amountErrorText;
  String? _scannedRefNumber;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.posController.totalAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final total = widget.posController.totalAmount;
    final trimmedText = _amountController.text.trim();

    if (trimmedText.isEmpty) {
      setState(() => _amountErrorText = 'Please enter the amount received.');
      TopNotification.show(context, 'Please enter the amount received.', isError: true);
      return;
    }

    if (trimmedText.contains(' ')) {
      setState(() => _amountErrorText = 'Spaces are not allowed in amount.');
      TopNotification.show(context, 'Spaces are not allowed in amount.', isError: true);
      return;
    }

    final amountPaid = double.tryParse(trimmedText);
    if (amountPaid == null) {
      setState(() => _amountErrorText = 'Please enter a valid amount.');
      TopNotification.show(context, 'Please enter a valid amount.', isError: true);
      return;
    }

    if (amountPaid <= 0) {
      setState(() => _amountErrorText = 'Amount received must be greater than zero.');
      TopNotification.show(context, 'Amount received must be greater than zero.', isError: true);
      return;
    }

    if (amountPaid < total) {
      setState(() => _amountErrorText = 'Amount received is less than total due (₱${total.toStringAsFixed(2)}).');
      TopNotification.show(context, 'Amount received is less than the total.', isError: true);
      return;
    }

    setState(() => _amountErrorText = null);

    if (_method == EmployeePaymentMethod.gCash && (_scannedRefNumber == null || _scannedRefNumber!.trim().isEmpty)) {
      final proceedWithoutRef = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('No GCash Ref No. Scanned', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'You have not scanned or entered a GCash reference number.\n\nDo you want to proceed without a reference number?',
            style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Scan/Enter Ref #'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Proceed Anyway'),
            ),
          ],
        ),
      );

      if (proceedWithoutRef != true) return;
    }

    final change = amountPaid - total;
    final methodName = _method == EmployeePaymentMethod.cash ? 'Cash' : 'GCash';

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Payment',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to proceed with this payment?',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightPeach.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Due:', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                      Text(
                        '₱${total.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Method:', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                      Text(
                        methodName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkText),
                      ),
                    ],
                  ),
                  if (_method == EmployeePaymentMethod.gCash &&
                      _scannedRefNumber != null &&
                      _scannedRefNumber!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('GCash Ref #:', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                        Text(
                          GcashOcrHelper.formatRefNumber(_scannedRefNumber!),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount Received:', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                      Text(
                        '₱${amountPaid.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkText),
                      ),
                    ],
                  ),
                  if (_method == EmployeePaymentMethod.cash && change > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Change:', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                        Text(
                          '₱${change.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    final receipt = widget.posController.checkout(
      paymentMethod: _method,
      amountPaid: amountPaid,
      paymentReferenceNumber: _method == EmployeePaymentMethod.gCash ? _scannedRefNumber : null,
    );
    if (receipt != null) {
      EmployeeShiftController.instance.recordSale(
        paymentMethod: receipt.paymentMethod,
        amount: receipt.totalAmount,
      );
      widget.onCompleted(receipt);
    } else {
      if (mounted) {
        TopNotification.show(
          context,
          'Checkout failed: Selected batch has insufficient stock or is unavailable.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.posController.totalAmount;
    final cart = widget.posController.cart;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Complete Sale',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText)),
              const SizedBox(height: 16),
              const Text('Order Summary',
                  style: TextStyle(
                      color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              _CheckoutOrderSummary(cart: cart),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.borderColor),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Due', style: TextStyle(color: AppColors.secondaryText)),
                  Text(
                    '₱${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Payment Method',
                  style: TextStyle(
                      color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _PaymentMethodChip(
                      label: 'Cash',
                      icon: Icons.money,
                      isSelected: _method == EmployeePaymentMethod.cash,
                      onTap: () {
                        setState(() {
                          _method = EmployeePaymentMethod.cash;
                          _amountErrorText = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PaymentMethodChip(
                      label: 'GCash',
                      icon: Icons.account_balance_wallet,
                      isSelected: _method == EmployeePaymentMethod.gCash,
                      onTap: () {
                        setState(() {
                          _method = EmployeePaymentMethod.gCash;
                          _amountErrorText = null;
                          _amountController.text = widget.posController.totalAmount.toStringAsFixed(2);
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_method == EmployeePaymentMethod.gCash) ...[
                const SizedBox(height: 20),
                const Text('GCash QR Code & Receipt OCR',
                    style: TextStyle(
                        color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                _GcashQrView(
                  posController: widget.posController,
                  scannedRefNumber: _scannedRefNumber,
                  onRefNumberScanned: (ref) {
                    setState(() => _scannedRefNumber = ref);
                  },
                ),
              ],
              const SizedBox(height: 20),
              const Text('Amount Received',
                  style: TextStyle(
                      color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                onChanged: (_) {
                  if (_amountErrorText != null) {
                    setState(() => _amountErrorText = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: total.toStringAsFixed(2),
                  prefixText: '₱ ',
                  errorText: _amountErrorText,
                  filled: true,
                  fillColor: AppColors.lightPeach,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _amountErrorText != null
                        ? const BorderSide(color: Colors.red, width: 1)
                        : BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _amountErrorText != null
                        ? const BorderSide(color: Colors.red, width: 1.5)
                        : const BorderSide(color: AppColors.primaryOrange, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Confirm Payment',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only line-by-line breakdown of every item in the sale — product
/// name, quantity, unit price, and per-line subtotal — shown inside the
/// "Complete Sale" sheet so the cashier can double-check the order before
/// confirming payment.
class _CheckoutOrderSummary extends StatelessWidget {
  const _CheckoutOrderSummary({required this.cart});

  final List<EmployeePosCartItem> cart;

  @override
  Widget build(BuildContext context) {
    if (cart.isEmpty) {
      return const Text(
        'No items in this sale.',
        style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightPeach.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          for (int i = 0; i < cart.length; i++) ...[
            if (i > 0) const Divider(height: 16, color: AppColors.borderColor),
            _CheckoutOrderSummaryRow(item: cart[i]),
          ],
        ],
      ),
    );
  }
}

class _CheckoutOrderSummaryRow extends StatelessWidget {
  const _CheckoutOrderSummaryRow({required this.item});

  final EmployeePosCartItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
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
                  '₱${item.unitPrice.toStringAsFixed(2)} x ${item.product.isWeightBased ? item.quantity.toStringAsFixed(2) : item.quantity.toStringAsFixed(0)} ${item.product.isWeightBased ? 'kg' : 'pcs'}',
                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '₱${item.subtotal.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.darkText,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodChip extends StatelessWidget {
  const _PaymentMethodChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryOrange.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : AppColors.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GcashQrView extends StatelessWidget {
  const _GcashQrView({
    required this.posController,
    this.scannedRefNumber,
    this.onRefNumberScanned,
  });

  final EmployeePosController posController;
  final String? scannedRefNumber;
  final ValueChanged<String>? onRefNumberScanned;

  Future<void> _scanReceiptOcr(BuildContext context) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scan GCash Receipt',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose how to scan or upload the GCash payment receipt:',
                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.lightPeach,
                  child: Icon(Icons.camera_alt_rounded, color: AppColors.primaryOrange),
                ),
                title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Capture phone screen or printed receipt', style: TextStyle(fontSize: 11)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.lightPeach,
                  child: Icon(Icons.photo_library_rounded, color: AppColors.primaryOrange),
                ),
                title: const Text('Choose Screenshot from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Select a saved GCash receipt image', style: TextStyle(fontSize: 11)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !context.mounted) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (image == null || !context.mounted) return;

      TopNotification.show(context, 'Scanning GCash receipt with Google OCR...');

      final bytes = await image.readAsBytes();
      List<OcrTextItem> ocrItems = [];

      try {
        final ocrService = MlKitOcrService();
        ocrItems = await ocrService.processImageWebOrMobile(
          imagePath: image.path,
          bytes: bytes,
          filterJunk: false,
        );
        ocrService.dispose();
      } catch (e) {
        debugPrint('[POS OCR Exception]: $e');
      }

      final validation = GcashOcrHelper.validateReceipt(
        items: ocrItems,
        fileSizeBytes: bytes.length,
      );

      final String? detectedRef = validation.extractedRefNumber ?? GcashOcrHelper.extractRefNumber(ocrItems);

      if (context.mounted) {
        if (detectedRef != null && detectedRef.isNotEmpty) {
          onRefNumberScanned?.call(detectedRef);
          TopNotification.show(
            context,
            'GCash Receipt scanned! Ref #: ${GcashOcrHelper.formatRefNumber(detectedRef)}',
          );
          _showRefVerificationDialog(context, detectedRef);
        } else {
          TopNotification.show(
            context,
            'GCash Ref No. could not be read automatically. Please enter it below.',
            isError: true,
          );
          _showRefVerificationDialog(context, '');
        }
      }
    } catch (e) {
      debugPrint('[POS OCR Error]: $e');
      if (context.mounted) {
        TopNotification.show(
          context,
          'Could not scan screenshot. Please enter the GCash Ref No. manually.',
          isError: true,
        );
        _showRefVerificationDialog(context, '');
      }
    }
  }

  void _showRefVerificationDialog(BuildContext context, String initialRef) {
    final controller = TextEditingController(
      text: initialRef.isNotEmpty ? GcashOcrHelper.formatRefNumber(initialRef) : '',
    );
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified, color: AppColors.primaryOrange),
            SizedBox(width: 8),
            Text('Verify Reference No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confirm or edit the GCash reference number automatically extracted by Google OCR:',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 15),
              decoration: InputDecoration(
                labelText: 'GCash Reference Number *',
                hintText: 'e.g. 5045 062 915234',
                filled: true,
                fillColor: AppColors.lightPeach,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryOrange, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () {
              final cleanRef = controller.text.trim().replaceAll(' ', '');
              if (cleanRef.isNotEmpty && onRefNumberScanned != null) {
                onRefNumberScanned!(cleanRef);
              }
              Navigator.pop(dialogCtx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save Reference #'),
          ),
        ],
      ),
    );
  }

  void _showFullScreen(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: ProductImage(
                  image: imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 0,
                  fallbackIcon: Icons.broken_image,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmChange(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change GCash QR'),
        content: const Text('Are you sure you want to change or remove the current GCash QR code?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryOrange),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      posController.updateGcashQrCode(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = EmployeeProfileController.instance.profile.role == 'Owner';

    return ListenableBuilder(
      listenable: Listenable.merge([posController, ShopSettingsController.instance]),
      builder: (context, _) {
        final storeQr = ShopSettingsController.instance.gcashQrUrl;
        final currentQr = (storeQr != null && storeQr.trim().isNotEmpty) ? storeQr : posController.gcashQrCode;

        if (currentQr == null) {
          if (!isOwner) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightPeach,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primaryOrange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'GCash QR code is not set. Please contact the owner to upload the store QR.',
                      style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          }

          return InkWell(
            onTap: () {
              posController.updateGcashQrCode(
                  'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=GCash'
              );
            },
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.lightPeach,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5), style: BorderStyle.solid),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, color: AppColors.primaryOrange, size: 32),
                  SizedBox(height: 8),
                  Text('Upload GCash QR Code',
                      style: TextStyle(color: AppColors.primaryOrange, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _showFullScreen(context, currentQr),
                  child: Hero(
                    tag: 'gcash_qr',
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: ProductImage(
                        image: currentQr,
                        width: 100,
                        height: 100,
                        borderRadius: 12,
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.qr_code_2_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tap QR code image to enlarge for customer scanning.',
                        style: TextStyle(color: AppColors.secondaryText, fontSize: 11),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () => _scanReceiptOcr(context),
                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                        label: const Text('Scan Receipt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      if (isOwner) ...[
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: () => _confirmChange(context),
                          icon: const Icon(Icons.edit_outlined, size: 14),
                          label: const Text('Change QR', style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryOrange,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (scannedRefNumber != null && scannedRefNumber!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ref #: ${GcashOcrHelper.formatRefNumber(scannedRefNumber!)} (Scanned)',
                        style: TextStyle(
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16, color: Colors.green),
                      onPressed: () => _showRefVerificationDialog(context, scannedRefNumber!),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit Reference #',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      onPressed: () => onRefNumberScanned?.call(''),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Clear Reference #',
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
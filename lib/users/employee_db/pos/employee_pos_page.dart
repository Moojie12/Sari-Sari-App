import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../employee_inventory_controller.dart';
import '../inventory/employee_dummy_products.dart';
import '../inventory/employee_product_model.dart';
import 'employee_pos_controller.dart';
import 'employee_receipt_page.dart';
import 'employee_batch_selection_sheet.dart';

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

class _EmployeePosPageState extends State<EmployeePosPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<EmployeeProduct> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    return widget.inventory.products.where((product) {
      final matchesCategory =
          _selectedCategory == 'All' || product.category == _selectedCategory;
      final matchesSearch = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.barcode.contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _addToCart(EmployeeProduct product) {
    if (product.stockStatus == EmployeeStockStatus.outOfStock) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('This product is out of stock.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EmployeeBatchSelectionSheet(
        product: product,
        onConfirm: (batch, quantity) {
          widget.posController.addBatchToCart(product, batch, quantity: quantity);
        },
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.inventory, widget.posController]),
          builder: (context, _) {
            final products = _filteredProducts;
            return Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildCategories(),
                const SizedBox(height: 8),
                Expanded(
                  child: products.isEmpty
                      ? _buildEmptyState()
                      : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _PosProductCard(
                        product: product,
                        onTap: () => _addToCart(product),
                      );
                    },
                  ),
                ),
                if (widget.posController.cart.isNotEmpty)
                  _CartBar(
                    posController: widget.posController,
                    onCheckout: _openCheckout,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Point of Sale',
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: 28,
            fontWeight: FontWeight.bold,
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
          suffixIcon:
          const Icon(Icons.qr_code_scanner, color: AppColors.primaryOrange),
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
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: kEmployeeProductCategories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = kEmployeeProductCategories[index];
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

class _PosProductCard extends StatelessWidget {
  const _PosProductCard({required this.product, required this.onTap});
  final EmployeeProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOut = product.stockStatus == EmployeeStockStatus.outOfStock;
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderColor.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: isOut ? null : onTap,
        child: Padding(
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
                    child: Icon(Icons.image_outlined,
                        size: 28,
                        color: AppColors.primaryOrange.withValues(alpha: 0.4)),
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
              Text(
                '₱${product.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isOut ? 'Out of stock' : '${product.quantity} in stock',
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
      ),
    );
  }
}

/// Bottom cart summary bar. Slide it up (or tap the item-count/total area)
/// to reveal the list of items currently added to the cart before hitting
/// Checkout.
class _CartBar extends StatefulWidget {
  const _CartBar({
    required this.posController,
    required this.onCheckout,
  });

  final EmployeePosController posController;
  final VoidCallback onCheckout;

  @override
  State<_CartBar> createState() => _CartBarState();
}

class _CartBarState extends State<_CartBar> {
  bool _expanded = false;

  void _setExpanded(bool value) {
    if (_expanded == value) return;
    setState(() => _expanded = value);
  }

  void _toggleExpanded() => _setExpanded(!_expanded);

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -150) {
      _setExpanded(true); // swiped up
    } else if (velocity > 150) {
      _setExpanded(false); // swiped down
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.posController.itemCount;
    final totalAmount = widget.posController.totalAmount;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleExpanded,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Column(
                children: [
                  // Drag handle — hints that this section can be slid up.
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('$itemCount item(s)',
                                    style: const TextStyle(
                                        color: AppColors.secondaryText,
                                        fontSize: 12)),
                                const SizedBox(width: 4),
                                Icon(
                                  _expanded
                                      ? Icons.keyboard_arrow_down
                                      : Icons.keyboard_arrow_up,
                                  size: 16,
                                  color: AppColors.secondaryText,
                                ),
                              ],
                            ),
                            Text(
                              '₱${totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.darkText,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: widget.onCheckout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Checkout',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? _CartItemsList(posController: widget.posController)
                : const SizedBox(width: double.infinity),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 12 : 24),
        ],
      ),
    );
  }
}

/// Scrollable preview of every product currently added to the cart, with
/// quantity +/- controls and a remove option, shown when the cart bar is
/// expanded.
class _CartItemsList extends StatelessWidget {
  const _CartItemsList({required this.posController});

  final EmployeePosController posController;

  @override
  Widget build(BuildContext context) {
    final cart = posController.cart;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: AppColors.borderColor),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              shrinkWrap: true,
              itemCount: cart.length,
              separatorBuilder: (context, index) =>
              const Divider(height: 16, color: AppColors.borderColor),
              itemBuilder: (context, index) {
                final item = cart[index];
                return _CartItemTile(
                  item: item,
                  onIncrement: () =>
                      posController.incrementQuantity(item.product.id, item.batchId),
                  onDecrement: () =>
                      posController.decrementQuantity(item.product.id, item.batchId),
                  onRemove: () =>
                      posController.removeFromCart(item.product.id, item.batchId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final EmployeePosCartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
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
                '₱${item.product.price.toStringAsFixed(2)} each',
                style: const TextStyle(
                    color: AppColors.secondaryText, fontSize: 11),
              ),
            ],
          ),
        ),
        _QuantityStepper(
          quantity: item.quantity,
          onIncrement: onIncrement,
          onDecrement: onDecrement,
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

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(icon: Icons.remove, onTap: onDecrement),
        SizedBox(
          width: 24,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.darkText,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ),
        _StepperButton(icon: Icons.add, onTap: onIncrement),
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

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _confirm() {
    final total = widget.posController.totalAmount;
    final amountPaid = double.tryParse(_amountController.text) ?? total;
    if (amountPaid < total) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Amount received is less than the total.')));
      return;
    }

    final receipt =
    widget.posController.checkout(paymentMethod: _method, amountPaid: amountPaid);
    if (receipt != null) widget.onCompleted(receipt);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.posController.totalAmount;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Complete Sale',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText)),
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
                    onTap: () => setState(() => _method = EmployeePaymentMethod.cash),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PaymentMethodChip(
                    label: 'GCash',
                    icon: Icons.account_balance_wallet,
                    isSelected: _method == EmployeePaymentMethod.gCash,
                    onTap: () => setState(() => _method = EmployeePaymentMethod.gCash),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Amount Received',
                style: TextStyle(
                    color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: total.toStringAsFixed(2),
                prefixText: '₱ ',
                filled: true,
                fillColor: AppColors.lightPeach,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
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
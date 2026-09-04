import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../customer_cart_controller.dart';
import '../purchases/customer_order_controller.dart';
import '../purchases/customer_order_model.dart';
import 'customer_order_confirmation_page.dart';

class CustomerCheckoutPage extends StatefulWidget {
  const CustomerCheckoutPage({
    super.key,
    required this.cartController,
    required this.orderController,
  });

  final CustomerCartController cartController;
  final CustomerOrderController orderController;

  @override
  State<CustomerCheckoutPage> createState() => _CustomerCheckoutPageState();
}

class _CustomerCheckoutPageState extends State<CustomerCheckoutPage> {
  OrderType _orderType = OrderType.pickup;
  PaymentMethod _paymentMethod = PaymentMethod.cashOnDelivery;
  final double _deliveryFee = 20.0;

  double get _total => widget.cartController.totalAmount + (_orderType == OrderType.delivery ? _deliveryFee : 0);

  void _handlePlaceOrder() {
    final orderId = widget.orderController.generateOrderNumber();
    final items = widget.cartController.items.map((item) => CustomerOrderItem(
      productId: item.product.id,
      productName: item.product.name,
      price: item.product.price,
      quantity: item.quantity,
      subtotal: item.subtotal,
    )).toList();

    final order = CustomerOrder(
      orderId: orderId,
      orderDate: DateTime.now(),
      items: items,
      orderType: _orderType,
      paymentMethod: _paymentMethod,
      paymentStatus: _paymentMethod == PaymentMethod.cashOnDelivery ? PaymentStatus.unpaid : PaymentStatus.paid,
      deliveryAddress: _orderType == OrderType.delivery ? 'Juan Dela Cruz, Pagsanjan, Laguna, 09XXXXXXXXX' : null,
      subtotal: widget.cartController.totalAmount,
      deliveryFee: _orderType == OrderType.delivery ? _deliveryFee : 0,
      totalAmount: _total,
      status: OrderStatus.pending,
    );

    widget.orderController.placeOrder(order);
    widget.cartController.clearCart();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerOrderConfirmationPage(order: order),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Checkout',
          style: TextStyle(color: AppColors.darkText, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkText),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: 'Order Summary'),
            const SizedBox(height: 12),
            _OrderSummaryList(items: widget.cartController.items),
            const SizedBox(height: 32),
            
            _SectionHeader(title: 'Order Type'),
            const SizedBox(height: 12),
            _OrderTypeSelector(
              selectedType: _orderType,
              onChanged: (type) => setState(() => _orderType = type),
            ),
            const SizedBox(height: 32),

            if (_orderType == OrderType.delivery) ...[
              _SectionHeader(title: 'Delivery Information'),
              const SizedBox(height: 12),
              _DeliveryInfoCard(),
              const SizedBox(height: 32),
            ],

            _SectionHeader(title: 'Payment Method'),
            const SizedBox(height: 12),
            _PaymentMethodSelector(
              selectedMethod: _paymentMethod,
              onChanged: (method) => setState(() => _paymentMethod = method),
            ),
            const SizedBox(height: 32),

            _SectionHeader(title: 'Price Summary'),
            const SizedBox(height: 12),
            _PriceSummaryCard(
              subtotal: widget.cartController.totalAmount,
              deliveryFee: _orderType == OrderType.delivery ? _deliveryFee : 0,
              total: _total,
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handlePlaceOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('PLACE ORDER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
    );
  }
}

class _OrderSummaryList extends StatelessWidget {
  const _OrderSummaryList({required this.items});
  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${item.product.name} x${item.quantity}', style: const TextStyle(color: AppColors.secondaryText)),
              Text('₱${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _OrderTypeSelector extends StatelessWidget {
  const _OrderTypeSelector({required this.selectedType, required this.onChanged});
  final OrderType selectedType;
  final ValueChanged<OrderType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SelectableCard(
            title: 'Pickup',
            isSelected: selectedType == OrderType.pickup,
            onTap: () => onChanged(OrderType.pickup),
            icon: Icons.storefront,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SelectableCard(
            title: 'Delivery',
            isSelected: selectedType == OrderType.delivery,
            onTap: () => onChanged(OrderType.delivery),
            icon: Icons.delivery_dining,
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({required this.selectedMethod, required this.onChanged});
  final PaymentMethod selectedMethod;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PaymentOption(
          title: 'Cash on Delivery',
          isSelected: selectedMethod == PaymentMethod.cashOnDelivery,
          onTap: () => onChanged(PaymentMethod.cashOnDelivery),
          icon: Icons.money,
        ),
        const SizedBox(height: 12),
        _PaymentOption(
          title: 'GCash',
          isSelected: selectedMethod == PaymentMethod.gCash,
          onTap: () => onChanged(PaymentMethod.gCash),
          icon: Icons.account_balance_wallet,
        ),
      ],
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({required this.title, required this.isSelected, required this.onTap, required this.icon});
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryOrange.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText,
            )),
          ],
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({required this.title, required this.isSelected, required this.onTap, required this.icon});
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.darkText : AppColors.secondaryText,
            )),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.primaryOrange),
          ],
        ),
      ),
    );
  }
}

class _DeliveryInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.primaryOrange),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Juan Dela Cruz', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Pagsanjan, Laguna', style: TextStyle(color: AppColors.secondaryText)),
                Text('09XXXXXXXXX', style: TextStyle(color: AppColors.secondaryText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceSummaryCard extends StatelessWidget {
  const _PriceSummaryCard({required this.subtotal, required this.deliveryFee, required this.total});
  final double subtotal;
  final double deliveryFee;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _PriceRow(label: 'Subtotal', value: subtotal),
          const SizedBox(height: 8),
          _PriceRow(label: 'Delivery Fee', value: deliveryFee),
          const Divider(height: 24),
          _PriceRow(label: 'Total', value: total, isBold: true),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.value, this.isBold = false});
  final String label;
  final double value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          color: isBold ? AppColors.darkText : AppColors.secondaryText,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: isBold ? 18 : 14,
        )),
        Text('₱${value.toStringAsFixed(2)}', style: TextStyle(
          color: isBold ? AppColors.primaryOrange : AppColors.darkText,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: isBold ? 18 : 14,
        )),
      ],
    );
  }
}

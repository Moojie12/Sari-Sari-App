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
  final _addressController = TextEditingController(text: 'Juan Dela Cruz, Pagsanjan, Laguna, 09XXXXXXXXX');

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _handlePlaceOrder() {
    final order = CustomerOrder(
      orderId: widget.orderController.generateOrderNumber(),
      orderDate: DateTime.now(),
      items: widget.cartController.items.map((item) => CustomerOrderItem(
        productId: item.product.id,
        productName: item.product.name,
        price: item.product.price,
        quantity: item.quantity,
        subtotal: item.subtotal,
      )).toList(),
      orderType: _orderType,
      paymentMethod: _paymentMethod,
      paymentStatus: PaymentStatus.unpaid,
      deliveryAddress: _orderType == OrderType.delivery ? _addressController.text : null,
      subtotal: widget.cartController.totalAmount,
      deliveryFee: _orderType == OrderType.delivery ? 20.0 : 0.0,
      totalAmount: widget.cartController.totalAmount + (_orderType == OrderType.delivery ? 20.0 : 0.0),
      status: OrderStatus.pending,
    );

    widget.orderController.placeOrder(order);
    widget.cartController.clearCart();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerOrderConfirmationPage(order: order),
      ),
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
            const Text('Order Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _OptionCard(
                  label: 'Pickup',
                  icon: Icons.storefront,
                  isSelected: _orderType == OrderType.pickup,
                  onTap: () => setState(() => _orderType = OrderType.pickup),
                ),
                const SizedBox(width: 12),
                _OptionCard(
                  label: 'Delivery',
                  icon: Icons.local_shipping,
                  isSelected: _orderType == OrderType.delivery,
                  onTap: () => setState(() => _orderType = OrderType.delivery),
                ),
              ],
            ),
            if (_orderType == OrderType.delivery) ...[
              const SizedBox(height: 24),
              const Text('Delivery Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text('Payment Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _PaymentTile(
              label: 'Cash on Delivery',
              icon: Icons.money,
              isSelected: _paymentMethod == PaymentMethod.cashOnDelivery,
              onTap: () => setState(() => _paymentMethod = PaymentMethod.cashOnDelivery),
            ),
            const SizedBox(height: 8),
            _PaymentTile(
              label: 'GCash',
              icon: Icons.account_balance_wallet,
              isSelected: _paymentMethod == PaymentMethod.gCash,
              onTap: () => setState(() => _paymentMethod = PaymentMethod.gCash),
            ),
            const SizedBox(height: 24),
            const Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _SummaryRow(label: 'Subtotal', value: widget.cartController.totalAmount),
                  if (_orderType == OrderType.delivery)
                    const _SummaryRow(label: 'Delivery Fee', value: 20.0),
                  const Divider(height: 24),
                  _SummaryRow(
                    label: 'Total',
                    value: widget.cartController.totalAmount + (_orderType == OrderType.delivery ? 20.0 : 0.0),
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _handlePlaceOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Place Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.label, required this.icon, required this.isSelected, required this.onTap});
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryOrange : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppColors.primaryOrange : AppColors.borderColor),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : AppColors.secondaryText),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.darkText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.label, required this.icon, required this.isSelected, required this.onTap});
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primaryOrange : AppColors.borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.primaryOrange),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.isBold = false});
  final String label;
  final double value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isBold ? AppColors.darkText : AppColors.secondaryText, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            '₱${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? AppColors.primaryOrange : AppColors.darkText,
              fontSize: isBold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

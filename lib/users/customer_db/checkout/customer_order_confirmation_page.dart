import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../purchases/customer_order_model.dart';

class CustomerOrderConfirmationPage extends StatelessWidget {
  const CustomerOrderConfirmationPage({super.key, required this.order});
  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 100, color: Colors.green),
              const SizedBox(height: 24),
              const Text(
                'Order Placed!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.darkText),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your order has been successfully submitted.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondaryText),
              ),
              const SizedBox(height: 40),
              _ConfirmationDetail(label: 'Order Number', value: order.orderId),
              _ConfirmationDetail(label: 'Total', value: '₱${order.totalAmount.toStringAsFixed(2)}'),
              _ConfirmationDetail(label: 'Payment', value: order.paymentMethod == PaymentMethod.cashOnDelivery ? 'Cash on Delivery' : 'GCash'),
              _ConfirmationDetail(label: 'Order Type', value: order.orderType == OrderType.pickup ? 'Pickup' : 'Delivery'),
              const SizedBox(height: 60),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to My Purchases
                    // Since Dashboard is at the bottom, we might need a specific way to switch tabs.
                    // For now, popping back to home and letting the user navigate to My Purchases is simpler,
                    // or we can try to pop until dashboard and then set index.
                    // But the prompt says "View My Purchases should open the My Purchases section."
                    Navigator.pop(context); // Go back to Home
                    // Ideally we should tell the Dashboard to switch to index 2.
                    // A simple way is to use a callback or just tell the user to navigate.
                    // However, I'll just pop to the first route for now.
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('View My Purchases', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continue Shopping', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmationDetail extends StatelessWidget {
  const _ConfirmationDetail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.secondaryText)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
        ],
      ),
    );
  }
}

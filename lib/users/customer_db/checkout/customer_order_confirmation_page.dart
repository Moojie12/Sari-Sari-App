import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../owner_db/profile/shop_settings_controller.dart';
import '../customer_db.dart';
import '../purchases/customer_order_model.dart';
import '../customer_dashboard.dart';
import '../../../shared/utils/gcash_ocr_helper.dart';
import '../tutorial/customer_tutorial_keys.dart';

class CustomerOrderConfirmationPage extends StatelessWidget {
  const CustomerOrderConfirmationPage({super.key, required this.order});
  final CustomerOrder order;

  void _navigateToDashboard(BuildContext context, int tabIndex) {
    CustomerTutorialKeys.reset();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CustomerDashboard.dashboardKey.currentState?.switchTab(tabIndex);
      });
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CustomerDb()),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CustomerDashboard.dashboardKey.currentState?.switchTab(tabIndex);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRefNumber = order.paymentMethod == PaymentMethod.gCash &&
        order.paymentReferenceNumber != null &&
        order.paymentReferenceNumber!.isNotEmpty;

    final isPickup = order.orderType == OrderType.pickup;
    final storeAddress = ShopSettingsController.instance.storeAddress;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _navigateToDashboard(context, 0);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 90, color: Colors.green),
                const SizedBox(height: 20),
                const Text(
                  'Order Placed!',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.darkText),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your order has been successfully submitted.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.secondaryText),
                ),
                const SizedBox(height: 28),
                _ConfirmationDetail(label: 'Order Number', value: order.displayOrderId),
                _ConfirmationDetail(label: 'Total', value: '₱${order.totalAmount.toStringAsFixed(2)}'),
                _ConfirmationDetail(
                  label: 'Payment',
                  value: order.paymentMethod == PaymentMethod.cashOnDelivery ? 'Cash on Delivery' : 'GCash',
                ),
                if (hasRefNumber)
                  _ConfirmationDetail(
                    label: 'GCash Ref No.',
                    value: GcashOcrHelper.formatRefNumber(order.paymentReferenceNumber!),
                  ),
                _ConfirmationDetail(label: 'Order Type', value: isPickup ? 'Pickup' : 'Delivery'),

                // Pickup instructions & Store Address
                if (isPickup) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.storefront, color: AppColors.primaryOrange, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Pickup Store Address',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkText),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          storeAddress,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.darkText),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(Icons.info_outline, size: 16, color: AppColors.primaryOrange),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This order must be picked up at the store once it is ready. Please wait until your order status changes to "Ready for Pickup" before going to the store.',
                                  style: TextStyle(fontSize: 12, color: AppColors.secondaryText, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _navigateToDashboard(context, 2),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('View My Purchases', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => _navigateToDashboard(context, 0),
                  child: const Text('Continue Shopping', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
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

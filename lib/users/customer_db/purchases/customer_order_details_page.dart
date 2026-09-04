import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'customer_order_model.dart';

class CustomerOrderDetailsPage extends StatelessWidget {
  const CustomerOrderDetailsPage({super.key, required this.order});
  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Order Details',
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
            _OrderInfoSection(order: order),
            const SizedBox(height: 24),
            _StatusTimeline(currentStatus: order.status, orderType: order.orderType),
            const SizedBox(height: 24),
            const Text('Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _OrderItemsList(items: order.items),
            const SizedBox(height: 24),
            const Text('Order Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _OrderDetailsCard(order: order),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _OrderInfoSection extends StatelessWidget {
  const _OrderInfoSection({required this.order});
  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Order Number', style: TextStyle(color: AppColors.secondaryText)),
              Text(order.orderId, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Order Date', style: TextStyle(color: AppColors.secondaryText)),
              Text(order.formattedDate, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Status', style: TextStyle(color: AppColors.secondaryText)),
              Text(order.status.label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.currentStatus, required this.orderType});
  final OrderStatus currentStatus;
  final OrderType orderType;

  @override
  Widget build(BuildContext context) {
    final statuses = _getTimelineStatuses();
    final currentIndex = statuses.indexOf(currentStatus);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: List.generate(statuses.length, (index) {
          final status = statuses[index];
          final isCompleted = index <= currentIndex;
          final isCurrent = index == currentIndex;
          final isLast = index == statuses.length - 1;

          return IntrinsicHeight(
            child: Row(
              children: [
                Column(
                  children: [
                    Icon(
                      isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 20,
                      color: isCompleted ? AppColors.primaryOrange : AppColors.placeholderColor,
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isCompleted ? AppColors.primaryOrange : AppColors.borderColor,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    status.label,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCompleted ? AppColors.darkText : AppColors.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  List<OrderStatus> _getTimelineStatuses() {
    if (orderType == OrderType.pickup) {
      return [
        OrderStatus.pending,
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.readyForPickup,
        OrderStatus.completed,
      ];
    } else {
      return [
        OrderStatus.pending,
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.readyForShipment,
        OrderStatus.outForDelivery,
        OrderStatus.completed,
      ];
    }
  }
}

class _OrderItemsList extends StatelessWidget {
  const _OrderItemsList({required this.items});
  final List<CustomerOrderItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: AppColors.lightBackground, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.image_outlined, size: 24, color: AppColors.placeholderColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${item.quantity} x ₱${item.price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                  ],
                ),
              ),
              Text('₱${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _OrderDetailsCard extends StatelessWidget {
  const _OrderDetailsCard({required this.order});
  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _DetailRow(label: 'Order Type', value: order.orderType == OrderType.pickup ? 'Pickup' : 'Delivery'),
          _DetailRow(label: 'Payment Method', value: order.paymentMethod == PaymentMethod.cashOnDelivery ? 'Cash on Delivery' : 'GCash'),
          _DetailRow(label: 'Payment Status', value: order.paymentStatus.name.toUpperCase()),
          if (order.deliveryAddress != null)
            _DetailRow(label: 'Delivery Address', value: order.deliveryAddress!),
          const Divider(height: 24),
          _DetailRow(label: 'Subtotal', value: '₱${order.subtotal.toStringAsFixed(2)}'),
          _DetailRow(label: 'Delivery Fee', value: '₱${order.deliveryFee.toStringAsFixed(2)}'),
          _DetailRow(label: 'Total', value: '₱${order.totalAmount.toStringAsFixed(2)}', isBold: true),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.isBold = false});
  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.secondaryText)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: isBold ? AppColors.primaryOrange : AppColors.darkText,
                fontSize: isBold ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

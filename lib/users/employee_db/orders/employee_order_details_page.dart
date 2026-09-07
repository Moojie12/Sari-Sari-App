import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../customer_db/purchases/customer_order_model.dart';
import 'employee_orders_controller.dart';
import 'employee_orders_page.dart';
import '../messages/employee_chat_page.dart';
import '../messages/employee_messages_controller.dart';

class EmployeeOrderDetailsPage extends StatelessWidget {
  const EmployeeOrderDetailsPage({
    super.key,
    required this.order,
    required this.controller,
  });

  final CustomerOrder order;
  final EmployeeOrderController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Order #${order.orderId}',
          style: const TextStyle(color: AppColors.darkText, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkText),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          // Re-fetch order from controller to get latest status if updated
          final currentOrder = controller.orders.firstWhere(
            (o) => o.orderId == order.orderId,
            orElse: () => order,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OrderInfoSection(order: currentOrder),
                const SizedBox(height: 24),
                const Text('Order Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _StatusTimelineView(order: currentOrder),
                if (currentOrder.status == OrderStatus.outForDelivery &&
                    currentOrder.orderType == OrderType.delivery) ...[
                  const SizedBox(height: 24),
                  const Text('Delivery Tracking',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _DeliveryMapSection(order: currentOrder),
                ],
                const SizedBox(height: 24),
                const Text('Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _OrderItemsList(items: currentOrder.items),
                const SizedBox(height: 24),
                const Text('Delivery & Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _OrderDetailsCard(order: currentOrder),
                const SizedBox(height: 32),
                if (currentOrder.status != OrderStatus.completed &&
                    currentOrder.status != OrderStatus.cancelled)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _showStatusUpdateSheet(context, currentOrder),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Update Order Status',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showStatusUpdateSheet(BuildContext context, CustomerOrder currentOrder) {
    // We can reuse the same bottom sheet logic from the list page
    // but we need a way to trigger it. 
    // For simplicity, I'll let the user tap the timeline or this button.
    // In EmployeeOrdersPage, we have _showStatusUpdateDialog which is private.
    // I will refactor or just implement a similar one here.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Update Status',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkText),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(bottomSheetContext),
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              StatusTimelinePicker(
                order: currentOrder,
                onStatusSelected: (newStatus) {
                  _showConfirmationDialog(
                    context: context,
                    title: 'Update Status',
                    message: 'Are you sure you want to change the status to "${newStatus.label}"?',
                    onConfirm: () {
                      controller.updateOrderStatus(currentOrder.orderId, newStatus);
                      Navigator.pop(bottomSheetContext);
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    _showConfirmationDialog(
                      context: context,
                      title: 'Cancel Order',
                      message: 'Are you sure you want to cancel this order? This action cannot be undone.',
                      confirmColor: Colors.red,
                      onConfirm: () {
                        controller.updateOrderStatus(currentOrder.orderId, OrderStatus.cancelled);
                        Navigator.pop(bottomSheetContext);
                      },
                    );
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Cancel Order'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onConfirm,
    Color confirmColor = AppColors.primaryOrange,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: Text('Confirm', style: TextStyle(color: confirmColor, fontWeight: FontWeight.bold)),
          ),
        ],
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Customer Name', style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
              InkWell(
                onTap: () {
                  final messagesController = EmployeeMessagesController.instance;
                  final thread = messagesController.threads.firstWhere(
                    (t) => t.recipient.name == order.customerName,
                    orElse: () => messagesController.threads.firstWhere((t) => t.recipient.isCustomer),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmployeeChatPage(recipientId: thread.recipient.id),
                    ),
                  );
                },
                child: Text(
                  order.customerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'Order Date', value: order.formattedDate),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Status', style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
              _StatusBadge(status: order.status),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 14)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

class _StatusTimelineView extends StatelessWidget {
  const _StatusTimelineView({required this.order});
  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final statuses = _getTimelineStatuses();
    final currentIndex = statuses.indexOf(order.status);

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
    if (order.orderType == OrderType.pickup) {
      return [OrderStatus.pending, OrderStatus.confirmed, OrderStatus.preparing, OrderStatus.readyForPickup, OrderStatus.completed];
    } else {
      return [OrderStatus.pending, OrderStatus.confirmed, OrderStatus.preparing, OrderStatus.readyForShipment, OrderStatus.outForDelivery, OrderStatus.completed];
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
                width: 45,
                height: 45,
                decoration: BoxDecoration(color: AppColors.lightBackground, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.shopping_bag_outlined, size: 20, color: AppColors.placeholderColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${item.quantity} x ₱${item.price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                  ],
                ),
              ),
              Text('₱${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
            _DetailRow(label: 'Customer Details', value: order.deliveryAddress!),
          const Divider(height: 24),
          _DetailRow(label: 'Subtotal', value: '₱${order.subtotal.toStringAsFixed(2)}'),
          _DetailRow(label: 'Delivery Fee', value: '₱${order.deliveryFee.toStringAsFixed(2)}'),
          _DetailRow(label: 'Total Amount', value: '₱${order.totalAmount.toStringAsFixed(2)}', isBold: true),
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
          Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: isBold ? AppColors.primaryOrange : AppColors.darkText,
                fontSize: isBold ? 15 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryMapSection extends StatelessWidget {
  const _DeliveryMapSection({required this.order});
  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmployeeDeliveryTrackingPage(order: order),
          ),
        );
      },
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Placeholder for the Map
              Image.network(
                'https://static-maps.yandex.ru/1.x/?lang=en_US&ll=121.0483,14.5547&z=14&l=map&size=600,300',
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: Icon(Icons.map, size: 50, color: Colors.grey)),
                ),
              ),
              // Overlay to make it look like a map preview
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, color: AppColors.primaryOrange, size: 40),
                    SizedBox(height: 8),
                    Text(
                      'Tap to View Real-time Map',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 10, color: Colors.black)],
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

class EmployeeDeliveryTrackingPage extends StatelessWidget {
  const EmployeeDeliveryTrackingPage({super.key, required this.order});
  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Delivery Tracking',
            style: TextStyle(color: AppColors.darkText, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkText),
      ),
      body: Stack(
        children: [
          // Simulated Full Screen Map
          Container(
            color: Colors.grey[100],
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 100, color: AppColors.placeholderColor),
                  SizedBox(height: 16),
                  Text('Google Maps / Mapbox Integration Here',
                      style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.bold)),
                  Text('Showing rider movement and destination',
                      style: TextStyle(color: AppColors.secondaryText)),
                ],
              ),
            ),
          ),
          // Floating Info Card
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppColors.lightBackground,
                        child: Icon(Icons.person, color: AppColors.primaryOrange),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.customerName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(order.deliveryAddress ?? 'No address provided',
                                style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('On the way',
                            style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _TrackingAction(icon: Icons.phone, label: 'Call', onTap: () {}),
                      _TrackingAction(icon: Icons.chat_bubble_outline, label: 'Message', onTap: () {
                        Navigator.pop(context); // Go back to details to use chat
                      }),
                      _TrackingAction(icon: Icons.navigation_outlined, label: 'Navigate', onTap: () {}),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Simple marker placeholders on map
          Positioned(
            top: 150,
            left: 100,
            child: Icon(Icons.location_on, color: AppColors.primaryOrange, size: 40),
          ),
          Positioned(
            top: 300,
            right: 80,
            child: Icon(Icons.delivery_dining, color: Colors.blue, size: 40),
          ),
        ],
      ),
    );
  }
}

class _TrackingAction extends StatelessWidget {
  const _TrackingAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.darkText, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case OrderStatus.pending: color = Colors.orange; break;
      case OrderStatus.confirmed: color = Colors.blue; break;
      case OrderStatus.preparing: color = Colors.amber; break;
      case OrderStatus.readyForPickup:
      case OrderStatus.readyForShipment: color = Colors.indigo; break;
      case OrderStatus.outForDelivery: color = Colors.purple; break;
      case OrderStatus.delivered:
      case OrderStatus.completed: color = Colors.green; break;
      case OrderStatus.cancelled: color = Colors.red; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

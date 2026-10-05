import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/delivery_tracking_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/osm_delivery_map.dart';
import '../../../shared/widgets/product_image.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
import '../employee_inventory_controller.dart';
import 'assign_delivery_person_sheet.dart';
import 'employee_delivery_tracking_page.dart';
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
          'Order #${order.displayOrderId}',
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
                if (currentOrder.status == OrderStatus.cancelled) ...[
                  const SizedBox(height: 16),
                  _CancelledOrderBanner(reason: currentOrder.cancellationReason),
                ],
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
                  if (newStatus == OrderStatus.outForDelivery) {
                    Navigator.pop(bottomSheetContext);
                    AssignDeliveryPersonSheet.show(
                      context,
                      order: currentOrder,
                      controller: controller,
                    );
                    return;
                  }

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
                    _showCancelOrderDialog(
                      context: context,
                      order: currentOrder,
                      controller: controller,
                      bottomSheetContext: bottomSheetContext,
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

  void _showCancelOrderDialog({
    required BuildContext context,
    required CustomerOrder order,
    required EmployeeOrderController controller,
    required BuildContext bottomSheetContext,
  }) {
    final formKey = GlobalKey<FormState>();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cancel Order #${order.displayOrderId}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please state the reason for cancelling this order. This will be recorded and sent to the customer.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                maxLength: 150,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Reason for Cancellation *',
                  hintText: 'e.g. Out of stock, Store closed, Unresponsive customer',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryOrange, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a cancellation reason';
                  }
                  if (value.trim().length < 3) {
                    return 'Reason must be at least 3 characters long';
                  }
                  if (value.trim().length > 150) {
                    return 'Reason cannot exceed 150 characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Keep Order', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final reason = reasonController.text.trim();
                Navigator.pop(dialogContext);
                controller.cancelOrder(order.orderId, reason: reason);
                Navigator.pop(bottomSheetContext);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
                  final messagesController =
                      EmployeeMessagesController.instance;

                  final recipientId = order.userId ??
                      'cust_${order.customerName.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';

                  final thread = messagesController.getOrCreateThread(
                    recipientId: recipientId,
                    name: order.customerName,
                    role: 'Customer',
                    isCustomer: true,
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmployeeChatPage(
                        recipientId: thread.recipient.id,
                        recipientName: thread.recipient.name,
                      ),
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

  String? _getProductImage(CustomerOrderItem item) {
    final inventory = EmployeeInventoryController.instance;
    // 1. Search by product ID
    final productById = inventory.findById(item.productId);
    if (productById != null && productById.image != null && productById.image!.isNotEmpty) {
      return productById.image;
    }
    // 2. Search by barcode
    final productByBarcode = inventory.findByBarcode(item.productId);
    if (productByBarcode != null && productByBarcode.image != null && productByBarcode.image!.isNotEmpty) {
      return productByBarcode.image;
    }
    // 3. Search by product name (case-insensitive)
    final trimmedName = item.productName.trim().toLowerCase();
    for (final prod in inventory.products) {
      if (prod.name.trim().toLowerCase() == trimmedName) {
        if (prod.image != null && prod.image!.isNotEmpty) {
          return prod.image;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: EmployeeInventoryController.instance,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: items.map((item) {
              final imageUrl = _getProductImage(item);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    ProductImage(
                      image: imageUrl,
                      width: 50,
                      height: 50,
                      borderRadius: 8,
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
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _OrderDetailsCard extends StatelessWidget {
  const _OrderDetailsCard({required this.order});
  final CustomerOrder order;

  void _showImageDialog(BuildContext context, String imageUrl) {
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

  @override
  Widget build(BuildContext context) {
    final isGcash = order.paymentMethod == PaymentMethod.gCash;
    final hasPaymentProof = isGcash && order.paymentProofUrl != null && order.paymentProofUrl!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _DetailRow(label: 'Order Type', value: order.orderType == OrderType.pickup ? 'Pickup' : 'Delivery'),
          _DetailRow(label: 'Payment Method', value: order.paymentMethod == PaymentMethod.cashOnDelivery ? 'Cash on Delivery' : 'GCash'),
          if (isGcash && order.paymentReferenceNumber != null && order.paymentReferenceNumber!.isNotEmpty)
            _DetailRow(label: 'GCash Ref #', value: order.paymentReferenceNumber!),
          _DetailRow(label: 'Payment Status', value: order.paymentStatus.name.toUpperCase()),
          if (order.deliveryAddress != null)
            _DetailRow(label: 'Customer Details', value: order.deliveryAddress!),
          if (hasPaymentProof) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showImageDialog(context, order.paymentProofUrl!),
                icon: const Icon(Icons.receipt_long, size: 18, color: AppColors.primaryOrange),
                label: const Text('View Customer Payment Screenshot', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryOrange),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
          if (isGcash && order.status == OrderStatus.cancelled) ...[
            const Divider(height: 24),
            _DetailRow(label: 'GCash Refund Name', value: order.gcashRefundName ?? 'Not Provided Yet'),
            _DetailRow(label: 'GCash Refund Phone', value: order.gcashRefundNumber ?? 'Not Provided Yet'),
            _DetailRow(
              label: 'Refund Status',
              value: order.refundStatus == 'refunded' ? 'REFUNDED' : 'PENDING REFUND',
              isBold: true,
            ),
          ],
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
    final riderName = order.deliveryPersonName ?? 'Store Rider';
    final riderRole = order.deliveryPersonRole ?? 'Employee';
    final riderCoords = DeliveryTrackingService.instance.getCachedTracking(order.orderId)?.riderLatLng ??
        DeliveryTrackingService.storeLocation;
    final destCoords = order.deliveryLatitude != null && order.deliveryLongitude != null
        ? LatLng(order.deliveryLatitude!, order.deliveryLongitude!)
        : DeliveryTrackingService.storeLocation;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmployeeDeliveryTrackingPage(order: order),
          ),
        );
      },
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: OsmDeliveryMap(
                riderLocation: riderCoords,
                destinationLocation: destCoords,
                riderName: riderName,
                riderRole: riderRole,
                destinationAddress: order.deliveryAddress ?? 'Customer Address',
                showControls: false,
                interactive: false,
              ),
            ),
            // Header info pill
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.two_wheeler, color: AppColors.primaryOrange, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Rider: $riderName ($riderRole)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.darkText),
                    ),
                  ],
                ),
              ),
            ),
            // Action button
            Positioned(
              bottom: 12,
              right: 12,
              child: Material(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(20),
                elevation: 3,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gps_fixed, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Tap to Track & Share GPS',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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

class _CancelledOrderBanner extends StatelessWidget {
  const _CancelledOrderBanner({this.reason});
  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFFCDD2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cancel_outlined, color: Colors.red, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Cancelled',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'This order was cancelled and is no longer active.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFC62828),
                  ),
                ),
                if (reason != null && reason!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reason: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFFB71C1C),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            reason!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB71C1C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


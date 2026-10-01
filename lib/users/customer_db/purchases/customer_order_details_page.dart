import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'customer_order_model.dart';
import 'customer_order_controller.dart';
import 'customer_delivery_tracking_widget.dart';

class CustomerOrderDetailsPage extends StatelessWidget {
  const CustomerOrderDetailsPage({super.key, required this.order});
  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CustomerOrderController.instance,
      builder: (context, _) {
        final currentOrder = CustomerOrderController.instance.getOrderById(order.orderId) ?? order;

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
                _OrderInfoSection(order: currentOrder),
                const SizedBox(height: 24),
                _StatusTimeline(currentStatus: currentOrder.status, orderType: currentOrder.orderType, cancellationReason: currentOrder.cancellationReason),
                if (currentOrder.status == OrderStatus.outForDelivery) ...[
                  const SizedBox(height: 24),
                  CustomerDeliveryTrackingWidget(order: currentOrder),
                ],
                const SizedBox(height: 24),
                const Text('Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _OrderItemsList(items: currentOrder.items),
                const SizedBox(height: 24),
                const Text('Order Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _OrderDetailsCard(order: currentOrder),
                const SizedBox(height: 24),
                _CancelOrderSection(order: currentOrder),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrderInfoSection extends StatelessWidget {
  const _OrderInfoSection({required this.order});
  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final isCancelled = order.status == OrderStatus.cancelled;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Order Number', style: TextStyle(color: AppColors.secondaryText)),
              Text(order.displayOrderId, style: const TextStyle(fontWeight: FontWeight.bold)),
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
              Text(
                order.status.label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCancelled ? Colors.red : AppColors.primaryOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.currentStatus, required this.orderType, this.cancellationReason});
  final OrderStatus currentStatus;
  final OrderType orderType;
  final String? cancellationReason;

  @override
  Widget build(BuildContext context) {
    if (currentStatus == OrderStatus.cancelled) {
      return _CancelledOrderBanner(reason: cancellationReason);
    }

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
                  'This order was cancelled and is no longer being processed.',
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

class _CancelOrderSection extends StatefulWidget {
  const _CancelOrderSection({required this.order});
  final CustomerOrder order;

  @override
  State<_CancelOrderSection> createState() => _CancelOrderSectionState();
}

class _CancelOrderSectionState extends State<_CancelOrderSection> {
  bool _isCancelling = false;

  final List<String> _cancellationReasons = const [
    'Changed my mind',
    'Ordered by mistake / Incorrect item',
    'Delivery or pickup takes too long',
    'Found cheaper price elsewhere',
    'Other reason',
  ];

  void _showCancelOrderDialog() {
    String selectedReason = _cancellationReasons.first;
    final customReasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cancel Order #${widget.order.displayOrderId}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please select a reason for cancelling this order. This will be recorded and sent to the store.',
                      style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      decoration: InputDecoration(
                        labelText: 'Reason for Cancellation *',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primaryOrange, width: 2),
                        ),
                      ),
                      items: _cancellationReasons.map((r) {
                        return DropdownMenuItem<String>(
                          value: r,
                          child: Text(r, style: const TextStyle(fontSize: 13, color: AppColors.darkText)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedReason = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: customReasonController,
                      maxLines: 2,
                      maxLength: 150,
                      decoration: InputDecoration(
                        labelText: selectedReason == 'Other reason'
                            ? 'Specify Reason *'
                            : 'Additional Note (Optional)',
                        hintText: 'e.g. Need to change delivery address',
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
                      validator: (v) {
                        if (selectedReason == 'Other reason') {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please specify your reason for cancelling';
                          }
                          if (v.trim().length < 3) {
                            return 'Reason must be at least 3 characters long';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Keep Order', style: TextStyle(color: AppColors.secondaryText)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  final extraNote = customReasonController.text.trim();
                  String finalReason = selectedReason;
                  if (selectedReason == 'Other reason') {
                    finalReason = extraNote;
                  } else if (extraNote.isNotEmpty) {
                    finalReason = '$selectedReason ($extraNote)';
                  }

                  Navigator.pop(dialogCtx);
                  setState(() => _isCancelling = true);

                  // Live verification: Only pending orders can be cancelled
                  final liveOrder = CustomerOrderController.instance.getOrderById(widget.order.orderId);
                  if (liveOrder != null && liveOrder.status != OrderStatus.pending) {
                    if (mounted) {
                      setState(() => _isCancelling = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Cannot cancel order: status has already been updated to "${liveOrder.status.label}".',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  final success = await CustomerOrderController.instance.cancelOrder(
                    widget.order.orderId,
                    reason: finalReason,
                  );
                  if (mounted) {
                    setState(() => _isCancelling = false);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Order #${widget.order.displayOrderId} has been successfully cancelled.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to cancel order. Only pending orders can be cancelled.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Confirm Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.order.status;

    // If order is already cancelled, don't show the cancel button
    if (status == OrderStatus.cancelled) {
      return const SizedBox.shrink();
    }

    // Only pending orders can be cancelled
    final bool canCancel = status == OrderStatus.pending;

    if (canCancel) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isCancelling ? null : _showCancelOrderDialog,
          icon: _isCancelling
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                )
              : const Icon(Icons.cancel_outlined, color: Colors.red),
          label: Text(
            _isCancelling ? 'Cancelling Order...' : 'Cancel Order',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.red.withValues(alpha: 0.04),
          ),
        ),
      );
    }

    // Once status has changed, button is disabled ("hindi na pwedeng pindutin")
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: null, // Disabled: customer cannot click
          icon: const Icon(Icons.block, color: AppColors.placeholderColor),
          label: const Text(
            'Cancel Order',
            style: TextStyle(
              color: AppColors.placeholderColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.borderColor, width: 1.2),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.grey.shade100,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Cancellation is unavailable because order is already ${status.label.toLowerCase()}. Only pending orders can be cancelled.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

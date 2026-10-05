import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/gcash_ocr_helper.dart';
import '../../../shared/utils/top_notification.dart';
import '../../../shared/widgets/product_image.dart';
import '../../employee_db/employee_inventory_controller.dart';
import '../../employee_db/orders/employee_orders_controller.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
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
                _StatusTimeline(order: currentOrder),
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
  const _StatusTimeline({required this.order});
  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    if (order.status == OrderStatus.cancelled) {
      return _CancelledOrderBanner(order: order);
    }

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
                          Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${item.quantity} x ₱${item.price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text('₱${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
    final hasPaymentProof = isGcash &&
        order.paymentProofUrl != null &&
        order.paymentProofUrl!.isNotEmpty;
    final hasRefNumber = isGcash &&
        order.paymentReferenceNumber != null &&
        order.paymentReferenceNumber!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _DetailRow(label: 'Order Type', value: order.orderType == OrderType.pickup ? 'Pickup' : 'Delivery'),
          _DetailRow(label: 'Payment Method', value: order.paymentMethod == PaymentMethod.cashOnDelivery ? 'Cash on Delivery' : 'GCash'),
          if (hasRefNumber)
            _DetailRow(label: 'GCash Ref #', value: GcashOcrHelper.formatRefNumber(order.paymentReferenceNumber!)),
          _DetailRow(label: 'Payment Status', value: order.paymentStatus.name.toUpperCase()),
          if (order.deliveryAddress != null)
            _DetailRow(label: 'Delivery Address', value: order.deliveryAddress!),
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



class _CancelledOrderBanner extends StatefulWidget {
  const _CancelledOrderBanner({required this.order});
  final CustomerOrder order;

  @override
  State<_CancelledOrderBanner> createState() => _CancelledOrderBannerState();
}

class _CancelledOrderBannerState extends State<_CancelledOrderBanner> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;

  void _showProofDialog(BuildContext context, String imageUrl) {
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

  Future<void> _submitGcashDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    await EmployeeOrderController.instance.submitGcashRefundDetails(
      widget.order.orderId,
      name: name,
      phone: phone,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      TopNotification.show(
        context,
        'GCash refund details submitted successfully! Owner will process your refund soon.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isGcash = order.paymentMethod == PaymentMethod.gCash;
    final hasGcashDetails = order.gcashRefundName != null &&
        order.gcashRefundName!.isNotEmpty &&
        order.gcashRefundNumber != null &&
        order.gcashRefundNumber!.isNotEmpty;
    final isRefunded = order.refundStatus == 'refunded';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    if (order.cancellationReason != null && order.cancellationReason!.isNotEmpty) ...[
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
                                order.cancellationReason!,
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
          if (isGcash) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFEF9A9A)),
            const SizedBox(height: 8),
            if (!hasGcashDetails) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Action Required for GCash Refund',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Please enter your GCash Registered Name and Mobile Number so the store owner can refund your ₱${order.totalAmount.toStringAsFixed(2)}:',
                        style: const TextStyle(fontSize: 12, color: AppColors.darkText),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'GCash Registered Name *',
                          hintText: 'e.g. Juan Dela Cruz',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter GCash account name';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'GCash Mobile Number *',
                          hintText: 'e.g. 09171234567',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter GCash mobile number';
                          final clean = val.trim().replaceAll(RegExp(r'\D'), '');
                          if (clean.length != 11 || !clean.startsWith('09')) {
                            return 'Enter valid 11-digit mobile number starting with 09';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitGcashDetails,
                          icon: _isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(_isSubmitting ? 'Submitting...' : 'Submit GCash Details for Refund'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isRefunded ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isRefunded ? Colors.green.shade300 : Colors.orange.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isRefunded ? Icons.check_circle_rounded : Icons.hourglass_bottom_rounded,
                          color: isRefunded ? Colors.green : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isRefunded ? 'GCash Refund Completed' : 'GCash Refund Pending',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isRefunded ? Colors.green.shade900 : Colors.orange.shade900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Account Name: ${order.gcashRefundName}\n'
                      'Mobile Number: ${order.gcashRefundNumber}\n'
                      'Refund Amount: ₱${order.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.4),
                    ),
                    if (isRefunded && order.paymentReferenceNumber != null && order.paymentReferenceNumber!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified, color: Colors.green.shade700, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'GCash Refund Ref #: ${GcashOcrHelper.formatRefNumber(order.paymentReferenceNumber!)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (isRefunded && order.refundProofUrl != null && order.refundProofUrl!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showProofDialog(context, order.refundProofUrl!),
                          icon: const Icon(Icons.receipt_long, size: 18, color: Colors.green),
                          label: const Text('View Refund Proof Screenshot', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.green),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
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

  void _showCancelOrderDialog() {
    final formKey = GlobalKey<FormState>();
    final reasonController = TextEditingController();
    final gcashNameController = TextEditingController();
    final gcashPhoneController = TextEditingController();

    final isGcash = widget.order.paymentMethod == PaymentMethod.gCash;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text('Cancel Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                Text(
                  'Are you sure you want to cancel Order #${widget.order.displayOrderId}? This action cannot be undone.',
                  style: const TextStyle(color: AppColors.darkText, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Reason for Cancellation *',
                    hintText: 'e.g. Changed my mind, Duplicate order',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please state cancellation reason';
                    return null;
                  },
                ),
                if (isGcash) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'GCash Refund Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryOrange),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Provide your GCash details so the store owner can process your refund:',
                    style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: gcashNameController,
                    decoration: InputDecoration(
                      labelText: 'GCash Registered Name *',
                      hintText: 'e.g. Juan Dela Cruz',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Please enter GCash account name';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: gcashPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'GCash Mobile Number *',
                      hintText: 'e.g. 09171234567',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Please enter GCash mobile number';
                      final clean = val.trim().replaceAll(RegExp(r'\D'), '');
                      if (clean.length != 11 || !clean.startsWith('09')) {
                        return 'Enter valid 11-digit mobile number starting with 09';
                      }
                      return null;
                    },
                  ),
                ],
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

              final reason = reasonController.text.trim();
              final gcashName = gcashNameController.text.trim();
              final gcashPhone = gcashPhoneController.text.trim();

              Navigator.pop(dialogCtx);
              setState(() => _isCancelling = true);

              // Live verification: Only pending orders can be cancelled
              final liveOrder = CustomerOrderController.instance.getOrderById(widget.order.orderId);
              if (liveOrder != null && liveOrder.status != OrderStatus.pending) {
                if (mounted) {
                  setState(() => _isCancelling = false);
                  TopNotification.show(
                    context,
                    'Cannot cancel order: status has already been updated to "${liveOrder.status.label}".',
                    isError: true,
                  );
                }
                return;
              }

              final success = await EmployeeOrderController.instance.cancelOrder(
                widget.order.orderId,
                reason: reason,
                gcashRefundName: isGcash ? gcashName : null,
                gcashRefundNumber: isGcash ? gcashPhone : null,
              );

              if (mounted) {
                setState(() => _isCancelling = false);
                if (success) {
                  TopNotification.show(
                    context,
                    'Order #${widget.order.displayOrderId} has been successfully cancelled.',
                  );
                } else {
                  TopNotification.show(
                    context,
                    'Failed to cancel order. Only pending orders can be cancelled.',
                    isError: true,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes, Cancel Order'),
          ),
        ],
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

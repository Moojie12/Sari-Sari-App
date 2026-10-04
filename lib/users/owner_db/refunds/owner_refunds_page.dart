import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
import '../../employee_db/orders/employee_orders_controller.dart';

class OwnerRefundsPage extends StatefulWidget {
  const OwnerRefundsPage({super.key});

  @override
  State<OwnerRefundsPage> createState() => _OwnerRefundsPageState();
}

class _OwnerRefundsPageState extends State<OwnerRefundsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final EmployeeOrderController _ordersController = EmployeeOrderController.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('GCash Refund Section', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryOrange,
          labelColor: AppColors.primaryOrange,
          unselectedLabelColor: AppColors.secondaryText,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            ListenableBuilder(
              listenable: _ordersController,
              builder: (context, _) {
                final count = _ordersController.pendingRefundOrders.length;
                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Pending Refunds'),
                      if (count > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const Tab(text: 'Completed Refunds'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: _ordersController,
        builder: (context, _) {
          final pending = _ordersController.pendingRefundOrders;
          final completed = _ordersController.completedRefundOrders;

          return TabBarView(
            controller: _tabController,
            children: [
              _RefundsListView(orders: pending, isPending: true),
              _RefundsListView(orders: completed, isPending: false),
            ],
          );
        },
      ),
    );
  }
}

class _RefundsListView extends StatelessWidget {
  const _RefundsListView({
    required this.orders,
    required this.isPending,
  });

  final List<CustomerOrder> orders;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.check_circle_outline_rounded : Icons.history_rounded,
              size: 64,
              color: AppColors.placeholderColor,
            ),
            const SizedBox(height: 16),
            Text(
              isPending ? 'No Pending GCash Refunds' : 'No Completed GCash Refunds',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText),
            ),
            const SizedBox(height: 6),
            Text(
              isPending
                  ? 'All cancelled GCash pre-orders have been refunded.'
                  : 'Processed GCash refunds will appear here.',
              style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return _RefundOrderCard(order: orders[index], isPending: isPending);
      },
    );
  }
}

class _RefundOrderCard extends StatefulWidget {
  const _RefundOrderCard({
    required this.order,
    required this.isPending,
  });

  final CustomerOrder order;
  final bool isPending;

  @override
  State<_RefundOrderCard> createState() => _RefundOrderCardState();
}

class _RefundOrderCardState extends State<_RefundOrderCard> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    TopNotification.show(context, '$label copied to clipboard!');
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, color: Colors.white, size: 64),
                      SizedBox(height: 16),
                      Text('Failed to load image', style: TextStyle(color: Colors.white)),
                    ],
                  ),
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

  Future<void> _showManualGcashDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: widget.order.gcashRefundName ?? '');
    final phoneController = TextEditingController(text: widget.order.gcashRefundNumber ?? '');

    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: AppColors.primaryOrange),
            SizedBox(width: 8),
            Text('Customer GCash Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter or update customer GCash details provided via call or chat:',
                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'GCash Registered Name *',
                  filled: true,
                  fillColor: AppColors.lightPeach,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter name';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'GCash Mobile Number *',
                  filled: true,
                  fillColor: AppColors.lightPeach,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter mobile number';
                  final clean = val.trim().replaceAll(RegExp(r'\D'), '');
                  if (clean.length != 11 || !clean.startsWith('09')) {
                    return 'Enter valid 11-digit mobile number starting with 09';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              Navigator.pop(dialogCtx);

              await EmployeeOrderController.instance.submitGcashRefundDetails(
                widget.order.orderId,
                name: name,
                phone: phone,
              );
              if (mounted) {
                TopNotification.show(context, 'Customer GCash details updated successfully!');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save GCash Details'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadReceipt() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1024,
    );

    if (image == null) return;

    final file = File(image.path);
    final bytes = await file.readAsBytes();
    final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Confirm Refund Proof', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to attach this receipt image and complete the ₱${widget.order.totalAmount.toStringAsFixed(2)} refund for Order #${widget.order.displayOrderId}?',
              style: const TextStyle(fontSize: 13, color: AppColors.darkText),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                file,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm & Submit Refund'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isUploading = true);

      await EmployeeOrderController.instance.submitRefundProof(
        widget.order.orderId,
        proofUrl: base64Image,
      );

      if (mounted) {
        setState(() => _isUploading = false);
        TopNotification.show(context, 'Refund proof uploaded and confirmed for Order #${widget.order.displayOrderId}!');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final hasGcashDetails = order.gcashRefundName != null &&
        order.gcashRefundName!.isNotEmpty &&
        order.gcashRefundNumber != null &&
        order.gcashRefundNumber!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${order.displayOrderId}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.darkText),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isPending ? Colors.orange.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.isPending ? Colors.orange.shade300 : Colors.green.shade300),
                ),
                child: Text(
                  widget.isPending ? 'PENDING REFUND' : 'REFUNDED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.isPending ? Colors.orange.shade900 : Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Order Date: ${order.formattedDate} • Type: ${order.orderType.name.toUpperCase()}',
            style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Customer Name:', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
              Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Amount to Refund:', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
              Text(
                '₱${order.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red),
              ),
            ],
          ),
          if (order.cancellationReason != null && order.cancellationReason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Cancellation Reason:', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                Expanded(
                  child: Text(
                    order.cancellationReason!,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasGcashDetails ? AppColors.lightPeach.withValues(alpha: 0.5) : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: hasGcashDetails ? AppColors.borderColor : Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Customer GCash Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: hasGcashDetails ? AppColors.darkText : Colors.red.shade900,
                      ),
                    ),
                    InkWell(
                      onTap: _showManualGcashDialog,
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 14, color: AppColors.primaryOrange),
                          const SizedBox(width: 2),
                          Text(
                            hasGcashDetails ? 'Edit' : 'Add Details',
                            style: const TextStyle(color: AppColors.primaryOrange, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!hasGcashDetails) ...[
                  const Text(
                    'Customer has not submitted GCash details yet. Tap "Add Details" if received via call/chat.',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Name: ${order.gcashRefundName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: AppColors.primaryOrange),
                        onPressed: () => _copyToClipboard(context, order.gcashRefundName!, 'GCash Name'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Mobile #: ${order.gcashRefundNumber}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: AppColors.primaryOrange),
                        onPressed: () => _copyToClipboard(context, order.gcashRefundNumber!, 'GCash Number'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (widget.isPending) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickAndUploadReceipt,
                icon: _isUploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(_isUploading ? 'Uploading Proof...' : 'Upload GCash Refund Screenshot'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ] else ...[
            if (order.refundProofUrl != null && order.refundProofUrl!.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showImageDialog(context, order.refundProofUrl!),
                  icon: const Icon(Icons.receipt_long, size: 18, color: Colors.green),
                  label: const Text('View Uploaded Refund Receipt', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

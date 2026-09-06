import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../customer_db/purchases/customer_order_model.dart';
import 'employee_order_details_page.dart';
import 'employee_orders_controller.dart';

class EmployeeOrdersPage extends StatefulWidget {
  const EmployeeOrdersPage({super.key, required this.controller});

  final EmployeeOrderController controller;

  @override
  State<EmployeeOrdersPage> createState() => _EmployeeOrdersPageState();
}

class _EmployeeOrdersPageState extends State<EmployeeOrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text(
                'Orders',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: Text(
                'Manage incoming customer orders.',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                ),
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryOrange,
              unselectedLabelColor: AppColors.secondaryText,
              indicatorColor: AppColors.primaryOrange,
              tabs: const [
                Tab(text: 'Active'),
                Tab(text: 'Completed'),
              ],
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _OrderList(
                        orders: widget.controller.activeOrders,
                        controller: widget.controller,
                      ),
                      _OrderList(
                        orders: widget.controller.completedOrders,
                        controller: widget.controller,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders, required this.controller});
  final List<CustomerOrder> orders;
  final EmployeeOrderController controller;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(
        child: Text(
          'No orders found.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _OrderCard(order: order, controller: controller);
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.controller});
  final CustomerOrder order;
  final EmployeeOrderController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmployeeOrderDetailsPage(order: order, controller: controller),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.orderId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.darkText,
                  ),
                ),
                _StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Customer: ${order.customerName}${order.orderType == OrderType.pickup ? " (Walk-in)" : ""}',
              style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Divider(height: 24),
            ...order.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Text('${item.quantity}x ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Expanded(child: Text(item.productName, style: const TextStyle(fontSize: 13))),
                  Text('₱${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                ],
              ),
            )),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '₱${order.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (order.status != OrderStatus.completed && order.status != OrderStatus.cancelled) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showStatusUpdateDialog(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryOrange,
                        side: const BorderSide(color: AppColors.primaryOrange),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Update Status'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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

  void _showStatusUpdateDialog(BuildContext context) {
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
              const SizedBox(height: 8),
              Text(
                'Update the progress of Order #${order.orderId}',
                style: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
              ),
              const SizedBox(height: 24),
              StatusTimelinePicker(
                order: order,
                onStatusSelected: (newStatus) {
                  _showConfirmationDialog(
                    context: context,
                    title: 'Update Status',
                    message: 'Are you sure you want to change the status to "${newStatus.label}"?',
                    onConfirm: () {
                      controller.updateOrderStatus(order.orderId, newStatus);
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
                      message: 'Are you sure you want to cancel Order #${order.orderId}? This action cannot be undone.',
                      confirmColor: Colors.red,
                      onConfirm: () {
                        controller.updateOrderStatus(order.orderId, OrderStatus.cancelled);
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
}

class StatusTimelinePicker extends StatelessWidget {
  const StatusTimelinePicker({required this.order, required this.onStatusSelected});
  final CustomerOrder order;
  final ValueChanged<OrderStatus> onStatusSelected;

  @override
  Widget build(BuildContext context) {
    final statuses = _getTimelineStatuses();
    final currentIndex = statuses.indexOf(order.status);

    return Column(
      children: List.generate(statuses.length, (index) {
        final status = statuses[index];
        final isCompleted = index <= currentIndex;
        final isCurrent = index == currentIndex;
        final isNext = index == currentIndex + 1;
        final isLast = index == statuses.length - 1;

        return IntrinsicHeight(
          child: InkWell(
            onTap: (isNext || (index > currentIndex && order.status != OrderStatus.completed))
                ? () => onStatusSelected(status)
                : null,
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? AppColors.primaryOrange
                            : (isNext ? AppColors.primaryOrange.withValues(alpha: 0.2) : Colors.transparent),
                        border: Border.all(
                          color: isCompleted ? AppColors.primaryOrange : AppColors.placeholderColor,
                          width: 2,
                        ),
                      ),
                      child: isCompleted
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.label,
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                            fontSize: 15,
                            color: isCompleted
                                ? AppColors.darkText
                                : (isNext ? AppColors.primaryOrange : AppColors.secondaryText),
                          ),
                        ),
                        if (isNext)
                          const Text(
                            'Tap to mark as active',
                            style: TextStyle(color: AppColors.primaryOrange, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                ),
                if (isNext)
                  const Icon(Icons.chevron_right, color: AppColors.primaryOrange),
              ],
            ),
          ),
        );
      }),
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
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

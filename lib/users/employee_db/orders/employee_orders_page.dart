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
    _tabController = TabController(length: 3, vsync: this);
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
                Tab(text: 'Demand'),
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
                      _DemandList(
                        demandItems: widget.controller.demandItems,
                        controller: widget.controller,
                      ),
                      _ActiveOrdersView(
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

class _DemandList extends StatelessWidget {
  const _DemandList({required this.demandItems, required this.controller});
  final List<ProductDemand> demandItems;
  final EmployeeOrderController controller;

  @override
  Widget build(BuildContext context) {
    if (demandItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.placeholderColor),
              SizedBox(height: 16),
              Text(
                'No pending product demand.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    // Sort items: Unmarked first, then marked
    final sortedItems = List<ProductDemand>.from(demandItems)
      ..sort((a, b) {
        if (a.isMarked == b.isMarked) return 0;
        return a.isMarked ? 1 : -1;
      });

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: sortedItems.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${demandItems.length} Products to Collect',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryText),
                ),
                TextButton.icon(
                  onPressed: () => _showBulkActionDialog(context),
                  icon: Icon(
                    demandItems.every((item) => item.isMarked) ? Icons.refresh : Icons.done_all,
                    size: 18,
                  ),
                  label: Text(
                    demandItems.every((item) => item.isMarked) ? 'Reset List' : 'Mark All',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryOrange,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
          );
        }
        final demand = sortedItems[index - 1];
        return _DemandItemCard(demand: demand, controller: controller);
      },
    );
  }

  void _showBulkActionDialog(BuildContext context) {
    final allMarked = demandItems.every((item) => item.isMarked);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(allMarked ? 'Reset All Marks?' : 'Mark All as Collected?'),
        content: Text(
          allMarked
              ? 'Are you sure you want to mark all products as NOT collected?'
              : 'Are you sure you want to mark all items in this list as collected?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              controller.markAllDemand(!allMarked);
              Navigator.pop(context);
            },
            child: Text(
              'Confirm',
              style: TextStyle(
                color: allMarked ? Colors.red : AppColors.primaryOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemandItemCard extends StatelessWidget {
  const _DemandItemCard({required this.demand, required this.controller});
  final ProductDemand demand;
  final EmployeeOrderController controller;

  void _handleToggle(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(demand.isMarked ? 'Unmark Product?' : 'Mark as Collected?'),
        content: Text(
          demand.isMarked
              ? 'Are you sure you want to mark "${demand.productName}" as NOT collected yet?'
              : 'Have you collected all ${demand.totalQuantity} units of "${demand.productName}"?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              controller.toggleDemandMark(demand.productId);
              Navigator.pop(context);
            },
            child: Text(
              'Confirm',
              style: TextStyle(
                color: demand.isMarked ? Colors.red : AppColors.primaryOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: demand.isMarked ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: demand.isMarked ? AppColors.primaryOrange.withValues(alpha: 0.2) : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleToggle(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Opacity(
              opacity: demand.isMarked ? 0.6 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: demand.isMarked
                              ? Colors.grey.shade200
                              : AppColors.primaryOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          demand.isMarked ? Icons.check_circle : Icons.shopping_basket,
                          color: demand.isMarked ? Colors.green : AppColors.primaryOrange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              demand.productName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.darkText,
                                decoration: demand.isMarked ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            Text(
                              'Requested by ${demand.orderIds.length} orders',
                              style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: demand.isMarked ? Colors.grey : AppColors.primaryOrange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'x${demand.totalQuantity}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (demand.orderIds.isNotEmpty) ...[
                    const Divider(height: 24),
                    const Text(
                      'Orders to distribute to:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: demand.orderIds.map((id) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child: Text(
                          '#$id',
                          style: const TextStyle(fontSize: 10, color: AppColors.secondaryText),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveOrdersView extends StatelessWidget {
  const _ActiveOrdersView({required this.controller});
  final EmployeeOrderController controller;

  @override
  Widget build(BuildContext context) {
    final activeOrders = controller.activeOrders;
    final pickupOrders = activeOrders.where((o) => o.orderType == OrderType.pickup).toList();
    final deliveryOrders = activeOrders.where((o) => o.orderType == OrderType.delivery).toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.lightBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.secondaryText,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_pin_circle, size: 16),
                      const SizedBox(width: 8),
                      Text('Pickup (${pickupOrders.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_shipping, size: 16),
                      const SizedBox(width: 8),
                      Text('Delivery (${deliveryOrders.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _OrderList(orders: pickupOrders, controller: controller),
                _OrderList(orders: deliveryOrders, controller: controller),
              ],
            ),
          ),
        ],
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

    // Sort orders so Pending/Urgent ones are at the top
    final sortedOrders = List<CustomerOrder>.from(orders)
      ..sort((a, b) => a.status.index.compareTo(b.status.index));

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: sortedOrders.length,
      itemBuilder: (context, index) {
        final order = sortedOrders[index];
        return _OrderCard(order: order, controller: controller);
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.controller});
  final CustomerOrder order;
  final EmployeeOrderController controller;

  OrderStatus? _getNextStatus() {
    switch (order.status) {
      case OrderStatus.pending:
        return OrderStatus.confirmed;
      case OrderStatus.confirmed:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return order.orderType == OrderType.pickup
            ? OrderStatus.readyForPickup
            : OrderStatus.readyForShipment;
      case OrderStatus.readyForShipment:
        return OrderStatus.outForDelivery;
      case OrderStatus.readyForPickup:
      case OrderStatus.outForDelivery:
      case OrderStatus.delivered:
        return OrderStatus.completed;
      default:
        return null;
    }
  }

  void _handleNextAction(BuildContext context, OrderStatus nextStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Order Status'),
        content: Text('Mark Order #${order.orderId} as "${nextStatus.label}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              controller.updateOrderStatus(order.orderId, nextStatus);
              Navigator.pop(context);
            },
            child: const Text('Confirm', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextStatus = _getNextStatus();
    final isCompletedOrCancelled = order.status == OrderStatus.completed || order.status == OrderStatus.cancelled;

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
          border: order.status == OrderStatus.pending 
              ? Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _OrderTypeIcon(type: order.orderType),
                    const SizedBox(width: 8),
                    Text(
                      '#${order.orderId}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.darkText,
                      ),
                    ),
                  ],
                ),
                _StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: AppColors.secondaryText),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.customerName,
                    style: const TextStyle(color: AppColors.darkText, fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  order.formattedDate,
                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
                ),
              ],
            ),
            const Divider(height: 24),
            ...order.items.take(2).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Text('${item.quantity}x ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondaryText)),
                  Expanded(child: Text(item.productName, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            )),
            if (order.items.length > 2)
              Text('+${order.items.length - 2} more items', style: const TextStyle(fontSize: 11, color: AppColors.secondaryText, fontStyle: FontStyle.italic)),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Amount', style: TextStyle(color: AppColors.secondaryText, fontSize: 11)),
                    Text(
                      '₱${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                if (!isCompletedOrCancelled && nextStatus != null)
                  Flexible(
                    child: ElevatedButton(
                      onPressed: () => _handleNextAction(context, nextStatus),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              nextStatus == OrderStatus.readyForShipment 
                                  ? 'Set to Ready for Shipment'
                                  : nextStatus == OrderStatus.readyForPickup
                                      ? 'Ready for Pickup'
                                      : 'Set to ${nextStatus.label}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward, size: 14),
                        ],
                      ),
                    ),
                  )
                else if (!isCompletedOrCancelled)
                  OutlinedButton(
                    onPressed: () => _showStatusUpdateDialog(context),
                    child: const Text('Update'),
                  ),
              ],
            ),
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
  const StatusTimelinePicker({super.key, required this.order, required this.onStatusSelected});
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
    IconData icon;
    switch (status) {
      case OrderStatus.pending:
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        break;
      case OrderStatus.confirmed:
        color = Colors.blue;
        icon = Icons.check_circle_outline;
        break;
      case OrderStatus.preparing:
        color = Colors.amber;
        icon = Icons.restaurant;
        break;
      case OrderStatus.readyForPickup:
        color = Colors.indigo;
        icon = Icons.shopping_bag_outlined;
        break;
      case OrderStatus.readyForShipment:
        color = Colors.indigo;
        icon = Icons.inventory_2_outlined;
        break;
      case OrderStatus.outForDelivery:
        color = Colors.purple;
        icon = Icons.delivery_dining;
        break;
      case OrderStatus.delivered:
      case OrderStatus.completed:
        color = Colors.green;
        icon = Icons.done_all;
        break;
      case OrderStatus.cancelled:
        color = Colors.red;
        icon = Icons.cancel_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status.label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTypeIcon extends StatelessWidget {
  const _OrderTypeIcon({required this.type});
  final OrderType type;

  @override
  Widget build(BuildContext context) {
    final bool isPickup = type == OrderType.pickup;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Icon(
        isPickup ? Icons.person_pin_circle : Icons.local_shipping,
        size: 16,
        color: AppColors.secondaryText,
      ),
    );
  }
}

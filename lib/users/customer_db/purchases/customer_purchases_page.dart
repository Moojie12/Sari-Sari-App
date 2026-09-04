import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_controller.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_details_page.dart';

class CustomerPurchasesPage extends StatefulWidget {
  const CustomerPurchasesPage({super.key, required this.orderController});
  final CustomerOrderController orderController;

  @override
  State<CustomerPurchasesPage> createState() => _CustomerPurchasesPageState();
}

class _CustomerPurchasesPageState extends State<CustomerPurchasesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Text(
                'My Purchases',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppColors.primaryOrange,
                labelColor: AppColors.primaryOrange,
                unselectedLabelColor: AppColors.secondaryText,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'To Pay'),
                  Tab(text: 'To Ship'),
                  Tab(text: 'To Receive'),
                  Tab(text: 'Completed'),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.orderController,
                builder: (context, _) {
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _OrderList(
                        orders: widget.orderController.getOrdersByStatus([OrderStatus.pending]),
                        emptyMessage: 'No orders waiting for payment.',
                      ),
                      _OrderList(
                        orders: widget.orderController.getOrdersByStatus([
                          OrderStatus.confirmed,
                          OrderStatus.preparing,
                          OrderStatus.readyForShipment,
                          OrderStatus.readyForPickup,
                        ]),
                        emptyMessage: 'No orders waiting for shipment.',
                      ),
                      _OrderList(
                        orders: widget.orderController.getOrdersByStatus([OrderStatus.outForDelivery]),
                        emptyMessage: 'No orders to receive.',
                      ),
                      _OrderList(
                        orders: widget.orderController.getOrdersByStatus([
                          OrderStatus.delivered,
                          OrderStatus.completed,
                        ]),
                        emptyMessage: 'No completed orders yet.',
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
  const _OrderList({required this.orders, required this.emptyMessage});
  final List<CustomerOrder> orders;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_bag_outlined, size: 48, color: AppColors.placeholderColor),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: const TextStyle(color: AppColors.secondaryText),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final order = orders[index];
        return _OrderCard(
          order: order,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CustomerOrderDetailsPage(order: order),
              ),
            );
          },
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});
  final CustomerOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  order.formattedDate,
                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                ),
              ],
            ),
            const Divider(height: 24),
            ...order.items.take(2).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${item.productName} x${item.quantity}',
                style: const TextStyle(color: AppColors.secondaryText),
              ),
            )),
            if (order.items.length > 2)
              const Text('...', style: TextStyle(color: AppColors.secondaryText)),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total: ₱${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${order.status.label}',
                      style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: onTap,
                  child: const Text('View Details', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


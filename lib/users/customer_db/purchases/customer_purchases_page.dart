import 'package:flutter/material.dart';
import 'package:sari_sari/core/theme/app_colors.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_controller.dart';
import 'customer_order_model.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_details_page.dart';
import 'package:sari_sari/shared/widgets/skeleton.dart';
import 'package:sari_sari/shared/widgets/app_pagination.dart';
import 'package:sari_sari/shared/utils/gcash_ocr_helper.dart';

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
    _tabController = TabController(length: 5, vsync: this);
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.primaryOrange,
                labelColor: AppColors.primaryOrange,
                unselectedLabelColor: AppColors.secondaryText,
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: const [
                  Tab(text: 'To Pay'),
                  Tab(text: 'To Ship'),
                  Tab(text: 'To Receive'),
                  Tab(text: 'Completed'),
                  Tab(text: 'Cancelled'),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.orderController,
                builder: (context, _) {
                  if (widget.orderController.isLoading && widget.orderController.orders.isEmpty) {
                    return ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: 3,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) => const OrderCardSkeleton(),
                    );
                  }
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _OrderList(
                        orders: widget.orderController.getOrdersByStatus([OrderStatus.pending]),
                        emptyMessage: 'No orders waiting for payment.',
                        onRefresh: widget.orderController.refresh,
                      ),
                      _OrderList(
                        orders: widget.orderController.getOrdersByStatus([
                          OrderStatus.confirmed,
                          OrderStatus.preparing,
                          OrderStatus.readyForShipment,
                          OrderStatus.readyForPickup,
                        ]),
                        emptyMessage: 'No orders waiting for shipment.',
                        onRefresh: widget.orderController.refresh,
                      ),
                      _OrderList(
                        orders: widget.orderController.getOrdersByStatus([OrderStatus.outForDelivery]),
                        emptyMessage: 'No orders to receive.',
                        onRefresh: widget.orderController.refresh,
                      ),
                      _OrderList(
                        orders: widget.orderController.getOrdersByStatus([
                          OrderStatus.delivered,
                          OrderStatus.completed,
                        ]),
                        emptyMessage: 'No completed orders yet.',
                        onRefresh: widget.orderController.refresh,
                      ),
                      _OrderList(
                        orders: widget.orderController.getOrdersByStatus([OrderStatus.cancelled]),
                        emptyMessage: 'No cancelled orders.',
                        onRefresh: widget.orderController.refresh,
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

class _OrderList extends StatefulWidget {
  const _OrderList({
    required this.orders,
    required this.emptyMessage,
    required this.onRefresh,
  });
  final List<CustomerOrder> orders;
  final String emptyMessage;
  final RefreshCallback onRefresh;

  @override
  State<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<_OrderList> {
  static const int _itemsPerPage = 10;
  int _currentPage = 1;

  @override
  void didUpdateWidget(covariant _OrderList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final totalPages = (widget.orders.length / _itemsPerPage).ceil().clamp(1, 9999);
    if (_currentPage > totalPages) {
      setState(() => _currentPage = totalPages);
    }
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orders.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primaryOrange,
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 48, color: AppColors.placeholderColor),
                  const SizedBox(height: 12),
                  Text(
                    widget.emptyMessage,
                    style: const TextStyle(color: AppColors.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final totalCount = widget.orders.length;
    final totalPages = (totalCount / _itemsPerPage).ceil().clamp(1, 9999);
    final activePage = _currentPage > totalPages ? totalPages : (_currentPage < 1 ? 1 : _currentPage);
    final startIndex = (activePage - 1) * _itemsPerPage;
    final pagedCount = (totalCount - startIndex).clamp(0, _itemsPerPage);
    final pagedOrders = widget.orders.skip(startIndex).take(pagedCount).toList();

    return RefreshIndicator(
      color: AppColors.primaryOrange,
      onRefresh: widget.onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        itemCount: pagedOrders.length + (totalPages > 1 ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index < pagedOrders.length) {
            final order = pagedOrders[index];
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
          }
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            child: Center(
              child: AppPagination(
                currentPage: activePage,
                totalPages: totalPages,
                onPageChanged: _onPageChanged,
              ),
            ),
          );
        },
      ),
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
                  'Order #${order.displayOrderId}',
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
                '${item.productName} x${item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(2)}',
                style: const TextStyle(color: AppColors.secondaryText),
              ),
            )),
            if (order.items.length > 2)
              const Text('...', style: TextStyle(color: AppColors.secondaryText)),
            if (order.status == OrderStatus.cancelled &&
                order.cancellationReason != null &&
                order.cancellationReason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'Reason: ${order.cancellationReason}',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade900, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (order.status == OrderStatus.cancelled && order.refundStatus == 'refunded') ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (order.refundRefNumber ?? order.paymentReferenceNumber) != null &&
                                (order.refundRefNumber ?? order.paymentReferenceNumber)!.isNotEmpty
                            ? 'Refunded via GCash · Ref #${GcashOcrHelper.formatRefNumber((order.refundRefNumber ?? order.paymentReferenceNumber)!)}'
                            : 'Refunded via GCash',
                        style: TextStyle(fontSize: 11, color: Colors.green.shade900, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                      style: TextStyle(
                        fontSize: 12,
                        color: order.status == OrderStatus.cancelled ? Colors.red : AppColors.secondaryText,
                        fontWeight: order.status == OrderStatus.cancelled ? FontWeight.bold : FontWeight.normal,
                      ),
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

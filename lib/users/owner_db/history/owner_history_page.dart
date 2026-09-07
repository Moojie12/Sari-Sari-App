import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../../customer_db/purchases/customer_order_model.dart';
import '../../employee_db/inventory/employee_dummy_products.dart';
import '../../employee_db/orders/employee_order_details_page.dart';
import '../../employee_db/orders/employee_orders_controller.dart';
import '../../employee_db/pos/employee_pos_controller.dart';
import '../../employee_db/pos/employee_receipt_page.dart';

class OwnerTransactionHistoryPage extends StatefulWidget {
  const OwnerTransactionHistoryPage({super.key});

  @override
  State<OwnerTransactionHistoryPage> createState() => _OwnerTransactionHistoryPageState();
}

class _OwnerTransactionHistoryPageState extends State<OwnerTransactionHistoryPage> with SingleTickerProviderStateMixin {
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
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        foregroundColor: AppColors.darkText,
        title: const Text('Transaction History',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryOrange,
          unselectedLabelColor: AppColors.secondaryText,
          indicatorColor: AppColors.primaryOrange,
          tabs: const [
            Tab(text: 'Delivery Transactions'),
            Tab(text: 'In-Store Transactions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DeliveryTransactionsList(),
          _InStoreTransactionsList(),
        ],
      ),
    );
  }
}

class OwnerActivityLogsPage extends StatelessWidget {
  const OwnerActivityLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        foregroundColor: AppColors.darkText,
        title: const Text('Employee Activity Logs',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _ActivityLogsList(),
    );
  }
}

class _DeliveryTransactionsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = EmployeeOrderController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final orders = controller.orders
            .where((o) => o.orderType == OrderType.delivery && o.status == OrderStatus.completed)
            .toList();

        if (orders.isEmpty) {
          return const Center(
            child: Text('No completed delivery transactions', style: TextStyle(color: AppColors.secondaryText)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = orders[index];
            return _HistoryCard(
              title: 'Order #${order.orderId}',
              subtitle: 'Customer: ${order.customerName} · ${order.items.length} items',
              trailingText: '₱ ${order.totalAmount.toStringAsFixed(2)}',
              date: order.formattedDate,
              status: order.status.label,
              statusColor: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomerOrderReceiptPage(order: order),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _InStoreTransactionsList extends StatefulWidget {
  @override
  State<_InStoreTransactionsList> createState() => _InStoreTransactionsListState();
}

class _InStoreTransactionsListState extends State<_InStoreTransactionsList> with SingleTickerProviderStateMixin {
  late TabController _subTabController;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.lightBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _subTabController,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              color: AppColors.primaryOrange,
              borderRadius: BorderRadius.circular(10),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.secondaryText,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_pin_circle, size: 16),
                    SizedBox(width: 8),
                    Text('Picked-up'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.store, size: 16),
                    SizedBox(width: 8),
                    Text('Walk-in'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: [
              _PickupTransactionsList(),
              _WalkInTransactionsList(),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickupTransactionsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = EmployeeOrderController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final orders = controller.orders
            .where((o) => o.orderType == OrderType.pickup && o.status == OrderStatus.completed)
            .toList();

        if (orders.isEmpty) {
          return const Center(
            child: Text('No picked-up transactions', style: TextStyle(color: AppColors.secondaryText)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = orders[index];
            return _HistoryCard(
              title: 'Pickup Order #${order.orderId}',
              subtitle: 'Customer: ${order.customerName} · ${order.items.length} items',
              trailingText: '₱ ${order.totalAmount.toStringAsFixed(2)}',
              date: order.formattedDate,
              status: 'Picked-up',
              statusColor: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomerOrderReceiptPage(order: order),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _WalkInTransactionsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Generate dummy walk-in receipts
    final receipts = List.generate(5, (index) => _generateDummyReceipt(index));

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: receipts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final receipt = receipts[index];
        return _HistoryCard(
          title: 'Walk-in Receipt #${receipt.receiptNumber}',
          subtitle: 'Employee: Maria Santos · ${receipt.items.length} items',
          trailingText: '₱ ${receipt.totalAmount.toStringAsFixed(2)}',
          date: 'Today, 3:45 PM',
          status: 'Completed',
          statusColor: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmployeeReceiptPage(
                  receipt: receipt,
                  actionLabel: 'Close',
                ),
              ),
            );
          },
        );
      },
    );
  }

  EmployeeReceipt _generateDummyReceipt(int index) {
    final product = kEmployeeDummyProducts[index % kEmployeeDummyProducts.length];
    return EmployeeReceipt(
      receiptNumber: 'RC-1002$index',
      dateTime: DateTime.now(),
      items: [
        EmployeePosCartItem(
          product: product,
          batchId: 'B001',
          unitPrice: product.price,
          quantity: 2,
        ),
      ],
      totalAmount: product.price * 2,
      amountPaid: product.price * 2 + 10,
      paymentMethod: index % 2 == 0 ? EmployeePaymentMethod.cash : EmployeePaymentMethod.gCash,
    );
  }
}



class _ActivityLogsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: 15,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.1),
              child: const Icon(Icons.person, color: AppColors.primaryOrange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(color: AppColors.darkText, fontSize: 13),
                      children: [
                        TextSpan(text: 'Maria Santos ', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: '(Employee) '),
                        TextSpan(text: 'adjusted stock for ', style: TextStyle(color: AppColors.secondaryText)),
                        TextSpan(text: 'Bear Brand Milk', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Today, 10:15 AM', style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.5), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerOrderReceiptPage extends StatelessWidget {
  const CustomerOrderReceiptPage({super.key, required this.order});
  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.darkText,
        title: const Text('Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'Order Completed',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.darkText),
              ),
              const SizedBox(height: 4),
              Text('Order #${order.orderId}', style: const TextStyle(color: AppColors.secondaryText)),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Customer: ${order.customerName}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        if (order.deliveryAddress != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Address: ${order.deliveryAddress}',
                                style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                          ),
                        const Divider(height: 24),
                        ...order.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text('${item.productName} x${item.quantity}',
                                      style: const TextStyle(color: AppColors.darkText)),
                                ),
                                Text('₱${item.subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 24),
                        _ReceiptRow(label: 'Subtotal', value: '₱${order.subtotal.toStringAsFixed(2)}'),
                        if (order.deliveryFee > 0)
                          _ReceiptRow(label: 'Delivery Fee', value: '₱${order.deliveryFee.toStringAsFixed(2)}'),
                        _ReceiptRow(
                            label: 'Total Amount',
                            value: '₱${order.totalAmount.toStringAsFixed(2)}',
                            isBold: true),
                        const SizedBox(height: 12),
                        _ReceiptRow(
                          label: 'Payment Method',
                          value: order.paymentMethod == PaymentMethod.cashOnDelivery ? 'Cash on Delivery' : 'GCash',
                        ),
                        _ReceiptRow(label: 'Date', value: order.formattedDate),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value, this.isBold = false});
  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isBold ? AppColors.darkText : AppColors.secondaryText,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isBold ? AppColors.primaryOrange : AppColors.darkText,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.title,
    required this.subtitle,
    required this.trailingText,
    required this.date,
    this.canVoid = false,
    this.status,
    this.statusColor,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String trailingText;
  final String date;
  final bool canVoid;
  final String? status;
  final Color? statusColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(trailingText,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                    if (status != null)
                      Text(
                        status!,
                        style: TextStyle(
                          color: statusColor ?? AppColors.secondaryText,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(date,
                    style: TextStyle(
                        color: AppColors.secondaryText.withValues(alpha: 0.5), fontSize: 11)),
                if (canVoid)
                  TextButton(
                    onPressed: () {
                      TopNotification.show(context, 'Transaction voided successfully.');
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Void', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



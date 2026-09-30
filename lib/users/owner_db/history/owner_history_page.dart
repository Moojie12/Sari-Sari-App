import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../customer_db/purchases/customer_order_model.dart';
import '../../employee_db/orders/employee_orders_controller.dart';
import '../../employee_db/messages/employee_chat_page.dart';
import '../../employee_db/messages/employee_messages_controller.dart';

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

        return _GroupedTransactionsListView(
          orders: orders,
          emptyMessage: 'No completed delivery transactions',
          titlePrefix: 'Order',
          statusLabel: 'Completed',
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
            .where((o) => o.orderType == OrderType.pickup && o.customerName != 'Walk-in' && o.status == OrderStatus.completed)
            .toList();

        return _GroupedTransactionsListView(
          orders: orders,
          emptyMessage: 'No picked-up transactions found',
          titlePrefix: 'Pickup Order',
          statusLabel: 'Picked-up',
        );
      },
    );
  }
}

class _WalkInTransactionsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = EmployeeOrderController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final orders = controller.orders
            .where((o) => o.customerName == 'Walk-in' && o.status == OrderStatus.completed)
            .toList();

        return _GroupedTransactionsListView(
          orders: orders,
          emptyMessage: 'No walk-in transactions found',
          titlePrefix: 'Walk-in Receipt',
          statusLabel: 'Completed',
        );
      },
    );
  }
}

class _GroupedTransactionsListView extends StatefulWidget {
  const _GroupedTransactionsListView({
    required this.orders,
    required this.emptyMessage,
    required this.titlePrefix,
    required this.statusLabel,
  });

  final List<CustomerOrder> orders;
  final String emptyMessage;
  final String titlePrefix;
  final String statusLabel;

  @override
  State<_GroupedTransactionsListView> createState() => _GroupedTransactionsListViewState();
}

class _GroupedTransactionsListViewState extends State<_GroupedTransactionsListView> {
  DateTime _selectedDate = DateTime.now();
  bool _filterByDate = true;

  @override
  Widget build(BuildContext context) {
    final yyyy = _selectedDate.year.toString();
    final mm = _selectedDate.month.toString().padLeft(2, '0');
    final dd = _selectedDate.day.toString().padLeft(2, '0');
    final dateFormatted = '$yyyy-$mm-$dd';

    // Filter orders if _filterByDate is true
    final filteredOrders = _filterByDate
        ? widget.orders.where((o) {
            return o.orderDate.year == _selectedDate.year &&
                o.orderDate.month == _selectedDate.month &&
                o.orderDate.day == _selectedDate.day;
          }).toList()
        : widget.orders;

    return Column(
      children: [
        // --- Date Picker Navigation Bar ---
        Container(
          margin: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Previous Day button
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.chevron_left, size: 22, color: AppColors.darkText),
                onPressed: () {
                  setState(() {
                    _filterByDate = true;
                    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                  });
                },
                tooltip: 'Previous Day',
              ),
              const Spacer(),

              // Date Picker trigger button (< 📅 YYYY-MM-DD ▼ >)
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                      _filterByDate = true;
                      _selectedDate = picked;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primaryOrange),
                      const SizedBox(width: 8),
                      Text(
                        dateFormatted,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkText),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.secondaryText),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // Next Day button
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.chevron_right, size: 22, color: AppColors.darkText),
                onPressed: () {
                  setState(() {
                    _filterByDate = true;
                    _selectedDate = _selectedDate.add(const Duration(days: 1));
                  });
                },
                tooltip: 'Next Day',
              ),

              const SizedBox(width: 4),
              // Show All / Filter Toggle Chip
              InkWell(
                onTap: () {
                  setState(() {
                    _filterByDate = !_filterByDate;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: !_filterByDate ? AppColors.primaryOrange : AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: !_filterByDate ? AppColors.primaryOrange : AppColors.borderColor,
                    ),
                  ),
                  child: Text(
                    !_filterByDate ? 'All Dates' : 'Show All',
                    style: TextStyle(
                      color: !_filterByDate ? Colors.white : AppColors.secondaryText,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // --- List Content ---
        Expanded(
          child: _buildListContent(filteredOrders, dateFormatted),
        ),
      ],
    );
  }

  Widget _buildListContent(List<CustomerOrder> filteredOrders, String dateFormatted) {
    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded, size: 48, color: AppColors.secondaryText.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              _filterByDate
                  ? 'No transactions on $dateFormatted'
                  : widget.emptyMessage,
              style: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
            ),
            if (_filterByDate) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                label: const Text('Show All Dates'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primaryOrange),
                onPressed: () {
                  setState(() {
                    _filterByDate = false;
                  });
                },
              ),
            ],
          ],
        ),
      );
    }

    // Sort descending by orderDate
    final sortedOrders = List<CustomerOrder>.from(filteredOrders)
      ..sort((a, b) => b.orderDate.compareTo(a.orderDate));

    // Group by day
    final Map<DateTime, List<CustomerOrder>> grouped = {};
    for (final order in sortedOrders) {
      final dayKey = DateTime(order.orderDate.year, order.orderDate.month, order.orderDate.day);
      grouped.putIfAbsent(dayKey, () => []).add(order);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: sortedDates.length,
      itemBuilder: (context, dateIndex) {
        final dateKey = sortedDates[dateIndex];
        final dayOrders = grouped[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header per day
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.primaryOrange),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatGroupDate(dateKey),
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.borderColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${dayOrders.length} ${dayOrders.length == 1 ? 'transaction' : 'transactions'}',
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Order Cards for this date
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: dayOrders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, orderIndex) {
                final order = dayOrders[orderIndex];
                return _HistoryCard(
                  title: '${widget.titlePrefix} #${order.displayOrderId}',
                  customerName: order.customerName,
                  itemsCount: order.items.length,
                  trailingText: '₱ ${order.totalAmount.toStringAsFixed(2)}',
                  date: _formatFullDateTime(order.orderDate),
                  status: widget.statusLabel.isNotEmpty ? widget.statusLabel : order.status.label,
                  statusColor: Colors.green,
                  revenue: order.subtotal,
                  capital: order.totalCapital,
                  profit: order.totalProfit,
                  processedBy: order.processedBy,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CustomerOrderReceiptPage(order: order),
                      ),
                    );
                  },
                  onCustomerTap: () {
                    final messagesController = EmployeeMessagesController.instance;
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
                );
              },
            ),
          ],
        );
      },
    );
  }

  static String _formatGroupDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDay = DateTime(date.year, date.month, date.day);

    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final monthStr = monthNames[date.month - 1];

    if (itemDay == today) {
      return 'Today — $monthStr ${date.day}, ${date.year}';
    } else if (itemDay == yesterday) {
      return 'Yesterday — $monthStr ${date.day}, ${date.year}';
    } else {
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final weekdayStr = dayNames[date.weekday - 1];
      return '$weekdayStr — $monthStr ${date.day}, ${date.year}';
    }
  }

  static String _formatFullDateTime(DateTime date) {
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final monthStr = monthNames[date.month - 1];
    final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$monthStr ${date.day}, ${date.year} • $hour:$minute $period';
  }
}

class _ActivityLogsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No activity logs found', style: TextStyle(color: AppColors.secondaryText)),
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
              Text('Order #${order.displayOrderId}', style: const TextStyle(color: AppColors.secondaryText)),
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
                        if (order.processedBy != null && order.processedBy!.isNotEmpty)
                          _ReceiptRow(label: 'Sold By', value: order.processedBy!),
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
    required this.customerName,
    required this.itemsCount,
    required this.trailingText,
    required this.date,
    this.status,
    this.statusColor,
    this.onTap,
    this.onCustomerTap,
    this.capital,
    this.revenue,
    this.profit,
    this.processedBy,
  });

  final String title;
  final String customerName;
  final int itemsCount;
  final String trailingText;
  final String date;
  final String? status;
  final Color? statusColor;
  final VoidCallback? onTap;
  final VoidCallback? onCustomerTap;

  final double? capital;
  final double? revenue;
  final double? profit;
  final String? processedBy;

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
                      _buildSubtitle(),
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
            if (capital != null || revenue != null || profit != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.borderColor),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat('Capital: ₱${(capital ?? 0).toStringAsFixed(2)}', Colors.blueGrey),
                  _buildMiniStat('Revenue: ₱${(revenue ?? 0).toStringAsFixed(2)}', AppColors.primaryOrange),
                  _buildMiniStat('Profit: ₱${(profit ?? 0).toStringAsFixed(2)}', Colors.green),
                ],
              ),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(date,
                    style: TextStyle(
                        color: AppColors.secondaryText.withValues(alpha: 0.5), fontSize: 11)),
                if (processedBy != null && processedBy!.isNotEmpty)
                  Text(
                    'Sold by: $processedBy',
                    style: const TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Customer: ',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
        GestureDetector(
          onTap: onCustomerTap,
          child: Text(
            customerName,
            style: const TextStyle(
                color: AppColors.darkText,
                fontSize: 12,
                fontWeight: FontWeight.bold),
          ),
        ),
        Text(' · $itemsCount items',
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
      ],
    );
  }

  Widget _buildMiniStat(String text, Color color) {
    return Column(
      children: [
        Text(text.split(':')[0], style: const TextStyle(color: AppColors.secondaryText, fontSize: 9)),
        Text(text.split(':')[1].trim(),
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

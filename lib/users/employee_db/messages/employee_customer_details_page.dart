import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../customer_db/purchases/customer_order_model.dart';
import '../orders/employee_orders_controller.dart';
import '../orders/employee_order_details_page.dart';
import 'employee_message_model.dart';

class EmployeeCustomerDetailsPage extends StatelessWidget {
  const EmployeeCustomerDetailsPage({
    super.key,
    required this.recipient,
  });

  final ChatRecipient recipient;

  @override
  Widget build(BuildContext context) {
    final orderController = EmployeeOrderController.instance;
    // Filter orders by customer name since our dummy data uses names
    final customerOrders = orderController.orders.where(
      (o) => o.customerName == recipient.name,
    ).toList();

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          recipient.isCustomer ? 'Customer Details' : 'Employee Details',
          style: const TextStyle(color: AppColors.darkText, fontSize: 18, fontWeight: FontWeight.bold),
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
            _ProfileHeader(recipient: recipient),
            const SizedBox(height: 32),
            const Text(
              'Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
            ),
            const SizedBox(height: 16),
            _InfoCard(recipient: recipient),
            if (recipient.isCustomer) ...[
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Order History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
                  ),
                  Text(
                    '${customerOrders.length} Orders',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (customerOrders.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No transaction history found.',
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: customerOrders.length,
                  itemBuilder: (context, index) {
                    final order = customerOrders[index];
                    return _OrderHistoryItem(order: order, controller: orderController);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.recipient});
  final ChatRecipient recipient;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.1),
            child: Text(
              recipient.initials,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryOrange,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            recipient.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.darkText),
          ),
          Text(
            recipient.role,
            style: const TextStyle(fontSize: 14, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.recipient});
  final ChatRecipient recipient;

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
          _InfoTile(
            icon: Icons.person_outline,
            label: 'Full Name',
            value: recipient.name,
          ),
          const Divider(height: 32),
          _InfoTile(
            icon: Icons.email_outlined,
            label: 'Email Address',
            value: recipient.email ?? 'Not provided',
          ),
          const Divider(height: 32),
          _InfoTile(
            icon: Icons.phone_outlined,
            label: 'Phone Number',
            value: recipient.phone ?? 'Not provided',
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.lightBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryOrange, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.darkText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderHistoryItem extends StatelessWidget {
  const _OrderHistoryItem({required this.order, required this.controller});
  final CustomerOrder order;
  final EmployeeOrderController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderColor),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmployeeOrderDetailsPage(order: order, controller: controller),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long_outlined, color: AppColors.primaryOrange, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.orderId}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      order.formattedDate,
                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₱${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                  ),
                  _StatusSmallBadge(status: order.status),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.placeholderColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusSmallBadge extends StatelessWidget {
  const _StatusSmallBadge({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case OrderStatus.pending: color = Colors.orange; break;
      case OrderStatus.completed: color = Colors.green; break;
      case OrderStatus.cancelled: color = Colors.red; break;
      default: color = Colors.blue; break;
    }
    return Text(
      status.label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
    );
  }
}

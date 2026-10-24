import 'package:flutter/material.dart';
import 'package:sari_sari/core/theme/app_colors.dart';
import '../customer_dashboard.dart';
import 'customer_notification_model.dart';
import '../chat/customer_chat_page.dart';
import '../purchases/customer_order_controller.dart';
import '../purchases/customer_order_details_page.dart';

class CustomerNotificationDetailsPage extends StatelessWidget {
  const CustomerNotificationDetailsPage({
    super.key,
    required this.notification,
  });

  final CustomerNotification notification;

  String _formatFullTimestamp(DateTime dateTime) {
    final year = dateTime.year;
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = monthNames[dateTime.month - 1];
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$month $day, $year · $hour:$minute $period';
  }

  String _getTypeLabel(CustomerNotificationType type) {
    switch (type) {
      case CustomerNotificationType.orderUpdate:
        return 'Order Update';
      case CustomerNotificationType.promotion:
        return 'Promotion / Offer';
      case CustomerNotificationType.security:
        return 'Security Alert';
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = notification.type.color;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notification Details',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Main Card Container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                  // Type Header Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          notification.type.icon,
                          color: typeColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getTypeLabel(notification.type),
                              style: TextStyle(
                                color: typeColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatFullTimestamp(notification.timestamp),
                              style: TextStyle(
                                color: AppColors.secondaryText.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Notification Title
                  Text(
                    notification.title,
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notification Message Body
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.lightBackground.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      notification.message,
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Contextual Action Buttons
            if (notification.title.toLowerCase().contains('message') ||
                notification.message.toLowerCase().contains('message')) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CustomerChatPage()),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Reply in Chat', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
              const SizedBox(height: 12),
            ] else if (notification.type == CustomerNotificationType.orderUpdate ||
                notification.title.toLowerCase().contains('order') ||
                notification.message.toLowerCase().contains('order')) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  final orders = CustomerOrderController.instance.orders;
                  final combined = '${notification.title} ${notification.message}';
                  final ordMatch = RegExp(r'ORD-[A-Za-z0-9\-]+', caseSensitive: false).firstMatch(combined);
                  final extractedId = ordMatch?.group(0)?.toUpperCase();
                  final matchedOrder = orders.where((o) =>
                      (extractedId != null && (o.orderId.toUpperCase() == extractedId || o.displayOrderId.toUpperCase() == extractedId)) ||
                      (o.orderId.isNotEmpty && combined.contains(o.orderId))).firstOrNull;

                  if (matchedOrder != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CustomerOrderDetailsPage(order: matchedOrder)),
                    );
                  } else {
                    CustomerDashboard.dashboardKey.currentState?.switchTab(2);
                  }
                },
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('View Order Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
              const SizedBox(height: 12),
            ] else if (notification.type == CustomerNotificationType.promotion) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  CustomerDashboard.dashboardKey.currentState?.switchTab(0);
                },
                icon: const Icon(Icons.storefront),
                label: const Text('Shop Deals', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
              const SizedBox(height: 12),
            ],

            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkText,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Close', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

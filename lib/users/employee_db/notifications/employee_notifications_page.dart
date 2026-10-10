import 'package:flutter/material.dart';

import '../../../core/services/dashboard_navigation_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../customer_db/purchases/customer_order_model.dart';
import '../employee_inventory_controller.dart';
import '../inventory/employee_product_model.dart';
import '../orders/employee_orders_controller.dart';
import 'employee_notification_details_page.dart';
import 'employee_notification_model.dart';
import 'employee_notifications_controller.dart';
import '../../../shared/widgets/skeleton.dart';

EmployeeProduct? findProductForNotification(
  EmployeeNotification notification,
  EmployeeInventoryController inventory,
) {
  final products = inventory.products;
  if (products.isEmpty) return null;

  // 1. Check explicit productId
  if (notification.productId != null && notification.productId!.isNotEmpty) {
    final prod = inventory.findById(notification.productId!);
    if (prod != null) return prod;
  }

  // 2. Check notification id suffix (e.g. 'outofstock-prod123', 'expired-prod123')
  for (final prod in products) {
    if (notification.id.endsWith(prod.id)) {
      return prod;
    }
  }

  // 3. Check explicit productName match
  if (notification.productName != null && notification.productName!.isNotEmpty) {
    final nameLower = notification.productName!.trim().toLowerCase();
    for (final prod in products) {
      if (prod.name.trim().toLowerCase() == nameLower) return prod;
    }
  }

  // 4. Match product name inside title or message
  final titleLower = notification.title.toLowerCase();
  final messageLower = notification.message.toLowerCase();

  EmployeeProduct? bestMatch;
  int longestNameLength = 0;

  for (final prod in products) {
    final pNameLower = prod.name.trim().toLowerCase();
    if (pNameLower.isEmpty) continue;

    if (messageLower.contains(pNameLower) || titleLower.contains(pNameLower)) {
      if (pNameLower.length > longestNameLength) {
        longestNameLength = pNameLower.length;
        bestMatch = prod;
      }
    }
  }

  return bestMatch;
}

CustomerOrder? findOrderForNotification(
  EmployeeNotification notification,
  EmployeeOrderController orderController,
) {
  final orders = orderController.orders;
  if (orders.isEmpty) return null;

  // 1. Explicit orderId
  if (notification.orderId != null && notification.orderId!.isNotEmpty) {
    for (final order in orders) {
      if (order.orderId == notification.orderId) return order;
    }
  }

  // 2. Search orderId inside message or title
  final message = notification.message;
  final title = notification.title;

  for (final order in orders) {
    if (order.orderId.isNotEmpty && (message.contains(order.orderId) || title.contains(order.orderId))) {
      return order;
    }
  }

  return null;
}

/// "Notifications" screen: shows low stock, out-of-stock, and expiring
/// product alerts, plus any mock orders or tasks assigned to the employee.
class EmployeeNotificationsPage extends StatelessWidget {
  const EmployeeNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = EmployeeNotificationsController();

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => controller.markAllAsRead(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Mark read',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () => controller.clearReadNotifications(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Clear read',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.isLoading && controller.notifications.isEmpty) {
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: 6,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => const NotificationSkeleton(),
            );
          }

          final notifications = controller.notifications;

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 48,
                    color: AppColors.primaryOrange.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No new notifications',
                    style: TextStyle(
                      color: AppColors.secondaryText.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primaryOrange,
            onRefresh: () async {
              await controller.loadStoreNotifications();
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return Dismissible(
                  key: Key(notification.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) {
                    controller.deleteNotification(notification.id);
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                  ),
                  child: _NotificationTile(
                    notification: notification,
                    onTap: () {
                      controller.markAsRead(notification.id);

                      // 1. Try product match
                      final matchingProduct = findProductForNotification(
                        notification,
                        EmployeeInventoryController.instance,
                      );

                      if (matchingProduct != null) {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                        Future.microtask(() {
                          DashboardNavigationController.instance.navigateToInventory(
                            openProductDetail: matchingProduct,
                          );
                        });
                        return;
                      }

                      // 2. Try order match
                      final matchingOrder = findOrderForNotification(
                        notification,
                        EmployeeOrderController.instance,
                      );

                      if (matchingOrder != null) {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                        Future.microtask(() {
                          DashboardNavigationController.instance.navigateToOrders(
                            openOrderDetail: matchingOrder,
                          );
                        });
                        return;
                      }

                      // 3. Fallback to details page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EmployeeNotificationDetailsPage(
                            notification: notification.copyWith(isRead: true),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final EmployeeNotification notification;
  final VoidCallback onTap;

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final isToday = now.year == dateTime.year && now.month == dateTime.month && now.day == dateTime.day;
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:$minute $period';
    if (isToday) return time;
    return '${dateTime.month}/${dateTime.day} · $time';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: notification.isRead ? AppColors.cardWhite.withValues(alpha: 0.7) : AppColors.cardWhite,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: notification.type.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notification.type.icon,
                  color: notification.type.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            color: AppColors.darkText,
                            fontSize: 14,
                            fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold,
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryOrange,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: AppColors.secondaryText.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTimestamp(notification.timestamp),
                      style: TextStyle(
                        color: AppColors.secondaryText.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

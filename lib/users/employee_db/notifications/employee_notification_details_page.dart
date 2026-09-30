import 'package:flutter/material.dart';
import 'package:sari_sari/core/services/dashboard_navigation_controller.dart';
import 'package:sari_sari/core/theme/app_colors.dart';
import 'package:sari_sari/shared/widgets/product_image.dart';
import '../employee_inventory_controller.dart';
import '../inventory/employee_product_model.dart';
import 'employee_notification_model.dart';
import 'employee_notifications_page.dart';

class EmployeeNotificationDetailsPage extends StatelessWidget {
  const EmployeeNotificationDetailsPage({
    super.key,
    required this.notification,
  });

  final EmployeeNotification notification;

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

  String _getTypeLabel(EmployeeNotificationType type) {
    switch (type) {
      case EmployeeNotificationType.lowStock:
        return 'Low Stock Alert';
      case EmployeeNotificationType.outOfStock:
        return 'Out of Stock Alert';
      case EmployeeNotificationType.expiring:
        return 'Expiration Alert';
      case EmployeeNotificationType.newOrder:
        return 'New Customer Order';
      case EmployeeNotificationType.assignedTask:
        return 'Assigned Task';
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = notification.type.color;
    final matchingProduct = findProductForNotification(
      notification,
      EmployeeInventoryController.instance,
    );

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

                  // Title
                  Text(
                    notification.title,
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Message Body
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

                  // Product Info Section if matched
                  if (matchingProduct != null) ...[
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    const Text(
                      'Linked Product',
                      style: TextStyle(
                        color: AppColors.labelText,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.borderColor.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          ProductImage(
                            image: matchingProduct.image,
                            width: 52,
                            height: 52,
                            borderRadius: 10,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  matchingProduct.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkText,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₱${matchingProduct.price.toStringAsFixed(2)} · ${matchingProduct.category}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${matchingProduct.stockStatus.label} · Qty: ${matchingProduct.quantity.toInt()} ${matchingProduct.unit}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: notification.type.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Go to Inventory Button if product matched
            if (matchingProduct != null) ...[
              ElevatedButton.icon(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  Future.microtask(() {
                    DashboardNavigationController.instance.navigateToInventory(
                      openProductDetail: matchingProduct,
                    );
                  });
                },
                icon: const Icon(Icons.inventory_2_outlined, size: 20),
                label: const Text(
                  'Go to Product in Inventory',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondaryText,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Done / Close',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

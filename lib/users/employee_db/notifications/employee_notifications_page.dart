import 'package:flutter/material.dart';

import '../../../core/services/dashboard_navigation_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../customer_db/purchases/customer_order_model.dart';
import '../employee_inventory_controller.dart';
import '../inventory/employee_product_model.dart';
import '../orders/employee_orders_controller.dart';
import 'employee_notification_details_page.dart';
import '../messages/employee_chat_page.dart';
import '../messages/employee_message_model.dart';
import '../messages/employee_messages_controller.dart';
import '../messages/employee_messages_page.dart';
import '../orders/employee_order_details_page.dart';
import '../../owner_db/refunds/owner_refunds_page.dart';
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
      if (order.orderId == notification.orderId || order.displayOrderId == notification.orderId) {
        return order;
      }
    }
  }

  // 2. Search ORD-... regex in title or message
  final combined = '${notification.title} ${notification.message}';
  final ordMatch = RegExp(r'ORD-[A-Za-z0-9\-]+', caseSensitive: false).firstMatch(combined);
  if (ordMatch != null) {
    final extractedId = ordMatch.group(0)!.toUpperCase();
    for (final order in orders) {
      if (order.orderId.toUpperCase() == extractedId ||
          order.displayOrderId.toUpperCase() == extractedId ||
          order.orderId.toUpperCase().contains(extractedId) ||
          extractedId.contains(order.orderId.toUpperCase())) {
        return order;
      }
    }
  }

  // 3. Search exact order id inside message or title
  for (final order in orders) {
    if (order.orderId.isNotEmpty && combined.contains(order.orderId)) {
      return order;
    }
    if (order.displayOrderId.isNotEmpty && combined.contains(order.displayOrderId)) {
      return order;
    }
  }

  return null;
}

/// "Notifications" screen: shows low stock, out-of-stock, and expiring
/// product alerts, plus any mock orders or tasks assigned to the employee.
/// "Notifications" screen: shows low stock, out-of-stock, and expiring
/// product alerts, plus any mock orders or tasks assigned to the employee.
class EmployeeNotificationsPage extends StatefulWidget {
  const EmployeeNotificationsPage({super.key});

  @override
  State<EmployeeNotificationsPage> createState() => _EmployeeNotificationsPageState();
}

class _EmployeeNotificationsPageState extends State<EmployeeNotificationsPage> {
  final EmployeeNotificationsController _controller = EmployeeNotificationsController();
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _enterSelectionMode(String initialId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.clear();
      _selectedIds.add(initialId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<EmployeeNotification> notifs) {
    setState(() {
      if (_selectedIds.length == notifs.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.clear();
        _selectedIds.addAll(notifs.map((n) => n.id));
      }
    });
  }

  Future<void> _confirmMarkAllRead() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark all as read?'),
        content: const Text('Are you sure you want to mark all notifications as read?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
            child: const Text('Mark as Read', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _controller.markAllAsRead();
    }
  }

  Future<void> _confirmClearRead() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear read notifications?'),
        content: const Text('Are you sure you want to delete all read notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _controller.clearReadNotifications();
    }
  }

  Future<void> _confirmDeleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count ${count == 1 ? 'notification' : 'notifications'}?'),
        content: Text('Are you sure you want to delete the selected $count ${count == 1 ? 'notification' : 'notifications'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _controller.deleteNotifications(_selectedIds);
      _exitSelectionMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: AppColors.primaryOrange,
              elevation: 0,
              titleSpacing: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _exitSelectionMode,
              ),
              title: Text(
                '${_selectedIds.length} selected',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.select_all, color: Colors.white),
                  tooltip: 'Select All',
                  onPressed: () => _selectAll(_controller.notifications),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  tooltip: 'Delete Selected',
                  onPressed: _confirmDeleteSelected,
                ),
                const SizedBox(width: 8),
              ],
            )
          : AppBar(
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
                ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) {
                    final canMarkRead = _controller.unreadCount > 0;
                    final canClearRead = _controller.notifications.any((n) => n.isRead);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: canMarkRead ? _confirmMarkAllRead : null,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Mark read',
                            style: TextStyle(
                              color: canMarkRead ? Colors.white : Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: canClearRead ? _confirmClearRead : null,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Clear read',
                            style: TextStyle(
                              color: canClearRead ? Colors.white : Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    );
                  },
                ),
              ],
            ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading && _controller.notifications.isEmpty) {
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: 6,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => const NotificationSkeleton(),
            );
          }

          final notifications = _controller.notifications;

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
              await _controller.loadStoreNotifications();
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final isSelected = _selectedIds.contains(notification.id);

                return Dismissible(
                  key: Key(notification.id),
                  direction: _isSelectionMode ? DismissDirection.none : DismissDirection.endToStart,
                  onDismissed: (_) {
                    _controller.deleteNotification(notification.id);
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
                    isSelectionMode: _isSelectionMode,
                    isSelected: isSelected,
                    onLongPress: () {
                      if (!_isSelectionMode) {
                        _enterSelectionMode(notification.id);
                      } else {
                        _toggleSelection(notification.id);
                      }
                    },
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleSelection(notification.id);
                        return;
                      }

                      _controller.markAsRead(notification.id);

                      final titleLower = notification.title.toLowerCase();
                      final messageLower = notification.message.toLowerCase();

                      // 1. CHAT / MESSAGE: "New message from <Name>" or contains "message" / "chat"
                      if (titleLower.contains('message') ||
                          titleLower.contains('chat') ||
                          messageLower.contains('sent you a message') ||
                          messageLower.contains('chat message')) {
                        // Extract customer name if in title: "New message from Cyrus O. Nocum"
                        String senderName = '';
                        final match = RegExp(r'message from\s+(.+)', caseSensitive: false).firstMatch(notification.title);
                        if (match != null) {
                          senderName = match.group(1)?.trim() ?? '';
                        }

                        // Try finding in active chat threads
                        ChatThread? matchedThread;
                        final threads = EmployeeMessagesController.instance.threads;
                        if (notification.customerId != null && notification.customerId!.isNotEmpty) {
                          matchedThread = threads.where((t) => t.recipient.id == notification.customerId).firstOrNull;
                        }
                        if (matchedThread == null && senderName.isNotEmpty && threads.isNotEmpty) {
                          final sLower = senderName.toLowerCase();
                          matchedThread = threads.where((t) {
                            final rLower = t.recipient.name.toLowerCase();
                            return rLower == sLower || rLower.contains(sLower) || sLower.contains(rLower);
                          }).firstOrNull;
                        }

                        final targetRecipientId = matchedThread?.recipient.id ?? notification.customerId ?? senderName;
                        final targetRecipientName = matchedThread?.recipient.name ?? (senderName.isNotEmpty ? senderName : 'Customer');

                        if (targetRecipientId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EmployeeChatPage(
                                recipientId: targetRecipientId,
                                recipientName: targetRecipientName,
                              ),
                            ),
                          );
                          return;
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EmployeeMessagesPage(viewerRole: 'Staff'),
                            ),
                          );
                          return;
                        }
                      }

                      // 2. GCash REFUND NOTIFICATION
                      if (titleLower.contains('refund') || messageLower.contains('refund')) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OwnerRefundsPage(),
                          ),
                        );
                        return;
                      }

                      // 3. PRODUCT / INVENTORY MATCH
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

                      // 4. ORDER MATCH
                      final matchingOrder = findOrderForNotification(
                        notification,
                        EmployeeOrderController.instance,
                      );

                      if (matchingOrder != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EmployeeOrderDetailsPage(
                              order: matchingOrder,
                              controller: EmployeeOrderController.instance,
                            ),
                          ),
                        );
                        return;
                      }

                      // 5. Generic ORDER notification
                      if (notification.type == EmployeeNotificationType.newOrder ||
                          titleLower.contains('order') ||
                          messageLower.contains('order')) {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                        Future.microtask(() {
                          DashboardNavigationController.instance.navigateToOrders();
                        });
                        return;
                      }

                      // 6. Generic INVENTORY alert
                      if (notification.type == EmployeeNotificationType.lowStock ||
                          notification.type == EmployeeNotificationType.outOfStock ||
                          notification.type == EmployeeNotificationType.expiring) {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                        Future.microtask(() {
                          DashboardNavigationController.instance.navigateToInventory();
                        });
                        return;
                      }

                      // 7. Fallback to details page
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
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  final EmployeeNotification notification;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;

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
      color: isSelected
          ? AppColors.primaryOrange.withValues(alpha: 0.12)
          : (notification.isRead ? AppColors.cardWhite.withValues(alpha: 0.7) : AppColors.cardWhite),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSelectionMode) ...[
                Checkbox(
                  value: isSelected,
                  activeColor: AppColors.primaryOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (_) => onTap(),
                ),
                const SizedBox(width: 8),
              ],
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
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: AppColors.darkText,
                              fontSize: 14,
                              fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold,
                            ),
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

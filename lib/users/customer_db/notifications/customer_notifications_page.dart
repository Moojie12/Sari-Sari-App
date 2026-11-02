import 'package:flutter/material.dart';

import 'package:sari_sari/core/theme/app_colors.dart';
import 'package:sari_sari/shared/widgets/skeleton.dart';
import 'customer_notification_details_page.dart';
import '../chat/customer_chat_page.dart';
import '../customer_dashboard.dart';
import '../purchases/customer_order_controller.dart';
import '../purchases/customer_order_details_page.dart';
import '../purchases/customer_order_model.dart';
import 'customer_notification_model.dart';
import 'customer_notifications_controller.dart';

class CustomerNotificationsPage extends StatefulWidget {
  const CustomerNotificationsPage({super.key});

  @override
  State<CustomerNotificationsPage> createState() => _CustomerNotificationsPageState();
}

class _CustomerNotificationsPageState extends State<CustomerNotificationsPage> {
  final CustomerNotificationsController _controller = CustomerNotificationsController();
  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _simulateLoading();
  }

  void _simulateLoading() {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

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

  void _selectAll(List<CustomerNotification> notifs) {
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
              automaticallyImplyLeading: false,
              title: const Text(
                'Notifications',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
          if ((_isLoading || _controller.isLoading) && _controller.notifications.isEmpty) {
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
                    size: 64,
                    color: AppColors.primaryOrange.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primaryOrange,
            onRefresh: () async {
              await _controller.loadNotifications();
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

                      // 1. CHAT / MESSAGE: "New message from Store" or contains "message" / "chat"
                      if (titleLower.contains('message') ||
                          titleLower.contains('chat') ||
                          messageLower.contains('message') ||
                          messageLower.contains('chat')) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CustomerChatPage(),
                          ),
                        );
                        return;
                      }

                      // 2. ORDER UPDATE: Order Status Update, Delivery Tracking, Ready for Pickup
                      if (notification.type == CustomerNotificationType.orderUpdate ||
                          titleLower.contains('order') ||
                          messageLower.contains('order') ||
                          messageLower.contains('delivery') ||
                          messageLower.contains('pickup') ||
                          messageLower.contains('preparing')) {
                        final orders = CustomerOrderController.instance.orders;
                        CustomerOrder? matchedOrder;

                        final combined = '${notification.title} ${notification.message}';
                        final ordMatch = RegExp(r'ORD-[A-Za-z0-9\-]+', caseSensitive: false).firstMatch(combined);
                        if (ordMatch != null) {
                          final extractedId = ordMatch.group(0)!.toUpperCase();
                          for (final order in orders) {
                            if (order.orderId.toUpperCase() == extractedId ||
                                order.displayOrderId.toUpperCase() == extractedId ||
                                order.orderId.toUpperCase().contains(extractedId) ||
                                extractedId.contains(order.orderId.toUpperCase())) {
                              matchedOrder = order;
                              break;
                            }
                          }
                        }

                        if (matchedOrder == null) {
                          for (final order in orders) {
                            if (order.orderId.isNotEmpty && combined.contains(order.orderId)) {
                              matchedOrder = order;
                              break;
                            }
                            if (order.displayOrderId.isNotEmpty && combined.contains(order.displayOrderId)) {
                              matchedOrder = order;
                              break;
                            }
                          }
                        }

                        if (matchedOrder != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CustomerOrderDetailsPage(order: matchedOrder!),
                            ),
                          );
                          return;
                        } else {
                          // Switch tab directly to My Purchases
                          CustomerDashboard.dashboardKey.currentState?.switchTab(2);
                          return;
                        }
                      }

                      // 3. PROMOTIONS / DISCOUNTS / SALE
                      if (notification.type == CustomerNotificationType.promotion ||
                          titleLower.contains('promo') ||
                          titleLower.contains('discount') ||
                          titleLower.contains('sale') ||
                          messageLower.contains('promo') ||
                          messageLower.contains('discount')) {
                        CustomerDashboard.dashboardKey.currentState?.switchTab(0);
                        return;
                      }

                      // 4. SECURITY / ACCOUNT
                      if (notification.type == CustomerNotificationType.security) {
                        CustomerDashboard.dashboardKey.currentState?.switchTab(3);
                        return;
                      }

                      // 5. Fallback to CustomerNotificationDetailsPage
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomerNotificationDetailsPage(
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

  final CustomerNotification notification;
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
          : (notification.isRead ? Colors.white.withValues(alpha: 0.6) : Colors.white),
      borderRadius: BorderRadius.circular(16),
      elevation: isSelected ? 1 : (notification.isRead ? 0 : 2),
      shadowColor: Colors.black.withValues(alpha: 0.1),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: notification.type.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notification.type.icon,
                  color: notification.type.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
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
                              fontSize: 15,
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
                        color: AppColors.secondaryText.withValues(alpha: 0.9),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTimestamp(notification.timestamp),
                      style: TextStyle(
                        color: AppColors.secondaryText.withValues(alpha: 0.6),
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

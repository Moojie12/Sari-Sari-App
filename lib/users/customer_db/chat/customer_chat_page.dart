import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'customer_chat_controller.dart';

class CustomerChatPage extends StatelessWidget {
  const CustomerChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = CustomerChatController.instance;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primaryOrange,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () => controller.markAllAsRead(),
            child: const Text(
              'Mark all as read',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: 5,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              // First two items are unread only if controller.unreadCount > 0
              final bool isUnread = index < controller.unreadCount;
              return _ChatTile(
                name: index == 0 ? 'Sari-Sari Support' : 'Store Assistant $index',
                lastMessage: index == 0 
                    ? 'How can we help you today?' 
                    : 'Your order #123$index is ready for pickup.',
                time: '${10 + index}:30 AM',
                isUnread: isUnread,
              );
            },
          );
        },
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String time;
  final bool isUnread;

  const _ChatTile({
    required this.name,
    required this.lastMessage,
    required this.time,
    this.isUnread = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: AppColors.borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.1),
              child: const Icon(
                Icons.person_outline,
                color: AppColors.primaryOrange,
                size: 28,
              ),
            ),
            if (isUnread)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
            color: AppColors.darkText,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isUnread ? AppColors.darkText : AppColors.secondaryText,
            fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: TextStyle(
                fontSize: 12,
                color: isUnread ? AppColors.primaryOrange : AppColors.secondaryText,
                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.placeholderColor),
          ],
        ),
        onTap: () {
          // Navigation to specific chat screen can be added here
        },
      ),
    );
  }
}

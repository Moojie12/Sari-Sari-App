import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'employee_chat_page.dart';
import 'employee_message_model.dart';
import 'employee_messages_controller.dart';

/// "Messages" screen: entry point into the Owner &lt;-&gt; Employee
/// conversation (sales/inventory/stock/order concerns and day-to-day
/// coordination). Employee-side scope only, for now, so there's a single
/// thread — with the Store Owner.
class EmployeeMessagesPage extends StatelessWidget {
  const EmployeeMessagesPage({super.key});

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
    final controller = EmployeeMessagesController();

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
          'Messages',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final lastMessage = controller.lastMessage;
          final unreadCount = controller.unreadCount;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Material(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EmployeeChatPage()),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.12),
                          child: const Icon(Icons.storefront_outlined, color: AppColors.primaryOrange),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Store Owner',
                                    style: TextStyle(
                                      color: AppColors.darkText,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (lastMessage != null)
                                    Text(
                                      _formatTimestamp(lastMessage.sentAt),
                                      style: TextStyle(
                                        color: AppColors.secondaryText.withValues(alpha: 0.7),
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      lastMessage == null
                                          ? 'No messages yet'
                                          : (lastMessage.sender == MessageSender.employee
                                          ? 'You: ${lastMessage.text}'
                                          : lastMessage.text),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: unreadCount > 0
                                            ? AppColors.darkText
                                            : AppColors.secondaryText.withValues(alpha: 0.8),
                                        fontSize: 13,
                                        fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (unreadCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      constraints: const BoxConstraints(minWidth: 20),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        unreadCount > 9 ? '9+' : '$unreadCount',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
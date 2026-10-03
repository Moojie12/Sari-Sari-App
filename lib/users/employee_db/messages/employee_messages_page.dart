import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/editable_profile_avatar.dart';
import 'employee_chat_page.dart';
import 'employee_message_model.dart';
import 'employee_messages_controller.dart';

/// "Messages" screen: entry point into internal (Owner) and external
/// (Customer) conversations for the Employee.
class EmployeeMessagesPage extends StatelessWidget {
  const EmployeeMessagesPage({super.key, this.viewerRole = 'Employee'});

  final String viewerRole;

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
          final threads = controller.threads.where((t) {
            final nameLower = t.recipient.name.toLowerCase();
            final isWalkIn = nameLower.contains('walk-in') || nameLower.contains('walkin');
            final hasMessages = t.messages.isNotEmpty;

            return !isWalkIn && hasMessages;
          }).toList();

          if (threads.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.forum_outlined,
                    size: 48,
                    color: AppColors.primaryOrange.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No messages yet',
                    style: TextStyle(
                      color: AppColors.secondaryText.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: threads.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final thread = threads[index];
              final lastMessage = thread.lastMessage;
              final unreadCount = thread.unreadCount;
              final recipient = thread.recipient;

              return Material(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmployeeChatPage(recipientId: recipient.id),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        EditableProfileAvatar(
                          initials: recipient.initials,
                          photoPath: recipient.avatarUrl,
                          radius: 26,
                          isEditable: false,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          recipient.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.darkText,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          recipient.role,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppColors.secondaryText.withValues(alpha: 0.6),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (lastMessage != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatTimestamp(lastMessage.sentAt),
                                      style: TextStyle(
                                        color: AppColors.secondaryText.withValues(alpha: 0.7),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      lastMessage == null
                                          ? 'No messages yet'
                                          : (lastMessage.sender == MessageSender.me
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
              );
            },
          );
        },
      ),
    );
  }
}

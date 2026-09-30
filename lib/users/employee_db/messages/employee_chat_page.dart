import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/services/chat_database_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/editable_profile_avatar.dart';
import 'employee_customer_details_page.dart';
import 'employee_message_model.dart';
import 'employee_messages_controller.dart';

/// Chat thread between the signed-in Employee and a recipient (Owner or Customer).
class EmployeeChatPage extends StatefulWidget {
  const EmployeeChatPage({
    super.key,
    required this.recipientId,
    this.recipientName,
  });

  final String recipientId;
  final String? recipientName;

  @override
  State<EmployeeChatPage> createState() => _EmployeeChatPageState();
}

class _EmployeeChatPageState extends State<EmployeeChatPage> {
  final _controller = EmployeeMessagesController();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription<List<EmployeeMessage>>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToLiveMessages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.markAllRead(widget.recipientId);
      _scrollToBottom();
    });
  }

  void _subscribeToLiveMessages() {
    try {
      _messagesSubscription?.cancel();
      _messagesSubscription = ChatDatabaseService.instance.streamMessages(
        customerId: widget.recipientId,
        isEmployeeView: true,
      ).listen((liveMessages) {
        if (mounted) {
          _controller.updateThreadMessages(widget.recipientId, liveMessages);
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        }
      });
    } catch (e) {
      debugPrint('Error subscribing to live messages in chat page: $e');
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _send() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _controller.sendMessage(widget.recipientId, text);
    _textController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        var thread = _controller.getThread(widget.recipientId);
        if (thread == null && widget.recipientName != null) {
          thread = _controller.getOrCreateThread(
            recipientId: widget.recipientId,
            name: widget.recipientName!,
            role: 'Customer',
            isCustomer: true,
          );
        }

        if (thread == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Chat')),
            body: const Center(child: Text('Thread not found')),
          );
        }

        final recipient = thread.recipient;
        final messages = thread.messages;

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            backgroundColor: AppColors.primaryOrange,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            titleSpacing: 0,
            title: Row(
              children: [
                EditableProfileAvatar(
                  initials: recipient.initials,
                  photoPath: recipient.avatarUrl,
                  radius: 16,
                  isEditable: false,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recipient.name,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      recipient.role,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              if (recipient.isCustomer || recipient.isEmployee)
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EmployeeCustomerDetailsPage(recipient: recipient),
                      ),
                    );
                  },
                  tooltip: recipient.isCustomer ? 'Customer Details' : 'Employee Details',
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: AppColors.placeholderColor.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No messages yet.\nType a message below to start chatting.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.secondaryText.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final bool showDateHeader = index == 0 ||
                                !_isSameDay(messages[index - 1].sentAt, message.sentAt);

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (showDateHeader) _DateHeaderChip(date: message.sentAt),
                                _ChatBubble(
                                  message: message,
                                  timeLabel: _formatTime(message.sentAt),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                _MessageComposer(controller: _textController, onSend: _send),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.timeLabel});

  final EmployeeMessage message;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final isMe = message.sender == MessageSender.me;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryOrange : AppColors.cardWhite,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.darkText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeLabel,
              style: TextStyle(
                color: isMe ? Colors.white.withValues(alpha: 0.75) : AppColors.secondaryText.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(top: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Type a message…',
                hintStyle: const TextStyle(color: AppColors.placeholderColor, fontSize: 13),
                filled: true,
                fillColor: AppColors.lightPeach,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.primaryOrange,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onSend,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateHeaderChip extends StatelessWidget {
  const _DateHeaderChip({required this.date});

  final DateTime date;

  String _formatDateHeader(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      const monthNames = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      const dayOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      final dow = dayOfWeek[dateTime.weekday % 7];
      final month = monthNames[dateTime.month - 1];
      if (dateTime.year == now.year) {
        return '$dow, $month ${dateTime.day}';
      }
      return '$dow, $month ${dateTime.day}, ${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.placeholderColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _formatDateHeader(date),
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

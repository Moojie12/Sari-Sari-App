import 'package:flutter/material.dart';

/// Who sent an [EmployeeMessage].
enum MessageSender { me, them }

/// Information about a chat participant (Owner or Customer).
@immutable
class ChatRecipient {
  const ChatRecipient({
    required this.id,
    required this.name,
    required this.role,
    this.isCustomer = false,
    this.avatarIcon = Icons.person_outline,
    this.email,
    this.phone,
  });

  final String id;
  final String name;
  final String role;
  final bool isCustomer;
  final IconData avatarIcon;
  final String? email;
  final String? phone;

  bool get isEmployee => role == 'Employee';

  String get initials {
    final parts = name.split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }
}

/// A single chat bubble in a conversation.
@immutable
class EmployeeMessage {
  const EmployeeMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.sentAt,
    this.isRead = true,
  });

  final String id;
  final MessageSender sender;
  final String text;
  final DateTime sentAt;

  /// Whether the message has been seen by the employee.
  final bool isRead;

  EmployeeMessage copyWith({bool? isRead}) {
    return EmployeeMessage(
      id: id,
      sender: sender,
      text: text,
      sentAt: sentAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

/// A collection of messages between the Employee and a specific recipient.
class ChatThread {
  const ChatThread({
    required this.recipient,
    required this.messages,
  });

  final ChatRecipient recipient;
  final List<EmployeeMessage> messages;

  EmployeeMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  int get unreadCount =>
      messages.where((m) => m.sender == MessageSender.them && !m.isRead).length;

  ChatThread copyWith({List<EmployeeMessage>? messages}) {
    return ChatThread(
      recipient: recipient,
      messages: messages ?? this.messages,
    );
  }
}

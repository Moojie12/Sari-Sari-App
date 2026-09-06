import 'package:flutter/foundation.dart';

/// Who sent an [EmployeeMessage] — the only two participants in the
/// Owner &lt;-&gt; Employee conversation.
enum MessageSender { employee, owner }

/// A single chat bubble in the Owner &lt;-&gt; Employee conversation (internal
/// store communication: sales concerns, inventory/stock concerns,
/// instructions, problem reports, day-to-day coordination).
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

  /// Whether the *employee* has seen this message yet. Only meaningful for
  /// [MessageSender.owner] messages — the employee's own messages are
  /// always considered read.
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
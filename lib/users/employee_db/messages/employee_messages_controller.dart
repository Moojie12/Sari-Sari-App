import 'package:flutter/foundation.dart';

import 'employee_message_model.dart';

/// Owns the Owner &lt;-&gt; Employee message thread.
///
/// Frontend-only: there is no backend/chat server yet, so this just keeps
/// one seeded conversation in memory for the session. [sendMessage] appends
/// the employee's message and, to keep the screen feeling alive during
/// front-end review, queues a short canned reply from the Owner shortly
/// after — swap [_simulateOwnerReply] out once real messaging is wired up.
class EmployeeMessagesController extends ChangeNotifier {
  EmployeeMessagesController._();

  static final EmployeeMessagesController instance = EmployeeMessagesController._();

  factory EmployeeMessagesController() => instance;

  final List<EmployeeMessage> _messages = [
    EmployeeMessage(
      id: 'm1',
      sender: MessageSender.owner,
      text: 'Good morning! Please check the remaining stocks of the beverages.',
      sentAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    EmployeeMessage(
      id: 'm2',
      sender: MessageSender.employee,
      text: "Okay po, I'll check the inventory now.",
      sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 55)),
    ),
    EmployeeMessage(
      id: 'm3',
      sender: MessageSender.owner,
      text: 'Thank you! Let me know if any items need restocking.',
      sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 50)),
      isRead: false,
    ),
  ];

  int _nextId = 4;

  List<EmployeeMessage> get messages => List.unmodifiable(_messages);

  EmployeeMessage? get lastMessage => _messages.isEmpty ? null : _messages.last;

  /// Owner messages the employee hasn't opened the thread to see yet —
  /// backs the badge on the "Messages" menu item and the Profile nav icon.
  int get unreadCount =>
      _messages.where((m) => m.sender == MessageSender.owner && !m.isRead).length;

  void sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _messages.add(EmployeeMessage(
      id: 'm${_nextId++}',
      sender: MessageSender.employee,
      text: trimmed,
      sentAt: DateTime.now(),
    ));
    notifyListeners();
    _simulateOwnerReply();
  }

  /// Marks every Owner message as read — called when the employee opens
  /// the chat thread.
  void markAllRead() {
    var changed = false;
    for (var i = 0; i < _messages.length; i++) {
      if (_messages[i].sender == MessageSender.owner && !_messages[i].isRead) {
        _messages[i] = _messages[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void _simulateOwnerReply() {
    Future.delayed(const Duration(seconds: 2), () {
      _messages.add(EmployeeMessage(
        id: 'm${_nextId++}',
        sender: MessageSender.owner,
        text: "Noted, thank you for the update.",
        sentAt: DateTime.now(),
        isRead: false,
      ));
      notifyListeners();
    });
  }
}
import 'dart:async';
import 'package:flutter/material.dart';

import 'employee_message_model.dart';

/// Owns the message threads for the Employee.
///
/// Manages conversations between the Employee and the Store Owner,
/// as well as conversations with Customers (order status, service, etc.).
class EmployeeMessagesController extends ChangeNotifier {
  EmployeeMessagesController._() {
    _threads = [];
  }

  static final EmployeeMessagesController instance = EmployeeMessagesController._();

  factory EmployeeMessagesController() => instance;

  late List<ChatThread> _threads;

  List<ChatThread> get threads => List.unmodifiable(_threads);

  int get unreadCount => _threads.fold(0, (sum, thread) => sum + thread.unreadCount);

  ChatThread? getThread(String recipientId) {
    try {
      return _threads.firstWhere((t) => t.recipient.id == recipientId);
    } catch (_) {
      return null;
    }
  }

  void sendMessage(String recipientId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final index = _threads.indexWhere((t) => t.recipient.id == recipientId);
    if (index < 0) return;

    final thread = _threads[index];
    final newMessage = EmployeeMessage(
      id: 'm-${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.me,
      text: trimmed,
      sentAt: DateTime.now(),
    );

    final updatedMessages = List<EmployeeMessage>.from(thread.messages)..add(newMessage);
    _threads[index] = thread.copyWith(messages: updatedMessages);
    notifyListeners();

    _simulateReply(recipientId);
  }

  void markAllRead(String recipientId) {
    final index = _threads.indexWhere((t) => t.recipient.id == recipientId);
    if (index < 0) return;

    final thread = _threads[index];
    var changed = false;
    final updatedMessages = thread.messages.map((m) {
      if (m.sender == MessageSender.them && !m.isRead) {
        changed = true;
        return m.copyWith(isRead: true);
      }
      return m;
    }).toList();

    if (changed) {
      _threads[index] = thread.copyWith(messages: updatedMessages);
      notifyListeners();
    }
  }

  void _simulateReply(String recipientId) {
    final thread = getThread(recipientId);
    if (thread == null) return;

    Future.delayed(const Duration(seconds: 2), () {
      final replyText = thread.recipient.isCustomer
          ? "Sige po, thank you!"
          : "Noted, thank you for the update.";

      final index = _threads.indexWhere((t) => t.recipient.id == recipientId);
      if (index < 0) return;

      final updatedThread = _threads[index];
      final reply = EmployeeMessage(
        id: 'r-${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.them,
        text: replyText,
        sentAt: DateTime.now(),
        isRead: false,
      );

      final newMessages = List<EmployeeMessage>.from(updatedThread.messages)..add(reply);
      _threads[index] = updatedThread.copyWith(messages: newMessages);
      notifyListeners();
    });
  }
}

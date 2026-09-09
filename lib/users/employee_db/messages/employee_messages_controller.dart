import 'dart:async';
import 'package:flutter/material.dart';

import 'employee_message_model.dart';

/// Owns the message threads for the Employee.
///
/// Manages conversations between the Employee and the Store Owner,
/// as well as conversations with Customers (order status, service, etc.).
class EmployeeMessagesController extends ChangeNotifier {
  EmployeeMessagesController._() {
    _threads = [
      _createOwnerThread(),
      _createEmployeeThread(),
      _createCustomerThread(
        id: 'cust-1',
        name: 'Maria Santos',
        email: 'maria.santos@gmail.com',
        phone: '0917 123 4567',
        initialMessage: 'Ask ko lang po if available pa yung Selecta Cookies & Cream 1.3L?',
      ),
      _createCustomerThread(
        id: 'cust-2',
        name: 'Roberto Gomez',
        email: 'roberto.gomez@yahoo.com',
        phone: '0920 987 6543',
        initialMessage: 'Hi, follow up ko lang po yung order #1005 ko for pickup.',
      ),
    ];
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

  ChatThread _createOwnerThread() {
    return ChatThread(
      recipient: const ChatRecipient(
        id: 'owner',
        name: 'Juan Dela Cruz',
        role: 'Owner',
        avatarIcon: Icons.storefront_outlined,
      ),
      messages: [
        EmployeeMessage(
          id: 'om1',
          sender: MessageSender.them,
          text: 'Good morning! Please check the remaining stocks of the beverages.',
          sentAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        EmployeeMessage(
          id: 'om2',
          sender: MessageSender.me,
          text: "Okay po, I'll check the inventory now.",
          sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 55)),
        ),
        EmployeeMessage(
          id: 'om3',
          sender: MessageSender.them,
          text: 'Thank you! Let me know if any items need restocking.',
          sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 50)),
          isRead: false,
        ),
      ],
    );
  }

  ChatThread _createEmployeeThread() {
    return ChatThread(
      recipient: const ChatRecipient(
        id: 'employee-1',
        name: 'Pedro Penduko',
        role: 'Employee',
        avatarIcon: Icons.badge_outlined,
        email: 'pedro.penduko@sarisari.com',
        phone: '0933 555 7788',
      ),
      messages: [
        EmployeeMessage(
          id: 'em1',
          sender: MessageSender.them,
          text: 'Sir, tapos na po yung inventory count para sa araw na ito.',
          sentAt: DateTime.now().subtract(const Duration(hours: 1)),
          isRead: false,
        ),
      ],
    );
  }

  ChatThread _createCustomerThread({
    required String id,
    required String name,
    required String email,
    required String phone,
    required String initialMessage,
  }) {
    return ChatThread(
      recipient: ChatRecipient(
        id: id,
        name: name,
        role: 'Customer',
        isCustomer: true,
        email: email,
        phone: phone,
      ),
      messages: [
        EmployeeMessage(
          id: '$id-m1',
          sender: MessageSender.them,
          text: initialMessage,
          sentAt: DateTime.now().subtract(const Duration(minutes: 45)),
          isRead: false,
        ),
      ],
    );
  }
}

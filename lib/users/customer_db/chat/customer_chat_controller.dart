import 'package:flutter/foundation.dart';
import '../../employee_db/messages/employee_message_model.dart';

class CustomerChatController extends ChangeNotifier {
  CustomerChatController._();
  static final CustomerChatController instance = CustomerChatController._();
  factory CustomerChatController() => instance;

  final List<EmployeeMessage> _messages = [
    EmployeeMessage(
      id: '1',
      sender: MessageSender.them,
      text: 'Hello! How can we help you today?',
      sentAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  List<EmployeeMessage> get messages => List.unmodifiable(_messages);

  int get unreadCount => _messages.where((m) => m.sender == MessageSender.them && !m.isRead).length;

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;
    
    final newMessage = EmployeeMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: MessageSender.me,
      text: text,
      sentAt: DateTime.now(),
    );

    _messages.add(newMessage);
    notifyListeners();

    // Simulate store response
    Future.delayed(const Duration(seconds: 2), () {
      final reply = EmployeeMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: MessageSender.them,
        text: 'Thank you for your message. We will get back to you shortly.',
        sentAt: DateTime.now(),
        isRead: false,
      );
      _messages.add(reply);
      notifyListeners();
    });
  }

  void markAllAsRead() {
    bool changed = false;
    for (int i = 0; i < _messages.length; i++) {
      if (_isThemUnread(_messages[i])) {
        _messages[i] = _messages[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  bool _isThemUnread(EmployeeMessage m) => m.sender == MessageSender.them && !m.isRead;

  bool get hasActiveChats => _messages.isNotEmpty;
}

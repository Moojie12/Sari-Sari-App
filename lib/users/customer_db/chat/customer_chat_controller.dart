import 'package:flutter/foundation.dart';

class CustomerChatController extends ChangeNotifier {
  CustomerChatController._();
  static final CustomerChatController instance = CustomerChatController._();
  factory CustomerChatController() => instance;

  // Mock data for unread messages
  int _unreadCount = 2;
  int get unreadCount => _unreadCount;

  // For simulation: mark all as read
  void markAllAsRead() {
    _unreadCount = 0;
    notifyListeners();
  }

  // Check if there are active chats
  bool get hasActiveChats => true; // Always true for mock
}

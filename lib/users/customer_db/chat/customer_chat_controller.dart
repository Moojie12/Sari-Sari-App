import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/chat_database_service.dart';
import '../../employee_db/messages/employee_message_model.dart';

class CustomerChatController extends ChangeNotifier {
  CustomerChatController._() {
    _subscribeToLiveMessages();
  }
  static final CustomerChatController instance = CustomerChatController._();
  factory CustomerChatController() => instance;

  final List<EmployeeMessage> _messages = <EmployeeMessage>[];
  StreamSubscription<List<EmployeeMessage>>? _messagesSubscription;

  List<EmployeeMessage> get messages => List.unmodifiable(_messages);

  int get unreadCount => _messages.where((m) => m.sender == MessageSender.them && !m.isRead).length;

  String get effectiveCustomerId => AuthService().currentUser?.uid ?? 'current_customer';
  String get effectiveCustomerName => AuthService().currentUser?.displayName ?? 'Customer';

  void _subscribeToLiveMessages() {
    try {
      _messagesSubscription?.cancel();
      _messagesSubscription = ChatDatabaseService.instance.streamMessages(
        customerId: effectiveCustomerId,
        isEmployeeView: false,
      ).listen((liveMessages) {
        _messages.clear();
        _messages.addAll(liveMessages);
        notifyListeners();
      }, onError: (e) {
        debugPrint('Error streaming customer messages: $e');
      });
    } catch (e) {
      debugPrint('Failed to subscribe to customer messages: $e');
    }
  }

  void sendMessage(String text, {String? customerId, String? customerName}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final targetId = customerId ?? effectiveCustomerId;
    final targetName = customerName ?? effectiveCustomerName;

    final newMessage = EmployeeMessage(
      id: 'm-${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.me,
      text: trimmed,
      sentAt: DateTime.now(),
    );

    _messages.add(newMessage);
    notifyListeners();

    // Send to Firebase Live Database
    ChatDatabaseService.instance.sendMessage(
      customerId: targetId,
      customerName: targetName,
      sender: 'customer',
      text: trimmed,
    );
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

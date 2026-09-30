import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/chat_database_service.dart';
import '../orders/employee_orders_controller.dart';
import 'employee_message_model.dart';

/// Owns the message threads for the Employee and Owner.
///
/// Manages conversations between staff and customers (order status, service, etc.).
class EmployeeMessagesController extends ChangeNotifier {
  EmployeeMessagesController._() {
    _threads.clear();
    _subscribeToRealtimeChats();
    syncCustomersFromOrders();
    EmployeeOrderController.instance.addListener(syncCustomersFromOrders);
  }

  static final EmployeeMessagesController instance = EmployeeMessagesController._();

  factory EmployeeMessagesController() => instance;

  final List<ChatThread> _threads = <ChatThread>[];
  StreamSubscription<List<ChatThread>>? _chatSubscription;

  List<ChatThread> get threads => List.unmodifiable(_threads);

  int get unreadCount {
    if (_threads.isEmpty) return 0;
    int total = 0;
    for (final thread in _threads) {
      total += thread.unreadCount;
    }
    return total;
  }

  void _subscribeToRealtimeChats() {
    try {
      _chatSubscription?.cancel();
      _chatSubscription = ChatDatabaseService.instance.streamAllThreads().listen(
        (realtimeThreads) {
          _mergeThreads(realtimeThreads);
        },
        onError: (e) {
          debugPrint('Error listening to chat threads: $e');
        },
      );
    } catch (e) {
      debugPrint('Failed to subscribe to chat threads: $e');
    }
  }

  final Set<String> _fetchedUserProfiles = {};

  /// Look up customer profile (avatarUrl, email, phone) from Firebase
  void fetchUserProfile(String userId) {
    if (userId.isEmpty || _fetchedUserProfiles.contains(userId)) return;
    _fetchedUserProfiles.add(userId);

    try {
      AuthService().database.ref().child('users/$userId').get().then((snapshot) {
        if (snapshot.exists && snapshot.value is Map) {
          final map = Map<String, dynamic>.from(snapshot.value as Map);
          final avatarUrl = map['avatar_url']?.toString() ?? map['photoUrl']?.toString() ?? map['photo_url']?.toString();
          final email = map['email']?.toString();
          final phone = map['phone']?.toString() ?? map['phoneNumber']?.toString();

          final index = _threads.indexWhere((t) => t.recipient.id == userId);
          if (index >= 0) {
            final old = _threads[index].recipient;
            if (old.avatarUrl != avatarUrl || old.email != email || old.phone != phone) {
              _threads[index] = ChatThread(
                recipient: ChatRecipient(
                  id: old.id,
                  name: map['fullName']?.toString() ?? map['name']?.toString() ?? old.name,
                  role: old.role,
                  avatarUrl: avatarUrl ?? old.avatarUrl,
                  isCustomer: old.isCustomer,
                  email: email ?? old.email,
                  phone: phone ?? old.phone,
                ),
                messages: _threads[index].messages,
              );
              notifyListeners();
            }
          }
        }
      }).catchError((e) {
        debugPrint('Error fetching user profile for chat: $e');
      });
    } catch (_) {}
  }

  void _mergeThreads(List<ChatThread> realtimeThreads) {
    for (final rtThread in realtimeThreads) {
      final index = _threads.indexWhere((t) => t.recipient.id == rtThread.recipient.id);
      if (index >= 0) {
        _threads[index] = rtThread;
      } else {
        _threads.add(rtThread);
      }
      fetchUserProfile(rtThread.recipient.id);
    }
    syncCustomersFromOrders();
    _sortThreads();
    notifyListeners();
  }

  /// Ensures every customer who placed an order is represented in the chat threads.
  void syncCustomersFromOrders() {
    final orders = EmployeeOrderController.instance.orders;
    bool changed = false;
    for (final order in orders) {
      if (order.userId != null && order.userId!.isNotEmpty) {
        fetchUserProfile(order.userId!);
        final existingIndex = _threads.indexWhere((t) => t.recipient.id == order.userId);
        if (existingIndex < 0) {
          _threads.add(ChatThread(
            recipient: ChatRecipient(
              id: order.userId!,
              name: order.customerName,
              role: 'Customer',
              isCustomer: true,
            ),
            messages: const [],
          ));
          changed = true;
        }
      }
    }
    if (changed) {
      _sortThreads();
      notifyListeners();
    }
  }

  void _sortThreads() {
    _threads.sort((a, b) {
      final aLast = a.lastMessage?.sentAt;
      final bLast = b.lastMessage?.sentAt;
      if (aLast == null && bLast == null) return 0;
      if (aLast == null) return 1;
      if (bLast == null) return -1;
      return bLast.compareTo(aLast);
    });
  }

  ChatThread? getThread(String recipientId) {
    try {
      return _threads.firstWhere((t) => t.recipient.id == recipientId);
    } catch (_) {
      return null;
    }
  }

  /// Gets an existing thread or creates a new thread for the recipient.
  ChatThread getOrCreateThread({
    required String recipientId,
    required String name,
    required String role,
    bool isCustomer = true,
  }) {
    final existingIndex = _threads.indexWhere(
      (t) => t.recipient.id == recipientId || t.recipient.name.toLowerCase() == name.toLowerCase(),
    );
    if (existingIndex >= 0) {
      return _threads[existingIndex];
    }

    final recipient = ChatRecipient(
      id: recipientId,
      name: name,
      role: role,
      isCustomer: isCustomer,
    );

    final newThread = ChatThread(
      recipient: recipient,
      messages: [],
    );

    _threads.insert(0, newThread);
    notifyListeners();
    return newThread;
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

    // Persist live message to Firebase Realtime Database
    ChatDatabaseService.instance.sendMessage(
      customerId: recipientId,
      customerName: thread.recipient.name,
      sender: 'employee',
      text: trimmed,
    );
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

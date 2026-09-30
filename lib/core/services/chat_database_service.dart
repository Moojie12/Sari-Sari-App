import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../users/employee_db/messages/employee_message_model.dart';
import 'auth_service.dart';

/// Database service dedicated to saving and streaming live chat messages
/// in real-time via Firebase Realtime Database under `chats/`.
class ChatDatabaseService {
  ChatDatabaseService._internal();
  static final ChatDatabaseService instance = ChatDatabaseService._internal();
  factory ChatDatabaseService() => instance;

  final AuthService _authService = AuthService();

  /// Save a message to Firebase Realtime Database at:
  /// `chats/$customerId/messages/$messageId`
  Future<void> sendMessage({
    required String customerId,
    required String customerName,
    required String sender, // 'customer' or 'employee'
    required String text,
    String? avatarUrl,
  }) async {
    if (customerId.isEmpty || text.trim().isEmpty) return;
    try {
      final db = _authService.database;
      final timestamp = DateTime.now();
      final msgId = 'm-${timestamp.millisecondsSinceEpoch}';

      final messageRef = db.ref().child('chats/$customerId/messages/$msgId');
      await messageRef.set({
        'id': msgId,
        'sender': sender,
        'text': text.trim(),
        'sentAt': timestamp.toIso8601String(),
        'isRead': false,
      });

      // Update meta information for thread list
      final metaRef = db.ref().child('chats/$customerId/meta');
      final metaData = <String, dynamic>{
        'customerId': customerId,
        'customerName': customerName,
        'lastMessage': text.trim(),
        'lastSentAt': timestamp.toIso8601String(),
        'lastSender': sender,
      };
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        metaData['avatarUrl'] = avatarUrl;
      }
      await metaRef.update(metaData);

      debugPrint('Live chat message sent to Firebase for customer $customerId');
    } catch (e) {
      debugPrint('Failed to send live chat message to database: $e');
    }
  }

  /// Streams real-time messages for a specific customer chat thread from Firebase
  Stream<List<EmployeeMessage>> streamMessages({
    required String customerId,
    required bool isEmployeeView,
  }) {
    if (customerId.isEmpty) return const Stream.empty();
    try {
      final db = _authService.database;
      final ref = db.ref().child('chats/$customerId/messages');

      return ref.onValue.map((event) {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          return <EmployeeMessage>[];
        }

        final Map<dynamic, dynamic> rawMap =
            event.snapshot.value as Map<dynamic, dynamic>;
        final List<EmployeeMessage> list = [];

        rawMap.forEach((key, val) {
          if (val is Map) {
            final senderRole = val['sender']?.toString() ?? 'customer';
            
            // If employee view: 'employee' is me, 'customer' is them
            // If customer view: 'customer' is me, 'employee' is them
            final bool isMe = isEmployeeView
                ? (senderRole == 'employee' || senderRole == 'me')
                : (senderRole == 'customer' || senderRole == 'me');

            list.add(
              EmployeeMessage(
                id: val['id']?.toString() ?? key.toString(),
                sender: isMe ? MessageSender.me : MessageSender.them,
                text: val['text']?.toString() ?? '',
                sentAt: DateTime.tryParse(val['sentAt']?.toString() ?? '') ?? DateTime.now(),
                isRead: val['isRead'] == true,
              ),
            );
          }
        });

        list.sort((a, b) => a.sentAt.compareTo(b.sentAt));
        return list;
      });
    } catch (e) {
      debugPrint('Failed to stream live messages: $e');
      return const Stream.empty();
    }
  }

  /// Streams all chat threads from Firebase Realtime Database
  Stream<List<ChatThread>> streamAllThreads() {
    try {
      final db = _authService.database;
      final ref = db.ref().child('chats');

      return ref.onValue.map((event) {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          return <ChatThread>[];
        }

        final Map<dynamic, dynamic> chatsMap =
            event.snapshot.value as Map<dynamic, dynamic>;
        final List<ChatThread> threads = [];

        chatsMap.forEach((key, val) {
          if (val is Map) {
            final String customerId = key.toString();
            final meta = val['meta'];
            final messagesMap = val['messages'];

            String customerName = 'Customer $customerId';
            String? avatarUrl;
            if (meta is Map) {
              customerName = meta['customerName']?.toString() ?? customerName;
              avatarUrl = meta['avatarUrl']?.toString() ?? meta['photoUrl']?.toString();
            }

            final List<EmployeeMessage> messages = [];

            if (messagesMap is Map) {
              messagesMap.forEach((msgKey, msgVal) {
                if (msgVal is Map) {
                  final senderRole = msgVal['sender']?.toString() ?? 'customer';
                  final bool isMe = (senderRole == 'employee' || senderRole == 'me' || senderRole == 'owner');

                  messages.add(
                    EmployeeMessage(
                      id: msgVal['id']?.toString() ?? msgKey.toString(),
                      sender: isMe ? MessageSender.me : MessageSender.them,
                      text: msgVal['text']?.toString() ?? '',
                      sentAt: DateTime.tryParse(msgVal['sentAt']?.toString() ?? '') ?? DateTime.now(),
                      isRead: msgVal['isRead'] == true,
                    ),
                  );
                }
              });
            }

            messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

            threads.add(
              ChatThread(
                recipient: ChatRecipient(
                  id: customerId,
                  name: customerName,
                  role: 'Customer',
                  avatarUrl: avatarUrl,
                  isCustomer: true,
                ),
                messages: messages,
              ),
            );
          }
        });

        threads.sort((a, b) {
          final aLast = a.lastMessage?.sentAt;
          final bLast = b.lastMessage?.sentAt;
          if (aLast == null && bLast == null) return 0;
          if (aLast == null) return 1;
          if (bLast == null) return -1;
          return bLast.compareTo(aLast);
        });

        return threads;
      });
    } catch (e) {
      debugPrint('Failed to stream all threads: $e');
      return const Stream.empty();
    }
  }
}

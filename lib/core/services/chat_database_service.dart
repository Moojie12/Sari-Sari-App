import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../users/employee_db/messages/employee_message_model.dart';
import '../../users/employee_db/notifications/employee_notifications_controller.dart';
import '../../users/employee_db/notifications/employee_notification_model.dart';
import '../../users/customer_db/notifications/customer_notifications_controller.dart';
import '../../users/customer_db/notifications/customer_notification_model.dart';
import 'auth_service.dart';
import 'onesignal_notification_service.dart';

/// Database service dedicated to saving and streaming live chat messages
/// in real-time via Firebase Realtime Database under `chats/`.
class ChatDatabaseService {
  ChatDatabaseService._internal();
  static final ChatDatabaseService instance = ChatDatabaseService._internal();
  factory ChatDatabaseService() => instance;

  final AuthService _authService = AuthService();
  String? _lastSentFingerprint;
  DateTime? _lastSentTimestamp;

  /// Save a message to Firebase Realtime Database at:
  /// `chats/$customerId/messages/$messageId`
  Future<void> sendMessage({
    required String customerId,
    required String customerName,
    required String sender, // 'customer', 'employee', 'owner'
    required String text,
    String? avatarUrl,
  }) async {
    final cleanText = text.trim();
    if (customerId.isEmpty || cleanText.isEmpty) return;

    // Deduplication check: Avoid sending identical message within 1.5 seconds
    final fingerprint = '$customerId|$sender|$cleanText';
    final now = DateTime.now();
    if (_lastSentFingerprint == fingerprint &&
        _lastSentTimestamp != null &&
        now.difference(_lastSentTimestamp!).inMilliseconds < 1500) {
      debugPrint('[ChatDatabaseService] Duplicate rapid message blocked: $cleanText');
      return;
    }
    _lastSentFingerprint = fingerprint;
    _lastSentTimestamp = now;

    try {
      final db = _authService.database;
      final timestamp = DateTime.now();
      final msgId = 'm-${timestamp.millisecondsSinceEpoch}';

      final messageRef = db.ref().child('chats/$customerId/messages/$msgId');
      await messageRef.set({
        'id': msgId,
        'sender': sender,
        'text': cleanText,
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

      debugPrint('Live chat message sent to Firebase for customer $customerId by $sender');

      // Trigger notification for the recipient without disrupting chat flow
      final senderRole = sender.toLowerCase().trim();
      if (senderRole == 'customer') {
        _notifyStaffOfChatMessage(
          customerId: customerId,
          customerName: customerName,
          text: text.trim(),
        );
      } else {
        _notifyCustomerOfChatMessage(
          customerId: customerId,
          text: text.trim(),
        );
      }
    } catch (e) {
      debugPrint('Failed to send live chat message to database: $e');
    }
  }

  void _notifyStaffOfChatMessage({
    required String customerId,
    required String customerName,
    required String text,
  }) {
    try {
      final displayName = customerName.isNotEmpty ? customerName : 'A customer';
      final title = 'New message from $displayName';
      final body = text.length > 80 ? '${text.substring(0, 77)}...' : text;

      // Add to store in-app notifications
      EmployeeNotificationsController.instance.addNotification(
        type: EmployeeNotificationType.assignedTask,
        title: title,
        message: body,
        customerId: customerId,
        sendPush: false,
      );

      // Send OneSignal push to all store staff
      OneSignalNotificationService.instance.sendStaffNotification(
        title: title,
        body: body,
        type: 'chat_message',
        excludeUserId: customerId,
        additionalData: {
          'customerId': customerId,
          'customerName': displayName,
        },
      );
    } catch (e) {
      debugPrint('[ChatDatabaseService] Note: Failed to notify staff of chat: $e');
    }
  }

  void _notifyCustomerOfChatMessage({
    required String customerId,
    required String text,
  }) {
    try {
      final title = 'New message from Store';
      final body = text.length > 80 ? '${text.substring(0, 77)}...' : text;

      // Add to customer in-app notifications
      CustomerNotificationsController.instance.addNotification(
        type: CustomerNotificationType.orderUpdate,
        title: title,
        message: body,
        userId: customerId,
        sendPush: false,
      );

      // Send OneSignal push to the customer
      final currentStaffUid = AuthService().currentUser?.uid;
      OneSignalNotificationService.instance.sendCustomerNotification(
        customerUserId: customerId,
        title: title,
        body: body,
        type: 'chat_message',
        excludeUserId: currentStaffUid,
        additionalData: {
          'customerId': customerId,
        },
      );
    } catch (e) {
      debugPrint('[ChatDatabaseService] Note: Failed to notify customer of chat: $e');
    }
  }

  /// Marks all messages from the other participant as read in Firebase Realtime Database
  Future<void> markMessagesAsRead({
    required String customerId,
    required bool isEmployeeView,
  }) async {
    if (customerId.isEmpty) return;
    try {
      final db = _authService.database;
      final ref = db.ref().child('chats/$customerId/messages');
      final snapshot = await ref.get();
      if (!snapshot.exists || snapshot.value == null) return;

      final data = snapshot.value;
      if (data is Map) {
        final updates = <String, dynamic>{};
        data.forEach((key, val) {
          if (val is Map) {
            final senderRole = val['sender']?.toString().toLowerCase() ?? 'customer';
            final isThem = isEmployeeView
                ? (senderRole == 'customer')
                : (senderRole == 'employee' || senderRole == 'owner' || senderRole == 'staff');
            final isRead = val['isRead'] == true;
            if (isThem && !isRead) {
              updates['$key/isRead'] = true;
            }
          }
        });

        if (updates.isNotEmpty) {
          await ref.update(updates);
          debugPrint('Marked ${updates.length} messages as read for customer $customerId in Firebase RTDB');
        }
      }
    } catch (e) {
      debugPrint('Failed to mark messages as read in database: $e');
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
            final senderRole = val['sender']?.toString().toLowerCase() ?? 'customer';

            // If employee or owner view: 'employee'/'owner'/'staff'/'me' is me, 'customer' is them
            // If customer view: 'customer'/'me' is me, 'employee'/'owner'/'staff' is them
            final bool isMe = isEmployeeView
                ? (senderRole == 'employee' || senderRole == 'owner' || senderRole == 'me' || senderRole == 'staff')
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

            String customerName = 'Customer ${customerId.length > 6 ? customerId.substring(0, 6) : customerId}';
            String? avatarUrl;
            if (meta is Map) {
              customerName = meta['customerName']?.toString() ?? customerName;
              avatarUrl = meta['avatarUrl']?.toString() ?? meta['photoUrl']?.toString();
            }

            final List<EmployeeMessage> messages = [];

            if (messagesMap is Map) {
              messagesMap.forEach((msgKey, msgVal) {
                if (msgVal is Map) {
                  final senderRole = msgVal['sender']?.toString().toLowerCase() ?? 'customer';
                  final bool isMe = (senderRole == 'employee' || senderRole == 'owner' || senderRole == 'me' || senderRole == 'staff');

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

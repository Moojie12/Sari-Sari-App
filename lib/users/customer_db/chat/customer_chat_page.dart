import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/editable_profile_avatar.dart';
import '../../employee_db/messages/employee_message_model.dart';
import 'customer_chat_controller.dart';

class StoreStaffMember {
  final String uid;
  final String name;
  final String role;
  final String? photoUrl;
  final bool isOwner;

  StoreStaffMember({
    required this.uid,
    required this.name,
    required this.role,
    this.photoUrl,
    this.isOwner = false,
  });
}

class CustomerChatPage extends StatefulWidget {
  const CustomerChatPage({super.key});

  @override
  State<CustomerChatPage> createState() => _CustomerChatPageState();
}

class _CustomerChatPageState extends State<CustomerChatPage> {
  final _controller = CustomerChatController.instance;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.markAllAsRead();
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _send() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _controller.sendMessage(text);
    _textController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<List<StoreStaffMember>> _fetchStoreSupportTeam() async {
    final Map<String, StoreStaffMember> staffMap = {};

    void processUserRecord(String uid, Map<String, dynamic> data) {
      if (uid.trim().isEmpty) return;

      final status = (data['status'] ?? '').toString().toLowerCase().trim();
      final isArchived = data['isArchived'] == true ||
          data['archived'] == true ||
          data['is_archived'] == true;

      if (status == 'disabled' || status == 'archived' || isArchived) {
        return;
      }

      final rawRole = (data['role'] ?? '').toString().toLowerCase().trim();
      if (rawRole == 'owner' ||
          rawRole == 'employee' ||
          rawRole == 'admin' ||
          rawRole == 'staff') {
        String fName =
            (data['firstName'] ?? data['first_name'] ?? '').toString().trim();
        String lName = (data['surname'] ??
                data['lastName'] ??
                data['last_name'] ??
                '')
            .toString()
            .trim();
        String mInit = (data['middleInitial'] ?? data['middle_initial'] ?? '')
            .toString()
            .trim();
        String dName =
            (data['displayName'] ?? data['name'] ?? '').toString().trim();

        String fullName = '';
        if (fName.isNotEmpty || lName.isNotEmpty) {
          final mi = mInit.isNotEmpty
              ? '${mInit.replaceAll(".", "").toUpperCase()}. '
              : '';
          fullName = '$fName $mi$lName'.trim();
        } else if (dName.isNotEmpty) {
          fullName = dName;
        } else {
          final email = (data['email'] ?? '').toString().trim();
          if (email.contains('@')) {
            fullName = email.split('@').first;
          } else {
            fullName = (rawRole == 'owner' || rawRole == 'admin')
                ? 'Store Owner'
                : 'Employee';
          }
        }

        String roleLabel = 'Employee';
        bool isOwner = false;
        if (rawRole == 'owner' || rawRole == 'admin') {
          roleLabel = 'Store Owner';
          isOwner = true;
        } else {
          final customTitle = (data['roleTitle'] ??
                  data['designation'] ??
                  data['jobTitle'] ??
                  '')
              .toString()
              .trim();
          roleLabel = customTitle.isNotEmpty ? customTitle : 'Employee';
        }

        final avatar = data['avatar_url']?.toString() ??
            data['photoUrl']?.toString() ??
            data['photo_url']?.toString() ??
            data['photoPath']?.toString();

        staffMap[uid] = StoreStaffMember(
          uid: uid,
          name: fullName,
          role: roleLabel,
          photoUrl: avatar,
          isOwner: isOwner,
        );
      }
    }

    // 1. Fetch from Firebase Realtime Database
    try {
      final snapshot = await AuthService().database.ref().child('users').get();
      if (snapshot.exists && snapshot.value is Map) {
        final rawMap = Map<dynamic, dynamic>.from(snapshot.value as Map);
        rawMap.forEach((key, value) {
          if (value is Map) {
            final data = Map<String, dynamic>.from(value);
            processUserRecord(key.toString(), data);
          }
        });
      }
    } catch (e) {
      debugPrint('[CustomerChatPage] Error loading store support team from RTDB: $e');
    }

    // 2. Fetch from Supabase profiles as complement or fallback
    try {
      final profiles = await SupabaseService().getAllProfiles();
      for (final profile in profiles) {
        final uid = profile['firebase_uid']?.toString().isNotEmpty == true
            ? profile['firebase_uid'].toString()
            : (profile['id']?.toString() ?? '');
        if (uid.isNotEmpty) {
          final existing = staffMap[uid];
          if (existing == null) {
            processUserRecord(uid, profile);
          } else if ((existing.name == 'Store Owner' || existing.name == 'Employee') &&
              ((profile['first_name']?.toString().isNotEmpty ?? false) ||
                  (profile['surname']?.toString().isNotEmpty ?? false))) {
            processUserRecord(uid, profile);
          }
        }
      }
    } catch (e) {
      debugPrint('[CustomerChatPage] Error loading store support team from Supabase: $e');
    }

    final List<StoreStaffMember> staffList = staffMap.values.toList();

    staffList.sort((a, b) {
      if (a.isOwner && !b.isOwner) return -1;
      if (!a.isOwner && b.isOwner) return 1;
      return a.name.compareTo(b.name);
    });

    return staffList;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final messages = _controller.messages;

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            backgroundColor: AppColors.primaryOrange,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            titleSpacing: 0,
            title: const Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.storefront_outlined, color: Colors.white, size: 18),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tindahan ni Eca Support',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Online',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.white),
                onPressed: () => _showStoreStaffInfo(context),
                tooltip: 'Store Info',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: AppColors.placeholderColor.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No messages yet.\nSend a message to contact store support.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.secondaryText.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          itemCount: messages.length,
                          itemBuilder: (context, index) => _ChatBubble(
                            message: messages[index],
                            timeLabel: _formatTime(messages[index].sentAt),
                          ),
                        ),
                ),
                _MessageComposer(controller: _textController, onSend: _send),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStoreStaffInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Store Support Team',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text(
              'Both the owner and employees can assist you in this chat.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Flexible(
              child: FutureBuilder<List<StoreStaffMember>>(
                future: _fetchStoreSupportTeam(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: CircularProgressIndicator(color: AppColors.primaryOrange),
                      ),
                    );
                  }

                  final staffList = snapshot.data ?? [];
                  if (staffList.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No store support staff found.',
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: staffList.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final staff = staffList[index];
                      return _StaffRow(
                        name: staff.name,
                        role: staff.role,
                        icon: staff.isOwner ? Icons.storefront_outlined : Icons.badge_outlined,
                        photoUrl: staff.photoUrl,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.name,
    required this.role,
    required this.icon,
    this.photoUrl,
  });

  final String name;
  final String role;
  final IconData icon;
  final String? photoUrl;

  String get _computedInitials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.lightPeach.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryOrange.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          EditableProfileAvatar(
            initials: _computedInitials,
            photoPath: photoUrl,
            radius: 20,
            isEditable: false,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.timeLabel});

  final EmployeeMessage message;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final isMe = message.sender == MessageSender.me;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryOrange : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 14),
          ),
          boxShadow: [
            if (!isMe)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.darkText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeLabel,
              style: TextStyle(
                color: isMe ? Colors.white70 : AppColors.secondaryText.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Type a message…',
                hintStyle: const TextStyle(color: AppColors.placeholderColor, fontSize: 14),
                filled: true,
                fillColor: AppColors.lightBackground,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: AppColors.primaryOrange,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onSend,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../authentication/login/login_page.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../messages/employee_messages_controller.dart';
import '../messages/employee_messages_page.dart';
import '../notifications/employee_notifications_controller.dart';
import '../notifications/employee_notifications_page.dart';
import 'employee_change_password_page.dart';
import 'employee_edit_profile_page.dart';
import 'employee_my_consumables_page.dart';
import 'employee_profile_controller.dart';
import 'employee_profile_model.dart';
import '../../owner_db/history/owner_history_page.dart';
import '../../../shared/widgets/editable_profile_avatar.dart';

/// Employee "Profile" tab: a menu into every Employee Profile feature —
/// Profile Information, Edit Profile, Messages, Notifications, Change
/// Password, and Logout.
class EmployeeProfilePage extends StatefulWidget {
  const EmployeeProfilePage({super.key});

  @override
  State<EmployeeProfilePage> createState() => _EmployeeProfilePageState();
}

class _EmployeeProfilePageState extends State<EmployeeProfilePage> {
  @override
  void initState() {
    super.initState();
    EmployeeProfileController.instance.loadProfile();
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context, rootNavigator: true);
              Navigator.pop(dialogContext); // Close dialog
              await AuthService().signOut();
              EmployeeProfileController.instance.clear();
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileController = EmployeeProfileController.instance;
    final messagesController = EmployeeMessagesController.instance;
    final notificationsController = EmployeeNotificationsController.instance;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 50, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile',
              style: TextStyle(
                color: AppColors.darkText,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ListenableBuilder(
              listenable: profileController,
              builder: (context, _) {
                final profile = profileController.profile;
                return _ProfileHeaderCard(
                  profile: profile,
                );
              },
            ),
            const SizedBox(height: 28),
            const Text(
              'Account Actions',
              style: TextStyle(
                color: AppColors.darkText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              children: [
                _MenuTile(
                  icon: Icons.edit_outlined,
                  label: 'Edit Profile',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EmployeeEditProfilePage()),
                  ),
                ),
                _MenuTile(
                  icon: Icons.lock_outline,
                  label: 'Change Password',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EmployeeChangePasswordPage()),
                  ),
                ),
                _MenuTile(
                  icon: Icons.set_meal_outlined,
                  label: 'My Consumables',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EmployeeMyConsumablesPage(role: 'Employee')),
                  ),
                ),
                _MenuTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Sales & Transaction Records',
                  isLast: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OwnerTransactionHistoryPage()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Updates',
              style: TextStyle(
                color: AppColors.darkText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: Listenable.merge([messagesController, notificationsController]),
              builder: (context, _) {
                return _MenuCard(
                  children: [
                    _MenuTile(
                      icon: Icons.forum_outlined,
                      label: 'Messages',
                      badgeCount: messagesController.unreadCount,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EmployeeMessagesPage(viewerRole: 'Employee')),
                      ),
                    ),
                    _MenuTile(
                      icon: Icons.notifications_none_outlined,
                      label: 'Notifications',
                      badgeCount: notificationsController.unreadCount,
                      isLast: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EmployeeNotificationsPage()),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _MenuCard(
              children: [
                _MenuTile(
                  icon: Icons.logout,
                  label: 'Logout',
                  isLast: true,
                  iconColor: Colors.redAccent,
                  labelColor: Colors.redAccent,
                  onTap: () => _showLogoutConfirmation(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar + name + role summary shown above the menu.
class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.profile,
  });

  final EmployeeProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          EditableProfileAvatar(
            initials: profile.initials,
            photoPath: profile.photoPath,
            radius: 30,
            isEditable: false,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName.trim().isEmpty ? 'Employee' : profile.fullName,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    profile.role,
                    style: const TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

/// Rounded white card that groups a set of [_MenuTile]s, matching the
/// card look used across the employee tabs (Home's stat cards, etc.).
class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

/// A single tappable row inside a [_MenuCard] — an icon, a label, an
/// optional unread-count badge, and a chevron.
class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
    this.badgeCount = 0,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;
  final int badgeCount;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isLast ? Radius.zero : Radius.zero,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(bottom: BorderSide(color: AppColors.borderColor.withValues(alpha: 0.6))),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor ?? AppColors.primaryOrange),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: labelColor ?? AppColors.darkText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (badgeCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  constraints: const BoxConstraints(minWidth: 20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              const Icon(Icons.chevron_right, size: 20, color: AppColors.placeholderColor),
            ],
          ),
        ),
      ),
    );
  }
}
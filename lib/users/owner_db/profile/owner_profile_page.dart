import 'package:flutter/material.dart';
import '../../../authentication/login/login_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../../employee_db/profile/employee_profile_controller.dart';
import '../../employee_db/profile/employee_profile_model.dart';
import '../../employee_db/profile/employee_change_password_page.dart';
import '../../employee_db/profile/employee_edit_profile_page.dart';
import '../../employee_db/profile/employee_profile_info_page.dart';
import '../../employee_db/messages/employee_messages_controller.dart';
import '../../employee_db/messages/employee_messages_page.dart';
import '../../employee_db/notifications/employee_notifications_controller.dart';
import '../../employee_db/notifications/employee_notifications_page.dart';
import '../history/owner_history_page.dart';
import '../reports/owner_reports_page.dart';
import '../reports/owner_shift_reports_page.dart';
import 'owner_archived_products_page.dart';
import '../../employee_db/profile/employee_my_consumables_page.dart';
import 'shop_settings_controller.dart';
import 'owner_create_employee_page.dart';

class OwnerProfilePage extends StatelessWidget {
  const OwnerProfilePage({super.key});

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
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
        padding: const EdgeInsets.fromLTRB(24, 50, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Owner Profile',
                style: TextStyle(color: AppColors.darkText, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ListenableBuilder(
              listenable: profileController,
              builder: (context, _) => _ProfileHeaderCard(
                profile: profileController.profile.copyWith(role: 'Owner'),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Account', style: TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _MenuCard(
              children: [
                _MenuTile(
                  icon: Icons.badge_outlined,
                  label: 'Profile Information',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeProfileInfoPage())),
                ),
                _MenuTile(
                  icon: Icons.person_add_alt_1_outlined,
                  label: 'Create Employee',
                  onTap: () async {
                    final created = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (context) => const OwnerCreateEmployeePage()),
                    );
                    if (created == true && context.mounted) {
                      _showSuccessDialog(context, 'Employee account created successfully.');
                    }
                  },
                ),
                _MenuTile(
                  icon: Icons.edit_outlined,
                  label: 'Edit Profile',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeEditProfilePage())),
                ),
                _MenuTile(
                  icon: Icons.lock_outline,
                  label: 'Change Password',
                  isLast: true,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeChangePasswordPage())),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text('Updates', style: TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold)),
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
                        MaterialPageRoute(builder: (context) => const EmployeeMessagesPage(viewerRole: 'Owner')),
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
            const SizedBox(height: 28),
            const Text('History & Accountability', style: TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _MenuCard(
              children: [
                _MenuTile(
                  icon: Icons.history,
                  label: 'Transaction History',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OwnerTransactionHistoryPage())),
                ),
                _MenuTile(
                  icon: Icons.bar_chart_rounded,
                  label: 'View Reports',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OwnerReportsPage())),
                ),
                _MenuTile(
                  icon: Icons.point_of_sale_outlined,
                  label: 'Shift Reports',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OwnerShiftReportsPage())),
                ),
                _MenuTile(
                  icon: Icons.list_alt,
                  label: 'Employee Activity Logs',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OwnerActivityLogsPage())),
                ),
                _MenuTile(
                  icon: Icons.archive_outlined,
                  label: 'Archived Products',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OwnerArchivedProductsPage())),
                ),
                _MenuTile(
                  icon: Icons.set_meal_outlined,
                  label: 'My Consumables',
                  isLast: true,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeMyConsumablesPage(role: 'Owner'))),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text('System Settings', style: TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _MenuCard(
              children: [
                _MenuTile(
                  icon: Icons.qr_code_2_outlined,
                  label: 'GCash QR Code',
                  onTap: () => _showGcashQrDialog(context),
                ),
                _MenuTile(
                  icon: Icons.low_priority,
                  label: 'Low-Stock Threshold',
                  onTap: () => _showThresholdDialog(context),
                ),
                _MenuTile(
                  icon: Icons.delivery_dining_outlined,
                  label: 'Delivery Fee Config',
                  onTap: () => _showDeliveryFeeDialog(context),
                ),
                _MenuTile(
                  icon: Icons.timer_outlined,
                  label: 'Expiry Monitoring Config',
                  isLast: true,
                  onTap: () => _showExpiryConfigDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 28),
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
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Future<void> _showGcashQrDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('GCash QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Upload your store\'s GCash QR code for customer payments.'),
            const SizedBox(height: 20),
            Container(
              height: 160,
              width: 160,
              decoration: BoxDecoration(
                color: AppColors.lightPeach,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: const Icon(Icons.add_a_photo_outlined, size: 48, color: AppColors.primaryOrange),
            ),
            const SizedBox(height: 16),
            const Text(
              'Click to upload or change image',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final proceed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Changes'),
                  content: const Text('Do you want to save this new GCash QR code?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Yes', style: TextStyle(color: AppColors.primaryOrange)),
                    ),
                  ],
                ),
              );

              if (proceed == true && context.mounted) {
                Navigator.pop(context);
                _showSuccessDialog(context, 'GCash QR code updated successfully.');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showThresholdDialog(BuildContext context) {
    final controller = ShopSettingsController.instance;
    final textController = TextEditingController(text: controller.lowStockThreshold.toString());
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Low-Stock Threshold'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Set the default item count for low stock alerts.'),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  if (errorText != null) setState(() => errorText = null);
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'e.g. 10',
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                if (textController.text.trim().isEmpty) {
                  setState(() => errorText = 'You must fill this field');
                  return;
                }

                final newValue = int.tryParse(textController.text);
                if (newValue == null) {
                  setState(() => errorText = 'Please enter a valid number');
                  return;
                }

                final proceed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Changes'),
                    content: const Text('Do you want to save this new low-stock threshold?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Yes', style: TextStyle(color: AppColors.primaryOrange)),
                      ),
                    ],
                  ),
                );

                if (proceed == true && context.mounted) {
                  controller.updateLowStockThreshold(newValue);
                  Navigator.pop(context);
                  _showSuccessDialog(context, 'Low-stock threshold updated.');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeliveryFeeDialog(BuildContext context) {
    final controller = ShopSettingsController.instance;
    final textController = TextEditingController(text: controller.deliveryFeePer500m.toString());
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Delivery Fee Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Set the delivery fee for every 500 meters (0.5 km) distance.'),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  if (errorText != null) setState(() => errorText = null);
                },
                decoration: InputDecoration(
                  prefixText: '₱ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'e.g. 5.00',
                  labelText: 'Fee per 500m',
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                if (textController.text.trim().isEmpty) {
                  setState(() => errorText = 'You must fill this field');
                  return;
                }

                final newValue = double.tryParse(textController.text);
                if (newValue == null) {
                  setState(() => errorText = 'Please enter a valid amount');
                  return;
                }

                final proceed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Changes'),
                    content: Text('Do you want to set the delivery fee to ₱${newValue.toStringAsFixed(2)} per 500m?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Yes', style: TextStyle(color: AppColors.primaryOrange)),
                      ),
                    ],
                  ),
                );

                if (proceed == true && context.mounted) {
                  controller.updateDeliveryFee(newValue);
                  Navigator.pop(context);
                  _showSuccessDialog(context, 'Delivery fee setting updated.');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExpiryConfigDialog(BuildContext context) {
    final controller = ShopSettingsController.instance;
    int selectedDays = controller.expiryMonitoringDays;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Expiry Monitoring'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Notify when items are within:'),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: selectedDays,
              items: const [
                DropdownMenuItem(value: 7, child: Text('7 Days')),
                DropdownMenuItem(value: 15, child: Text('15 Days')),
                DropdownMenuItem(value: 30, child: Text('30 Days')),
                DropdownMenuItem(value: 60, child: Text('60 Days')),
              ],
              onChanged: (v) {
                if (v != null) selectedDays = v;
              },
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final proceed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Changes'),
                  content: const Text('Do you want to save this expiry monitoring configuration?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Yes', style: TextStyle(color: AppColors.primaryOrange)),
                    ),
                  ],
                ),
              );

              if (proceed == true && context.mounted) {
                controller.updateExpiryMonitoringDays(selectedDays);
                Navigator.pop(context);
                _showSuccessDialog(context, 'Expiry monitoring configuration saved.');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Settings Updated',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
            ),
            const SizedBox(height: 10),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.profile});
  final EmployeeProfile profile;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.12),
            child: Text(profile.initials, style: const TextStyle(color: AppColors.primaryOrange, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.fullName, style: const TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(profile.role, style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.8), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(16)),
      child: Column(children: children),
    );
  }
}

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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: isLast ? null : Border(bottom: BorderSide(color: AppColors.borderColor.withValues(alpha: 0.6))),
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
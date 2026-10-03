import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../authentication/login/login_page.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import 'package:sari_sari/shared/utils/top_notification.dart';
import 'owner_profile_controller.dart';
import 'owner_edit_profile_page.dart';
import '../../employee_db/profile/employee_profile_model.dart';
import '../../employee_db/profile/employee_change_password_page.dart';
import '../../employee_db/messages/employee_messages_controller.dart';
import '../../employee_db/messages/employee_messages_page.dart';
import '../../employee_db/notifications/employee_notifications_controller.dart';
import '../../employee_db/notifications/employee_notifications_page.dart';
import '../history/owner_history_page.dart';
import '../reports/owner_reports_page.dart';
import '../reports/owner_operational_logs_page.dart';
import 'shop_settings_controller.dart';
import '../promotions/owner_sale_management_page.dart';
import '../../../shared/widgets/editable_profile_avatar.dart';

class OwnerProfilePage extends StatefulWidget {
  const OwnerProfilePage({super.key});

  @override
  State<OwnerProfilePage> createState() => _OwnerProfilePageState();
}

class _OwnerProfilePageState extends State<OwnerProfilePage> {
  @override
  void initState() {
    super.initState();
    OwnerProfileController.instance.loadProfile();
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
              Navigator.pop(dialogContext);
              await AuthService().signOut();
              OwnerProfileController.instance.clear();
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
    final profileController = OwnerProfileController.instance;
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
              builder: (context, _) {
                return _ProfileHeaderCard(
                  profile: profileController.profile,
                );
              },
            ),
            const SizedBox(height: 28),
            const Text('Account Actions', style: TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _MenuCard(
              children: [
                _MenuTile(
                  icon: Icons.edit_outlined,
                  label: 'Edit Profile',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OwnerEditProfilePage())),
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
                  icon: Icons.insights_rounded,
                  label: 'View Reports & Analytics',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OwnerReportsPage())),
                ),
                _MenuTile(
                  icon: Icons.receipt_long_rounded,
                  label: 'Operational Logs & Summaries',
                  isLast: true,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OwnerOperationalLogsPage())),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text('Promotions & Discounts', style: TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _MenuCard(
              children: [
                _MenuTile(
                  icon: Icons.local_offer_rounded,
                  label: 'Customize On-Sale Deals',
                  isLast: true,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OwnerSaleManagementPage())),
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
    final picker = ImagePicker();
    XFile? pickedFile;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final settings = ShopSettingsController.instance;
          final currentUrl = settings.gcashQrUrl;

          return AlertDialog(
            title: const Text('GCash QR Code'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Upload your store\'s GCash QR code for customer payments.'),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async {
                      final image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setDialogState(() {
                          pickedFile = image;
                        });
                      }
                    },
                    child: Container(
                      height: 180,
                      width: 180,
                      decoration: BoxDecoration(
                        color: AppColors.lightPeach,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.4), width: 1.5),
                      ),
                      child: pickedFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.file(
                                File(pickedFile!.path),
                                fit: BoxFit.cover,
                              ),
                            )
                          : (currentUrl != null && currentUrl.isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.network(
                                    currentUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image_outlined, size: 48, color: AppColors.primaryOrange),
                                        SizedBox(height: 8),
                                        Text('Image load failed', style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_outlined, size: 48, color: AppColors.primaryOrange),
                                    SizedBox(height: 8),
                                    Text('Tap to select image', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                                  ],
                                ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setDialogState(() {
                          pickedFile = image;
                        });
                      }
                    },
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: Text(pickedFile != null ? 'Change Selected Image' : 'Select New QR Image'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryOrange,
                      side: const BorderSide(color: AppColors.primaryOrange),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  if (pickedFile == null && (currentUrl == null || currentUrl.isEmpty)) {
                    TopNotification.show(context, 'Please select a QR code image to upload', isError: true);
                    return;
                  }

                  final proceed = await showDialog<bool>(
                    context: dialogContext,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Confirm Changes'),
                      content: const Text('Do you want to save this new GCash QR code?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Yes', style: TextStyle(color: AppColors.primaryOrange)),
                        ),
                      ],
                    ),
                  );

                  if (proceed == true && dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    if (pickedFile != null) {
                      await ShopSettingsController.instance.uploadGcashQrImage(File(pickedFile!.path));
                    }
                    if (context.mounted) {
                      _showSuccessDialog(context, 'GCash QR code updated successfully.');
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showThresholdDialog(BuildContext context) {
    final controller = ShopSettingsController.instance;
    final textController = TextEditingController(text: controller.lowStockThreshold.clamp(0, 99).toString());
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Low-Stock Threshold'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Set the default item count for low stock alerts (max 2 digits).'),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                onChanged: (_) {
                  if (errorText != null) setState(() => errorText = null);
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'e.g. 10 (max 99)',
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

                final newValue = int.tryParse(textController.text.trim());
                if (newValue == null || newValue < 0 || newValue > 99) {
                  setState(() => errorText = 'Please enter a valid 2-digit number (0-99)');
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
    final currentFee = controller.deliveryFeePer500m;
    final textController = TextEditingController(
      text: currentFee == currentFee.roundToDouble()
          ? currentFee.toInt().clamp(0, 99).toString()
          : currentFee.clamp(0.0, 99.0).toStringAsFixed(0),
    );
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Delivery Fee Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Set the delivery fee for every 500 meters (0.5 km) distance (max 2 digits).'),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                onChanged: (_) {
                  if (errorText != null) setState(() => errorText = null);
                },
                decoration: InputDecoration(
                  prefixText: '₱ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'e.g. 5 (max ₱99)',
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

                final newValue = double.tryParse(textController.text.trim());
                if (newValue == null || newValue < 0 || newValue > 99) {
                  setState(() => errorText = 'Please enter a valid 2-digit amount (0-99)');
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
              initialValue: selectedDays,
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
    TopNotification.showSuccessDialog(context, message, title: 'Settings Updated');
  }
}

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
      decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(16)),
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
                  profile.fullName.trim().isEmpty ? 'Owner' : profile.fullName,
                  style: const TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold),
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
                    style: const TextStyle(color: AppColors.primaryOrange, fontSize: 12, fontWeight: FontWeight.w600),
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
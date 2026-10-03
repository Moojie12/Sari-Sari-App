import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../../../shared/widgets/terms_and_conditions_page.dart';
import '../../../users/owner_db/profile/shop_settings_controller.dart';
import '../../services/admin_product_service.dart';

class SettingsSection extends StatefulWidget {
  final AdminProductService? productService;
  final String? initialStoreName;
  final int? initialRowsPerPage;
  final bool? initialShowCostColumn;
  final bool? initialConfirmBeforeArchive;
  final ValueChanged<String>? onStoreNameChanged;
  final ValueChanged<int>? onRowsPerPageChanged;
  final ValueChanged<bool>? onShowCostColumnChanged;
  final ValueChanged<bool>? onConfirmBeforeArchiveChanged;

  const SettingsSection({
    super.key,
    this.productService,
    this.initialStoreName,
    this.initialRowsPerPage,
    this.initialShowCostColumn,
    this.initialConfirmBeforeArchive,
    this.onStoreNameChanged,
    this.onRowsPerPageChanged,
    this.onShowCostColumnChanged,
    this.onConfirmBeforeArchiveChanged,
  });

  @override
  State<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<SettingsSection> {
  final _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final settings = ShopSettingsController.instance;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final hPadding = isMobile ? 16.0 : 32.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Clean Simple Header
                  const Text(
                    'System Settings',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Manage payment QR codes, low-stock alerts, delivery fees, and expiry notifications.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Simple Web Cards Layout
                  LayoutBuilder(
                    builder: (context, innerConstraints) {
                      final isWide = innerConstraints.maxWidth >= 800;

                      return Column(
                        children: [
                          if (isWide) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _SimpleSettingCard(
                                    icon: Icons.qr_code_2_rounded,
                                    title: 'GCash QR Code',
                                    subtitle: 'Upload store QR code for customer payments',
                                    currentValue: settings.gcashQrUrl != null && settings.gcashQrUrl!.isNotEmpty
                                        ? 'Uploaded'
                                        : 'Not Set',
                                    isValueActive: settings.gcashQrUrl != null && settings.gcashQrUrl!.isNotEmpty,
                                    buttonLabel: 'Upload QR Code',
                                    onTap: () => _showGcashQrDialog(context),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _SimpleSettingCard(
                                    icon: Icons.low_priority_rounded,
                                    title: 'Low-Stock Threshold',
                                    subtitle: 'Default quantity count for low stock alerts',
                                    currentValue: '${settings.lowStockThreshold} units',
                                    isValueActive: true,
                                    buttonLabel: 'Edit Low Stock Alert',
                                    onTap: () => _showThresholdDialog(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _SimpleSettingCard(
                                    icon: Icons.delivery_dining_rounded,
                                    title: 'Delivery Fee Config',
                                    subtitle: 'Delivery rate charged per 500m (0.5 km) distance',
                                    currentValue: '₱${settings.deliveryFeePer500m.toStringAsFixed(2)} / 500m',
                                    isValueActive: true,
                                    buttonLabel: 'Set Delivery Fee',
                                    onTap: () => _showDeliveryFeeDialog(context),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _SimpleSettingCard(
                                    icon: Icons.timer_rounded,
                                    title: 'Expiry Monitoring',
                                    subtitle: 'Days before expiration to notify about items',
                                    currentValue: '${settings.expiryMonitoringDays} Days',
                                    isValueActive: true,
                                    buttonLabel: 'Set Expiry Days',
                                    onTap: () => _showExpiryConfigDialog(context),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            _SimpleSettingCard(
                              icon: Icons.qr_code_2_rounded,
                              title: 'GCash QR Code',
                              subtitle: 'Upload store QR code for customer payments',
                              currentValue: settings.gcashQrUrl != null && settings.gcashQrUrl!.isNotEmpty
                                  ? 'Uploaded'
                                  : 'Not Set',
                              isValueActive: settings.gcashQrUrl != null && settings.gcashQrUrl!.isNotEmpty,
                              buttonLabel: 'Upload QR Code',
                              onTap: () => _showGcashQrDialog(context),
                            ),
                            const SizedBox(height: 16),
                            _SimpleSettingCard(
                              icon: Icons.low_priority_rounded,
                              title: 'Low-Stock Threshold',
                              subtitle: 'Default quantity count for low stock alerts',
                              currentValue: '${settings.lowStockThreshold} units',
                              isValueActive: true,
                              buttonLabel: 'Edit Low Stock Alert',
                              onTap: () => _showThresholdDialog(context),
                            ),
                            const SizedBox(height: 16),
                            _SimpleSettingCard(
                              icon: Icons.delivery_dining_rounded,
                              title: 'Delivery Fee Config',
                              subtitle: 'Delivery rate charged per 500m (0.5 km) distance',
                              currentValue: '₱${settings.deliveryFeePer500m.toStringAsFixed(2)} / 500m',
                              isValueActive: true,
                              buttonLabel: 'Set Delivery Fee',
                              onTap: () => _showDeliveryFeeDialog(context),
                            ),
                            const SizedBox(height: 16),
                            _SimpleSettingCard(
                              icon: Icons.timer_rounded,
                              title: 'Expiry Monitoring',
                              subtitle: 'Days before expiration to notify about items',
                              currentValue: '${settings.expiryMonitoringDays} Days',
                              isValueActive: true,
                              buttonLabel: 'Set Expiry Days',
                              onTap: () => _showExpiryConfigDialog(context),
                            ),
                          ],
                          const SizedBox(height: 24),
                          // Additional Legal Card
                          _SimpleSettingCard(
                            icon: Icons.gavel_rounded,
                            title: 'Terms & App Permissions',
                            subtitle: 'Review privacy policies, terms of use, and device camera permissions',
                            currentValue: 'View Policy',
                            isValueActive: false,
                            buttonLabel: 'View Policy & Terms',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TermsAndConditionsPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 1. GCash QR Code Modal
  Future<void> _showGcashQrDialog(BuildContext context) async {
    XFile? pickedFile;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final settings = ShopSettingsController.instance;
          final currentUrl = settings.gcashQrUrl;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('GCash QR Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Upload your store\'s GCash QR code image for customer payments.',
                    style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async {
                      final image = await _picker.pickImage(source: ImageSource.gallery);
                      if (image != null) setDialogState(() => pickedFile = image);
                    },
                    child: Container(
                      height: 180,
                      width: 180,
                      decoration: BoxDecoration(
                        color: AppColors.lightPeach,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderColor),
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
                                    errorBuilder: (context, error, stackTrace) => const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image_rounded, size: 40, color: AppColors.primaryOrange),
                                        SizedBox(height: 4),
                                        Text('Image load failed', style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_outlined, size: 40, color: AppColors.primaryOrange),
                                    SizedBox(height: 8),
                                    Text('Click to select QR image', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                                  ],
                                ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final image = await _picker.pickImage(source: ImageSource.gallery);
                      if (image != null) setDialogState(() => pickedFile = image);
                    },
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: Text(pickedFile != null ? 'Change Photo' : 'Choose Image File'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryOrange,
                      side: const BorderSide(color: AppColors.primaryOrange),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (pickedFile == null && (currentUrl == null || currentUrl.isEmpty)) {
                    TopNotification.show(context, 'Please select a QR image first', isError: true);
                    return;
                  }

                  Navigator.pop(dialogContext);
                  if (pickedFile != null) {
                    await settings.uploadGcashQrImage(File(pickedFile!.path));
                  }
                  if (context.mounted) {
                    TopNotification.showSuccessDialog(
                      context,
                      'GCash QR Code saved and synced to database.',
                      title: 'QR Code Saved',
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Save GCash QR'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 2. Low-Stock Threshold Modal
  void _showThresholdDialog(BuildContext context) {
    final controller = ShopSettingsController.instance;
    final textController = TextEditingController(
      text: controller.lowStockThreshold.clamp(0, 99).toString(),
    );
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Low-Stock Threshold', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set the default minimum product count for low stock alerts (0-99 units).',
                  style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  onChanged: (_) {
                    if (errorText != null) setDialogState(() => errorText = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'Low Stock Limit',
                    suffixText: 'units',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    errorText: errorText,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
            ),
            ElevatedButton(
              onPressed: () {
                final text = textController.text.trim();
                final val = int.tryParse(text);
                if (val == null || val < 0 || val > 99) {
                  setDialogState(() => errorText = 'Enter valid number (0-99)');
                  return;
                }

                controller.updateLowStockThreshold(val);
                Navigator.pop(dialogContext);
                TopNotification.showSuccessDialog(
                  context,
                  'Low-stock threshold updated to $val units.',
                  title: 'Threshold Saved',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save Threshold'),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Delivery Fee Modal
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
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delivery Fee Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set the delivery fee rate charged for every 500 meters (0.5 km) distance.',
                  style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  onChanged: (_) {
                    if (errorText != null) setDialogState(() => errorText = null);
                  },
                  decoration: InputDecoration(
                    prefixText: '₱ ',
                    labelText: 'Fee per 500m',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    errorText: errorText,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
            ),
            ElevatedButton(
              onPressed: () {
                final text = textController.text.trim();
                final val = double.tryParse(text);
                if (val == null || val < 0 || val > 99) {
                  setDialogState(() => errorText = 'Enter valid amount (0-99)');
                  return;
                }

                controller.updateDeliveryFee(val);
                Navigator.pop(dialogContext);
                TopNotification.showSuccessDialog(
                  context,
                  'Delivery fee rate set to ₱${val.toStringAsFixed(2)} per 500m.',
                  title: 'Fee Rate Saved',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save Delivery Fee'),
            ),
          ],
        ),
      ),
    );
  }

  // 4. Expiry Config Modal
  void _showExpiryConfigDialog(BuildContext context) {
    final controller = ShopSettingsController.instance;
    int selectedDays = controller.expiryMonitoringDays;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Expiry Monitoring', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select how many days in advance the system flags expiring products.',
                  style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: selectedDays,
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('7 Days Window')),
                    DropdownMenuItem(value: 15, child: Text('15 Days Window')),
                    DropdownMenuItem(value: 30, child: Text('30 Days Window')),
                    DropdownMenuItem(value: 60, child: Text('60 Days Window')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedDays = v);
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
            ),
            ElevatedButton(
              onPressed: () {
                controller.updateExpiryMonitoringDays(selectedDays);
                Navigator.pop(dialogContext);
                TopNotification.showSuccessDialog(
                  context,
                  'Expiry monitoring window set to $selectedDays days.',
                  title: 'Window Saved',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save Expiry Days'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleSettingCard extends StatelessWidget {
  const _SimpleSettingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.currentValue,
    required this.isValueActive,
    required this.buttonLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String currentValue;
  final bool isValueActive;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: AppColors.primaryOrange),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.borderColor),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isValueActive
                      ? AppColors.primaryOrange.withValues(alpha: 0.1)
                      : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  currentValue,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isValueActive ? AppColors.primaryOrange : AppColors.secondaryText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: OutlinedButton(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryOrange,
                    side: const BorderSide(color: AppColors.primaryOrange),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

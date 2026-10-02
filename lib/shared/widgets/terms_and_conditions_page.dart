import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';

/// Screen and Dialog for displaying Terms & Conditions and App Permissions.
class TermsAndConditionsPage extends StatefulWidget {
  final bool isModal;
  final VoidCallback? onAccept;

  const TermsAndConditionsPage({
    super.key,
    this.isModal = false,
    this.onAccept,
  });

  /// Helper method to present the page as a modal sheet
  static Future<bool?> showModal(BuildContext context, {VoidCallback? onAccept}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: TermsAndConditionsPage(
          isModal: true,
          onAccept: onAccept,
        ),
      ),
    );
  }

  @override
  State<TermsAndConditionsPage> createState() => _TermsAndConditionsPageState();
}

class _TermsAndConditionsPageState extends State<TermsAndConditionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Permission statuses
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _storageStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;
  bool _isLoadingPermissions = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkPermissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoadingPermissions = true);
    final camera = await Permission.camera.status;
    final location = await Permission.locationWhenInUse.status;
    final storage = await Permission.photos.status.isGranted
        ? PermissionStatus.granted
        : await Permission.storage.status;
    final notification = await Permission.notification.status;

    if (mounted) {
      setState(() {
        _cameraStatus = camera;
        _locationStatus = location;
        _storageStatus = storage;
        _notificationStatus = notification;
        _isLoadingPermissions = false;
      });
    }
  }

  Future<void> _requestPermission(Permission permission) async {
    final status = await permission.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    await _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: widget.isModal
            ? IconButton(
                icon: const Icon(Icons.close, color: AppColors.darkText),
                onPressed: () => Navigator.pop(context, false),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.darkText),
                onPressed: () => Navigator.pop(context),
              ),
        title: const Text(
          'Terms & Permissions',
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryOrange,
          unselectedLabelColor: AppColors.secondaryText,
          indicatorColor: AppColors.primaryOrange,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Terms & Conditions'),
            Tab(text: 'App Permissions'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTermsAndConditionsTab(),
                  _buildAppPermissionsTab(),
                ],
              ),
            ),
            if (widget.isModal) _buildModalFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsAndConditionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderBanner(
            icon: Icons.gavel_rounded,
            title: 'Terms and Conditions',
            subtitle: 'Welcome to Tindahan ni Eca! Please read our terms carefully before using the app.',
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            number: '1',
            title: 'Acceptance of Terms',
            content:
                'By creating an account or using Tindahan ni Eca ("the Application"), you agree to comply with and be bound by these Terms and Conditions. If you do not agree, please do not use the service.',
          ),
          _buildSectionCard(
            number: '2',
            title: 'User Accounts & Security',
            content:
                'Users are responsible for maintaining the confidentiality of their account credentials (email and password). You agree to notify us immediately of any unauthorized access to your account.',
          ),
          _buildSectionCard(
            number: '3',
            title: 'Ordering & Transactions',
            content:
                'All orders placed through the app are subject to product availability and store confirmation. Product prices, discounts, and inventory quantities are updated in real time by store managers.',
          ),
          _buildSectionCard(
            number: '4',
            title: 'Payments & GCash Guidelines',
            content:
                'Payments can be fulfilled via Cash on Delivery (COD) or GCash. Users must provide accurate reference numbers and valid proof of payment for GCash transactions.',
          ),
          _buildSectionCard(
            number: '5',
            title: 'Store Operations & Inventory',
            content:
                'Store owners and authorized employees use the app to manage inventory, product batches, point of sale (POS) checkout, and order fulfillment in accordance with store policies.',
          ),
          _buildSectionCard(
            number: '6',
            title: 'Privacy & Data Handling',
            content:
                'We respect your privacy. User details (name, email, phone number, delivery address) are encrypted and stored securely solely for providing application services and order processing.',
          ),
          _buildSectionCard(
            number: '7',
            title: 'Modifications & Updates',
            content:
                'Tindahan ni Eca reserves the right to update these terms at any time. Continued use of the application following updates constitutes acceptance of the revised terms.',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAppPermissionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderBanner(
            icon: Icons.verified_user_rounded,
            title: 'App Permissions Rationale',
            subtitle: 'Understand why Tindahan ni Eca requests specific device permissions to deliver core features.',
          ),
          const SizedBox(height: 20),
          _buildPermissionItem(
            icon: Icons.camera_alt_outlined,
            title: 'Camera Access',
            status: _cameraStatus,
            rationale:
                'Required for scanning product barcodes during POS checkout and inventory receiving, as well as capturing product packaging OCR scans.',
            onTapRequest: () => _requestPermission(Permission.camera),
          ),
          _buildPermissionItem(
            icon: Icons.location_on_outlined,
            title: 'Location (GPS) Access',
            status: _locationStatus,
            rationale:
                'Required for real-time delivery tracking, pinpointing delivery drop-off points, finding nearest store locations, and localized weather forecasts.',
            onTapRequest: () => _requestPermission(Permission.locationWhenInUse),
          ),
          _buildPermissionItem(
            icon: Icons.photo_library_outlined,
            title: 'Storage & Photo Access',
            status: _storageStatus,
            rationale:
                'Required for selecting user profile avatars, adding product images to inventory, saving sales receipts, and exporting CSV reports.',
            onTapRequest: () => _requestPermission(Permission.photos),
          ),
          _buildPermissionItem(
            icon: Icons.notifications_active_outlined,
            title: 'Push Notifications',
            status: _notificationStatus,
            rationale:
                'Required to receive real-time alerts regarding order status changes (Preparing, Out for Delivery, Delivered), low stock warnings, and promotional deals.',
            onTapRequest: () => _requestPermission(Permission.notification),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Manage Device Settings'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryOrange,
                side: const BorderSide(color: AppColors.primaryOrange),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String number,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required PermissionStatus status,
    required String rationale,
    required VoidCallback onTapRequest,
  }) {
    final isGranted = status.isGranted;
    final isPermanentlyDenied = status.isPermanentlyDenied;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGranted
              ? Colors.green.withValues(alpha: 0.3)
              : AppColors.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryOrange, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rationale,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (!_isLoadingPermissions)
            SizedBox(
              width: double.infinity,
              height: 36,
              child: isGranted
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle, size: 16, color: Colors.green),
                      label: const Text('Permission Granted', style: TextStyle(color: Colors.green, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: onTapRequest,
                      icon: Icon(
                        isPermanentlyDenied ? Icons.settings : Icons.lock_open,
                        size: 16,
                      ),
                      label: Text(
                        isPermanentlyDenied ? 'Open Settings' : 'Allow Access',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(PermissionStatus status) {
    if (status.isGranted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Granted',
          style: TextStyle(
            color: Colors.green,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (status.isPermanentlyDenied) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Denied',
          style: TextStyle(
            color: Colors.red,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Not Granted',
          style: TextStyle(
            color: Colors.orange,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  Widget _buildModalFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.borderColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Decline',
                style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                widget.onAccept?.call();
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'I Agree & Accept',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

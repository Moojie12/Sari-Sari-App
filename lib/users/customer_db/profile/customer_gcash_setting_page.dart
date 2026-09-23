import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../notifications/customer_notification_model.dart';
import '../notifications/customer_notifications_controller.dart';

class CustomerGcashSettingPage extends StatefulWidget {
  const CustomerGcashSettingPage({super.key});

  @override
  State<CustomerGcashSettingPage> createState() => _CustomerGcashSettingPageState();
}

class _CustomerGcashSettingPageState extends State<CustomerGcashSettingPage> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadGcashData();
  }

  Future<void> _loadGcashData() async {
    final user = AuthService().currentUser;
    if (user != null) {
      try {
        final db = AuthService().database;
        final snapshot = await db.ref().child('users/${user.uid}/payment_methods/gcash').get();
        if (snapshot.exists && snapshot.value is Map) {
          final data = Map<String, dynamic>.from(snapshot.value as Map);
          _phoneController.text = data['phone']?.toString() ?? '';
          _nameController.text = data['accountName']?.toString() ?? '';
        } else {
          _phoneController.text = '0912 345 6789';
        }
      } catch (e) {
        debugPrint('Error loading GCash data: $e');
        _phoneController.text = '0912 345 6789';
      }
    } else {
      _phoneController.text = '0912 345 6789';
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveGcashData() async {
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();

    if (phone.isEmpty) {
      TopNotification.show(context, 'Please enter a valid GCash mobile number.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    final user = AuthService().currentUser;
    if (user != null) {
      try {
        final db = AuthService().database;
        await db.ref().child('users/${user.uid}/payment_methods/gcash').set({
          'phone': phone,
          'accountName': name,
          'updatedAt': DateTime.now().toIso8601String(),
        });
        debugPrint('GCash settings saved to Firebase RTDB for user ${user.uid}');

        CustomerNotificationsController.instance.addNotification(
          type: CustomerNotificationType.security,
          title: 'GCash Account Updated',
          message: 'Your GCash payment method ($phone) was successfully updated.',
          userId: user.uid,
        );
      } catch (e) {
        debugPrint('Error saving GCash data to Firebase RTDB: $e');
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
      TopNotification.show(context, 'GCash account updated and saved to database!');
      Navigator.pop(context);
    }
  }

  Future<void> _unlinkGcash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink GCash Account', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to unlink your GCash account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isSaving = true);
      final user = AuthService().currentUser;
      if (user != null) {
        try {
          final db = AuthService().database;
          await db.ref().child('users/${user.uid}/payment_methods/gcash').remove();

          CustomerNotificationsController.instance.addNotification(
            type: CustomerNotificationType.security,
            title: 'GCash Account Unlinked',
            message: 'Your GCash payment method was unlinked.',
            userId: user.uid,
          );
        } catch (e) {
          debugPrint('Error unlinking GCash: $e');
        }
      }

      _phoneController.clear();
      _nameController.clear();

      if (mounted) {
        setState(() => _isSaving = false);
        TopNotification.show(context, 'GCash account unlinked successfully.');
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'GCash Payment Method',
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkText),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF007DFE), Color(0xFF0056B3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'GCash',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'LINKED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'Mobile Number',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _phoneController.text.isNotEmpty ? _phoneController.text : 'No Number Set',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildTextField(
                    label: 'GCash Registered Name',
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'GCash Mobile Number',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveGcashData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Save to Database',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isSaving ? null : _unlinkGcash,
                    child: const Text(
                      'Unlink Account',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.labelText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: AppColors.darkText, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryOrange, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

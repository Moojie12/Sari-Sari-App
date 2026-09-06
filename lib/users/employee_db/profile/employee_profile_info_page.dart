import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'employee_edit_profile_page.dart';
import 'employee_profile_controller.dart';

/// "Profile Information" screen: read-only view of the employee's name,
/// username, email, contact number, and role.
class EmployeeProfileInfoPage extends StatelessWidget {
  const EmployeeProfileInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = EmployeeProfileController();

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile Information',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            tooltip: 'Edit Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EmployeeEditProfilePage()),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final profile = controller.profile;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.12),
                        child: Text(
                          profile.initials,
                          style: const TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile.fullName,
                        style: const TextStyle(
                          color: AppColors.darkText,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.role,
                        style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.8), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _InfoRow(icon: Icons.person_outline, label: 'Full Name', value: profile.fullName),
                      _InfoRow(icon: Icons.alternate_email, label: 'Username', value: profile.username),
                      _InfoRow(icon: Icons.email_outlined, label: 'Email', value: profile.email),
                      _InfoRow(icon: Icons.phone_outlined, label: 'Contact Number', value: profile.contactNumber),
                      _InfoRow(icon: Icons.badge_outlined, label: 'Role', value: profile.role, isLast: true),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppColors.borderColor.withValues(alpha: 0.6))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryOrange),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.8), fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(color: AppColors.darkText, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
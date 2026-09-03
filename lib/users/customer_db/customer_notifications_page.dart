import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Placeholder page for the customer "Notifications" tab.
///
/// TODO: Replace with the real notification list once implemented.
/// Note: the unread-count badge shown on the bottom nav icon is currently
/// a mock value owned by `CustomerDashboard` — wire it to real data
/// (e.g. from a notifications provider/repository) when this page is
/// implemented.
class CustomerNotificationsPage extends StatelessWidget {
  const CustomerNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 48,
            color: AppColors.primaryOrange,
          ),
          const SizedBox(height: 12),
          const Text(
            'Notifications',
            style: TextStyle(
              color: AppColors.darkText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Placeholder',
            style: TextStyle(
              color: AppColors.secondaryText.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
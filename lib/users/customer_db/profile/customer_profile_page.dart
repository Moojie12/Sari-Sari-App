import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Placeholder page for the customer "Profile" tab.
class CustomerProfilePage extends StatelessWidget {
  const CustomerProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_outline,
            size: 48,
            color: AppColors.primaryOrange,
          ),
          const SizedBox(height: 12),
          Text(
            'Complete your profile',
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

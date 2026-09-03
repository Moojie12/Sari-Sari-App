import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Placeholder page for the customer "My Purchases" tab.
///
/// TODO: Replace with the real order-tracking experience, including the
/// order-status categories: All, To Pay, To Ship, To Receive, Completed,
/// Cancelled (e.g. as a TabBar/TabBarView above the order list).
class CustomerPurchasesPage extends StatelessWidget {
  const CustomerPurchasesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.shopping_bag_outlined,
            size: 48,
            color: AppColors.primaryOrange,
          ),
          const SizedBox(height: 12),
          const Text(
            'My Purchases',
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

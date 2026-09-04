import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Placeholder page for the customer "My Purchases" tab.
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
          Text(
            'No purchases found',
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

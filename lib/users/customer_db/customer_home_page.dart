import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Placeholder page for the customer "Home" tab.
///
/// TODO: Replace with the real shopping experience: product cards,
/// product search, categories, cart, checkout, and payment.
class CustomerHomePage extends StatelessWidget {
  const CustomerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 48,
            color: AppColors.primaryOrange,
          ),
          const SizedBox(height: 12),
          const Text(
            'Customer Home',
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
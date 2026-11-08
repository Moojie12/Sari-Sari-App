import 'package:flutter/material.dart';
import 'package:sari_sari/core/theme/app_colors.dart';

/// Shows a non-intrusive floating notice at the bottom of the screen.
/// Avoids blocking top navigation and headers, and provides clean feedback.
void showCustomerNotice(
  BuildContext context,
  String message, {
  bool isWarning = true,
  IconData? icon,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      backgroundColor: const Color(0xFF1E232A),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isWarning
              ? AppColors.primaryOrange.withValues(alpha: 0.40)
              : const Color(0xFF10B981).withValues(alpha: 0.40),
          width: 1.2,
        ),
      ),
      duration: const Duration(milliseconds: 2500),
      content: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (isWarning ? AppColors.primaryOrange : const Color(0xFF10B981)).withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon ?? (isWarning ? Icons.info_rounded : Icons.check_circle_rounded),
              color: isWarning ? AppColors.primaryOrange : const Color(0xFF34D399),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      backgroundColor: const Color(0xFF232528),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isWarning
              ? AppColors.primaryOrange.withValues(alpha: 0.6)
              : Colors.greenAccent.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      duration: const Duration(milliseconds: 2200),
      content: Row(
        children: [
          Icon(
            icon ?? (isWarning ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded),
            color: isWarning ? AppColors.primaryOrange : Colors.greenAccent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

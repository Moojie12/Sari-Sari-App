import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// A widget that displays real-time live password requirement checklist
/// with checkmarks as the user types.
class PasswordRequirementsWidget extends StatelessWidget {
  const PasswordRequirementsWidget({
    super.key,
    required this.password,
    this.confirmPassword,
    this.showConfirm = true,
  });

  final String password;
  final String? confirmPassword;
  final bool showConfirm;

  @override
  Widget build(BuildContext context) {
    final hasMinLength = password.length >= 8;
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\]').hasMatch(password);

    final hasConfirmInput = confirmPassword != null && confirmPassword!.isNotEmpty;
    final passwordsMatch = hasConfirmInput && confirmPassword == password && password.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightPeach.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primaryOrange.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password Requirements:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          _RequirementRow(
            label: 'At least 8 characters long',
            isMet: hasMinLength,
          ),
          const SizedBox(height: 4),
          _RequirementRow(
            label: 'At least 1 uppercase letter (A-Z)',
            isMet: hasUppercase,
          ),
          const SizedBox(height: 4),
          _RequirementRow(
            label: 'At least 1 lowercase letter (a-z)',
            isMet: hasLowercase,
          ),
          const SizedBox(height: 4),
          _RequirementRow(
            label: 'At least 1 number (0-9)',
            isMet: hasNumber,
          ),
          const SizedBox(height: 4),
          _RequirementRow(
            label: 'At least 1 special character (!@#\$%...)',
            isMet: hasSpecial,
          ),
          if (showConfirm && confirmPassword != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1, thickness: 0.5, color: AppColors.placeholderColor),
            ),
            _RequirementRow(
              label: 'Confirm password matches',
              isMet: passwordsMatch,
              isError: hasConfirmInput && !passwordsMatch,
            ),
          ],
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.label,
    required this.isMet,
    this.isError = false,
  });

  final String label;
  final bool isMet;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    IconData icon;
    Color textColor;

    if (isMet) {
      iconColor = Colors.green.shade600;
      icon = Icons.check_circle_rounded;
      textColor = Colors.green.shade800;
    } else if (isError) {
      iconColor = Colors.redAccent;
      icon = Icons.cancel_rounded;
      textColor = Colors.redAccent;
    } else {
      iconColor = AppColors.placeholderColor;
      icon = Icons.radio_button_unchecked_rounded;
      textColor = AppColors.secondaryText;
    }

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}

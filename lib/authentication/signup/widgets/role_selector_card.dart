import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// One tappable "I am a..." role card.
///
/// Lives inside `authentication/signup/widgets/` rather than `shared/`
/// because only the sign up screen uses it.
class RoleSelectorCard extends StatelessWidget {
  const RoleSelectorCard({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryOrange : AppColors.cardWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
              isSelected ? AppColors.primaryOrange : AppColors.borderColor,
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected ? Colors.white : AppColors.secondaryText,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.secondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
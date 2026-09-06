import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class _OwnerNavDestination {
  const _OwnerNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class OwnerFloatingNavBar extends StatelessWidget {
  const OwnerFloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.inventoryAlertCount = 0,
    this.posBadgeCount = 0,
    this.ordersAlertCount = 0,
    this.profileAlertCount = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int inventoryAlertCount;
  final int posBadgeCount;
  final int ordersAlertCount;
  final int profileAlertCount;

  static const List<_OwnerNavDestination> _destinations = [
    _OwnerNavDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    _OwnerNavDestination(
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale,
      label: 'POS',
    ),
    _OwnerNavDestination(
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      label: 'Inventory',
    ),
    _OwnerNavDestination(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: 'Orders',
    ),
    _OwnerNavDestination(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 32),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(28),
          color: AppColors.cardWhite,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_destinations.length, (index) {
                final destination = _destinations[index];
                final isSelected = index == selectedIndex;
                int? badgeCount;
                if (index == 1 && posBadgeCount > 0) badgeCount = posBadgeCount;
                if (index == 2 && inventoryAlertCount > 0) badgeCount = inventoryAlertCount;
                if (index == 3 && ordersAlertCount > 0) badgeCount = ordersAlertCount;
                if (index == 4 && profileAlertCount > 0) badgeCount = profileAlertCount;

                return Expanded(
                  child: InkWell(
                    onTap: () => onDestinationSelected(index),
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              isSelected ? destination.selectedIcon : destination.icon,
                              color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText.withValues(alpha: 0.6),
                              size: 24,
                            ),
                            if (badgeCount != null)
                              Positioned(
                                right: -8,
                                top: -4,
                                child: _AlertBadge(count: badgeCount),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          destination.label,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText.withValues(alpha: 0.6),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertBadge extends StatelessWidget {
  const _AlertBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}

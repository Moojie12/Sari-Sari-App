import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Configuration for a single destination in [EmployeeFloatingNavBar].
class _EmployeeNavDestination {
  const _EmployeeNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Floating bottom navigation bar for the employee app shell.
///
/// Purely presentational, mirroring `CustomerFloatingNavBar`: it is given
/// the currently [selectedIndex] and reports taps through
/// [onDestinationSelected]. [inventoryAlertCount] renders a badge on the
/// "Inventory" destination for low/out-of-stock items needing attention.
class EmployeeFloatingNavBar extends StatelessWidget {
  const EmployeeFloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.inventoryAlertCount = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int inventoryAlertCount;

  static const List<_EmployeeNavDestination> _destinations = [
    _EmployeeNavDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    _EmployeeNavDestination(
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale,
      label: 'POS',
    ),
    _EmployeeNavDestination(
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      label: 'Inventory',
    ),
    _EmployeeNavDestination(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Profile',
    ),
  ];

  /// Index of the "Inventory" destination, used to attach the badge.
  static const int _inventoryIndex = 2;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 32),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 60),
        child: Material(
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(28),
          color: AppColors.cardWhite,
          child: SizedBox(
            height: 54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_destinations.length, (index) {
                final destination = _destinations[index];
                final isSelected = index == selectedIndex;
                final showBadge = index == _inventoryIndex && inventoryAlertCount > 0;

                return Expanded(
                  child: _EmployeeNavItem(
                    destination: destination,
                    isSelected: isSelected,
                    badgeCount: showBadge ? inventoryAlertCount : null,
                    onTap: () => onDestinationSelected(index),
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

class _EmployeeNavItem extends StatelessWidget {
  const _EmployeeNavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
    this.badgeCount,
  });

  final _EmployeeNavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.primaryOrange;
    final inactiveColor = AppColors.secondaryText.withValues(alpha: 0.6);
    final color = isSelected ? activeColor : inactiveColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                isSelected ? destination.selectedIcon : destination.icon,
                color: color,
                size: 26,
              ),
              if (badgeCount != null)
                Positioned(
                  right: -8,
                  top: -4,
                  child: _AlertBadge(count: badgeCount!),
                ),
            ],
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
    final label = count > 9 ? '9+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}
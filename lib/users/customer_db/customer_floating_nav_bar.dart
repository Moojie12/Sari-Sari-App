import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Configuration for a single destination in [CustomerFloatingNavBar].
class _CustomerNavDestination {
  const _CustomerNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Modern floating bottom navigation bar for the customer app shell.
///
/// This widget is purely presentational: it is given the currently
/// [selectedIndex] and reports taps through [onDestinationSelected].
/// It does not manage any navigation state itself — that is owned by
/// `CustomerDashboard`.
///
/// [notificationBadgeCount] is a temporary/mock value used to render an
/// unread-notifications badge on the "Notifications" destination. Replace
/// it with real data once notifications are implemented (see TODO below).
class CustomerFloatingNavBar extends StatelessWidget {
  const CustomerFloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.notificationBadgeCount = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  // TODO: Replace this mock count with the real unread-notification count
  // once notification data is available (see CustomerNotificationsPage).
  final int notificationBadgeCount;

  static const List<_CustomerNavDestination> _destinations = [
    _CustomerNavDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    _CustomerNavDestination(
      icon: Icons.notifications_none_outlined,
      selectedIcon: Icons.notifications,
      label: 'Notifications',
    ),
    _CustomerNavDestination(
      icon: Icons.shopping_bag_outlined,
      selectedIcon: Icons.shopping_bag,
      label: 'My Purchases',
    ),
    _CustomerNavDestination(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Profile',
    ),
  ];

  /// Index of the "Notifications" destination, used to attach the badge.
  static const int _notificationsIndex = 1;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 32),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
                final showBadge =
                    index == _notificationsIndex && notificationBadgeCount > 0;

                return Expanded(
                  child: _CustomerNavItem(
                    destination: destination,
                    isSelected: isSelected,
                    badgeCount: showBadge ? notificationBadgeCount : null,
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

class _CustomerNavItem extends StatelessWidget {
  const _CustomerNavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
    this.badgeCount,
  });

  final _CustomerNavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const activeColor = AppColors.primaryOrange;
    final inactiveColor = AppColors.secondaryText.withValues(alpha: 0.6);
    final color = isSelected ? activeColor : inactiveColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? destination.selectedIcon : destination.icon,
                  color: color,
                  size: 24,
                ),
                if (badgeCount != null)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: _NotificationBadge(count: badgeCount!),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              destination.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  const _NotificationBadge({required this.count});

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
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'customer_floating_nav_bar.dart';
import 'customer_home_page.dart';
import 'customer_notifications_page.dart';
import 'customer_purchases_page.dart';
import 'customer_profile_page.dart';

/// Main shell for the customer-facing side of the app.
///
/// Owns the selected bottom-navigation index and displays the matching
/// page above a floating bottom navigation bar. Tab pages are kept in an
/// [IndexedStack] so switching tabs does not rebuild or discard their
/// state (e.g. scroll position) — only the visible child changes.
///
/// This shell only wires up navigation. The four tab pages
/// (`CustomerHomePage`, `CustomerNotificationsPage`,
/// `CustomerPurchasesPage`, `CustomerProfilePage`) are still placeholders;
/// their real functionality is implemented separately inside each page's
/// own file.
class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _selectedIndex = 0;

  // Mock/temporary unread-notification count shown as a badge on the
  // "Notifications" tab.
  // TODO: Replace with a real value, e.g. sourced from a notifications
  // repository/provider, once notifications are implemented.
  final int _unreadNotificationCount = 3;

  static const List<Widget> _pages = [
    CustomerHomePage(),
    CustomerNotificationsPage(),
    CustomerPurchasesPage(),
    CustomerProfilePage(),
  ];

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeInset = MediaQuery.of(context).padding.bottom;
    // Height of the floating nav bar (66) + its bottom margin (matches the
    // SafeArea `minimum` in CustomerFloatingNavBar) + a small breathing gap
    // so page content never sits underneath the floating bar.
    final navBarClearance =
        54.0 + (bottomSafeInset > 32.0 ? bottomSafeInset : 32.0) + 16.0;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Stack(
        children: [
          // Tab content. IndexedStack builds all four pages once and keeps
          // them alive, so switching tabs preserves each page's state
          // instead of recreating it from scratch.
          Padding(
            padding: EdgeInsets.only(bottom: navBarClearance),
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),
          // Floating bottom navigation bar, pinned to the bottom edge.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomerFloatingNavBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              notificationBadgeCount: _unreadNotificationCount,
            ),
          ),
        ],
      ),
    );
  }
}
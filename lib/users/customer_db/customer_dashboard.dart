import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/app_colors.dart';
import 'customer_cart_controller.dart';
import 'customer_floating_nav_bar.dart';
import 'home/customer_home_page.dart';
import 'notifications/customer_notifications_page.dart';
import 'purchases/customer_purchases_page.dart';
import 'profile/customer_profile_page.dart';

/// Main shell for the customer-facing side of the app.
///
/// Owns the selected bottom-navigation index and displays the matching
/// page above a floating bottom navigation bar. Tab pages are kept in an
/// [IndexedStack] so switching tabs does not rebuild or discard their
/// state (e.g. scroll position) — only the visible child changes.
class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _selectedIndex = 0;

  // Global cart controller shared across the customer experience.
  final _cartController = CustomerCartController();

  // Whether the floating nav bar is currently shown. Toggled by
  // [_handleScrollNotification] as the active tab's content scrolls.
  bool _isNavBarVisible = true;

  // Mock/temporary unread-notification count shown as a badge on the
  // "Notifications" tab.
  final int _unreadNotificationCount = 3;

  static const List<String> _labels = [
    'Home',
    'Notifications',
    'My Purchases',
    'Profile',
  ];

  List<Widget>? _cachedPages;

  List<Widget> get _pages => _cachedPages ??= [
        CustomerHomePage(cartController: _cartController),
        const CustomerNotificationsPage(),
        const CustomerPurchasesPage(),
        const CustomerProfilePage(),
      ];

  @override
  void dispose() {
    _cartController.dispose();
    super.dispose();
  }

  static const Duration _navBarAnimationDuration = Duration(milliseconds: 260);

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  bool _handleScrollNotification(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    switch (notification.direction) {
      case ScrollDirection.reverse:
        if (_isNavBarVisible) setState(() => _isNavBarVisible = false);
        break;
      case ScrollDirection.forward:
        if (!_isNavBarVisible) setState(() => _isNavBarVisible = true);
        break;
      case ScrollDirection.idle:
        break;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unified Header
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _labels[_selectedIndex],
                        style: const TextStyle(
                          color: AppColors.darkText,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ListenableBuilder(
                        listenable: _cartController,
                        builder: (context, _) => Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              elevation: 2,
                              shadowColor: Colors.black.withValues(alpha: 0.1),
                              child: IconButton(
                                onPressed: () {},
                                icon: const Icon(
                                  Icons.shopping_cart_outlined,
                                  color: AppColors.darkText,
                                  size: 22,
                                ),
                              ),
                            ),
                            if (_cartController.itemCount > 0)
                              Positioned(
                                right: 2,
                                top: 2,
                                child:
                                    _CartBadge(count: _cartController.itemCount),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Tab Content Area
              Expanded(
                child: NotificationListener<UserScrollNotification>(
                  onNotification: _handleScrollNotification,
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _pages,
                  ),
                ),
              ),
            ],
          ),
          // Floating Bottom Navigation Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !_isNavBarVisible,
              child: AnimatedSlide(
                duration: _navBarAnimationDuration,
                curve: Curves.easeOut,
                offset: _isNavBarVisible ? Offset.zero : const Offset(0, 2),
                child: AnimatedOpacity(
                  duration: _navBarAnimationDuration,
                  opacity: _isNavBarVisible ? 1 : 0,
                  child: CustomerFloatingNavBar(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _onDestinationSelected,
                    notificationBadgeCount: _unreadNotificationCount,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartBadge extends StatelessWidget {
  const _CartBadge({required this.count});

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
        border: Border.all(color: Colors.white, width: 1.5),
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

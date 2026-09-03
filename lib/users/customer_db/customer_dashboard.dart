import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/app_colors.dart';
import 'customer_cart_controller.dart';
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
/// The Home tab renders its own title inline as part of its scrollable
/// content (see `customer_home_page.dart`), so this shell only shows a
/// fixed title bar for the other tabs. The cart button always floats
/// above everything, regardless of tab or scroll position.
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
  // TODO: Replace with a real value, e.g. sourced from a notifications
  // repository/provider, once notifications are implemented.
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

  // Scroll notifications from any descendant Scrollable (e.g. the Home
  // page's CustomScrollView) bubble up to this NotificationListener
  // regardless of which tab is active, so this one handler covers every
  // tab automatically — no per-page wiring needed.
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
    return false; // Let the notification keep bubbling.
  }

  @override
  Widget build(BuildContext context) {
    // Home renders its own scrolling title, so skip the fixed bar for it.
    final showFixedTitleBar = _selectedIndex != 0;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Stack(
        children: [
          Column(
            children: [
              if (showFixedTitleBar)
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Text(
                      _labels[_selectedIndex],
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
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
          // Floating cart button — always visible in the top-right corner,
          // regardless of tab or scroll position.
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 12),
                child: ListenableBuilder(
                  listenable: _cartController,
                  builder: (context, _) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 4,
                        shadowColor: Colors.black.withValues(alpha: 0.2),
                        child: IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.shopping_cart_outlined,
                            color: AppColors.darkText,
                          ),
                        ),
                      ),
                      if (_cartController.itemCount > 0)
                        Positioned(
                          right: 2,
                          top: 2,
                          child: _CartBadge(count: _cartController.itemCount),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Floating bottom navigation bar, pinned to the bottom edge.
          // Slides down + fades out on scroll-down, reverses on scroll-up.
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
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/app_colors.dart';
import 'package:sari_sari/users/customer_db/cart/customer_cart_page.dart';
import 'package:sari_sari/users/customer_db/customer_cart_controller.dart';
import 'package:sari_sari/users/customer_db/customer_floating_nav_bar.dart';
import 'package:sari_sari/users/customer_db/home/customer_home_page.dart';
import 'package:sari_sari/users/customer_db/notifications/customer_notifications_page.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_controller.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_purchases_page.dart';
import 'package:sari_sari/users/customer_db/profile/customer_profile_page.dart';

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

  // Global order controller shared across the customer experience.
  final _orderController = CustomerOrderController();

  // Whether the floating nav bar is currently shown. Toggled by
  // [_handleScrollNotification] as the active tab's content scrolls.
  bool _isNavBarVisible = true;

  // Mock/temporary unread-notification count shown as a badge on the
  // "Notifications" tab.
  final int _unreadNotificationCount = 3;

  List<Widget>? _cachedPages;

  List<Widget> get _pages => _cachedPages ??= [
    CustomerHomePage(cartController: _cartController),
    const CustomerNotificationsPage(),
    CustomerPurchasesPage(orderController: _orderController),
    const CustomerProfilePage(),
  ];

  @override
  void dispose() {
    _cartController.dispose();
    _orderController.dispose();
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
          // Tab Content Area (fills the screen; the cart icon and nav bar
          // float above it instead of reserving their own layout space).
          NotificationListener<UserScrollNotification>(
            onNotification: _handleScrollNotification,
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),
          // Floating Cart Button — stays visible whenever the cart has
          // items, even if the nav bar (and this button, normally) would
          // otherwise be hidden by scrolling. Only fades away on scroll
          // once the cart is back to empty.
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: ListenableBuilder(
                listenable: _cartController,
                builder: (context, _) {
                  final hasItems = _cartController.itemCount > 0;
                  final isVisible = _isNavBarVisible || hasItems;
                  return IgnorePointer(
                    ignoring: !isVisible,
                    child: AnimatedOpacity(
                      duration: _navBarAnimationDuration,
                      opacity: isVisible ? 1 : 0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 26, 20, 0),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            FloatingActionButton(
                              mini: true,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CustomerCartPage(
                                      cartController: _cartController,
                                      orderController: _orderController,
                                    ),
                                  ),
                                );
                              },
                              backgroundColor: AppColors.primaryOrange,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.shopping_cart_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            if (hasItems)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: _CartBadge(
                                  count: _cartController.itemCount,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
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
    final label = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}
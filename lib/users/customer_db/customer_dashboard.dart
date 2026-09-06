import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:sari_sari/core/theme/app_colors.dart';
import 'package:sari_sari/users/customer_db/cart/customer_cart_page.dart';
import 'package:sari_sari/users/customer_db/customer_cart_controller.dart';
import 'package:sari_sari/users/customer_db/customer_floating_nav_bar.dart';
import 'package:sari_sari/users/customer_db/home/customer_home_page.dart';
import 'package:sari_sari/users/customer_db/notifications/customer_notifications_page.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_controller.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_purchases_page.dart';
import 'package:sari_sari/users/customer_db/profile/customer_profile_page.dart';
import 'package:sari_sari/users/customer_db/chat/customer_chat_page.dart';
import 'package:sari_sari/users/customer_db/chat/customer_chat_controller.dart';
import 'package:sari_sari/users/customer_db/notifications/customer_notifications_controller.dart';

/// Main shell for the customer-facing side of the app.
class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _selectedIndex = 0;

  // Using the singleton controllers (factory ensures we get the global instance)
  final _cartController = CustomerCartController();
  final _orderController = CustomerOrderController();
  final _notificationsController = CustomerNotificationsController();
  final _chatController = CustomerChatController();

  bool _isNavBarVisible = true;

  // Pages are now handled in a standard list inside build or initState
  // to avoid any stale state during Hot Reload.
  List<Widget> get _pages => [
    CustomerHomePage(
      cartController: _cartController,
      orderController: _orderController,
    ),
    const CustomerNotificationsPage(),
    CustomerPurchasesPage(orderController: _orderController),
    const CustomerProfilePage(),
  ];

  @override
  void dispose() {
    // Controllers that are singletons should usually NOT be disposed here
    // unless you want them to reset every time the dashboard is closed.
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
          NotificationListener<UserScrollNotification>(
            onNotification: _handleScrollNotification,
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),
          // Shortcut Button — Top Right
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: ListenableBuilder(
                listenable: Listenable.merge([_cartController, _chatController]),
                builder: (context, _) {
                  final isHome = _selectedIndex == 0;
                  final isProfile = _selectedIndex == 3;
                  final hasItems = _cartController.itemCount > 0;
                  final hasChats = _chatController.unreadCount > 0 || _chatController.hasActiveChats;
                  
                  // For Home: visible if nav bar is shown OR cart has items.
                  // For Profile: visible if nav bar is shown OR if there are active chats.
                  final isVisible = isHome 
                      ? (_isNavBarVisible || hasItems) 
                      : (isProfile && (_isNavBarVisible || hasChats));

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
                                if (isHome) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CustomerCartPage(
                                        cartController: _cartController,
                                        orderController: _orderController,
                                      ),
                                    ),
                                  );
                                } else if (isProfile) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const CustomerChatPage(),
                                    ),
                                  );
                                }
                              },
                              backgroundColor: AppColors.primaryOrange,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isHome ? Icons.shopping_cart_outlined : Icons.chat_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            if (isHome && hasItems)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: _StatusBadge(
                                  count: _cartController.itemCount,
                                ),
                              ),
                            if (isProfile && _chatController.unreadCount > 0)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: _StatusBadge(
                                  count: _chatController.unreadCount,
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
                  child: ListenableBuilder(
                    listenable: _notificationsController,
                    builder: (context, _) {
                      return CustomerFloatingNavBar(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: _onDestinationSelected,
                        notificationBadgeCount: _notificationsController.unreadCount,
                      );
                    },
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.count});
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

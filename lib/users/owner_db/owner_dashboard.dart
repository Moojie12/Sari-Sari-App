import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/app_colors.dart';
import '../employee_db/employee_inventory_controller.dart';
import '../employee_db/pos/employee_pos_controller.dart';
import '../employee_db/pos/employee_pos_page.dart';
import 'owner_floating_nav_bar.dart';
import 'home/owner_home_page.dart';
import 'inventory/owner_inventory_page.dart';
import 'profile/owner_profile_page.dart';
import '../employee_db/orders/employee_orders_controller.dart';
import '../employee_db/orders/employee_orders_page.dart';
import '../employee_db/messages/employee_messages_controller.dart';
import '../employee_db/notifications/employee_notifications_controller.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  int _selectedIndex = 0;
  final _inventoryController = EmployeeInventoryController.instance;
  late final _posController = EmployeePosController(inventory: _inventoryController);
  final _ordersController = EmployeeOrderController.instance;
  final _messagesController = EmployeeMessagesController.instance;
  final _notificationsController = EmployeeNotificationsController.instance;

  bool _isNavBarVisible = true;

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
  void dispose() {
    _posController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      OwnerHomePage(
        inventory: _inventoryController,
        onOpenPos: () => _onDestinationSelected(1),
        onOpenInventory: () => _onDestinationSelected(2),
        onOpenProfile: () => _onDestinationSelected(4),
      ),
      EmployeePosPage(inventory: _inventoryController, posController: _posController),
      OwnerInventoryPage(inventory: _inventoryController),
      EmployeeOrdersPage(controller: _ordersController),
      const OwnerProfilePage(),
    ];

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Stack(
        children: [
          NotificationListener<UserScrollNotification>(
            onNotification: _handleScrollNotification,
            child: IndexedStack(
              index: _selectedIndex,
              children: pages,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !_isNavBarVisible,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                offset: _isNavBarVisible ? Offset.zero : const Offset(0, 2),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 260),
                  opacity: _isNavBarVisible ? 1 : 0,
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      _inventoryController,
                      _posController,
                      _ordersController,
                      _messagesController,
                      _notificationsController,
                    ]),
                    builder: (context, _) {
                      return OwnerFloatingNavBar(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: _onDestinationSelected,
                        inventoryAlertCount: _inventoryController.lowStockProducts.length +
                            _inventoryController.outOfStockProducts.length,
                        posBadgeCount: _posController.itemCount,
                        ordersAlertCount: _ordersController.activeOrders.length,
                        profileAlertCount: _messagesController.unreadCount +
                            _notificationsController.unreadCount,
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

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/app_colors.dart';
import 'employee_floating_nav_bar.dart';
import 'employee_inventory_controller.dart';
import 'home/employee_home_page.dart';
import 'inventory/employee_inventory_page.dart';
import 'pos/employee_pos_controller.dart';
import 'pos/employee_pos_page.dart';
import 'profile/employee_profile_page.dart';

/// Main shell for the employee-facing (Cashier / Inventory Staff) side of
/// the app.
///
/// Owns the selected bottom-navigation index and the controllers shared
/// across tabs — [EmployeeInventoryController] (stock, shared by Home,
/// POS, and Inventory) and [EmployeePosController] (the current walk-in
/// sale, which deducts from that same inventory on checkout). Tab pages
/// are kept in an [IndexedStack] so switching tabs does not rebuild or
/// discard their state.
class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  int _selectedIndex = 0;

  final _inventoryController = EmployeeInventoryController();
  late final _posController = EmployeePosController(inventory: _inventoryController);

  // Whether the floating nav bar is currently shown. Toggled by
  // [_handleScrollNotification] as the active tab's content scrolls.
  bool _isNavBarVisible = true;

  List<Widget>? _cachedPages;

  List<Widget> get _pages => _cachedPages ??= [
    EmployeeHomePage(
      inventory: _inventoryController,
      posController: _posController,
      onOpenPos: () => _onDestinationSelected(1),
      onOpenInventory: () => _onDestinationSelected(2),
    ),
    EmployeePosPage(inventory: _inventoryController, posController: _posController),
    EmployeeInventoryPage(inventory: _inventoryController),
    const EmployeeProfilePage(),
  ];

  @override
  void dispose() {
    _posController.dispose();
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
                    listenable: _inventoryController,
                    builder: (context, _) {
                      return EmployeeFloatingNavBar(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: _onDestinationSelected,
                        inventoryAlertCount: _inventoryController.lowStockProducts.length +
                            _inventoryController.outOfStockProducts.length,
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

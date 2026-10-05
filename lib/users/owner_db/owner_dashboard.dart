import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/app_colors.dart';
import 'package:sari_sari/users/employee_db/employee_inventory_controller.dart';
import 'package:sari_sari/users/employee_db/pos/employee_pos_controller.dart';
import 'package:sari_sari/users/employee_db/pos/employee_pos_page.dart';
import 'package:sari_sari/users/owner_db/owner_floating_nav_bar.dart';
import 'package:sari_sari/users/owner_db/home/owner_home_page.dart';
import 'package:sari_sari/users/owner_db/inventory/owner_inventory_page.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_expiring_products_page.dart';
import 'package:sari_sari/users/owner_db/profile/owner_profile_page.dart';
import 'package:sari_sari/users/owner_db/profile/owner_profile_controller.dart';
import 'package:sari_sari/users/employee_db/orders/employee_order_details_page.dart';
import 'package:sari_sari/users/employee_db/orders/employee_orders_controller.dart';
import 'package:sari_sari/users/employee_db/orders/employee_orders_page.dart';
import 'package:sari_sari/users/employee_db/messages/employee_messages_controller.dart';
import 'package:sari_sari/users/employee_db/notifications/employee_notifications_controller.dart';

import 'package:sari_sari/core/services/dashboard_navigation_controller.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_batch_detail_sheet.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_edit_product_page.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_archive_stock_dialog.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_consume_stock_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    OwnerProfileController.instance.loadProfile();
    DashboardNavigationController.instance.addListener(_handleNavigationRequest);
  }

  @override
  void dispose() {
    DashboardNavigationController.instance.removeListener(_handleNavigationRequest);
    _posController.dispose();
    super.dispose();
  }

  void _handleNavigationRequest() {
    final nav = DashboardNavigationController.instance;
    final targetIndex = nav.requestedIndex;
    final pendingProduct = nav.pendingProductForDetail;
    final pendingOrder = nav.pendingOrderForDetail;

    if (targetIndex != null) {
      setState(() => _selectedIndex = targetIndex);
    }

    if (pendingOrder != null) {
      nav.consumePendingRequest();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmployeeOrderDetailsPage(
                order: pendingOrder,
                controller: _ordersController,
              ),
            ),
          );
        }
      });
      return;
    }

    if (pendingProduct != null) {
      nav.consumePendingRequest();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (sheetContext) => EmployeeBatchDetailSheet(
              product: pendingProduct,
              inventory: _inventoryController,
              onEditProduct: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmployeeEditProductPage(
                      inventory: _inventoryController,
                      product: pendingProduct,
                    ),
                  ),
                );
              },
              onArchiveProduct: () {
                Navigator.pop(sheetContext);
                showDialog(
                  context: context,
                  builder: (context) => EmployeeArchiveStockDialog(
                    product: pendingProduct,
                    inventory: _inventoryController,
                  ),
                );
              },
              onConsumeProduct: () {
                Navigator.pop(sheetContext);
                showDialog(
                  context: context,
                  builder: (context) => EmployeeConsumeStockDialog(
                    product: pendingProduct,
                    inventory: _inventoryController,
                    role: 'Owner',
                  ),
                );
              },
            ),
          );
        }
      });
    } else if (targetIndex != null) {
      nav.consumePendingRequest();
    }
  }

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
    final List<Widget> pages = [
      OwnerHomePage(
        inventory: _inventoryController,
        posController: _posController,
        onOpenInventory: () => _onDestinationSelected(2),
        onOpenPos: () => _onDestinationSelected(1),
        onOpenExpiringProducts: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmployeeExpiringProductsPage(inventory: _inventoryController),
            ),
          );
        },
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
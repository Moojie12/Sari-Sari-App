import 'package:flutter/foundation.dart';
import '../../users/customer_db/purchases/customer_order_model.dart';
import '../../users/employee_db/inventory/employee_product_model.dart';

/// Service to handle cross-tab navigation requests in Owner and Employee Dashboards.
///
/// Allows notification screens, widgets, or services to request navigating
/// to specific dashboard tabs (e.g. Inventory or Orders) and optionally auto-opening
/// a product detail/batch sheet or order details upon arrival.
class DashboardNavigationController extends ChangeNotifier {
  DashboardNavigationController._();
  static final DashboardNavigationController instance = DashboardNavigationController._();

  int? _requestedIndex;
  EmployeeProduct? _pendingProductForDetail;
  CustomerOrder? _pendingOrderForDetail;

  int? get requestedIndex => _requestedIndex;
  EmployeeProduct? get pendingProductForDetail => _pendingProductForDetail;
  CustomerOrder? get pendingOrderForDetail => _pendingOrderForDetail;

  /// Request tab navigation by index.
  /// Index 0: Home, 1: POS, 2: Inventory, 3: Orders, 4: Profile.
  void navigateToTab(
    int index, {
    EmployeeProduct? openProductDetail,
    CustomerOrder? openOrderDetail,
  }) {
    _requestedIndex = index;
    _pendingProductForDetail = openProductDetail;
    _pendingOrderForDetail = openOrderDetail;
    notifyListeners();
  }

  /// Convenience method to jump directly to Inventory tab (Index 2).
  void navigateToInventory({EmployeeProduct? openProductDetail}) {
    navigateToTab(2, openProductDetail: openProductDetail);
  }

  /// Convenience method to jump directly to Orders tab (Index 3).
  void navigateToOrders({CustomerOrder? openOrderDetail}) {
    navigateToTab(3, openOrderDetail: openOrderDetail);
  }

  /// Consumes and resets the pending navigation request after handled.
  void consumePendingRequest() {
    _requestedIndex = null;
    _pendingProductForDetail = null;
    _pendingOrderForDetail = null;
  }
}

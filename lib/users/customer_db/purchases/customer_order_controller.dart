import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/services/auth_service.dart';
import '../../employee_db/orders/employee_orders_controller.dart';
import 'customer_order_model.dart';

class CustomerOrderController extends ChangeNotifier {
  CustomerOrderController._() {
    _sharedController.addListener(_onSharedOrdersChanged);
  }
  static final CustomerOrderController instance = CustomerOrderController._();
  factory CustomerOrderController() => instance;

  final EmployeeOrderController _sharedController = EmployeeOrderController.instance;

  void _onSharedOrdersChanged() {
    notifyListeners();
  }

  bool get isLoading => _sharedController.isLoading;

  /// Returns customer-specific orders if logged in, or all orders for guest/test mode
  List<CustomerOrder> get orders {
    final currentUserId = AuthService().currentUser?.uid;
    if (currentUserId != null && currentUserId.isNotEmpty) {
      final userOrders = _sharedController.orders.where((o) => o.userId == currentUserId).toList();
      if (userOrders.isNotEmpty) {
        return userOrders;
      }
    }
    return _sharedController.orders;
  }

  List<CustomerOrder> getOrdersByStatus(List<OrderStatus> statuses) {
    return orders.where((order) => statuses.contains(order.status)).toList();
  }

  CustomerOrder? getOrderById(String orderId) {
    final index = _sharedController.orders.indexWhere((o) => o.orderId == orderId);
    return index != -1 ? _sharedController.orders[index] : null;
  }

  Future<void> refresh() async {
    await _sharedController.refresh();
  }

  void placeOrder(CustomerOrder order) {
    _sharedController.placeOrder(order);
    notifyListeners();
  }

  /// Cancel an order if it is in pending status.
  /// Returns true if successfully cancelled, or false if the order cannot be cancelled
  /// (e.g. status was already changed by store staff).
  Future<bool> cancelOrder(String orderId, {String? reason}) async {
    final result = await _sharedController.cancelOrder(orderId, reason: reason);
    if (result) {
      notifyListeners();
    }
    return result;
  }

  String generateOrderNumber() {
    final now = DateTime.now();
    final datePart = '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timePart = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final randomSuffix = (Random().nextInt(900) + 100).toString();
    return 'SS-$datePart$timePart-$randomSuffix';
  }

  @override
  void dispose() {
    _sharedController.removeListener(_onSharedOrdersChanged);
    super.dispose();
  }
}

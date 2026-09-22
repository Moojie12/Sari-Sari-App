import 'package:flutter/foundation.dart';
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

  List<CustomerOrder> get orders => _sharedController.orders;

  List<CustomerOrder> getOrdersByStatus(List<OrderStatus> statuses) {
    return _sharedController.orders.where((order) => statuses.contains(order.status)).toList();
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

  String generateOrderNumber() {
    return 'SS-${(orders.length + 1).toString().padLeft(4, '0')}';
  }

  @override
  void dispose() {
    _sharedController.removeListener(_onSharedOrdersChanged);
    super.dispose();
  }
}

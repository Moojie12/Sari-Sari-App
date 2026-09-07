import 'package:flutter/foundation.dart';
import '../../employee_db/orders/employee_orders_controller.dart';
import 'customer_order_model.dart';

class CustomerOrderController extends ChangeNotifier {
  CustomerOrderController._();
  static final CustomerOrderController instance = CustomerOrderController._();
  factory CustomerOrderController() => instance;

  final EmployeeOrderController _sharedController = EmployeeOrderController.instance;

  List<CustomerOrder> get orders => _sharedController.orders;

  List<CustomerOrder> getOrdersByStatus(List<OrderStatus> statuses) {
    return _sharedController.orders.where((order) => statuses.contains(order.status)).toList();
  }

  void placeOrder(CustomerOrder order) {
    _sharedController.placeOrder(order);
    notifyListeners();
  }

  String generateOrderNumber() {
    return 'SS-${(orders.length + 1).toString().padLeft(4, '0')}';
  }
}

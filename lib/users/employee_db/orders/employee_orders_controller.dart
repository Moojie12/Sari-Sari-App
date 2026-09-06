import 'package:flutter/foundation.dart';
import '../../customer_db/purchases/customer_order_model.dart';
import '../notifications/employee_notifications_controller.dart';
import '../notifications/employee_notification_model.dart';

class EmployeeOrderController extends ChangeNotifier {
  EmployeeOrderController._();
  static final EmployeeOrderController instance = EmployeeOrderController._();
  factory EmployeeOrderController() => instance;

  final List<CustomerOrder> _orders = [
    // Initial dummy orders
    CustomerOrder(
      orderId: 'SS-0001',
      customerName: 'Juan Dela Cruz',
      orderDate: DateTime.now().subtract(const Duration(days: 2)),
      items: const [
        CustomerOrderItem(
          productId: '1',
          productName: 'Lucky Me Pancit Canton',
          price: 15.0,
          quantity: 2,
          subtotal: 30.0,
        ),
        CustomerOrderItem(
          productId: '2',
          productName: 'Coca-Cola 1.5L',
          price: 75.0,
          quantity: 1,
          subtotal: 75.0,
        ),
      ],
      orderType: OrderType.delivery,
      paymentMethod: PaymentMethod.cashOnDelivery,
      paymentStatus: PaymentStatus.unpaid,
      deliveryAddress: 'Juan Dela Cruz, Pagsanjan, Laguna, 09XXXXXXXXX',
      subtotal: 105.0,
      deliveryFee: 20.0,
      totalAmount: 125.0,
      status: OrderStatus.pending,
    ),
    CustomerOrder(
      orderId: 'SS-0002',
      customerName: 'Maria Santos',
      orderDate: DateTime.now().subtract(const Duration(days: 1)),
      items: const [
        CustomerOrderItem(
          productId: '3',
          productName: 'Rice 1kg',
          price: 50.0,
          quantity: 3,
          subtotal: 150.0,
        ),
      ],
      orderType: OrderType.pickup,
      paymentMethod: PaymentMethod.gCash,
      paymentStatus: PaymentStatus.paid,
      subtotal: 150.0,
      deliveryFee: 0.0,
      totalAmount: 150.0,
      status: OrderStatus.confirmed,
    ),
  ];

  List<CustomerOrder> get orders => List.unmodifiable(_orders);

  List<CustomerOrder> get activeOrders => _orders
      .where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled)
      .toList();

  List<CustomerOrder> get completedOrders =>
      _orders.where((o) => o.status == OrderStatus.completed).toList();

  void updateOrderStatus(String orderId, OrderStatus newStatus) {
    final index = _orders.indexWhere((o) => o.orderId == orderId);
    if (index != -1) {
      final oldOrder = _orders[index];
      _orders[index] = CustomerOrder(
        orderId: oldOrder.orderId,
        customerName: oldOrder.customerName,
        orderDate: oldOrder.orderDate,
        items: oldOrder.items,
        orderType: oldOrder.orderType,
        paymentMethod: oldOrder.paymentMethod,
        paymentStatus: newStatus == OrderStatus.completed ? PaymentStatus.paid : oldOrder.paymentStatus,
        deliveryAddress: oldOrder.deliveryAddress,
        subtotal: oldOrder.subtotal,
        deliveryFee: oldOrder.deliveryFee,
        totalAmount: oldOrder.totalAmount,
        status: newStatus,
      );

      // Add notification for status update
      EmployeeNotificationsController.instance.addNotification(
        type: EmployeeNotificationType.assignedTask, // Using assignedTask for status updates for now
        title: 'Order Status Updated',
        message: 'Order #${oldOrder.orderId} status changed to ${newStatus.label}.',
      );

      notifyListeners();
    }
  }
}

import 'package:flutter/foundation.dart';
import 'customer_order_model.dart';

class CustomerOrderController extends ChangeNotifier {
  final List<CustomerOrder> _orders = [
    // Dummy Order #SS-0001: To Pay
    CustomerOrder(
      orderId: 'SS-0001',
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
    // Dummy Order #SS-0002: To Ship
    CustomerOrder(
      orderId: 'SS-0002',
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
    // Dummy Order #SS-0003: Out for Delivery
    CustomerOrder(
      orderId: 'SS-0003',
      orderDate: DateTime.now(),
      items: const [
        CustomerOrderItem(
          productId: '4',
          productName: 'Soft Drinks',
          price: 20.0,
          quantity: 2,
          subtotal: 40.0,
        ),
      ],
      orderType: OrderType.delivery,
      paymentMethod: PaymentMethod.cashOnDelivery,
      paymentStatus: PaymentStatus.unpaid,
      deliveryAddress: 'Juan Dela Cruz, Pagsanjan, Laguna, 09XXXXXXXXX',
      subtotal: 40.0,
      deliveryFee: 20.0,
      totalAmount: 60.0,
      status: OrderStatus.outForDelivery,
    ),
    // Dummy Order #SS-0004: Completed
    CustomerOrder(
      orderId: 'SS-0004',
      orderDate: DateTime.now().subtract(const Duration(days: 5)),
      items: const [
        CustomerOrderItem(
          productId: '5',
          productName: 'Instant Noodles',
          price: 15.0,
          quantity: 5,
          subtotal: 75.0,
        ),
      ],
      orderType: OrderType.pickup,
      paymentMethod: PaymentMethod.gCash,
      paymentStatus: PaymentStatus.paid,
      subtotal: 75.0,
      deliveryFee: 0.0,
      totalAmount: 75.0,
      status: OrderStatus.completed,
    ),
  ];

  List<CustomerOrder> get orders => List.unmodifiable(_orders);

  List<CustomerOrder> getOrdersByStatus(List<OrderStatus> statuses) {
    return _orders.where((order) => statuses.contains(order.status)).toList();
  }

  void placeOrder(CustomerOrder order) {
    _orders.insert(0, order);
    notifyListeners();
  }

  String generateOrderNumber() {
    return 'SS-${(_orders.length + 1).toString().padLeft(4, '0')}';
  }
}

import 'package:flutter/foundation.dart';
import '../../customer_db/purchases/customer_order_model.dart';
import '../employee_inventory_controller.dart';
import '../notifications/employee_notifications_controller.dart';
import '../notifications/employee_notification_model.dart';

class ProductDemand {
  final String productId;
  final String productName;
  final int totalQuantity;
  final List<String> orderIds;
  final bool isMarked;

  ProductDemand({
    required this.productId,
    required this.productName,
    required this.totalQuantity,
    required this.orderIds,
    this.isMarked = false,
  });
}

class EmployeeOrderController extends ChangeNotifier {
  EmployeeOrderController._();
  static final EmployeeOrderController instance = EmployeeOrderController._();
  factory EmployeeOrderController() => instance;

  final EmployeeInventoryController _inventory = EmployeeInventoryController.instance;

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
      deliveryAddress: 'Juan Dela Cruz, Pagsanjan, Laguna',
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

  final Set<String> _markedProductIds = {};

  List<CustomerOrder> get orders => List.unmodifiable(_orders);

  List<CustomerOrder> get activeOrders => _orders
      .where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled)
      .toList();

  List<CustomerOrder> get completedOrders =>
      _orders.where((o) => o.status == OrderStatus.completed).toList();

  List<ProductDemand> get demandItems {
    final Map<String, ProductDemand> demandMap = {};

    for (var order in activeOrders) {
      // Only include orders that are still being prepared/pending
      if (order.status == OrderStatus.pending ||
          order.status == OrderStatus.confirmed ||
          order.status == OrderStatus.preparing) {
        for (var item in order.items) {
          if (demandMap.containsKey(item.productId)) {
            final existing = demandMap[item.productId]!;
            demandMap[item.productId] = ProductDemand(
              productId: item.productId,
              productName: item.productName,
              totalQuantity: existing.totalQuantity + item.quantity,
              orderIds: [...existing.orderIds, order.orderId],
              isMarked: _markedProductIds.contains(item.productId),
            );
          } else {
            demandMap[item.productId] = ProductDemand(
              productId: item.productId,
              productName: item.productName,
              totalQuantity: item.quantity,
              orderIds: [order.orderId],
              isMarked: _markedProductIds.contains(item.productId),
            );
          }
        }
      }
    }

    return demandMap.values.toList();
  }

  void toggleDemandMark(String productId) {
    if (_markedProductIds.contains(productId)) {
      _markedProductIds.remove(productId);
    } else {
      _markedProductIds.add(productId);
    }
    notifyListeners();
  }

  void markAllDemand(bool collected) {
    if (collected) {
      final allIds = demandItems.map((item) => item.productId);
      _markedProductIds.addAll(allIds);
    } else {
      _markedProductIds.clear();
    }
    notifyListeners();
  }

  void placeOrder(CustomerOrder order) {
    _orders.insert(0, order);
    
    // Add notification for new order
    EmployeeNotificationsController.instance.addNotification(
      type: EmployeeNotificationType.newOrder,
      title: 'New Order Received',
      message: 'New order #${order.orderId} from ${order.customerName}.',
    );

    notifyListeners();
  }

  void updateOrderStatus(String orderId, OrderStatus newStatus) {
    final index = _orders.indexWhere((o) => o.orderId == orderId);
    if (index != -1) {
      final oldOrder = _orders[index];
      
      // Deduct stock if order is completed and it wasn't already completed/cancelled
      if (newStatus == OrderStatus.completed && 
          oldOrder.status != OrderStatus.completed && 
          oldOrder.status != OrderStatus.cancelled) {
        for (var item in oldOrder.items) {
          _inventory.adjustStock(item.productId, -item.quantity);
        }
      }

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

      // Cleanup: Remove product IDs from marked list if they are no longer in demand
      final currentDemandIds = demandItems.map((d) => d.productId).toSet();
      _markedProductIds.retainAll(currentDemandIds);

      notifyListeners();
    }
  }
}

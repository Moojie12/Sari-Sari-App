import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../customer_db/purchases/customer_order_model.dart';
import '../employee_inventory_controller.dart';
import '../notifications/employee_notifications_controller.dart';
import '../notifications/employee_notification_model.dart';
import '../../customer_db/notifications/customer_notifications_controller.dart';
import '../../customer_db/notifications/customer_notification_model.dart';

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
  EmployeeOrderController._() {
    _loadOrdersFromSupabase();
    _subscribeToRealtime();
  }
  static final EmployeeOrderController instance = EmployeeOrderController._();
  factory EmployeeOrderController() => instance;

  final EmployeeInventoryController _inventory = EmployeeInventoryController.instance;
  final SupabaseService _supabaseService = SupabaseService();

  RealtimeChannel? _realtimeChannel;
  final List<CustomerOrder> _orders = [];
  final Set<String> _markedProductIds = {};
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<CustomerOrder> get orders => List.unmodifiable(_orders);

  List<CustomerOrder> get activeOrders => _orders
      .where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled)
      .toList();

  List<CustomerOrder> get completedOrders =>
      _orders.where((o) => o.status == OrderStatus.completed).toList();

  Future<void> _loadOrdersFromSupabase() async {
    _isLoading = true;
    notifyListeners();

    try {
      final supabaseOrders = await _supabaseService.getAllOrdersWithItems();
      if (supabaseOrders.isNotEmpty) {
        _orders.clear();
        for (final data in supabaseOrders) {
          _orders.add(CustomerOrder.fromSupabase(data));
        }
      }
    } catch (e) {
      debugPrint('Error loading orders from Supabase: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeToRealtime() {
    if (_realtimeChannel != null) return;

    try {
      _realtimeChannel = _supabaseService.client
          .channel('public:orders_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) {
              debugPrint('Orders Realtime Event: ${payload.eventType}');
              _loadOrdersFromSupabase();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Failed to subscribe to orders realtime: $e');
    }
  }

  Future<void> refresh() async {
    await _loadOrdersFromSupabase();
  }

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
    final existingIndex = _orders.indexWhere((o) => o.orderId == order.orderId);
    if (existingIndex >= 0) {
      _orders[existingIndex] = order;
    } else {
      _orders.insert(0, order);
    }
    
    // Add notification for new order
    EmployeeNotificationsController.instance.addNotification(
      type: EmployeeNotificationType.newOrder,
      title: 'New Order Received',
      message: 'New order #${order.orderId} from ${order.customerName}.',
    );

    notifyListeners();

    // Persist order to Supabase database
    _supabaseService.saveCustomerOrder(order).then((_) {
      debugPrint('Order #${order.orderId} saved to database successfully.');
    }).catchError((e) {
      debugPrint('Error saving order to database: $e');
    });
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
          _inventory.adjustStock(item.productId, -item.quantity.toDouble());
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
        userId: oldOrder.userId, // Preserve the user ID
      );

      // Add notification for employee
      EmployeeNotificationsController.instance.addNotification(
        type: EmployeeNotificationType.assignedTask,
        title: 'Order Status Updated',
        message: 'Order #${oldOrder.orderId} status changed to ${newStatus.label}.',
      );

      // Add notification for customer
      CustomerNotificationsController.instance.addNotification(
        type: CustomerNotificationType.orderUpdate,
        title: 'Order Status Updated',
        message: 'Your order #${oldOrder.orderId} is now ${newStatus.label}.',
      );

      // Cleanup: Remove product IDs from marked list if they are no longer in demand
      final currentDemandIds = demandItems.map((d) => d.productId).toSet();
      _markedProductIds.retainAll(currentDemandIds);

      notifyListeners();

      // Update in Supabase database
      _supabaseService.updateOrderStatusInDb(
        orderId,
        newStatus.name,
        (newStatus == OrderStatus.completed ? PaymentStatus.paid : oldOrder.paymentStatus).name
      ).then((success) {
        if (success) {
          debugPrint('Order status updated successfully in Supabase database.');
        } else {
          debugPrint('Warning: Supabase order status update returned false for #$orderId.');
        }
      }).catchError((e) {
        debugPrint('Error updating order status in Supabase: $e');
      });
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}

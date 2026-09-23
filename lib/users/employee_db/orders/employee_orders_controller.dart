import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
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
    _loadAllOrders();
    _subscribeToRealtime();
    _subscribeToFirebaseRealtime();
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

  Future<void> _loadAllOrders() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadOrdersFromSupabase();
    } catch (e) {
      debugPrint('Error loading orders from Supabase: $e');
    }

    try {
      await _loadOrdersFromFirebase();
    } catch (e) {
      debugPrint('Error loading orders from Firebase: $e');
    }

    _orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
    _isLoading = false;
    notifyListeners();
  }

  void _mergeOrder(CustomerOrder order) {
    final existingIndex = _orders.indexWhere((o) => o.orderId == order.orderId);
    if (existingIndex >= 0) {
      _orders[existingIndex] = order;
    } else {
      _orders.add(order);
    }
  }

  Future<void> _loadOrdersFromSupabase() async {
    try {
      final supabaseOrders = await _supabaseService.getAllOrdersWithItems();
      if (supabaseOrders.isNotEmpty) {
        for (final data in supabaseOrders) {
          final order = CustomerOrder.fromSupabase(data);
          _mergeOrder(order);
        }
      }
    } catch (e) {
      debugPrint('Error loading orders from Supabase: $e');
    }
  }

  Future<void> _loadOrdersFromFirebase() async {
    try {
      final db = AuthService().database;
      final snapshot = await db.ref().child('orders').get();
      if (snapshot.exists && snapshot.value != null) {
        final val = snapshot.value;
        if (val is Map) {
          for (final entry in val.entries) {
            final orderData = entry.value;
            if (orderData is Map) {
              final parsed = CustomerOrder.fromMap(orderData);
              _mergeOrder(parsed);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading orders from Firebase RTDB: $e');
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

  void _subscribeToFirebaseRealtime() {
    try {
      final db = AuthService().database;
      db.ref().child('orders').onChildAdded.listen((event) {
        if (event.snapshot.value != null && event.snapshot.value is Map) {
          final order = CustomerOrder.fromMap(event.snapshot.value as Map);
          final existingIndex = _orders.indexWhere((o) => o.orderId == order.orderId);
          if (existingIndex == -1) {
            _orders.insert(0, order);
            _orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
            notifyListeners();
          }
        }
      }, onError: (e) {
        debugPrint('Firebase RTDB orders childAdded error: $e');
      });

      db.ref().child('orders').onChildChanged.listen((event) {
        if (event.snapshot.value != null && event.snapshot.value is Map) {
          final order = CustomerOrder.fromMap(event.snapshot.value as Map);
          final existingIndex = _orders.indexWhere((o) => o.orderId == order.orderId);
          if (existingIndex != -1) {
            _orders[existingIndex] = order;
            notifyListeners();
          }
        }
      }, onError: (e) {
        debugPrint('Firebase RTDB orders childChanged error: $e');
      });
    } catch (e) {
      debugPrint('Error subscribing to Firebase RTDB orders realtime: $e');
    }
  }

  Future<void> refresh() async {
    await _loadAllOrders();
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
    CustomerOrder orderToSave = order;
    final existingIndex = _orders.indexWhere((o) => o.orderId == order.orderId);
    if (existingIndex >= 0) {
      // Collision safety: NEVER overwrite an existing order!
      final uniqueSuffix = DateTime.now().microsecondsSinceEpoch.toString().substring(8);
      final uniqueId = '${order.orderId}-$uniqueSuffix';
      orderToSave = CustomerOrder(
        orderId: uniqueId,
        customerName: order.customerName,
        orderDate: order.orderDate,
        items: order.items,
        orderType: order.orderType,
        paymentMethod: order.paymentMethod,
        paymentStatus: order.paymentStatus,
        deliveryAddress: order.deliveryAddress,
        subtotal: order.subtotal,
        deliveryFee: order.deliveryFee,
        totalAmount: order.totalAmount,
        status: order.status,
        userId: order.userId,
      );
    }

    _orders.insert(0, orderToSave);
    
    // Add notification for employee / store
    EmployeeNotificationsController.instance.addNotification(
      type: EmployeeNotificationType.newOrder,
      title: 'New Order Received',
      message: 'New order #${orderToSave.orderId} from ${orderToSave.customerName} (₱${orderToSave.totalAmount.toStringAsFixed(2)}).',
    );

    // Add notification for customer
    CustomerNotificationsController.instance.addNotification(
      type: CustomerNotificationType.orderUpdate,
      title: 'Order Placed',
      message: 'Your order #${orderToSave.orderId} (₱${orderToSave.totalAmount.toStringAsFixed(2)}) has been placed successfully.',
      userId: orderToSave.userId,
    );

    notifyListeners();

    // Persist order to Supabase database
    _supabaseService.saveCustomerOrder(orderToSave).then((_) {
      debugPrint('Order #${orderToSave.orderId} saved to Supabase successfully.');
    }).catchError((e) {
      debugPrint('Error saving order to Supabase: $e');
    });

    // Dual-persist order to Firebase Realtime Database
    _saveOrderToFirebase(orderToSave);
  }

  /// Cancel an order requested by the customer.
  /// Strictly verifies that cancellation is ONLY permitted when the order is in [OrderStatus.pending].
  /// Once the status has been changed (preparing, confirmed, out for delivery, etc.), cancellation is rejected.
  Future<bool> cancelOrder(String orderId, {String? reason}) async {
    final index = _orders.indexWhere((o) => o.orderId == orderId);
    if (index == -1) {
      debugPrint('Cannot cancel order: #$orderId not found.');
      return false;
    }

    final currentOrder = _orders[index];
    if (currentOrder.status != OrderStatus.pending) {
      debugPrint(
        'Cannot cancel order #${currentOrder.orderId}: status is ${currentOrder.status.label}. Only pending orders can be cancelled.',
      );
      return false;
    }

    updateOrderStatus(orderId, OrderStatus.cancelled);
    return true;
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

      final isCancelled = newStatus == OrderStatus.cancelled;

      // Add notification for employee
      EmployeeNotificationsController.instance.addNotification(
        type: EmployeeNotificationType.assignedTask,
        title: isCancelled ? 'Order Cancelled' : 'Order Status Updated',
        message: isCancelled
            ? 'Order #${oldOrder.orderId} was cancelled.'
            : 'Order #${oldOrder.orderId} status changed to ${newStatus.label}.',
      );

      // Determine customer-friendly notification text
      String customerTitle;
      String customerMessage;
      switch (newStatus) {
        case OrderStatus.confirmed:
          customerTitle = 'Order Confirmed';
          customerMessage = 'Your order #${oldOrder.orderId} has been confirmed by the store.';
          break;
        case OrderStatus.preparing:
          customerTitle = 'Order Preparing';
          customerMessage = 'Your order #${oldOrder.orderId} is now being prepared.';
          break;
        case OrderStatus.readyForShipment:
          customerTitle = 'Ready for Shipment';
          customerMessage = 'Your order #${oldOrder.orderId} is packed and ready for delivery.';
          break;
        case OrderStatus.readyForPickup:
          customerTitle = 'Ready for Pickup';
          customerMessage = 'Your order #${oldOrder.orderId} is ready for pickup at the store.';
          break;
        case OrderStatus.outForDelivery:
          customerTitle = 'Out for Delivery';
          customerMessage = 'Rider is on the way with your order #${oldOrder.orderId}.';
          break;
        case OrderStatus.delivered:
          customerTitle = 'Order Delivered';
          customerMessage = 'Your order #${oldOrder.orderId} has been delivered.';
          break;
        case OrderStatus.completed:
          customerTitle = 'Order Completed';
          customerMessage = 'Thank you for shopping with us! Order #${oldOrder.orderId} is completed.';
          break;
        case OrderStatus.cancelled:
          customerTitle = 'Order Cancelled';
          customerMessage = 'Your order #${oldOrder.orderId} has been cancelled.';
          break;
        case OrderStatus.pending:
          customerTitle = 'Order Pending';
          customerMessage = 'Your order #${oldOrder.orderId} is pending payment/confirmation.';
          break;
      }

      // Add notification for customer
      CustomerNotificationsController.instance.addNotification(
        type: CustomerNotificationType.orderUpdate,
        title: customerTitle,
        message: customerMessage,
        userId: oldOrder.userId,
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

      // Update in Firebase Realtime Database
      _updateOrderStatusInFirebase(orderId, newStatus);
    }
  }

  Future<void> _saveOrderToFirebase(CustomerOrder order) async {
    try {
      final db = AuthService().database;
      await db.ref().child('orders/${order.orderId}').set({
        ...order.toMap(),
        'createdAt': DateTime.now().toIso8601String(),
      });
      debugPrint('Order #${order.orderId} synced to Firebase RTDB.');
    } catch (e) {
      debugPrint('Firebase RTDB order save error: $e');
    }
  }

  Future<void> _updateOrderStatusInFirebase(String orderId, OrderStatus newStatus) async {
    try {
      final db = AuthService().database;
      await db.ref().child('orders/$orderId').update({
        'status': newStatus.name,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      debugPrint('Order #$orderId status updated in Firebase RTDB to ${newStatus.name}');
    } catch (e) {
      debugPrint('Firebase RTDB order status update error: $e');
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}

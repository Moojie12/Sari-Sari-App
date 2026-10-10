import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/delivery_tracking_service.dart';
import '../../../core/services/local_database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../admin/services/admin_audit_service.dart';
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

  @visibleForTesting
  void clearOrdersForTesting() {
    _orders.clear();
    notifyListeners();
  }

  @visibleForTesting
  void addOrderForTesting(CustomerOrder order) {
    _orders.add(order);
    notifyListeners();
  }

  List<CustomerOrder> get activeOrders => _orders
      .where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled)
      .toList();

  List<CustomerOrder> get completedOrders =>
      _orders.where((o) => o.status == OrderStatus.completed).toList();

  Future<void> _loadAllOrders() async {
    _isLoading = true;
    notifyListeners();

    // 1. Cache-first: Load SQLite cached orders
    try {
      final localRows = await LocalDatabaseService.instance.queryAll('orders', orderBy: 'updated_at DESC');
      if (localRows.isNotEmpty) {
        for (final row in localRows) {
          final parsed = CustomerOrder.fromMap(row);
          _mergeOrder(parsed, saveToLocal: false);
        }
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cached orders from SQLite: $e');
    }

    // 2. Fetch from Supabase cloud database
    try {
      await _loadOrdersFromSupabase();
    } catch (e) {
      debugPrint('Error loading orders from Supabase: $e');
    }

    // 3. Fetch from Firebase RTDB
    try {
      await _loadOrdersFromFirebase();
    } catch (e) {
      debugPrint('Error loading orders from Firebase: $e');
    }

    _orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
    _isLoading = false;
    notifyListeners();
  }

  void _mergeOrder(CustomerOrder order, {bool saveToLocal = true}) {
    final existingIndex = _orders.indexWhere((o) => o.orderId == order.orderId);
    CustomerOrder merged = order;
    if (existingIndex >= 0) {
      final existing = _orders[existingIndex];
      final mergedItems = order.items.isNotEmpty ? order.items : existing.items;
      final mergedReason = (order.cancellationReason != null && order.cancellationReason!.isNotEmpty)
          ? order.cancellationReason
          : existing.cancellationReason;
      final mergedRefundName = (order.gcashRefundName != null && order.gcashRefundName!.isNotEmpty)
          ? order.gcashRefundName
          : existing.gcashRefundName;
      final mergedRefundNumber = (order.gcashRefundNumber != null && order.gcashRefundNumber!.isNotEmpty)
          ? order.gcashRefundNumber
          : existing.gcashRefundNumber;
      final mergedProofUrl = (order.refundProofUrl != null && order.refundProofUrl!.isNotEmpty)
          ? order.refundProofUrl
          : existing.refundProofUrl;
      final mergedRefundStatus = (order.refundStatus != null && order.refundStatus!.isNotEmpty)
          ? order.refundStatus
          : existing.refundStatus;
      final mergedRefNum = (order.paymentReferenceNumber != null && order.paymentReferenceNumber!.isNotEmpty)
          ? order.paymentReferenceNumber
          : existing.paymentReferenceNumber;

      merged = order.copyWith(
        items: mergedItems,
        cancellationReason: mergedReason,
        gcashRefundName: mergedRefundName,
        gcashRefundNumber: mergedRefundNumber,
        refundProofUrl: mergedProofUrl,
        refundStatus: mergedRefundStatus,
        paymentReferenceNumber: mergedRefNum,
      );
      _orders[existingIndex] = merged;
    } else {
      _orders.add(order);
    }

    if (saveToLocal && order.userId != null && order.userId!.isNotEmpty) {
      LocalDatabaseService.instance.insert('orders', merged.toSqliteMap());
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
        processedBy: order.processedBy,
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

  List<CustomerOrder> get pendingRefundOrders => _orders
      .where((o) =>
          o.status == OrderStatus.cancelled &&
          (o.paymentMethod == PaymentMethod.gCash ||
              o.paymentProofUrl != null ||
              o.gcashRefundName != null ||
              o.gcashRefundNumber != null) &&
          (o.refundStatus == 'pending' || o.refundStatus == null || o.refundStatus == ''))
      .toList();

  List<CustomerOrder> get completedRefundOrders => _orders
      .where((o) =>
          o.status == OrderStatus.cancelled &&
          (o.paymentMethod == PaymentMethod.gCash ||
              o.paymentProofUrl != null ||
              o.gcashRefundName != null ||
              o.gcashRefundNumber != null) &&
          o.refundStatus == 'refunded')
      .toList();

  /// Cancel an order requested by the customer or employee/owner.
  /// Strictly verifies that cancellation is ONLY permitted when the order is in [OrderStatus.pending].
  Future<bool> cancelOrder(
    String orderId, {
    String? reason,
    String? gcashRefundName,
    String? gcashRefundNumber,
  }) async {
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

    final isGcash = currentOrder.paymentMethod == PaymentMethod.gCash ||
        currentOrder.paymentProofUrl != null ||
        currentOrder.gcashRefundName != null ||
        currentOrder.gcashRefundNumber != null;
    final refundStatus = isGcash ? 'pending' : null;

    updateOrderStatus(
      orderId,
      OrderStatus.cancelled,
      cancellationReason: reason,
      gcashRefundName: gcashRefundName ?? currentOrder.gcashRefundName,
      gcashRefundNumber: gcashRefundNumber ?? currentOrder.gcashRefundNumber,
      refundStatus: refundStatus ?? currentOrder.refundStatus,
    );
    return true;
  }

  Future<void> submitGcashRefundDetails(
    String orderId, {
    required String name,
    required String phone,
  }) async {
    final index = _orders.indexWhere((o) => o.orderId == orderId);
    if (index == -1) return;

    final oldOrder = _orders[index];
    final updatedOrder = oldOrder.copyWith(
      gcashRefundName: name,
      gcashRefundNumber: phone,
      refundStatus: 'pending',
    );

    _orders[index] = updatedOrder;
    notifyListeners();

    _saveOrderToFirebase(updatedOrder);
    _saveGcashRefundDetailsToSupabase(updatedOrder);

    EmployeeNotificationsController.instance.addNotification(
      type: EmployeeNotificationType.assignedTask,
      title: 'GCash Refund Details Submitted',
      message: 'Customer provided GCash details ($name - $phone) for Order #${oldOrder.orderId}.',
    );
  }

  Future<void> submitRefundProof(
    String orderId, {
    required String proofUrl,
    String? refundRefNumber,
  }) async {
    final index = _orders.indexWhere((o) => o.orderId == orderId);
    if (index == -1) return;

    final oldOrder = _orders[index];
    final updatedOrder = oldOrder.copyWith(
      refundProofUrl: proofUrl,
      refundStatus: 'refunded',
      paymentReferenceNumber: refundRefNumber ?? oldOrder.paymentReferenceNumber,
    );

    _orders[index] = updatedOrder;
    notifyListeners();

    _saveOrderToFirebase(updatedOrder);
    _saveRefundProofToSupabase(updatedOrder);
    if (refundRefNumber != null && refundRefNumber.isNotEmpty) {
      _savePaymentReferenceToSupabase(updatedOrder);
    }

    CustomerNotificationsController.instance.addNotification(
      type: CustomerNotificationType.orderUpdate,
      title: 'GCash Refund Processed',
      message:
          'Your GCash refund of ₱${oldOrder.totalAmount.toStringAsFixed(2)} for Order #${oldOrder.orderId} has been sent! View screenshot proof in Order Details.',
      userId: oldOrder.userId,
    );
  }

  Future<void> updatePaymentReference(
    String orderId,
    String refNumber,
  ) async {
    final index = _orders.indexWhere((o) => o.orderId == orderId);
    if (index == -1) return;

    final oldOrder = _orders[index];
    final updatedOrder = oldOrder.copyWith(paymentReferenceNumber: refNumber);

    _orders[index] = updatedOrder;
    notifyListeners();

    _saveOrderToFirebase(updatedOrder);
    _savePaymentReferenceToSupabase(updatedOrder);
  }

  void updateOrderStatus(
    String orderId,
    OrderStatus newStatus, {
    String? cancellationReason,
    String? gcashRefundName,
    String? gcashRefundNumber,
    String? refundProofUrl,
    String? refundStatus,
    String? paymentReferenceNumber,
  }) {
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

      // Stop tracking if order is delivered, completed, or cancelled
      if (newStatus == OrderStatus.delivered ||
          newStatus == OrderStatus.completed ||
          newStatus == OrderStatus.cancelled) {
        DeliveryTrackingService.instance.stopTracking(orderId);
      }

      final finalReason = cancellationReason ?? oldOrder.cancellationReason;
      final finalRefundName = gcashRefundName ?? oldOrder.gcashRefundName;
      final finalRefundNumber = gcashRefundNumber ?? oldOrder.gcashRefundNumber;
      final finalProofUrl = refundProofUrl ?? oldOrder.refundProofUrl;
      final isGcashOrder = oldOrder.paymentMethod == PaymentMethod.gCash ||
          oldOrder.paymentProofUrl != null ||
          oldOrder.gcashRefundName != null ||
          oldOrder.gcashRefundNumber != null;

      final finalRefundStatus = refundStatus ??
          (newStatus == OrderStatus.cancelled && isGcashOrder
              ? (oldOrder.refundStatus ?? 'pending')
              : oldOrder.refundStatus);
      final finalRefNum = paymentReferenceNumber ?? oldOrder.paymentReferenceNumber;

      _orders[index] = oldOrder.copyWith(
        status: newStatus,
        cancellationReason: finalReason,
        paymentStatus: newStatus == OrderStatus.completed ? PaymentStatus.paid : oldOrder.paymentStatus,
        gcashRefundName: finalRefundName,
        gcashRefundNumber: finalRefundNumber,
        refundProofUrl: finalProofUrl,
        refundStatus: finalRefundStatus,
        paymentReferenceNumber: finalRefNum,
      );

      final isCancelled = newStatus == OrderStatus.cancelled;

      // Add notification for employee
      EmployeeNotificationsController.instance.addNotification(
        type: EmployeeNotificationType.assignedTask,
        title: isCancelled ? 'Order Cancelled' : 'Order Status Updated',
        message: isCancelled
            ? (finalReason != null && finalReason.isNotEmpty
                ? 'Order #${oldOrder.orderId} was cancelled. Reason: $finalReason'
                : 'Order #${oldOrder.orderId} was cancelled.')
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
          customerMessage = finalReason != null && finalReason.isNotEmpty
              ? 'Your order #${oldOrder.orderId} has been cancelled. Reason: $finalReason'
              : 'Your order #${oldOrder.orderId} has been cancelled.';
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

      AdminAuditService().logUpdate(
        'Order',
        orderId,
        oldOrder.customerName.isNotEmpty ? oldOrder.customerName : oldOrder.orderId,
        null,
        oldOrder.status.name,
        newStatus.name,
        'Order status updated to ${newStatus.name}',
      );

      notifyListeners();

      // Save cancellation reason to Supabase if cancelled
      if (isCancelled && finalReason != null && finalReason.isNotEmpty) {
        _saveCancellationReasonToSupabase(_orders[index]);
      }

      // Update in Supabase database
      _supabaseService.updateOrderStatusInDb(
        orderId,
        newStatus.name,
        (newStatus == OrderStatus.completed ? PaymentStatus.paid : oldOrder.paymentStatus).name,
        finalReason,
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
      _updateOrderStatusInFirebase(orderId, newStatus, _orders[index]);
    }
  }

  /// Assign a delivery person and set status to Out for Delivery
  Future<void> assignDeliveryPersonAndSetOutForDelivery({
    required String orderId,
    required DeliveryPerson deliveryPerson,
    LatLng? destinationCoords,
  }) async {
    final index = _orders.indexWhere((o) => o.orderId == orderId);
    if (index == -1) return;

    final oldOrder = _orders[index];

    // Resolve destination coordinates
    final dest = destinationCoords ??
        (oldOrder.deliveryLatitude != null && oldOrder.deliveryLongitude != null
            ? LatLng(oldOrder.deliveryLatitude!, oldOrder.deliveryLongitude!)
            : await DeliveryTrackingService.instance.geocodeAddress(oldOrder.deliveryAddress));

    final updatedOrder = oldOrder.copyWith(
      status: OrderStatus.outForDelivery,
      deliveryPersonId: deliveryPerson.id,
      deliveryPersonName: deliveryPerson.name,
      deliveryPersonRole: deliveryPerson.role,
      deliveryLatitude: dest.latitude,
      deliveryLongitude: dest.longitude,
    );

    _orders[index] = updatedOrder;
    notifyListeners();

    // Start tracking in DeliveryTrackingService
    await DeliveryTrackingService.instance.startTrackingForOrder(
      order: updatedOrder,
      deliveryPerson: deliveryPerson,
      destinationCoords: dest,
    );

    // Notifications
    EmployeeNotificationsController.instance.addNotification(
      type: EmployeeNotificationType.assignedTask,
      title: 'Order Out for Delivery',
      message: 'Order #${updatedOrder.orderId} assigned to ${deliveryPerson.name} (${deliveryPerson.role}) is now out for delivery.',
    );

    CustomerNotificationsController.instance.addNotification(
      type: CustomerNotificationType.orderUpdate,
      title: 'Out for Delivery',
      message: '${deliveryPerson.name} (${deliveryPerson.role}) is on the way with your order #${updatedOrder.orderId}.',
      userId: updatedOrder.userId,
    );

    AdminAuditService().logUpdate(
      'Order',
      orderId,
      oldOrder.customerName.isNotEmpty ? oldOrder.customerName : oldOrder.orderId,
      null,
      oldOrder.status.name,
      OrderStatus.outForDelivery.name,
      'Assigned delivery to ${deliveryPerson.name} (${deliveryPerson.role})',
    );

    // Persist to Supabase
    _supabaseService.updateOrderStatusInDb(
      orderId,
      OrderStatus.outForDelivery.name,
      updatedOrder.paymentStatus.name,
    ).then((_) {
      _saveDeliveryMetadataToSupabase(updatedOrder);
    }).catchError((e) {
      debugPrint('Error updating Supabase on outForDelivery: $e');
    });

    // Persist to Firebase Realtime Database
    _updateOrderStatusInFirebase(orderId, OrderStatus.outForDelivery, updatedOrder);
  }

  Future<void> _saveDeliveryMetadataToSupabase(CustomerOrder order) async {
    try {
      final supaClient = _supabaseService.client;
      final existing = await supaClient
          .from('orders')
          .select('order_notes')
          .eq('order_number', order.orderId)
          .maybeSingle();

      String notes = existing?['order_notes']?.toString() ?? '';
      
      // Remove old tags if any
      notes = notes.replaceAll(RegExp(r'\[delivery_person:[^\]]+\]'), '').trim();
      notes = notes.replaceAll(RegExp(r'\[coords:[^\]]+\]'), '').trim();

      final riderTag = '[delivery_person: ${order.deliveryPersonId ?? ''}|${order.deliveryPersonName ?? ''}|${order.deliveryPersonRole ?? ''}]';
      final coordsTag = order.deliveryLatitude != null && order.deliveryLongitude != null
          ? ' [coords: ${order.deliveryLatitude},${order.deliveryLongitude}]'
          : '';

      final updatedNotes = notes.isEmpty ? '$riderTag$coordsTag' : '$notes $riderTag$coordsTag';

      await supaClient.from('orders').update({
        'order_notes': updatedNotes,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('order_number', order.orderId);
      debugPrint('Delivery metadata synced to Supabase for #${order.orderId}');
    } catch (e) {
      debugPrint('Error syncing delivery metadata to Supabase: $e');
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

  Future<void> _saveCancellationReasonToSupabase(CustomerOrder order) async {
    if (order.cancellationReason == null || order.cancellationReason!.isEmpty) return;
    try {
      final supaClient = _supabaseService.client;
      final existing = await supaClient
          .from('orders')
          .select('order_notes')
          .eq('order_number', order.orderId)
          .maybeSingle();

      String notes = existing?['order_notes']?.toString() ?? '';
      notes = notes.replaceAll(RegExp(r'\[cancellation_reason:[^\]]+\]'), '').trim();

      final reasonTag = '[cancellation_reason: ${order.cancellationReason}]';
      final updatedNotes = notes.isEmpty ? reasonTag : '$notes $reasonTag';

      await supaClient.from('orders').update({
        'cancellation_reason': order.cancellationReason,
        'order_notes': updatedNotes,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('order_number', order.orderId);
      debugPrint('Cancellation reason synced to Supabase for #${order.orderId}');
    } catch (e) {
      try {
        final supaClient = _supabaseService.client;
        final existing = await supaClient
            .from('orders')
            .select('order_notes')
            .eq('order_number', order.orderId)
            .maybeSingle();

        String notes = existing?['order_notes']?.toString() ?? '';
        notes = notes.replaceAll(RegExp(r'\[cancellation_reason:[^\]]+\]'), '').trim();

        final reasonTag = '[cancellation_reason: ${order.cancellationReason}]';
        final updatedNotes = notes.isEmpty ? reasonTag : '$notes $reasonTag';

        await supaClient.from('orders').update({
          'order_notes': updatedNotes,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('order_number', order.orderId);
      } catch (_) {}
    }
  }

  Future<void> _saveGcashRefundDetailsToSupabase(CustomerOrder order) async {
    try {
      final supaClient = _supabaseService.client;
      final existing = await supaClient
          .from('orders')
          .select('order_notes')
          .eq('order_number', order.orderId)
          .maybeSingle();

      String notes = existing?['order_notes']?.toString() ?? '';
      notes = notes.replaceAll(RegExp(r'\[gcash_refund_name:[^\]]+\]'), '').trim();
      notes = notes.replaceAll(RegExp(r'\[gcash_refund_number:[^\]]+\]'), '').trim();
      notes = notes.replaceAll(RegExp(r'\[refund_status:[^\]]+\]'), '').trim();

      final tags = [
        if (order.gcashRefundName != null) '[gcash_refund_name: ${order.gcashRefundName}]',
        if (order.gcashRefundNumber != null) '[gcash_refund_number: ${order.gcashRefundNumber}]',
        if (order.refundStatus != null) '[refund_status: ${order.refundStatus}]',
      ].join(' ');

      final updatedNotes = notes.isEmpty ? tags : '$notes $tags';

      final updateData = <String, dynamic>{
        'order_notes': updatedNotes,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (order.gcashRefundName != null) updateData['gcash_refund_name'] = order.gcashRefundName;
      if (order.gcashRefundNumber != null) updateData['gcash_refund_number'] = order.gcashRefundNumber;
      if (order.refundStatus != null) updateData['refund_status'] = order.refundStatus;

      try {
        await supaClient.from('orders').update(updateData).eq('order_number', order.orderId);
      } catch (_) {
        await supaClient.from('orders').update({
          'order_notes': updatedNotes,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('order_number', order.orderId);
      }
      debugPrint('GCash refund details synced to Supabase for #${order.orderId}');
    } catch (e) {
      debugPrint('Error syncing GCash refund details to Supabase: $e');
    }
  }

  Future<void> _saveRefundProofToSupabase(CustomerOrder order) async {
    try {
      final supaClient = _supabaseService.client;
      final existing = await supaClient
          .from('orders')
          .select('order_notes')
          .eq('order_number', order.orderId)
          .maybeSingle();

      String notes = existing?['order_notes']?.toString() ?? '';
      notes = notes.replaceAll(RegExp(r'\[refund_proof_url:[^\]]+\]'), '').trim();
      notes = notes.replaceAll(RegExp(r'\[refund_status:[^\]]+\]'), '').trim();

      final tags = [
        if (order.refundProofUrl != null) '[refund_proof_url: ${order.refundProofUrl}]',
        if (order.refundStatus != null) '[refund_status: ${order.refundStatus}]',
      ].join(' ');

      final updatedNotes = notes.isEmpty ? tags : '$notes $tags';

      final updateData = <String, dynamic>{
        'order_notes': updatedNotes,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (order.refundProofUrl != null) updateData['refund_proof_url'] = order.refundProofUrl;
      if (order.refundStatus != null) updateData['refund_status'] = order.refundStatus;

      try {
        await supaClient.from('orders').update(updateData).eq('order_number', order.orderId);
      } catch (_) {
        await supaClient.from('orders').update({
          'order_notes': updatedNotes,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('order_number', order.orderId);
      }
      debugPrint('Refund proof synced to Supabase for #${order.orderId}');
    } catch (e) {
      debugPrint('Error syncing refund proof to Supabase: $e');
    }
  }

  Future<void> _savePaymentReferenceToSupabase(CustomerOrder order) async {
    if (order.paymentReferenceNumber == null) return;
    try {
      final supaClient = _supabaseService.client;
      final existing = await supaClient
          .from('orders')
          .select('order_notes')
          .eq('order_number', order.orderId)
          .maybeSingle();

      String notes = existing?['order_notes']?.toString() ?? '';
      notes = notes.replaceAll(RegExp(r'\[payment_ref:[^\]]+\]'), '').trim();

      final tag = '[payment_ref: ${order.paymentReferenceNumber}]';
      final updatedNotes = notes.isEmpty ? tag : '$notes $tag';

      final updateData = <String, dynamic>{
        'order_notes': updatedNotes,
        'updated_at': DateTime.now().toIso8601String(),
      };
      updateData['payment_reference_number'] = order.paymentReferenceNumber;

      try {
        await supaClient.from('orders').update(updateData).eq('order_number', order.orderId);
      } catch (_) {
        await supaClient.from('orders').update({
          'order_notes': updatedNotes,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('order_number', order.orderId);
      }
      debugPrint('Payment reference synced to Supabase for #${order.orderId}');
    } catch (e) {
      debugPrint('Error syncing payment reference to Supabase: $e');
    }
  }

  Future<void> _updateOrderStatusInFirebase(String orderId, OrderStatus newStatus, [CustomerOrder? order]) async {
    try {
      final db = AuthService().database;
      final updateData = <String, dynamic>{
        'status': newStatus.name,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (order != null) {
        if (order.cancellationReason != null) updateData['cancellationReason'] = order.cancellationReason;
        if (order.deliveryPersonId != null) updateData['deliveryPersonId'] = order.deliveryPersonId;
        if (order.deliveryPersonName != null) updateData['deliveryPersonName'] = order.deliveryPersonName;
        if (order.deliveryPersonRole != null) updateData['deliveryPersonRole'] = order.deliveryPersonRole;
        if (order.deliveryLatitude != null) updateData['deliveryLatitude'] = order.deliveryLatitude;
        if (order.deliveryLongitude != null) updateData['deliveryLongitude'] = order.deliveryLongitude;
        if (order.gcashRefundName != null) updateData['gcashRefundName'] = order.gcashRefundName;
        if (order.gcashRefundNumber != null) updateData['gcashRefundNumber'] = order.gcashRefundNumber;
        if (order.refundProofUrl != null) updateData['refundProofUrl'] = order.refundProofUrl;
        if (order.refundStatus != null) updateData['refundStatus'] = order.refundStatus;
        if (order.paymentReferenceNumber != null) updateData['paymentReferenceNumber'] = order.paymentReferenceNumber;
      }
      await db.ref().child('orders/$orderId').update(updateData);
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

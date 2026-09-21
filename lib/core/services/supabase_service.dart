import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// Service for handling all Supabase database operations
class SupabaseService {
  SupabaseService._internal();
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;

  SupabaseClient get _client => Supabase.instance.client;
  SupabaseClient get client => _client;

  // =============================================
  // PRODUCT OPERATIONS
  // =============================================

  /// Get all products with their current inventory status (FEFO-aware)
  Future<List<Map<String, dynamic>>> getProductsWithInventory() async {
    try {
      final response = await _client
          .from('products')
          .select('*, product_batches!left(*)');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch products: $e');
    }
  }

  /// Get a single product by ID with inventory info
  Future<Map<String, dynamic>?> getProductById(String productId) async {
    try {
      final response = await _client
          .from('products')
          .select('*, product_batches!left(quantity, expiry_date)')
          .eq('id', productId)
          .single();
      return response;
    } catch (e) {
      if (e.toString().contains('No rows found')) return null;
      throw Exception('Failed to fetch product: $e');
    }
  }

  /// Search products by name or barcode
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    try {
      final response = await _client
          .from('products')
          .select('*, product_batches!left(quantity, expiry_date)')
          .ilike('name', '%$query%')
          .or('barcode.ilike.%$query%');
      return response;
    } catch (e) {
      throw Exception('Failed to search products: $e');
    }
  }

  /// Add a new product
  Future<Map<String, dynamic>> addProduct(Map<String, dynamic> productData) async {
    try {
      // Map app fields to match your specific Supabase schema
      final mappedData = Map<String, dynamic>.from(productData);
      
      if (mappedData.containsKey('cost')) {
        mappedData['capital'] = mappedData.remove('cost');
      }
      
      // Your schema uses 'category' (text) which links to categories.name
      if (mappedData.containsKey('category_id')) {
        // We assume the app is passing the category name as the ID 
        // or we need to ensure the name is what's sent.
        mappedData['category'] = mappedData.remove('category_id');
      }

      // Ensure category exists before inserting product to satisfy foreign key constraint
      final categoryName = mappedData['category']?.toString();
      if (categoryName != null && categoryName.trim().isNotEmpty) {
        await ensureCategoryExists(categoryName.trim());
      }
      
      final response = await _client
          .from('products')
          .insert(mappedData)
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to add product: $e');
    }
  }

  /// Update an existing product
  Future<Map<String, dynamic>> updateProduct(
      String productId, Map<String, dynamic> updates) async {
    try {
      final mappedUpdates = Map<String, dynamic>.from(updates);
      
      if (mappedUpdates.containsKey('cost')) {
        mappedUpdates['capital'] = mappedUpdates.remove('cost');
      }
      
      if (mappedUpdates.containsKey('category_id')) {
        mappedUpdates['category'] = mappedUpdates.remove('category_id');
      }

      final categoryName = mappedUpdates['category']?.toString();
      if (categoryName != null && categoryName.trim().isNotEmpty) {
        await ensureCategoryExists(categoryName.trim());
      }

      final response = await _client
          .from('products')
          .update(mappedUpdates)
          .eq('id', productId)
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  /// Delete a product (will cascade to batches due to foreign key)
  Future<void> deleteProduct(String productId) async {
    try {
      await _client.from('products').delete().eq('id', productId);
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  /// Get products by category
  Future<List<Map<String, dynamic>>> getProductsByCategory(String category) async {
    try {
      final response = await _client
          .from('products')
          .select('*, product_batches!left(quantity, expiry_date)')
          .eq('category', category);
      return response;
    } catch (e) {
      throw Exception('Failed to fetch products by category: $e');
    }
  }

  /// Get low stock products (products where sellable quantity <= low stock threshold)
  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    try {
      final response = await _client
          .from('products')
          .select('*, product_batches!left(quantity, expiry_date)')
          .lte('low_stock_threshold', 0); // This is a simplification - we'd need to compute sellable quantity in DB
      return response;
    } catch (e) {
      throw Exception('Failed to fetch low stock products: $e');
    }
  }

  /// Get out of stock products (products where sellable quantity = 0)
  Future<List<Map<String, dynamic>>> getOutOfStockProducts() async {
    try {
      final response = await _client
          .from('products')
          .select('*, product_batches!left(quantity, expiry_date)')
          .lte('low_stock_threshold', 0); // Simplification - would need proper computation
      return response;
    } catch (e) {
      throw Exception('Failed to fetch out of stock products: $e');
    }
  }

  // =============================================
  // PRODUCT BATCH OPERATIONS
  // =============================================

  /// Get FEFO batches for a product (earliest expiry first, only batches with stock)
  Future<List<Map<String, dynamic>>> getProductBatchesFEFO(String productId) async {
    try {
      final response = await _client
          .from('product_batches')
          .select()
          .eq('product_id', productId)
          .gt('quantity', 0) // Only batches with stock
          .order('expiry_date', ascending: true) // FEFO: earliest first
          .order('received_date', ascending: true); // Then by received date
      return response;
    } catch (e) {
      throw Exception('Failed to fetch product batches: $e');
    }
  }

  /// Get all batches for a product (including expired/zero stock)
  Future<List<Map<String, dynamic>>> getAllProductBatches(String productId) async {
    try {
      final response = await _client
          .from('product_batches')
          .select()
          .eq('product_id', productId)
          .order('received_date', ascending: true);
      return response;
    } catch (e) {
      throw Exception('Failed to fetch all product batches: $e');
    }
  }

  /// Add a new batch to a product
  Future<Map<String, dynamic>> addProductBatch(
      String productId, Map<String, dynamic> batchData) async {
    try {
      final response = await _client
          .from('product_batches')
          .insert({
            ...batchData,
            'product_id': productId,
          })
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to add product batch: $e');
    }
  }

  /// Update batch quantity (for adjustments, wastage, etc.)
  Future<Map<String, dynamic>> updateBatchQuantity(
      String batchId, double newQuantity) async {
    try {
      final response = await _client
          .from('product_batches')
          .update({'quantity': newQuantity})
          .eq('id', batchId)
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to update batch quantity: $e');
    }
  }

  // =============================================
  // ORDER OPERATIONS
  // =============================================

  /// Create a new order with items using atomic RPC
  Future<String> createOrderWithItems({
    required String firebaseUid,
    required String orderNumber,
    required double totalAmount,
    required int totalItems,
    required List<Map<String, dynamic>> items,
    String? customerName,
    String? customerContact,
    String? deliveryAddress,
    String? orderNotes,
  }) async {
    try {
      final response = await _client.rpc('create_sale_transaction', params: {
        'p_firebase_uid': firebaseUid,
        'p_order_number': orderNumber,
        'p_total_amount': totalAmount,
        'p_total_items': totalItems,
        'p_customer_name': customerName,
        'p_customer_contact': customerContact,
        'p_delivery_address': deliveryAddress,
        'p_order_notes': orderNotes,
        'p_items': items,
      });
      return response as String;
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  /// Get orders for a user (Firebase UID)
  Future<List<Map<String, dynamic>>> getUserOrders(String firebaseUid) async {
    try {
      // Join with profiles to filter by firebase_uid
      final response = await _client
          .from('orders')
          .select('*, profiles!inner(firebase_uid)')
          .eq('profiles.firebase_uid', firebaseUid)
          .order('placed_at', ascending: false);
      return response;
    } catch (e) {
      throw Exception('Failed to fetch user orders: $e');
    }
  }

  /// Get detailed order information including items
  Future<Map<String, dynamic>> getOrderDetails(String orderId) async {
    try {
      // Get the order
      final orderResponse = await _client
          .from('orders')
          .select('*')
          .eq('id', orderId)
          .single();

      // Get order items
      final orderItemsResponse = await _client
          .from('order_items')
          .select('*, products!inner(name, category)')
          .eq('order_id', orderId);

      return {
        ...orderResponse,
        'order_items': orderItemsResponse,
      };
    } catch (e) {
      throw Exception('Failed to fetch order details: $e');
    }
  }

  /// Get all orders (for analytics/admin purposes)
  Future<List<Map<String, dynamic>>> getAllOrders() async {
    try {
      final response = await _client
          .from('orders')
          .select('*')
          .order('placed_at', ascending: false);
      return response;
    } catch (e) {
      throw Exception('Failed to fetch all orders: $e');
    }
  }

  /// Update order status
  Future<Map<String, dynamic>> updateOrderStatus(
      String orderId, String status) async {
    try {
      final response = await _client
          .from('orders')
          .update({'status': status})
          .eq('id', orderId)
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  /// Get order statistics for dashboard
  Future<Map<String, dynamic>> getOrderStatistics() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Get today's orders
      final todayOrders = await _client
          .from('orders')
          .select('*')
          .gte('placed_at', startOfDay.toIso8601String())
          .lt('placed_at', endOfDay.toIso8601String());

      // Get pending orders
      final pendingOrders = await _client
          .from('orders')
          .select('*')
          .eq('status', 'pending');

      // Get completed orders today
      final completedToday = await _client
          .from('orders')
          .select('*')
          .eq('status', 'completed')
          .gte('placed_at', startOfDay.toIso8601String())
          .lt('placed_at', endOfDay.toIso8601String());

      return {
        'today_orders': todayOrders.length,
        'pending_orders': pendingOrders.length,
        'completed_today': completedToday.length,
        'total_sales_today': todayOrders.fold(0.0, (sum, order) => sum + (order['total_amount'] as num).toDouble()),
      };
    } catch (e) {
      throw Exception('Failed to fetch order statistics: $e');
    }
  }

  // =============================================
  // PRE-ORDER OPERATIONS
  // =============================================

  /// Create a new pre-order with items using atomic RPC
  Future<String> createPreOrderWithItems({
    required String firebaseUid,
    required String orderNumber,
    required double totalAmount,
    required int totalItems,
    required List<Map<String, dynamic>> items,
    required DateTime expectedDate,
    String? customerName,
    String? customerContact,
    String? deliveryAddress,
    String? orderNotes,
  }) async {
    try {
      final response = await _client.rpc('create_preorder_transaction', params: {
        'p_firebase_uid': firebaseUid,
        'p_order_number': orderNumber,
        'p_total_amount': totalAmount,
        'p_total_items': totalItems,
        'p_customer_name': customerName,
        'p_customer_contact': customerContact,
        'p_delivery_address': deliveryAddress,
        'p_order_notes': orderNotes,
        'p_expected_date': expectedDate.toIso8601String(),
        'p_items': items,
      });
      return response as String;
    } catch (e) {
      throw Exception('Failed to create pre-order: $e');
    }
  }

  /// Get pre-orders for a user (Firebase UID)
  Future<List<Map<String, dynamic>>> getUserPreOrders(String firebaseUid) async {
    try {
      final response = await _client
          .from('pre_orders')
          .select('*, profiles!inner(firebase_uid)')
          .eq('profiles.firebase_uid', firebaseUid)
          .order('created_at', ascending: false);
      return response;
    } catch (e) {
      throw Exception('Failed to fetch user pre-orders: $e');
    }
  }

  /// Get detailed pre-order information including items
  Future<Map<String, dynamic>> getPreOrderDetails(String preOrderId) async {
    try {
      // Get the pre-order
      final preOrderResponse = await _client
          .from('pre_orders')
          .select('*')
          .eq('id', preOrderId)
          .single();

      // Get pre-order items
      final preOrderItemsResponse = await _client
          .from('pre_order_items')
          .select('*, products!inner(name, category)')
          .eq('pre_order_id', preOrderId);

      return {
        ...preOrderResponse,
        'pre_order_items': preOrderItemsResponse,
      };
    } catch (e) {
      throw Exception('Failed to fetch pre-order details: $e');
    }
  }

  /// Update pre-order status
  Future<Map<String, dynamic>> updatePreOrderStatus(
      String preOrderId, String status) async {
    try {
      final response = await _client
          .from('pre_orders')
          .update({'status': status})
          .eq('id', preOrderId)
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to update pre-order status: $e');
    }
  }

  /// Get pre-order statistics for dashboard
  Future<Map<String, dynamic>> getPreOrderStatistics() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Get today's pre-orders
      final todayPreOrders = await _client
          .from('pre_orders')
          .select('*')
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String());

      // Get active pre-orders
      final activePreOrders = await _client
          .from('pre_orders')
          .select('*')
          .eq('status', 'active');

      // Get completed pre-orders today
      final completedToday = await _client
          .from('pre_orders')
          .select('*')
          .eq('status', 'completed')
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String());

      return {
        'today_pre_orders': todayPreOrders.length,
        'active_pre_orders': activePreOrders.length,
        'completed_today': completedToday.length,
        'total_pre_order_value': todayPreOrders.fold(0.0, (sum, order) => sum + (order['total_amount'] as num).toDouble()),
      };
    } catch (e) {
      throw Exception('Failed to fetch pre-order statistics: $e');
    }
  }

  /// Convert a pre-order to a regular order using atomic RPC
  Future<String> convertPreOrderToOrder({
    required String preOrderId,
    required String orderNumber,
  }) async {
    try {
      final response = await _client.rpc('convert_preorder_to_order', params: {
        'p_preorder_id': preOrderId,
        'p_order_number': orderNumber,
      });
      return response as String;
    } catch (e) {
      throw Exception('Failed to convert pre-order to order: $e');
    }
  }

  // =============================================
  // SHIPMENT OPERATIONS
  // =============================================

  /// Create a new shipment for an order
  Future<Map<String, dynamic>> createShipment(Map<String, dynamic> shipmentData) async {
    try {
      final response = await _client
          .from('shipments')
          .insert(shipmentData)
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to create shipment: $e');
    }
  }

  /// Get shipment by ID
  Future<Map<String, dynamic>?> getShipmentById(String shipmentId) async {
    try {
      final response = await _client
          .from('shipments')
          .select('*, orders!inner(order_number, user_id)')
          .eq('id', shipmentId)
          .maybeSingle();
      return response;
    } catch (e) {
      throw Exception('Failed to fetch shipment: $e');
    }
  }

  /// Get shipments for an order
  Future<List<Map<String, dynamic>>> getShipmentsByOrderId(String orderId) async {
    try {
      final response = await _client
          .from('shipments')
          .select('*')
          .eq('order_id', orderId)
          .order('created_at', ascending: false);
      return response;
    } catch (e) {
      throw Exception('Failed to fetch shipments by order ID: $e');
    }
  }

  /// Update shipment status and tracking information
  Future<Map<String, dynamic>> updateShipment(
      String shipmentId, Map<String, dynamic> updates) async {
    try {
      final response = await _client
          .from('shipments')
          .update(updates)
          .eq('id', shipmentId)
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to update shipment: $e');
    }
  }

  /// Update shipment status only
  Future<Map<String, dynamic>> updateShipmentStatus(
      String shipmentId, String status, {String? actualDeliveryDate}) async {
    try {
      final updateData = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (status == 'delivered' && actualDeliveryDate != null) {
        updateData['actual_delivery_date'] = actualDeliveryDate;
      } else if (status == 'shipped' && actualDeliveryDate == null) {
        updateData['shipped_date'] = DateTime.now().toIso8601String();
      }

      final response = await _client
          .from('shipments')
          .update(updateData)
          .eq('id', shipmentId)
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to update shipment status: $e');
    }
  }

  /// Get shipment statistics for dashboard
  Future<Map<String, dynamic>> getShipmentStatistics() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Get shipments shipped today
      final shippedToday = await _client
          .from('shipments')
          .select('*')
          .gte('shipped_date', startOfDay.toIso8601String())
          .lt('shipped_date', endOfDay.toIso8601String());

      // Get shipments delivered today
      final deliveredToday = await _client
          .from('shipments')
          .select('*')
          .eq('status', 'delivered')
          .gte('actual_delivery_date', startOfDay.toIso8601String())
          .lt('actual_delivery_date', endOfDay.toIso8601String());

      // Get pending shipments (not yet shipped)
      final pendingShipments = await _client
          .from('shipments')
          .select('*')
          .eq('status', 'pending');

      // Get in-transit shipments (shipped but not delivered)
      final inTransitShipments = await _client
          .from('shipments')
          .select('*')
          .eq('status', 'shipped');

      return {
        'shipped_today': shippedToday.length,
        'delivered_today': deliveredToday.length,
        'pending_shipments': pendingShipments.length,
        'in_transit_shipments': inTransitShipments.length,
        'total_shipping_cost_today': shippedToday.fold(0.0, (sum, shipment) => sum + (shipment['shipping_cost'] as num).toDouble()),
      };
    } catch (e) {
      throw Exception('Failed to fetch shipment statistics: $e');
    }
  }

  // =============================================
  // INVENTORY TRANSACTION OPERATIONS
  // =============================================

  /// Record an inventory transaction (receipt, wastage, consumable, sale, adjustment)
  Future<Map<String, dynamic>> recordInventoryTransaction(
      Map<String, dynamic> transactionData) async {
    try {
      final response = await _client
          .from('inventory_transactions')
          .insert(transactionData)
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to record inventory transaction: $e');
    }
  }

  /// Record a product receipt transaction (when stock is received)
  Future<Map<String, dynamic>> recordProductReceipt({
    required String productId,
    required String? productBatchId, // null if creating new batch
    required double quantity,
    required double unitPrice,
    required String receivedFrom,
    String? referenceNumber,
    String? notes,
  }) async {
    try {
      final response = await _client
          .from('inventory_transactions')
          .insert({
            'product_id': productId,
            'product_batch_id': productBatchId,
            'transaction_type': 'receipt',
            'quantity': quantity,
            'unit_price': unitPrice,
            'total_amount': quantity * unitPrice,
            'received_from': receivedFrom,
            'reference_number': referenceNumber,
            'notes': notes,
          })
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to record product receipt: $e');
    }
  }

  /// Record a product wastage transaction (when stock is spoiled/expired/damaged)
  Future<Map<String, dynamic>> recordProductWastage({
    required String productId,
    required String productBatchId,
    required double quantity,
    required double unitPrice,
    required String? issuedTo, // Who caused/witnessed the wastage
    String? notes,
  }) async {
    try {
      final response = await _client
          .from('inventory_transactions')
          .insert({
            'product_id': productId,
            'product_batch_id': productBatchId,
            'transaction_type': 'wastage',
            'quantity': quantity,
            'unit_price': unitPrice,
            'total_amount': quantity * unitPrice,
            'issued_to': issuedTo,
            'notes': notes,
          })
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to record product wastage: $e');
    }
  }

  /// Record a product consumable transaction (when owner/employee takes stock for personal use)
  Future<Map<String, dynamic>> recordProductConsumable({
    required String productId,
    required String productBatchId,
    required double quantity,
    required double unitPrice,
    required String consumedBy, // Who took it for personal use
    String? notes,
  }) async {
    try {
      final response = await _client
          .from('inventory_transactions')
          .insert({
            'product_id': productId,
            'product_batch_id': productBatchId,
            'transaction_type': 'consumable',
            'quantity': quantity,
            'unit_price': unitPrice,
            'total_amount': quantity * unitPrice,
            'issued_to': consumedBy,
            'notes': notes,
          })
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to record product consumable: $e');
    }
  }

  /// Record a product sale transaction (when stock is sold to customer)
  Future<Map<String, dynamic>> recordProductSale({
    required String productId,
    required String productBatchId,
    required double quantity,
    required double unitPrice,
    required String issuedTo, // Customer name or identifier
    String? referenceNumber, // Invoice number
    String? notes,
  }) async {
    try {
      final response = await _client
          .from('inventory_transactions')
          .insert({
            'product_id': productId,
            'product_batch_id': productBatchId,
            'transaction_type': 'sale',
            'quantity': quantity,
            'unit_price': unitPrice,
            'total_amount': quantity * unitPrice,
            'issued_to': issuedTo,
            'reference_number': referenceNumber,
            'notes': notes,
          })
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to record product sale: $e');
    }
  }

  /// Record an inventory adjustment transaction (for corrections, etc.)
  Future<Map<String, dynamic>> recordInventoryAdjustment({
    required String productId,
    required String? productBatchId,
    required double quantity, // Can be positive or negative
    required double unitPrice,
    String? notes,
  }) async {
    try {
      final response = await _client
          .from('inventory_transactions')
          .insert({
            'product_id': productId,
            'product_batch_id': productBatchId,
            'transaction_type': 'adjustment',
            'quantity': quantity,
            'unit_price': unitPrice,
            'total_amount': quantity * unitPrice,
            'notes': notes,
          })
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to record inventory adjustment: $e');
    }
  }

  /// Get inventory transactions for a product (audit trail)
  Future<List<Map<String, dynamic>>> getProductTransactionHistory(
      String productId) async {
    try {
      final response = await _client
          .from('inventory_transactions')
          .select('*, product_batches!left(expiry_date, batch_number), products!left(name)')
          .eq('product_id', productId)
          .order('created_at', ascending: false);
      return response;
    } catch (e) {
      throw Exception('Failed to fetch transaction history: $e');
    }
  }

  /// Get inventory transactions by type for a product
  Future<List<Map<String, dynamic>>> getProductTransactionsByType(
      String productId, String transactionType) async {
    try {
      final response = await _client
          .from('inventory_transactions')
          .select('*, product_batches!left(expiry_date, batch_number), products!left(name)')
          .eq('product_id', productId)
          .eq('transaction_type', transactionType)
          .order('created_at', ascending: false);
      return response;
    } catch (e) {
      throw Exception('Failed to fetch product transactions by type: $e');
    }
  }

  /// Get daily inventory transactions for reporting
  Future<List<Map<String, dynamic>>> getDailyInventoryTransactions(
      DateTime date) async {
    try {
      final startDate = DateTime(date.year, date.month, date.day);
      final endDate = startDate.add(const Duration(days: 1));

      final response = await _client
          .from('inventory_transactions')
          .select('*, products!left(name, category), product_batches!left(expiry_date)')
          .gte('transaction_date', startDate.toIso8601String())
          .lt('transaction_date', endDate.toIso8601String())
          .order('transaction_date', ascending: true);
      return response;
    } catch (e) {
      throw Exception('Failed to fetch daily inventory transactions: $e');
    }
  }

  // =============================================
  // USER PROFILE OPERATIONS
  // =============================================

  /// Get or create user profile (linked to Firebase Auth UID)
  Future<Map<String, dynamic>> getOrCreateUserProfile(String firebaseUid) async {
    try {
      // Try to get existing profile using firebase_uid column
      final response = await _client
          .from('profiles')
          .select()
          .eq('firebase_uid', firebaseUid)
          .single();
      return response;
    } catch (e) {
      if (e.toString().contains('No rows found')) {
        // Return empty or create if needed - usually created via createUserProfile
        return {};
      }
      throw Exception('Failed to get user profile: $e');
    }
  }

  /// Get all profiles (for admin/user management)
  Future<List<Map<String, dynamic>>> getAllProfiles() async {
    try {
      final response = await _client
          .from('profiles')
          .select('*');
      return response;
    } catch (e) {
      throw Exception('Failed to fetch all profiles: $e');
    }
  }

  /// Create a new user profile
  Future<Map<String, dynamic>> _createUserProfile(String firebaseUid) async {
    try {
      final response = await _client
          .from('profiles')
          .insert({'id': firebaseUid})
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateUserProfile(
      String firebaseUid, Map<String, dynamic> updates) async {
    try {
      // Map camelCase fields to snake_case to match profiles table schema
      final mappedUpdates = <String, dynamic>{};

      if (updates.containsKey('firstName')) mappedUpdates['first_name'] = updates['firstName'];
      if (updates.containsKey('middleInitial')) mappedUpdates['middle_initial'] = updates['middleInitial'];
      if (updates.containsKey('surname')) mappedUpdates['surname'] = updates['surname'];
      if (updates.containsKey('email')) mappedUpdates['email'] = updates['email'];
      if (updates.containsKey('phone')) mappedUpdates['phone'] = updates['phone'];
      if (updates.containsKey('role')) mappedUpdates['role'] = updates['role'];
      if (updates.containsKey('status')) mappedUpdates['status'] = updates['status'];
      if (updates.containsKey('updatedAt')) mappedUpdates['updated_at'] = updates['updatedAt'];
      if (updates.containsKey('isArchived')) mappedUpdates['is_archived'] = updates['isArchived'];
      if (updates.containsKey('archivedAt')) mappedUpdates['archived_at'] = updates['archivedAt'];
      if (updates.containsKey('archivedBy')) mappedUpdates['archived_by'] = updates['archivedBy'];

      // Always ensure firebase_uid is set if it's a new record
      mappedUpdates['firebase_uid'] = firebaseUid;

      // Remove 'id' if it's in the updates to avoid UUID conversion errors
      // with the Firebase UID. Supabase will manage the UUID 'id' column.
      mappedUpdates.remove('id');

      // Upsert: Try to update based on firebase_uid, insert if not exists
      final response = await _client
          .from('profiles')
          .upsert(mappedUpdates, onConflict: 'firebase_uid')
          .select()
          .single();

      // Also update Firebase Realtime Database users node for Firebase-Supabase identity bridge
      try {
        await AuthService().database.ref().child('users/$firebaseUid').update(updates);
      } catch (e) {
        // ignore: avoid_print
        print('Failed to sync user profile to Firebase Realtime Database: $e');
      }

      return response;
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  /// Delete user profile
  Future<void> deleteUserProfile(String id) async {
    try {
      await _client.from('profiles').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete user profile: $e');
    }
  }

  // =============================================
  // CATEGORY OPERATIONS
  // =============================================

  /// Get all active (non-archived) categories, ordered by name.
  Future<List<Map<String, dynamic>>> getActiveCategories() async {
    try {
      final response = await _client
          .from('categories')
          .select()
          .eq('is_archived', false)
          .order('name');
      return response;
    } catch (e) {
      throw Exception('Failed to fetch active categories: $e');
    }
  }

  /// Get all categories (including archived), ordered by name.
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    try {
      final response = await _client
          .from('categories')
          .select()
          .order('name');
      return response;
    } catch (e) {
      throw Exception('Failed to fetch all categories: $e');
    }
  }

  /// Create a new category.
  Future<Map<String, dynamic>> createCategory({
    required String name,
    String? description,
    required String createdByProfileId,
  }) async {
    try {
      // Validate input
      if (name.trim().isEmpty) {
        throw Exception('Category name cannot be empty');
      }
      
      final insertData = {
        'name': name.trim(),
        'description': description?.trim(),
      };

      final response = await _client
          .from('categories')
          .insert(insertData)
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to create category: $e');
    }
  }

  /// Update an existing category.
  Future<Map<String, dynamic>> updateCategory({
    required String id,
    required String name,
    String? description,
    required String updatedByProfileId,
  }) async {
    try {
      final updateData = {
        'name': name.trim(),
        'description': description?.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('categories')
          .update(updateData)
          .eq('id', id)
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to update category: $e');
    }
  }

  /// Archives a category (soft delete).
  Future<void> archiveCategory({
    required String id,
    required String archivedByProfileId,
  }) async {
    try {
      await _client
          .from('categories')
          .update({
            'is_archived': true,
            'archived_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to archive category: $e');
    }
  }

  /// Restores an archived category to active state.
  Future<void> restoreCategory({
    required String id,
    required String restoredByProfileId,
  }) async {
    try {
      await _client
          .from('categories')
          .update({
            'is_archived': false,
            'archived_at': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to restore category: $e');
    }
  }

  /// Deletes a category permanently.
  ///
  /// Note: This should only be called on archived categories that are not associated with any products.
  Future<void> deleteCategory({
    required String id,
  }) async {
    try {
      await _client.from('categories').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete category: $e');
    }
  }

  /// Checks if a category name already exists (case-insensitive).
  ///
  /// [excludeId] is optional - if provided, ignores that category ID in the check
  /// (useful for update operations).
  Future<bool> categoryNameExists({
    required String name,
    String? excludeId,
  }) async {
    try {
      final query = _client
          .from('categories')
          .select('id')
          .ilike('name', name.trim());

      if (excludeId != null) {
        final result = await query.neq('id', excludeId);
        return result.isNotEmpty;
      } else {
        final result = await query;
        return result.isNotEmpty;
      }
    } catch (e) {
      throw Exception('Failed to check category name existence: $e');
    }
  }

  /// Ensures a category exists in the categories table.
  /// If it doesn't exist, it creates it so foreign key constraints on products table are satisfied.
  Future<void> ensureCategoryExists(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    try {
      final exists = await categoryNameExists(name: trimmed);
      if (!exists) {
        await _client.from('categories').insert({
          'name': trimmed,
          'description': '',
          'is_archived': false,
        });
      }
    } catch (_) {
      // Ignore if concurrent creation happened
    }
  }

  // =============================================
  // SHOP SETTINGS OPERATIONS
  // =============================================

  /// Get shop settings (singleton table)
  Future<Map<String, dynamic>> getShopSettings() async {
    try {
      final response = await _client
          .from('shop_settings')
          .select()
          .eq('id', 1)
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to fetch shop settings: $e');
    }
  }

  /// Get audit logs
  Future<List<Map<String, dynamic>>> getAuditLogs() async {
    try {
      final response = await _client
          .from('audit_logs')
          .select('*')
          .order('timestamp', ascending: false);
      return response;
    } catch (e) {
      throw Exception('Failed to fetch audit logs: $e');
    }
  }

  /// Update shop settings
  Future<Map<String, dynamic>> updateShopSettings(
      Map<String, dynamic> updates) async {
    try {
      final response = await _client
          .from('shop_settings')
          .update(updates)
          .eq('id', 1)
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to update shop settings: $e');
    }
  }

  // =============================================
  // HELPER METHODS
  // =============================================

  /// Calculate total sellable quantity for a product (FEFO sum of all batches with stock)
  Future<double> getTotalSellableQuantity(String productId) async {
    try {
      final batches = await getProductBatchesFEFO(productId);
      return batches.fold<double>(0.0, (sum, batch) => sum + (batch['quantity'] as num).toDouble());
    } catch (e) {
      throw Exception('Failed to calculate sellable quantity: $e');
    }
  }

  /// Check if product is in low stock status
  Future<bool> isLowStock(String productId, double lowStockThreshold) async {
    try {
      final sellableQty = await getTotalSellableQuantity(productId);
      return sellableQty <= lowStockThreshold && sellableQty > 0;
    } catch (e) {
      throw Exception('Failed to check low stock status: $e');
    }
  }

  /// Check if product is out of stock
  Future<bool> isOutOfStock(String productId) async {
    try {
      final sellableQty = await getTotalSellableQuantity(productId);
      return sellableQty <= 0;
    } catch (e) {
      throw Exception('Failed to check out of stock status: $e');
    }
  }

  /// Get earliest expiring batch ID for a product (for FEFO selling)
  Future<String?> getEarliestExpiringBatchId(String productId) async {
    try {
      final batches = await getProductBatchesFEFO(productId);
      if (batches.isEmpty) return null;
      return batches.first['id'] as String?;
    } catch (e) {
      throw Exception('Failed to get earliest expiring batch: $e');
    }
  }

  /// Diagnostic tool to test connection and basic auth integration.
  Future<Map<String, dynamic>> testConnection() async {
    final results = <String, dynamic>{};
    try {
      // 1. Check client initialization
      results['client_initialized'] = true;

      // 2. Check auth status
      final user = _client.auth.currentUser;
      results['user_logged_in'] = user != null;
      if (user != null) {
        results['user_id'] = user.id;
        results['user_email'] = user.email;
      }

      // 3. Try to fetch one category (basic read test)
      final categoryCheck = await _client.from('categories').select('count').limit(1).maybeSingle();
      results['database_reachable'] = true;
      results['categories_count'] = categoryCheck != null ? 1 : 0;

      // 4. Try to call a simple RPC or just check profile mapping
      if (user != null) {
        final profileCheck = await _client.from('profiles').select('role').eq('firebase_uid', user.id).maybeSingle();
        results['profile_mapped'] = profileCheck != null;
        if (profileCheck != null) {
          results['user_role'] = profileCheck['role'];
        }
      }

      results['status'] = 'Success';
    } catch (e) {
      results['status'] = 'Error';
      results['error'] = e.toString();
    }
    return results;
  }
}
import 'package:flutter/foundation.dart';
import '../models/admin_models.dart';
import '../../core/services/supabase_service.dart';

/// Service for handling sale operations using Supabase as the data source
class AdminSaleService extends ChangeNotifier {
  AdminSaleService({
    SupabaseService? supabaseService,
  }) : _supabaseService = supabaseService ?? SupabaseService() {
    initialize();
  }

  final SupabaseService _supabaseService;

  // Cached data
  List<AdminSale> _sales = [];

  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  // ==================== GETTERS ====================

  List<AdminSale> get allSales => List.unmodifiable(_sales);

  List<AdminSale> get completedSales =>
      _sales.where((s) => s.isCompleted).toList();

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ==================== INITIALIZATION ====================

  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadSales();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadSales() async {
    try {
      // Get all orders from Supabase
      final supabaseSales = await _supabaseService.getAllOrders();
      _sales = supabaseSales.map(_fromSupabaseSale).toList();
    } catch (e) {
      _error = 'Failed to load sales: $e';
      rethrow;
    }
  }

  Future<void> refresh() async {
    await initialize();
  }

  // ==================== SALE OPERATIONS ====================

  AdminSale saleById(String id) =>
    _sales.firstWhere((s) => s.id == id, orElse: () => throw StateError('Sale with id $id not found'));

  Future<String?> recordSale({
    required String cashierId,
    required List<SaleItem> items,
    String customerName = 'Walk-in',
    double discount = 0,
    PaymentMethod paymentMethod = PaymentMethod.cash,
    required double amountPaid,
  }) async {
    try {
      if (items.isEmpty) return 'Add at least one item to the sale.';

      // Validate cashier exists
      // In a real implementation, we'd check against user service
      // For now, we'll assume the cashierId is valid if it's not empty
      if (cashierId.isEmpty) return 'Invalid cashier.';

      // Validate products and check stock would require product service
      // For now, we'll proceed and let Supabase handle constraints
      // The product service should be notified separately to update stock

      // Calculate totals
      final subtotal = items.fold<double>(0, (sum, item) => sum + item.lineTotal);
      final total = subtotal - discount;
      if (amountPaid < total)
        return 'Amount paid is less than the total of ${formatPeso(total)}.';

      // Create order with items using Supabase RPC
      final orderNumber = 'OR-${DateTime.now().year}-${_generateSequenceNumber()}';

      final itemsData = items.map((item) => {
        'product_id': item.productId,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'unit_cost': item.unitCost,
      }).toList();

      final orderId = await _supabaseService.createOrderWithItems(
        firebaseUid: cashierId, // Assuming cashierId is Firebase UID for now
        orderNumber: orderNumber,
        totalAmount: total,
        totalItems: items.length,
        items: itemsData,
        customerName: customerName.trim().isEmpty ? 'Walk-in' : customerName.trim(),
        orderNotes: '', // Could add discount info here
      );

      // TODO: Update product quantities (decrease stock)
      // This would require coordination with product service
      // For now, we'll note that stock adjustment needs to happen elsewhere

      // Create AdminSale object for local cache
      final newSale = AdminSale(
        id: orderId,
        receiptNumber: orderNumber,
        cashierId: cashierId,
        cashierName: 'Unknown Cashier', // Would come from user service
        customerName: customerName.trim().isEmpty ? 'Walk-in' : customerName.trim(),
        items: items,
        discount: discount,
        paymentMethod: paymentMethod,
        amountPaid: amountPaid,
        timestamp: DateTime.now(),
      );

      _sales.add(newSale);
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to record sale: $e';
    }
  }

  Future<String?> voidSale(String id, String reason) async {
    try {
      final index = _sales.indexWhere((s) => s.id == id);
      if (index == -1) return 'That receipt no longer exists.';

      final sale = _sales[index];
      if (!sale.isCompleted) return 'That receipt is already ${sale.status.label.toLowerCase()}.';
      if (reason.trim().isEmpty) return 'Enter a reason for voiding this sale.';

      // Update order status in Supabase
      await _supabaseService.updateOrderStatus(id, 'voided');

      // TODO: Restore product quantities
      // This would require coordination with product service

      // Update local cache
      final voidedSale = sale.copyWith(
        status: SaleStatus.voided,
        voidReason: reason.trim(),
        voidedBy: 'Current User', // TODO: Get actual current user
        voidedAt: DateTime.now(),
      );

      _sales[index] = voidedSale;
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to void sale: $e';
    }
  }

  // ==================== ANALYTICS METHODS ====================

  List<DaySales> salesByDay(int days) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final result = <DaySales>[];

    for (var i = 0; i < days; i++) {
      final day = start.add(Duration(days: i));
      final ofDay = completedSales
          .where((s) => isSameDay(s.timestamp, day))
          .toList();
      result.add(DaySales(
        day,
        ofDay.fold<double>(0, (sum, s) => sum + s.total),
        ofDay.length,
      ));
    }
    return result;
  }

  List<WeekSales> salesByWeek(int weeks) {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    // Monday of the current week (DateTime.weekday: Mon = 1 ... Sun = 7).
    final currentWeekStart =
    todayMidnight.subtract(Duration(days: todayMidnight.weekday - 1));

    final result = <WeekSales>[];
    for (var i = weeks - 1; i >= 0; i--) {
      final weekStart = currentWeekStart.subtract(Duration(days: 7 * i));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final ofWeek = completedSales.where((s) {
        final d = DateTime(s.timestamp.year, s.timestamp.month, s.timestamp.day);
        return !d.isBefore(weekStart) && !d.isAfter(weekEnd);
      }).toList();
      result.add(WeekSales(
        weekStart,
        weekEnd,
        ofWeek.fold<double>(0, (sum, s) => sum + s.total),
        ofWeek.length,
      ));
    }
    return result;
  }

  List<MonthSales> salesByMonth(int months) {
    final now = DateTime.now();
    final result = <MonthSales>[];
    for (var i = months - 1; i >= 0; i--) {
      final monthIndex = now.year * 12 + (now.month - 1) - i;
      final year = monthIndex ~/ 12;
      final month = monthIndex % 12 + 1;
      final ofMonth = completedSales
          .where((s) => s.timestamp.year == year && s.timestamp.month == month)
          .toList();
      result.add(MonthSales(
        year,
        month,
        ofMonth.fold<double>(0, (sum, s) => sum + s.total),
        ofMonth.length,
      ));
    }
    return result;
  }

  List<ProductSalesStat> topSellingProducts({int limit = 5}) {
    final units = <String, double>{};
    final revenue = <String, double>{};
    final names = <String, String>{};
    final unitLabels = <String, String>{};

    for (final sale in completedSales) {
      for (final item in sale.items) {
        units[item.productId] = (units[item.productId] ?? 0) + item.quantity;
        revenue[item.productId] =
            (revenue[item.productId] ?? 0) + item.lineTotal;
        names[item.productId] = item.productName;
        unitLabels[item.productId] = item.unit;
      }
    }

    final stats = units.keys
        .map((id) => ProductSalesStat(
          productId: id,
          productName: names[id] ?? id,
          unit: unitLabels[id] ?? 'piece',
          unitsSold: units[id] ?? 0,
          revenue: revenue[id] ?? 0,
        ))
        .toList();

    stats.sort((a, b) => b.revenue.compareTo(a.revenue));
    return stats.take(limit).toList();
  }

  double get salesToday {
    final now = DateTime.now();
    return completedSales
        .where((s) => isSameDay(s.timestamp, now))
        .fold<double>(0, (sum, s) => sum + s.total);
  }

  double get profitToday {
    final now = DateTime.now();
    return completedSales
        .where((s) => isSameDay(s.timestamp, now))
        .fold<double>(0, (sum, s) => sum + s.profit);
  }

  int get ordersToday {
    final now = DateTime.now();
    return completedSales.where((s) => isSameDay(s.timestamp, now)).length;
  }

  double get salesAllTime =>
      completedSales.fold<double>(0, (sum, s) => sum + s.total);

  double get profitAllTime =>
      completedSales.fold<double>(0, (sum, s) => sum + s.profit);

  double get averageBasket =>
      completedSales.isEmpty ? 0 : salesAllTime / completedSales.length;

  // ==================== HELPER METHODS ====================

  String formatPeso(double value) {
    final isNegative = value < 0;
    final parts = value.abs().toStringAsFixed(2).split('.');
    final whole = parts[0];
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
      buffer.write(whole[i]);
    }
    return '${isNegative ? '-' : ''}₱$buffer.${parts[1]}';
  }

  String formatQuantity(double value, String unit) {
    final isWhole = value == value.roundToDouble();
    final text = isWhole ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
    return '$text $unit';
  }

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _generateSequenceNumber() {
    // Simple sequence number generator - in production this would be more robust
    return DateTime.now().millisecondsSinceEpoch % 10000;
  }

  // ==================== DATA TRANSFORMATION ====================

  AdminSale _fromSupabaseSale(Map<String, dynamic> data) {
    // Convert order items to SaleItem list
    final List<SaleItem> items = [];
    if (data['order_items'] != null && data['order_items'] is List) {
      for (var itemData in data['order_items']) {
        items.add(SaleItem(
          productId: itemData['product_id'] as String,
          productName: itemData['product_name'] as String ?? 'Unknown Product',
          unit: itemData['unit'] as String ?? 'piece',
          unitPrice: (itemData['unit_price'] as num).toDouble(),
          unitCost: (itemData['unit_cost'] as num).toDouble(),
          quantity: (itemData['quantity'] as num).toDouble(),
        ));
      }
    }

    return AdminSale(
      id: data['id'] as String,
      receiptNumber: data['order_number'] as String ?? '',
      cashierId: data['user_id'] as String ?? '',
      cashierName: data['cashier_name'] as String ?? 'Unknown Cashier',
      customerName: data['customer_name'] as String ?? 'Walk-in',
      items: items,
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
      paymentMethod: _parsePaymentMethod(data['payment_method'] as String?),
      amountPaid: (data['amount_paid'] as num).toDouble(),
      timestamp: DateTime.parse(data['placed_at'] as String),
      status: _parseSaleStatus(data['status'] as String?),
      voidReason: data['void_reason'] as String?,
      voidedBy: data['voided_by'] as String?,
      voidedAt: data['voided_at'] != null
          ? DateTime.parse(data['voided_at'] as String)
          : null,
    );
  }

  PaymentMethod _parsePaymentMethod(String? method) {
    switch (method?.toLowerCase()) {
      case 'gcash':
        return PaymentMethod.gcash;
      case 'maya':
        return PaymentMethod.maya;
      case 'card':
        return PaymentMethod.card;
      default:
        return PaymentMethod.cash;
    }
  }

  SaleStatus _parseSaleStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'voided':
        return SaleStatus.voided;
      case 'refunded':
        return SaleStatus.refunded;
      default:
        return SaleStatus.completed;
    }
  }
}
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
      final supabaseSales = await _supabaseService.getAllOrdersWithItems();
      _sales = supabaseSales.map(_fromSupabaseSale).toList();
    } catch (e) {
      _error = 'Failed to load sales: $e';
      rethrow;
    }
  }

  Future<void> refresh() async {
    _isInitialized = false;
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
      if (cashierId.isEmpty) return 'Invalid cashier.';

      final subtotal = items.fold<double>(0, (sum, item) => sum + item.lineTotal);
      final total = subtotal - discount;
      if (amountPaid < total) {
        return 'Amount paid is less than the total of ${formatPeso(total)}.';
      }

      final orderNumber = 'OR-${DateTime.now().year}-${_generateSequenceNumber()}';

      final itemsData = items.map((item) => {
        'product_id': item.productId,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'unit_cost': item.unitCost,
      }).toList();

      final orderId = await _supabaseService.createOrderWithItems(
        firebaseUid: cashierId,
        orderNumber: orderNumber,
        totalAmount: total,
        totalItems: items.length,
        items: itemsData,
        customerName: customerName.trim().isEmpty ? 'Walk-in' : customerName.trim(),
        orderNotes: '',
      );

      final newSale = AdminSale(
        id: orderId,
        receiptNumber: orderNumber,
        cashierId: cashierId,
        cashierName: 'Cashier',
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

      await _supabaseService.updateOrderStatus(id, 'voided');

      final voidedSale = sale.copyWith(
        status: SaleStatus.voided,
        voidReason: reason.trim(),
        voidedBy: 'Current User',
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

  List<ProductSalesStat> topSellingProducts({int limit = 6}) {
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
    return DateTime.now().millisecondsSinceEpoch % 10000;
  }

  // ==================== DATA TRANSFORMATION ====================

  AdminSale _fromSupabaseSale(Map<String, dynamic> data) {
    final List<SaleItem> items = [];
    if (data['order_items'] != null && data['order_items'] is List) {
      for (var itemData in data['order_items']) {
        items.add(SaleItem(
          productId: itemData['product_id']?.toString() ?? '',
          productName: itemData['product_name']?.toString() ?? 'Item',
          unit: itemData['unit']?.toString() ?? 'piece',
          unitPrice: (itemData['unit_price'] as num? ?? 0).toDouble(),
          unitCost: (itemData['unit_cost'] as num? ?? 0).toDouble(),
          quantity: (itemData['quantity'] as num? ?? 0).toDouble(),
        ));
      }
    }

    return AdminSale(
      id: data['id']?.toString() ?? '',
      receiptNumber: data['order_number']?.toString() ?? '',
      cashierId: data['user_id']?.toString() ?? '',
      cashierName: data['cashier_name']?.toString() ?? 'Cashier',
      customerName: data['customer_name']?.toString() ?? 'Walk-in',
      items: items,
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
      paymentMethod: _parsePaymentMethod(data['payment_method']?.toString()),
      amountPaid: (data['total_amount'] as num? ?? 0).toDouble(),
      timestamp: data['placed_at'] != null 
          ? DateTime.tryParse(data['placed_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: _parseSaleStatus(data['status']?.toString()),
      voidReason: data['void_reason']?.toString(),
      voidedBy: data['voided_by']?.toString(),
      voidedAt: data['voided_at'] != null
          ? DateTime.tryParse(data['voided_at'] as String)
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
      case 'cancelled':
        return SaleStatus.voided;
      case 'refunded':
        return SaleStatus.refunded;
      default:
        return SaleStatus.completed;
    }
  }
}
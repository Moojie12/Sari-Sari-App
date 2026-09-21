import 'package:flutter/foundation.dart';
import '../models/admin_models.dart';
import '../../core/services/supabase_service.dart';

/// Service for handling analytics and statistics using Supabase as the data source
class AdminAnalyticsService extends ChangeNotifier {
  AdminAnalyticsService({
    SupabaseService? supabaseService,
  }) : _supabaseService = supabaseService ?? SupabaseService() {
    initialize();
  }

  final SupabaseService _supabaseService;

  // Cached data
  List<AdminProduct> _products = [];
  List<AdminSale> _sales = [];

  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  // ==================== GETTERS ====================

  List<AdminProduct> get allProducts => List.unmodifiable(_products);

  List<AdminProduct> get activeProducts =>
      _products.where((p) => !p.isArchived).toList();

  List<AdminProduct> get archivedProducts =>
      _products.where((p) => p.isArchived).toList();

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
      // Load products and sales in parallel
      await Future.wait([
        _loadProducts(),
        _loadSales(),
      ]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadProducts() async {
    try {
      final supabaseProducts = await _supabaseService.getProductsWithInventory();
      _products = supabaseProducts.map(_fromSupabaseProduct).toList();
    } catch (e) {
      _error = 'Failed to load products: $e';
      rethrow;
    }
  }

  Future<void> _loadSales() async {
    try {
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

  // ==================== ANALYTICS METHODS ====================

  List<AdminProduct> get lowStockProducts {
    final list = activeProducts.where((p) => p.isLowStock || p.isOutOfStock).toList();
    list.sort((a, b) => a.quantity.compareTo(b.quantity));
    return list;
  }

  List<AdminProduct> get expiringProducts {
    final list =
    activeProducts.where((p) => p.isExpired || p.isExpiringSoon).toList();
    list.sort((a, b) => a.expirationDate!.compareTo(b.expirationDate!));
    return list;
  }

  double get inventoryValue =>
      activeProducts.fold<double>(0, (sum, p) => sum + p.stockValue);

  List<DaySales> salesByDay(int days) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final result = <DaySales>[];

    for (var i = 0; i < days; i++) {
      final day = start.add(Duration(days: i));
      final ofDay =
      completedSales.where((s) => isSameDay(s.timestamp, day)).toList();
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

  AdminProduct productById(String id) =>
    _products.firstWhere((p) => p.id == id, orElse: () => throw StateError('Product with id $id not found'));

  AdminSale saleById(String id) =>
    _sales.firstWhere((s) => s.id == id, orElse: () => throw StateError('Sale with id $id not found'));

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

  String formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d ${_kMonths[dt.month - 1]} ${dt.year}, $hh:$mm';
  }

  String formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final d = dt.day.toString().padLeft(2, '0');
    return '$d ${_kMonths[dt.month - 1]} ${dt.year}';
  }

  String formatShortDate(DateTime dt) => '${dt.day} ${_kMonths[dt.month - 1]}';

  String formatMonthYear(int year, int month) => '${_kMonths[month - 1]} $year';

  String formatWeekRange(DateTime start, DateTime end) {
    if (start.month == end.month) {
      return '${start.day}–${end.day} ${_kMonths[start.month - 1]}';
    }
    return '${start.day} ${_kMonths[start.month - 1]} – ${end.day} ${_kMonths[end.month - 1]}';
  }

  String formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return formatDate(dt);
  }

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ==================== DATA TRANSFORMATION ====================

  AdminProduct _fromSupabaseProduct(Map<String, dynamic> data) {
    // 1. Calculate total quantity and earliest expiry from the related batches
    double totalQuantity = 0;
    DateTime? earliestExpiry;
    
    if (data['product_batches'] != null && data['product_batches'] is List) {
      for (var batch in data['product_batches']) {
        if (batch['quantity'] != null) {
          totalQuantity += (batch['quantity'] as num).toDouble();
        }
        if (batch['expiry_date'] != null) {
          final expiry = DateTime.tryParse(batch['expiry_date'] as String);
          if (expiry != null && (earliestExpiry == null || expiry.isBefore(earliestExpiry))) {
            earliestExpiry = expiry;
          }
        }
      }
    }

    // 2. Map snake_case database fields to the AdminProduct model
    // Your SQL schema uses 'category' (text) and 'capital' (numeric)
    return AdminProduct(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? 'Unnamed Product',
      categoryId: data['category']?.toString() ?? '', 
      categoryName: data['category']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      price: (data['price'] as num? ?? 0).toDouble(),
      cost: (data['capital'] as num? ?? 0).toDouble(),
      quantity: totalQuantity,
      unit: data['unit']?.toString() ?? 'piece',
      barcode: data['barcode']?.toString() ?? '',
      expirationDate: earliestExpiry,
      lowStockThreshold: (data['low_stock_threshold'] as num?)?.toDouble() ?? kDefaultLowStockThreshold,
      image: data['image']?.toString(),
      createdAt: data['created_at'] != null ? DateTime.tryParse(data['created_at'] as String) : null,
      updatedAt: data['updated_at'] != null ? DateTime.tryParse(data['updated_at'] as String) : null,
      isArchived: data['is_archived'] as bool? ?? false,
    );
  }

  AdminSale _fromSupabaseSale(Map<String, dynamic> data) {
    // Convert order items to SaleItem list
    final List<SaleItem> items = [];
    if (data['order_items'] != null && data['order_items'] is List) {
      for (var itemData in data['order_items']) {
        items.add(SaleItem(
          productId: itemData['product_id']?.toString() ?? '',
          productName: itemData['product_name']?.toString() ?? 'Unknown Product',
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
      cashierName: data['cashier_name']?.toString() ?? 'Unknown Cashier',
      customerName: data['customer_name']?.toString() ?? 'Walk-in',
      items: items,
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
      paymentMethod: _parsePaymentMethod(data['payment_method']?.toString()),
      amountPaid: (data['total_amount'] as num? ?? 0).toDouble(), // total_amount in your schema
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
        return SaleStatus.voided;
      case 'refunded':
        return SaleStatus.refunded;
      default:
        return SaleStatus.completed;
    }
  }

  // Constants for formatting
  static const List<String> _kMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
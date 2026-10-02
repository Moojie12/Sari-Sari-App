import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  DateTime? _lastSyncTime;
  RealtimeChannel? _realtimeChannel;

  // ==================== GETTERS ====================

  List<AdminSale> get allSales => List.unmodifiable(_sales);

  List<AdminSale> get completedSales =>
      _sales.where((s) => s.isCompleted).toList();

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastSyncTime => _lastSyncTime;

  // ==================== INITIALIZATION & REALTIME ====================

  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadSales();
      _subscribeToRealtime();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeToRealtime() {
    if (_realtimeChannel != null) return;
    try {
      _realtimeChannel = _supabaseService.client
          .channel('public:admin_sales')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) {
              _loadSales().then((_) => notifyListeners()).catchError((e) {
                debugPrint('Realtime sales reload failed: $e');
              });
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'order_items',
            callback: (payload) {
              _loadSales().then((_) => notifyListeners()).catchError((e) {
                debugPrint('Realtime order items reload failed: $e');
              });
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Failed to subscribe to Supabase realtime in AdminSaleService: $e');
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadSales() async {
    try {
      // 1. Fetch profiles to resolve handler names and roles from database
      List<Map<String, dynamic>> profiles = [];
      try {
        profiles = await _supabaseService.getAllProfiles();
      } catch (e) {
        debugPrint('Could not fetch profiles for sales resolution: $e');
      }

      final Map<String, Map<String, dynamic>> staffProfilesById = {};
      final Map<String, Map<String, dynamic>> staffProfilesByName = {};
      Map<String, dynamic>? defaultOwnerProfile;
      Map<String, dynamic>? defaultEmployeeProfile;

      for (final p in profiles) {
        final id = p['id']?.toString() ?? '';
        final firebaseUid = p['firebase_uid']?.toString() ?? '';
        final firstName = (p['first_name'] ?? p['firstName'] ?? '').toString().trim();
        final surname = (p['surname'] ?? p['lastName'] ?? '').toString().trim();
        final fullName = '$firstName $surname'.trim().toLowerCase();
        final role = (p['role'] ?? '').toString().toLowerCase().trim();

        // STRICT: Only store staff (Owner, Employee, Admin) can be handlers.
        // Customers are strictly excluded!
        final isStaff = role == 'owner' || role == 'employee' || role == 'admin';

        if (isStaff) {
          if (id.isNotEmpty) staffProfilesById[id] = p;
          if (firebaseUid.isNotEmpty) staffProfilesById[firebaseUid] = p;
          if (fullName.isNotEmpty) staffProfilesByName[fullName] = p;
          if (firstName.isNotEmpty) staffProfilesByName[firstName.toLowerCase()] = p;

          if (role == 'owner' && defaultOwnerProfile == null) {
            defaultOwnerProfile = p;
          }
          if (role == 'employee' && defaultEmployeeProfile == null) {
            defaultEmployeeProfile = p;
          }
        }
      }

      // 2. Fetch orders with items
      final supabaseSales = await _supabaseService.getAllOrdersWithItems();
      _sales = supabaseSales.map((data) => _fromSupabaseSale(
        data,
        staffProfilesById: staffProfilesById,
        staffProfilesByName: staffProfilesByName,
        defaultOwner: defaultOwnerProfile,
        defaultEmployee: defaultEmployeeProfile,
      )).toList();
      _lastSyncTime = DateTime.now();
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
        transactionType: AdminTransactionType.inStore,
      );

      _sales.add(newSale);
      _lastSyncTime = DateTime.now();
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
        rawStatus: 'voided',
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

  /// Restores a previously voided sale back to completed status,
  /// updating the Supabase database and recalculating sales totals.
  Future<String?> unvoidSale(String id) async {
    try {
      final index = _sales.indexWhere((s) => s.id == id);
      if (index == -1) return 'That receipt no longer exists.';

      final sale = _sales[index];
      if (sale.isCompleted) return 'That receipt is not voided.';

      // 1. Update in Supabase database
      try {
        await _supabaseService.updateOrderStatusInDb(id, 'completed', 'paid');
      } catch (_) {
        await _supabaseService.updateOrderStatus(id, 'completed');
      }

      // 2. Update local state
      final restoredSale = sale.copyWith(
        status: SaleStatus.completed,
        rawStatus: 'completed',
        clearVoidInfo: true,
      );

      _sales[index] = restoredSale;
      _lastSyncTime = DateTime.now();
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to restore sale: $e';
    }
  }

  // ==================== ANALYTICS & SUMMARY METHODS ====================

  double get salesToday {
    final now = DateTime.now();
    return completedSales
        .where((s) => isSameDay(s.timestamp, now))
        .fold<double>(0, (sum, s) => sum + s.total);
  }

  int get ordersToday {
    final now = DateTime.now();
    return completedSales.where((s) => isSameDay(s.timestamp, now)).length;
  }

  double get salesThisWeek {
    final now = DateTime.now();
    final nowMidnight = DateTime(now.year, now.month, now.day);
    final weekStart = nowMidnight.subtract(Duration(days: nowMidnight.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return completedSales
        .where((s) => !s.timestamp.isBefore(weekStart) && !s.timestamp.isAfter(weekEnd))
        .fold<double>(0, (sum, s) => sum + s.total);
  }

  int get ordersThisWeek {
    final now = DateTime.now();
    final nowMidnight = DateTime(now.year, now.month, now.day);
    final weekStart = nowMidnight.subtract(Duration(days: nowMidnight.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return completedSales
        .where((s) => !s.timestamp.isBefore(weekStart) && !s.timestamp.isAfter(weekEnd))
        .length;
  }

  double get salesThisMonth {
    final now = DateTime.now();
    return completedSales
        .where((s) => s.timestamp.year == now.year && s.timestamp.month == now.month)
        .fold<double>(0, (sum, s) => sum + s.total);
  }

  int get ordersThisMonth {
    final now = DateTime.now();
    return completedSales
        .where((s) => s.timestamp.year == now.year && s.timestamp.month == now.month)
        .length;
  }

  int get inStoreOrdersCount =>
      _sales.where((s) => s.isInStore).length;

  int get deliveryOrdersCount =>
      _sales.where((s) => s.isDelivery).length;

  double get inStoreSalesTotal =>
      completedSales.where((s) => s.isInStore).fold<double>(0, (sum, s) => sum + s.total);

  double get deliverySalesTotal =>
      completedSales.where((s) => s.isDelivery).fold<double>(0, (sum, s) => sum + s.total);

  double get profitToday {
    final now = DateTime.now();
    return completedSales
        .where((s) => isSameDay(s.timestamp, now))
        .fold<double>(0, (sum, s) => sum + s.profit);
  }

  double get salesAllTime =>
      completedSales.fold<double>(0, (sum, s) => sum + s.total);

  double get profitAllTime =>
      completedSales.fold<double>(0, (sum, s) => sum + s.profit);

  double get averageBasket =>
      completedSales.isEmpty ? 0 : salesAllTime / completedSales.length;

  /// Filters sales records for a specified period and optional transaction filter
  List<AdminSale> getSalesForPeriod({
    required String period, // 'Daily', 'Weekly', 'Monthly'
    DateTime? referenceDate,
    String? transactionTypeFilter, // 'All Transactions', 'In-Store Transaction', 'Delivery Transaction'
  }) {
    final ref = referenceDate ?? DateTime.now();
    List<AdminSale> periodSales = [];

    switch (period.toLowerCase()) {
      case 'daily':
        periodSales = _sales.where((s) => isSameDay(s.timestamp, ref)).toList();
        break;
      case 'weekly':
        final refMidnight = DateTime(ref.year, ref.month, ref.day);
        final weekStart = refMidnight.subtract(Duration(days: refMidnight.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        periodSales = _sales.where((s) => !s.timestamp.isBefore(weekStart) && !s.timestamp.isAfter(weekEnd)).toList();
        break;
      case 'monthly':
        periodSales = _sales.where((s) => s.timestamp.year == ref.year && s.timestamp.month == ref.month).toList();
        break;
      default:
        periodSales = [..._sales];
    }

    if (transactionTypeFilter != null &&
        transactionTypeFilter != 'All Transactions' &&
        transactionTypeFilter != 'All') {
      if (transactionTypeFilter == 'In-Store Transaction') {
        periodSales = periodSales.where((s) => s.isInStore).toList();
      } else if (transactionTypeFilter == 'Delivery Transaction') {
        periodSales = periodSales.where((s) => s.isDelivery).toList();
      }
    }

    periodSales.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return periodSales;
  }

  List<DaySales> salesByDay(int days, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final start = DateTime(ref.year, ref.month, ref.day)
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

  List<WeekSales> salesByWeek(int weeks, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final refMidnight = DateTime(ref.year, ref.month, ref.day);
    final currentWeekStart =
    refMidnight.subtract(Duration(days: refMidnight.weekday - 1));

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

  List<MonthSales> salesByMonth(int months, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final result = <MonthSales>[];
    for (var i = months - 1; i >= 0; i--) {
      final monthIndex = ref.year * 12 + (ref.month - 1) - i;
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

  static String _capitalize(String? s) {
    if (s == null || s.trim().isEmpty) return '';
    final trimmed = s.trim();
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }

  AdminSale _fromSupabaseSale(
    Map<String, dynamic> data, {
    Map<String, Map<String, dynamic>> staffProfilesById = const {},
    Map<String, Map<String, dynamic>> staffProfilesByName = const {},
    Map<String, dynamic>? defaultOwner,
    Map<String, dynamic>? defaultEmployee,
  }) {
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

    final orderTypeStr = data['order_type']?.toString().toLowerCase().trim() ?? '';
    final deliveryAddress = data['delivery_address']?.toString().trim() ?? '';
    final isDelivery = orderTypeStr == 'delivery' || deliveryAddress.isNotEmpty;
    final transactionType = isDelivery
        ? AdminTransactionType.delivery
        : AdminTransactionType.inStore;

    // Resolve handler name and database role (STRICT: Owner or Employee only, NEVER customer)
    String handlerName = '';
    String? handlerRole;

    final notes = data['order_notes']?.toString() ?? '';
    final customerName = (data['customer_name']?.toString() ?? 'Walk-in').trim().toLowerCase();

    // 1. Check rider/delivery_person tag: [delivery_person: uid|name|role]
    if (notes.contains('[delivery_person:')) {
      final riderMatch = RegExp(r'\[delivery_person:\s*([^|\]]+)\|([^|\]]+)(?:\|([^|\]]+))?\]').firstMatch(notes);
      if (riderMatch != null) {
        final uid = riderMatch.group(1)?.trim();
        final rawName = riderMatch.group(2)?.trim();
        final rawRole = riderMatch.group(3)?.trim();

        if (uid != null && staffProfilesById.containsKey(uid)) {
          final p = staffProfilesById[uid]!;
          final fn = (p['first_name'] ?? p['firstName'] ?? '').toString().trim();
          final sn = (p['surname'] ?? p['lastName'] ?? '').toString().trim();
          handlerName = '$fn $sn'.trim();
          handlerRole = _capitalize(p['role']?.toString());
        } else if (rawName != null && rawName.isNotEmpty) {
          final lookup = rawName.toLowerCase().trim();
          if (staffProfilesByName.containsKey(lookup)) {
            final p = staffProfilesByName[lookup]!;
            final fn = (p['first_name'] ?? p['firstName'] ?? '').toString().trim();
            final sn = (p['surname'] ?? p['lastName'] ?? '').toString().trim();
            handlerName = '$fn $sn'.trim();
            handlerRole = _capitalize(p['role']?.toString());
          } else {
            handlerName = rawName;
            handlerRole = _capitalize(rawRole ?? 'Employee');
          }
        }
      }
    }

    // 2. Check "Sold by:" in order notes (POS orders: e.g. "Sold by: Maria Santos (Employee)" or "Sold by: Owner Owner (Owner)")
    if (handlerName.isEmpty && notes.contains('Sold by:')) {
      final soldMatch = RegExp(r'Sold by:\s*([^\n;\[]+)').firstMatch(notes);
      if (soldMatch != null && soldMatch.group(1) != null) {
        final rawSold = soldMatch.group(1)!.trim();
        final roleParenMatch = RegExp(r'^(.*?)\s*\((.*?)\)$').firstMatch(rawSold);
        String candidateName = rawSold;
        String? candidateRole;
        if (roleParenMatch != null) {
          candidateName = roleParenMatch.group(1)!.trim();
          candidateRole = _capitalize(roleParenMatch.group(2)!.trim());
        }

        final lookup = candidateName.toLowerCase().trim();
        if (staffProfilesByName.containsKey(lookup)) {
          final p = staffProfilesByName[lookup]!;
          final fn = (p['first_name'] ?? p['firstName'] ?? '').toString().trim();
          final sn = (p['surname'] ?? p['lastName'] ?? '').toString().trim();
          handlerName = '$fn $sn'.trim();
          handlerRole = _capitalize(p['role']?.toString());
        } else if (candidateRole != null && candidateRole.toLowerCase() != 'customer') {
          handlerName = candidateName;
          handlerRole = candidateRole;
        } else {
          handlerName = candidateName;
          handlerRole = 'Employee';
        }
      }
    }

    // 3. Check cashier_name column if provided (ensuring it's not the customer)
    final explicitCashier = data['cashier_name']?.toString().trim() ?? '';
    if (handlerName.isEmpty && explicitCashier.isNotEmpty) {
      final lookup = explicitCashier.toLowerCase();
      if (staffProfilesByName.containsKey(lookup)) {
        final p = staffProfilesByName[lookup]!;
        final fn = (p['first_name'] ?? p['firstName'] ?? '').toString().trim();
        final sn = (p['surname'] ?? p['lastName'] ?? '').toString().trim();
        handlerName = '$fn $sn'.trim();
        handlerRole = _capitalize(p['role']?.toString());
      } else if (lookup != customerName && lookup != 'customer') {
        handlerName = explicitCashier;
        handlerRole = 'Employee';
      }
    }

    // 4. Check user_id against STAFF profiles (ONLY if user_id belongs to an Owner or Employee)
    final userId = data['user_id']?.toString() ?? '';
    if (handlerName.isEmpty && staffProfilesById.containsKey(userId)) {
      final p = staffProfilesById[userId]!;
      final pRole = p['role']?.toString().toLowerCase().trim() ?? '';
      if (pRole == 'owner' || pRole == 'employee' || pRole == 'admin') {
        final fn = (p['first_name'] ?? p['firstName'] ?? '').toString().trim();
        final sn = (p['surname'] ?? p['lastName'] ?? '').toString().trim();
        handlerName = '$fn $sn'.trim();
        handlerRole = _capitalize(p['role']?.toString());
      }
    }

    // 5. Default store staff fallback (Owner or Employee, NEVER the customer)
    if (handlerName.isEmpty) {
      if (defaultOwner != null) {
        final fn = (defaultOwner['first_name'] ?? '').toString().trim();
        final sn = (defaultOwner['surname'] ?? '').toString().trim();
        handlerName = '$fn $sn'.trim();
        handlerRole = _capitalize(defaultOwner['role']?.toString() ?? 'Owner');
      } else if (defaultEmployee != null) {
        final fn = (defaultEmployee['first_name'] ?? '').toString().trim();
        final sn = (defaultEmployee['surname'] ?? '').toString().trim();
        handlerName = '$fn $sn'.trim();
        handlerRole = _capitalize(defaultEmployee['role']?.toString() ?? 'Employee');
      } else {
        handlerName = 'Store Owner';
        handlerRole = 'Owner';
      }
    }

    // Strict safety check: If role is still missing or customer, force Owner
    if (handlerRole == null || handlerRole.isEmpty || handlerRole.toLowerCase() == 'customer') {
      handlerRole = 'Owner';
    }

    return AdminSale(
      id: data['id']?.toString() ?? '',
      receiptNumber: (data['order_number']?.toString().isNotEmpty ?? false)
          ? data['order_number'].toString()
          : (data['id']?.toString() ?? ''),
      cashierId: data['user_id']?.toString() ?? '',
      cashierName: handlerName,
      customerName: data['customer_name']?.toString() ?? 'Walk-in',
      items: items,
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
      paymentMethod: _parsePaymentMethod(data['payment_method']?.toString()),
      amountPaid: (data['total_amount'] as num? ?? 0).toDouble(),
      timestamp: data['placed_at'] != null 
          ? DateTime.tryParse(data['placed_at'] as String)?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      status: _parseSaleStatus(data['status']?.toString()),
      transactionType: transactionType,
      rawStatus: data['status']?.toString(),
      voidReason: data['void_reason']?.toString(),
      voidedBy: data['voided_by']?.toString(),
      voidedAt: data['voided_at'] != null
          ? DateTime.tryParse(data['voided_at'] as String)?.toLocal()
          : null,
      handlerRole: handlerRole,
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
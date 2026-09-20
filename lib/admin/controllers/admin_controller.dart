import 'package:flutter/foundation.dart';

import '../models/admin_models.dart';

/// In-memory store for the admin console.
class AdminController extends ChangeNotifier {
  AdminController._() {
    _seed();
  }

  static final AdminController instance = AdminController._();

  final List<AdminUser> _users = [];
  final List<AdminProduct> _products = [];
  final List<AdminCategory> _categories = [];
  final List<AdminSale> _sales = [];
  final List<AdminAuditLog> _auditLogs = [];

  String currentActor = 'Maria Santos';

  int _userSeq = 0;
  int _productSeq = 0;
  int _categorySeq = 0;
  int _logSeq = 0;

  // ==================== READ ====================

  List<AdminUser> get allUsers => List.unmodifiable(_users);
  List<AdminUser> get activeUsers =>
      _users.where((u) => !u.isArchived).toList();
  List<AdminUser> get archivedUsers =>
      _users.where((u) => u.isArchived).toList();

  List<AdminProduct> get allProducts => List.unmodifiable(_products);
  List<AdminProduct> get activeProducts =>
      _products.where((p) => !p.isArchived).toList();
  List<AdminProduct> get archivedProducts =>
      _products.where((p) => p.isArchived).toList();

  List<AdminCategory> get allCategories => List.unmodifiable(_categories);
  List<AdminCategory> get activeCategories =>
      _categories.where((c) => !c.isArchived).toList();
  List<AdminCategory> get archivedCategories =>
      _categories.where((c) => c.isArchived).toList();

  List<AdminSale> get allSales {
    final list = [..._sales];
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  List<AdminSale> get completedSales =>
      allSales.where((s) => s.isCompleted).toList();

  List<AdminAuditLog> get allAuditLogs {
    final list = [..._auditLogs];
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  AdminUser? userById(String id) =>
      _users.cast<AdminUser?>().firstWhere((u) => u?.id == id, orElse: () => null);

  AdminProduct? productById(String id) => _products
      .cast<AdminProduct?>()
      .firstWhere((p) => p?.id == id, orElse: () => null);

  AdminCategory? categoryById(String id) => _categories
      .cast<AdminCategory?>()
      .firstWhere((c) => c?.id == id, orElse: () => null);

  AdminSale? saleById(String id) =>
      _sales.cast<AdminSale?>().firstWhere((s) => s?.id == id, orElse: () => null);

  int getActiveProductCountForCategory(String categoryId) =>
      _products.where((p) => !p.isArchived && p.categoryId == categoryId).length;

  int getProductCountForCategory(String categoryId) =>
      _products.where((p) => p.categoryId == categoryId).length;

  bool isProductInSales(String productId) =>
      _sales.any((s) => s.items.any((i) => i.productId == productId));

  bool isUserInSales(String userId) =>
      _sales.any((s) => s.cashierId == userId);

  // ==================== ANALYTICS ====================

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

  /// Totals for each of the last [days] calendar days, oldest first,
  /// ending with today.
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

  /// Totals for each of the last [weeks] Monday-to-Sunday calendar weeks,
  /// oldest first, ending with the current (in-progress) week.
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

  /// Totals for each of the last [months] calendar months, oldest first,
  /// ending with the current (in-progress) month.
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

  // ==================== VALIDATION ====================

  static final RegExp _emailPattern =
  RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
  static final RegExp _phonePattern = RegExp(r'^[0-9+\-\s()]{7,15}$');

  String? _validateUserFields({
    required String firstName,
    required String surname,
    required String username,
    required String email,
    required String phone,
    String? password,
    String? confirmPassword,
    String? excludeId,
  }) {
    if (firstName.trim().isEmpty) return 'Enter the person\'s first name.';
    if (surname.trim().isEmpty) return 'Enter the person\'s surname.';
    if (username.trim().isEmpty) return 'Enter a username.';
    if (username.trim().length < 3) return 'Username needs at least 3 characters.';
    if (username.contains(' ')) return 'Username cannot contain spaces.';
    if (email.trim().isEmpty) return 'Enter an email address.';
    if (!_emailPattern.hasMatch(email.trim())) return 'That email address doesn\'t look right.';
    if (phone.trim().isEmpty) return 'Enter a mobile number.';
    if (!_phonePattern.hasMatch(phone.trim())) return 'Enter a valid mobile number (7–15 digits).';

    if (excludeId == null) {
      if (password == null || password.isEmpty) return 'Enter a password.';
      if (password.length < 6) return 'Password must be at least 6 characters.';
      if (password != confirmPassword) return 'Passwords do not match.';
    }

    final takenUsername = _users.any((u) =>
    u.id != excludeId &&
        u.username.toLowerCase() == username.trim().toLowerCase());
    if (takenUsername) return 'That username is already taken.';

    final takenEmail = _users.any((u) =>
    u.id != excludeId &&
        u.email.toLowerCase() == email.trim().toLowerCase());
    if (takenEmail) return 'That email is already registered.';

    return null;
  }

  String? _validateProductFields({
    required String name,
    required String categoryId,
    required double price,
    required double cost,
    required double quantity,
    required String unit,
    required String barcode,
    String? excludeId,
  }) {
    if (name.trim().isEmpty) return 'Enter a product name.';
    if (categoryId.isEmpty) return 'Pick a category for this product.';

    final category = categoryById(categoryId);
    if (category == null) return 'That category no longer exists.';
    if (category.isArchived) return 'That category is archived. Restore it first or pick another.';

    if (price < 0) return 'Selling price cannot be negative.';
    if (cost < 0) return 'Cost cannot be negative.';
    if (quantity < 0) return 'Stock cannot be negative.';
    if (!kProductUnits.contains(unit)) return 'Pick a valid unit.';
    if (price > 0 && cost > price) return 'Cost is higher than the selling price — you\'d lose money on every sale.';
    if (!kDecimalUnits.contains(unit) && quantity != quantity.roundToDouble()) return 'Stock must be a whole number when the unit is "$unit".';

    final duplicateName = _products.any((p) =>
    p.id != excludeId &&
        !p.isArchived &&
        p.name.trim().toLowerCase() == name.trim().toLowerCase());
    if (duplicateName) return 'A product with that name already exists.';

    if (barcode.trim().isNotEmpty) {
      final duplicateBarcode = _products.any(
              (p) => p.id != excludeId && p.barcode.trim() == barcode.trim());
      if (duplicateBarcode) return 'That barcode is already used by another product.';
    }

    return null;
  }

  String? _validateCategoryFields({
    required String name,
    String? excludeId,
  }) {
    if (name.trim().isEmpty) return 'Enter a category name.';
    if (name.trim().length < 2) return 'Category name needs at least 2 characters.';
    final duplicate = _categories.any((c) =>
    c.id != excludeId &&
        c.name.trim().toLowerCase() == name.trim().toLowerCase());
    if (duplicate) return 'A category with that name already exists.';
    return null;
  }

  // ==================== USERS: CRUD ====================

  String? createUser({
    required String firstName,
    String middleInitial = '',
    required String surname,
    required String username,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
    required AdminRole role,
    String status = 'Enabled',
  }) {
    final error = _validateUserFields(
      firstName: firstName,
      surname: surname,
      username: username,
      email: email,
      phone: phone,
      password: password,
      confirmPassword: confirmPassword,
    );
    if (error != null) return error;

    final user = AdminUser(
      id: _nextUserId(),
      firstName: firstName.trim(),
      middleInitial: middleInitial.trim(),
      surname: surname.trim(),
      username: username.trim(),
      email: email.trim(),
      phone: phone.trim(),
      password: password,
      role: role,
      status: status,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _users.add(user);
    _log(AuditAction.create, 'User', user.id, user.fullName, '—', status);
    notifyListeners();
    return null;
  }

  String? updateUser(
      String id, {
        required String firstName,
        String middleInitial = '',
        required String surname,
        required String username,
        required String email,
        required String phone,
        required AdminRole role,
        required String status,
      }) {
    final index = _users.indexWhere((u) => u.id == id);
    if (index == -1) return 'That account no longer exists.';

    final error = _validateUserFields(
      firstName: firstName,
      surname: surname,
      username: username,
      email: email,
      phone: phone,
      excludeId: id,
    );
    if (error != null) return error;

    final existing = _users[index];

    if (existing.role == AdminRole.owner && role != AdminRole.owner) {
      final remainingOwners = activeUsers
          .where((u) => u.role == AdminRole.owner && u.id != id)
          .length;
      if (remainingOwners == 0) return 'This is the only owner account. Promote someone else first.';
    }

    _users[index] = existing.copyWith(
      firstName: firstName.trim(),
      middleInitial: middleInitial.trim(),
      surname: surname.trim(),
      username: username.trim(),
      email: email.trim(),
      phone: phone.trim(),
      role: role,
      status: status,
      updatedAt: DateTime.now(),
    );

    _log(AuditAction.update, 'User', id, existing.fullName, existing.status, status);
    notifyListeners();
    return null;
  }

  String? archiveUser(String id) {
    final index = _users.indexWhere((u) => u.id == id);
    if (index == -1) return 'That account no longer exists.';
    final user = _users[index];
    if (user.isArchived) return 'That account is already archived.';

    if (user.role == AdminRole.owner) {
      final remainingOwners = activeUsers
          .where((u) => u.role == AdminRole.owner && u.id != id)
          .length;
      if (remainingOwners == 0) return 'You can\'t archive the only owner account.';
    }

    _users[index] = user.copyWith(
      isArchived: true,
      archivedAt: DateTime.now(),
      archivedBy: currentActor,
      updatedAt: DateTime.now(),
    );

    _log(AuditAction.archive, 'User', id, user.fullName, 'Active', 'Archived');
    notifyListeners();
    return null;
  }

  String? restoreUser(String id) {
    final index = _users.indexWhere((u) => u.id == id);
    if (index == -1) return 'That account no longer exists.';
    final user = _users[index];
    if (!user.isArchived) return 'That account is already active.';

    final usernameTaken = _users.any((u) =>
    u.id != id &&
        !u.isArchived &&
        u.username.toLowerCase() == user.username.toLowerCase());
    if (usernameTaken) return 'Someone else now uses the username "${user.username}". Rename one of them first.';

    _users[index] = user.copyWith(
      isArchived: false,
      clearArchiveMeta: true,
      updatedAt: DateTime.now(),
    );

    _log(AuditAction.restore, 'User', id, user.fullName, 'Archived', 'Active');
    notifyListeners();
    return null;
  }

  String? permanentlyDeleteUser(String id) {
    final user = userById(id);
    if (user == null) return 'That account no longer exists.';
    if (!user.isArchived) return 'Archive the account before deleting it.';
    if (isUserInSales(id)) return 'This account is attached to past sales, so it can\'t be deleted.';

    _users.removeWhere((u) => u.id == id);
    _log(AuditAction.permanentDelete, 'User', id, user.fullName, 'Archived', 'Deleted');
    notifyListeners();
    return null;
  }

  // ==================== PRODUCTS: CRUD ====================

  String? createProduct({
    required String name,
    required String categoryId,
    required String description,
    required double price,
    required double cost,
    required double quantity,
    required String unit,
    required String barcode,
    DateTime? expirationDate,
    double lowStockThreshold = kDefaultLowStockThreshold,
  }) {
    final error = _validateProductFields(name: name, categoryId: categoryId, price: price, cost: cost, quantity: quantity, unit: unit, barcode: barcode);
    if (error != null) return error;

    final category = categoryById(categoryId)!;
    final product = AdminProduct(
      id: _nextProductId(),
      name: name.trim(),
      categoryId: categoryId,
      categoryName: category.name,
      description: description.trim(),
      price: price,
      cost: cost,
      quantity: quantity,
      unit: unit,
      barcode: barcode.trim(),
      expirationDate: expirationDate,
      lowStockThreshold: lowStockThreshold,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _products.add(product);
    _log(AuditAction.create, 'Product', product.id, product.name, '—', 'Active');
    notifyListeners();
    return null;
  }

  String? updateProduct(
      String id, {
        required String name,
        required String categoryId,
        required String description,
        required double price,
        required double cost,
        required double quantity,
        required String unit,
        required String barcode,
        DateTime? expirationDate,
        bool clearExpiration = false,
        double? lowStockThreshold,
      }) {
    final index = _products.indexWhere((p) => p.id == id);
    if (index == -1) return 'That product no longer exists.';

    final error = _validateProductFields(name: name, categoryId: categoryId, price: price, cost: cost, quantity: quantity, unit: unit, barcode: barcode, excludeId: id);
    if (error != null) return error;

    final existing = _products[index];
    final category = categoryById(categoryId)!;

    _products[index] = existing.copyWith(
      name: name.trim(),
      categoryId: categoryId,
      categoryName: category.name,
      description: description.trim(),
      price: price,
      cost: cost,
      quantity: quantity,
      unit: unit,
      barcode: barcode.trim(),
      expirationDate: expirationDate,
      clearExpiration: clearExpiration,
      lowStockThreshold: lowStockThreshold,
      updatedAt: DateTime.now(),
    );

    _log(AuditAction.update, 'Product', id, name.trim(),
        formatQuantity(existing.quantity, existing.unit),
        formatQuantity(quantity, unit));
    notifyListeners();
    return null;
  }

  String? adjustStock(String id, double delta, {String reason = 'Manual adjustment'}) {
    final index = _products.indexWhere((p) => p.id == id);
    if (index == -1) return 'That product no longer exists.';
    final product = _products[index];
    final updated = product.quantity + delta;
    if (updated < 0) return 'Stock can\'t go below zero.';

    _products[index] =
        product.copyWith(quantity: updated, updatedAt: DateTime.now());
    _log(
      AuditAction.update,
      'Product',
      id,
      product.name,
      formatQuantity(product.quantity, product.unit),
      formatQuantity(updated, product.unit),
      note: reason,
    );
    notifyListeners();
    return null;
  }

  String? archiveProduct(String id) {
    final index = _products.indexWhere((p) => p.id == id);
    if (index == -1) return 'That product no longer exists.';
    final product = _products[index];
    if (product.isArchived) return 'That product is already archived.';

    _products[index] = product.copyWith(
      isArchived: true,
      archivedAt: DateTime.now(),
      archivedBy: currentActor,
      updatedAt: DateTime.now(),
    );

    _log(AuditAction.archive, 'Product', id, product.name, 'Active', 'Archived');
    notifyListeners();
    return null;
  }

  String? restoreProduct(String id) {
    final index = _products.indexWhere((p) => p.id == id);
    if (index == -1) return 'That product no longer exists.';
    final product = _products[index];
    if (!product.isArchived) return 'That product is already active.';

    final category = categoryById(product.categoryId);
    if (category == null || category.isArchived) return 'Its category "${product.categoryName}" is archived.';

    _products[index] = product.copyWith(
      isArchived: false,
      clearArchiveMeta: true,
      updatedAt: DateTime.now(),
    );

    _log(AuditAction.restore, 'Product', id, product.name, 'Archived', 'Active');
    notifyListeners();
    return null;
  }

  String? permanentlyDeleteProduct(String id) {
    final product = productById(id);
    if (product == null) return 'That product no longer exists.';
    if (!product.isArchived) return 'Archive the product before deleting it.';
    if (isProductInSales(id)) return 'This product appears on past receipts.';

    _products.removeWhere((p) => p.id == id);
    _log(AuditAction.permanentDelete, 'Product', id, product.name, 'Archived', 'Deleted');
    notifyListeners();
    return null;
  }

  // ==================== CATEGORIES: CRUD ====================

  String? createCategory({
    required String name,
    required String description,
  }) {
    final error = _validateCategoryFields(name: name);
    if (error != null) return error;

    final category = AdminCategory(
      id: _nextCategoryId(),
      name: name.trim(),
      description: description.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _categories.add(category);
    _log(AuditAction.create, 'Category', category.id, category.name, '—', 'Active');
    notifyListeners();
    return null;
  }

  String? updateCategory(
      String id, {
        required String name,
        required String description,
      }) {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index == -1) return 'That category no longer exists.';

    final error = _validateCategoryFields(name: name, excludeId: id);
    if (error != null) return error;

    final existing = _categories[index];
    _categories[index] = existing.copyWith(
      name: name.trim(),
      description: description.trim(),
      updatedAt: DateTime.now(),
    );

    for (var i = 0; i < _products.length; i++) {
      if (_products[i].categoryId == id) {
        _products[i] = _products[i].copyWith(categoryName: name.trim());
      }
    }

    _log(AuditAction.update, 'Category', id, name.trim(), existing.name, name.trim());
    notifyListeners();
    return null;
  }

  String? archiveCategory(String id) {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index == -1) return 'That category no longer exists.';
    final category = _categories[index];
    if (category.isArchived) return 'That category is already archived.';

    final linked = getActiveProductCountForCategory(id);
    if (linked > 0) return '$linked active products are still in "${category.name}".';

    _categories[index] = category.copyWith(
      isArchived: true,
      archivedAt: DateTime.now(),
      archivedBy: currentActor,
      updatedAt: DateTime.now(),
    );

    _log(AuditAction.archive, 'Category', id, category.name, 'Active', 'Archived');
    notifyListeners();
    return null;
  }

  String? restoreCategory(String id) {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index == -1) return 'That category no longer exists.';
    final category = _categories[index];
    if (!category.isArchived) return 'That category is already active.';

    _categories[index] = category.copyWith(
      isArchived: false,
      clearArchiveMeta: true,
      updatedAt: DateTime.now(),
    );

    _log(AuditAction.restore, 'Category', id, category.name, 'Archived', 'Active');
    notifyListeners();
    return null;
  }

  String? permanentlyDeleteCategory(String id) {
    final category = categoryById(id);
    if (category == null) return 'That category no longer exists.';
    if (!category.isArchived) return 'Archive the category before deleting it.';

    final linked = getProductCountForCategory(id);
    if (linked > 0) return '$linked products are still assigned to "${category.name}".';

    _categories.removeWhere((c) => c.id == id);
    _log(AuditAction.permanentDelete, 'Category', id, category.name, 'Archived', 'Deleted');
    notifyListeners();
    return null;
  }

  // ==================== SALES ====================

  String? recordSale({
    required String cashierId,
    required List<SaleItem> items,
    String customerName = 'Walk-in',
    double discount = 0,
    PaymentMethod paymentMethod = PaymentMethod.cash,
    required double amountPaid,
  }) {
    if (items.isEmpty) return 'Add at least one item to the sale.';
    final cashier = userById(cashierId);
    if (cashier == null) return 'That cashier account no longer exists.';

    for (final item in items) {
      final product = productById(item.productId);
      if (product == null) return '"${item.productName}" no longer exists.';
      if (product.isArchived) return '"${product.name}" is archived.';
      if (product.quantity < item.quantity) return 'Only ${formatQuantity(product.quantity, product.unit)} of "${product.name}" left.';
    }

    final sale = AdminSale(
      id: 'S${(++_saleSeq).toString().padLeft(4, '0')}',
      receiptNumber: _receiptNumber(_saleSeq),
      cashierId: cashierId,
      cashierName: cashier.fullName,
      customerName: customerName.trim().isEmpty ? 'Walk-in' : customerName.trim(),
      items: items,
      discount: discount,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
      timestamp: DateTime.now(),
    );

    if (amountPaid < sale.total) return 'Amount paid is less than the total of ${formatPeso(sale.total)}.';

    for (final item in items) {
      final index = _products.indexWhere((p) => p.id == item.productId);
      _products[index] = _products[index].copyWith(quantity: _products[index].quantity - item.quantity);
    }

    _sales.add(sale);
    _log(AuditAction.create, 'Sale', sale.id, sale.receiptNumber, '—', 'Completed');
    notifyListeners();
    return null;
  }

  String? voidSale(String id, String reason) {
    final index = _sales.indexWhere((s) => s.id == id);
    if (index == -1) return 'That receipt no longer exists.';
    final sale = _sales[index];
    if (!sale.isCompleted) return 'That receipt is already ${sale.status.label.toLowerCase()}.';
    if (reason.trim().isEmpty) return 'Enter a reason for voiding this sale.';

    for (final item in sale.items) {
      final pIndex = _products.indexWhere((p) => p.id == item.productId);
      if (pIndex != -1) {
        _products[pIndex] = _products[pIndex].copyWith(quantity: _products[pIndex].quantity + item.quantity);
      }
    }

    _sales[index] = sale.copyWith(
      status: SaleStatus.voided,
      voidReason: reason.trim(),
      voidedBy: currentActor,
      voidedAt: DateTime.now(),
    );

    _log(AuditAction.voidSale, 'Sale', id, sale.receiptNumber, 'Completed', 'Voided', note: reason.trim());
    notifyListeners();
    return null;
  }

  // ==================== INTERNALS ====================

  String _nextUserId() => 'U${(++_userSeq).toString().padLeft(3, '0')}';
  String _nextProductId() => 'P${(++_productSeq).toString().padLeft(3, '0')}';
  String _nextCategoryId() => 'C${(++_categorySeq).toString().padLeft(3, '0')}';
  String _receiptNumber(int seq) => 'OR-${DateTime.now().year}-${seq.toString().padLeft(4, '0')}';

  void _log(AuditAction action, String entityType, String entityId, String entityName, String previousStatus, String newStatus, {String? note, DateTime? at}) {
    _auditLogs.add(AdminAuditLog(
      id: 'L${(++_logSeq).toString().padLeft(4, '0')}',
      action: action,
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
      performedBy: currentActor,
      timestamp: at ?? DateTime.now(),
      previousStatus: previousStatus,
      newStatus: newStatus,
      note: note,
    ));
  }

  // ==================== SEED DATA ====================

  void _seed() {
    final now = DateTime.now();

    void addCategory(String name, String description, int daysAgo, {bool archived = false}) {
      _categories.add(AdminCategory(
        id: _nextCategoryId(),
        name: name,
        description: description,
        createdAt: now.subtract(Duration(days: daysAgo)),
        updatedAt: now.subtract(Duration(days: daysAgo)),
        isArchived: archived,
        archivedAt: archived ? now.subtract(const Duration(days: 9)) : null,
        archivedBy: archived ? 'Maria Santos' : null,
      ));
    }

    addCategory('Beverages', 'Soft drinks, juice, bottled water, coffee', 240);
    addCategory('Snacks', 'Chips, biscuits, candy, instant noodles', 238);
    addCategory('Canned goods', 'Sardines, corned beef, meat loaf', 236);
    addCategory('Rice & grains', 'Sold by weight from the sack', 230);
    addCategory('Household', 'Detergent, soap, dishwashing liquid', 220);
    addCategory('Frozen goods', 'Discontinued — no freezer since March', 200, archived: true);

    void addUser(String fName, String mi, String sName, String username, String email, String phone, AdminRole role, int daysAgo, {String status = 'Enabled', bool archived = false}) {
      _users.add(AdminUser(
        id: _nextUserId(),
        firstName: fName,
        middleInitial: mi,
        surname: sName,
        username: username,
        email: email,
        phone: phone,
        role: role,
        status: status,
        password: 'password123',
        createdAt: now.subtract(Duration(days: daysAgo)),
        updatedAt: now.subtract(Duration(days: daysAgo ~/ 2)),
        isArchived: archived,
        archivedAt: archived ? now.subtract(const Duration(days: 14)) : null,
        archivedBy: archived ? 'Maria Santos' : null,
      ));
    }

    addUser('Nico', '', 'Maglente', 'nico.m', 'nico@sarisarihub.ph', '0917 555 0100', AdminRole.admin, 365);
    addUser('Maria', '', 'Santos', 'maria.santos', 'maria@sarisarihub.ph', '0917 555 0101', AdminRole.owner, 240);
    addUser('Jun', '', 'Dela Cruz', 'jun.dc', 'jun@sarisarihub.ph', '0918 555 0142', AdminRole.employee, 180);
    addUser('Aileen', '', 'Reyes', 'aileen.r', 'aileen@sarisarihub.ph', '0927 555 0177', AdminRole.employee, 120);
    addUser('Noel', '', 'Bautista', 'noel.b', 'noel@sarisarihub.ph', '0916 555 0188', AdminRole.employee, 95, status: 'Disabled');
    addUser('Rosa', '', 'Lim', 'rosa.lim', 'rosa.lim@gmail.com', '0905 555 0211', AdminRole.customer, 88);
    addUser('Ernesto', '', 'Villa', 'ernie.v', 'ernesto.villa@gmail.com', '0939 555 0250', AdminRole.customer, 62);
    addUser('Grace', '', 'Ocampo', 'grace.o', 'grace.ocampo@yahoo.com', '0921 555 0299', AdminRole.customer, 40);
    addUser('Ricky', '', 'Tan', 'ricky.tan', 'ricky.tan@gmail.com', '0908 555 0303', AdminRole.customer, 30);
    addUser('Delia', '', 'Mercado', 'delia.m', 'delia.mercado@gmail.com', '0919 555 0344', AdminRole.customer, 150, archived: true);
    addUser('Boy', '', 'Fernandez', 'boy.f', 'boy.fernandez@gmail.com', '0947 555 0361', AdminRole.employee, 210, archived: true);

    void addProduct(String name, String categoryId, String description, double price, double cost, double quantity, String unit, String barcode, {int? expiresInDays, double threshold = kDefaultLowStockThreshold, bool archived = false}) {
      final category = categoryById(categoryId)!;
      _products.add(AdminProduct(
        id: _nextProductId(),
        name: name,
        categoryId: categoryId,
        categoryName: category.name,
        description: description,
        price: price,
        cost: cost,
        quantity: quantity,
        unit: unit,
        barcode: barcode,
        expirationDate: expiresInDays == null ? null : now.add(Duration(days: expiresInDays)),
        lowStockThreshold: threshold,
        createdAt: now.subtract(const Duration(days: 200)),
        updatedAt: now.subtract(const Duration(days: 3)),
        isArchived: archived,
        archivedAt: archived ? now.subtract(const Duration(days: 20)) : null,
        archivedBy: archived ? 'Maria Santos' : null,
      ));
    }

    addProduct('Coke Sakto 200ml', 'C001', 'Single-serve bottle', 15, 11.5, 48, 'bottle', '4801981234567', expiresInDays: 120, threshold: 12);
    addProduct('Nature\'s Spring Water 500ml', 'C001', 'Purified water', 14, 10, 30, 'bottle', '4801981234574', threshold: 12);
    addProduct('Kopiko Brown 3-in-1', 'C001', 'Coffee mix, per sachet', 9, 6.5, 120, 'sachet', '4800016641046', expiresInDays: 200, threshold: 24);
    addProduct('Pineapple juice 1L', 'C001', 'Tetra pack', 78, 62, 4, 'box', '4800047321004', expiresInDays: 45);
    addProduct('Lucky Me Pancit Canton', 'C002', 'Original flavour', 17, 13.5, 96, 'pack', '4800016644047', expiresInDays: 180, threshold: 24);
    addProduct('Piattos Cheese 40g', 'C002', 'Potato crisps', 22, 17, 36, 'pack', '4800016120022', expiresInDays: 90, threshold: 12);
    addProduct('Skyflakes crackers', 'C002', 'Single pack', 8, 5.75, 3, 'pack', '4800016320019', expiresInDays: 25);
    addProduct('Mentos roll', 'C002', 'Mint candy', 12, 8.5, 0, 'piece', '4800017730015');
    addProduct('555 Sardines 155g', 'C003', 'Tomato sauce', 27, 21.5, 40, 'can', '4806502100104', expiresInDays: 400, threshold: 10);
    addProduct('Argentina Corned Beef 150g', 'C003', 'Chunky', 48, 40, 18, 'can', '4800024570024', expiresInDays: 500, threshold: 8);
    addProduct('Sinandomeng rice', 'C004', 'Sold loose from the sack', 58, 48, 24.5, 'kg', '', threshold: 10);
    addProduct('Dinorado rice', 'C004', 'Premium, sold loose', 68, 57, 3.75, 'kg', '', threshold: 10);
    addProduct('Tide Bar 380g', 'C005', 'Laundry bar soap', 32, 25, 22, 'piece', '4902430735926', threshold: 8);
    addProduct('Joy Dishwashing 45ml', 'C005', 'Sachet', 10, 7, 60, 'sachet', '4902430602051', threshold: 20);
    addProduct('Safeguard soap 60g', 'C005', 'Classic white', 28, 22, 5, 'piece', '4902430448024');
    addProduct('Selecta ice cream 750ml', 'C006', 'Freezer discontinued', 145, 120, 0, 'box', '4800361410014', archived: true);
    addProduct('Hotdog 1kg pack', 'C006', 'Freezer discontinued', 210, 178, 0, 'pack', '4800361410021', archived: true);

    _seedSales(now);
    _seedHistoricalLogs(now);
  }

  void _seedSales(DateTime now) {
    var seed = 7;
    int next(int max) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed % max;
    }

    final cashiers = _users.where((u) => !u.isArchived && u.role != AdminRole.customer).toList();
    final sellable = _products.where((p) => !p.isArchived).toList();
    final customers = ['Walk-in', 'Rosa Lim', 'Ernesto Villa', 'Grace Ocampo', 'Ricky Tan', 'Walk-in'];

    for (var dayOffset = 13; dayOffset >= 0; dayOffset--) {
      final orders = 2 + next(4);
      for (var o = 0; o < orders; o++) {
        final day = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: dayOffset))
            .add(Duration(hours: 8 + next(11), minutes: next(60)));
        if (day.isAfter(now)) continue;

        final lineCount = 1 + next(4);
        final items = <SaleItem>[];
        final usedIds = <String>{};
        for (var l = 0; l < lineCount; l++) {
          final product = sellable[next(sellable.length)];
          if (!usedIds.add(product.id)) continue;
          final qty = kDecimalUnits.contains(product.unit) ? (0.5 + next(4) * 0.25) : (1 + next(3)).toDouble();
          items.add(SaleItem(productId: product.id, productName: product.name, unit: product.unit, unitPrice: product.price, unitCost: product.cost, quantity: qty));
        }
        if (items.isEmpty) continue;

        final cashier = cashiers[next(cashiers.length)];
        final subtotal = items.fold<double>(0, (sum, item) => sum + item.lineTotal);
        final discount = next(10) == 0 ? 5.0 : 0.0;
        final total = subtotal - discount;
        final paid = (total / 20).ceil() * 20.0;

        _sales.add(AdminSale(
          id: 'S${(++_saleSeq).toString().padLeft(4, '0')}',
          receiptNumber: 'OR-${day.year}-${_saleSeq.toString().padLeft(4, '0')}',
          cashierId: cashier.id,
          cashierName: cashier.fullName,
          customerName: customers[next(customers.length)],
          items: items,
          discount: discount,
          paymentMethod: PaymentMethod.values[next(4)],
          amountPaid: paid,
          timestamp: day,
        ));
      }
    }

    if (_sales.length > 4) {
      final target = _sales[3];
      _sales[3] = target.copyWith(
        status: SaleStatus.voided,
        voidReason: 'Wrong item scanned at the counter',
        voidedBy: 'Maria Santos',
        voidedAt: target.timestamp.add(const Duration(minutes: 6)),
      );
    }
  }

  void _seedHistoricalLogs(DateTime now) {
    _log(AuditAction.create, 'Category', 'C001', 'Beverages', '—', 'Active', at: now.subtract(const Duration(days: 240)));
    _log(AuditAction.create, 'User', 'U001', 'Maria Santos', '—', 'Active', at: now.subtract(const Duration(days: 240)));
    _log(AuditAction.create, 'Product', 'P001', 'Coke Sakto 200ml', '—', 'Active', at: now.subtract(const Duration(days: 200)));
    _log(AuditAction.update, 'Product', 'P011', 'Sinandomeng rice', '₱55.00', '₱58.00', at: now.subtract(const Duration(days: 30)), note: 'Supplier price increase');
    _log(AuditAction.archive, 'User', 'U010', 'Boy Fernandez', 'Active', 'Archived', at: now.subtract(const Duration(days: 14)), note: 'Resigned');
    _log(AuditAction.archive, 'Category', 'C006', 'Frozen goods', 'Active', 'Archived', at: now.subtract(const Duration(days: 9)), note: 'Freezer broke down');
    _log(AuditAction.archive, 'User', 'U009', 'Delia Mercado', 'Active', 'Archived', at: now.subtract(const Duration(days: 14)));
    _log(AuditAction.voidSale, 'Sale', 'S0004', 'Voided receipt', 'Completed', 'Voided', at: now.subtract(const Duration(days: 12)), note: 'Wrong item scanned at the counter');
  }
}

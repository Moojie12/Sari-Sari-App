import 'package:flutter/foundation.dart';

import '../models/admin_models.dart';

/// In-memory store for the admin console.
class AdminController extends ChangeNotifier {
  AdminController._();

  static final AdminController instance = AdminController._();

  final List<AdminUser> _users = [];
  final List<AdminProduct> _products = [];
  final List<AdminCategory> _categories = [];
  final List<AdminSale> _sales = [];
  final List<AdminAuditLog> _auditLogs = [];

  String currentActor = 'System Admin';

  int _userSeq = 0;
  int _productSeq = 0;
  int _categorySeq = 0;
  int _saleSeq = 0;
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
    required String fullName,
    required String username,
    required String email,
    required String phone,
    String? excludeId,
  }) {
    if (fullName.trim().isEmpty) return 'Enter the person\'s full name.';
    if (fullName.trim().length < 2) return 'Full name needs at least 2 characters.';
    if (username.trim().isEmpty) return 'Enter a username.';
    if (username.trim().length < 3) return 'Username needs at least 3 characters.';
    if (username.contains(' ')) return 'Username cannot contain spaces.';
    if (email.trim().isEmpty) return 'Enter an email address.';
    if (!_emailPattern.hasMatch(email.trim())) return 'That email address doesn\'t look right.';
    if (phone.trim().isEmpty) return 'Enter a mobile number.';
    if (!_phonePattern.hasMatch(phone.trim())) return 'Enter a valid mobile number (7–15 digits).';

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
    if (price > 0 && cost > price) return 'Cost is higher than the selling price.';
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

  // ==================== CRUD ====================

  String? createUser({
    required String fullName,
    required String username,
    required String email,
    required String phone,
    required AdminRole role,
    String status = 'Active',
    String verificationStatus = 'Unverified',
  }) {
    final error = _validateUserFields(fullName: fullName, username: username, email: email, phone: phone);
    if (error != null) return error;

    final user = AdminUser(
      id: _nextUserId(),
      fullName: fullName.trim(),
      username: username.trim(),
      email: email.trim(),
      phone: phone.trim(),
      role: role,
      status: status,
      verificationStatus: verificationStatus,
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
        required String fullName,
        required String username,
        required String email,
        required String phone,
        required AdminRole role,
        required String status,
        required String verificationStatus,
      }) {
    final index = _users.indexWhere((u) => u.id == id);
    if (index == -1) return 'That account no longer exists.';

    final error = _validateUserFields(fullName: fullName, username: username, email: email, phone: phone, excludeId: id);
    if (error != null) return error;

    final existing = _users[index];

    if (existing.role == AdminRole.owner && role != AdminRole.owner) {
      final remainingOwners = activeUsers
          .where((u) => u.role == AdminRole.owner && u.id != id)
          .length;
      if (remainingOwners == 0) return 'This is the only owner account.';
    }

    _users[index] = existing.copyWith(
      fullName: fullName.trim(),
      username: username.trim(),
      email: email.trim(),
      phone: phone.trim(),
      role: role,
      status: status,
      verificationStatus: verificationStatus,
      updatedAt: DateTime.now(),
    );

    _log(AuditAction.update, 'User', id, fullName.trim(), existing.status, status);
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
    if (usernameTaken) return 'Someone else now uses the username "${user.username}".';

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
    if (isUserInSales(id)) return 'This account is attached to past sales.';

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

    _log(AuditAction.update, 'Product', id, name.trim(), formatQuantity(existing.quantity, existing.unit), formatQuantity(quantity, unit));
    notifyListeners();
    return null;
  }

  String? adjustStock(String id, double delta, {String reason = 'Manual adjustment'}) {
    final index = _products.indexWhere((p) => p.id == id);
    if (index == -1) return 'That product no longer exists.';
    final product = _products[index];
    final updated = product.quantity + delta;
    if (updated < 0) return 'Stock can\'t go below zero.';

    _products[index] = product.copyWith(quantity: updated, updatedAt: DateTime.now());
    _log(AuditAction.update, 'Product', id, product.name, formatQuantity(product.quantity, product.unit), formatQuantity(updated, product.unit), note: reason);
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
    if (category == null || category.isArchived) return 'Its category is archived.';

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

  String _nextUserId() => 'U${(++_userSeq).toString().padLeft(3, '0')}';
  String _nextProductId() => 'P${(++_productSeq).toString().padLeft(3, '0')}';
  String _nextCategoryId() => 'C${(++_categorySeq).toString().padLeft(3, '0')}';
}

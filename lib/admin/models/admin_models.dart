import 'package:flutter/foundation.dart';

// ============================================================
// SHARED ENUMS
// ============================================================

enum AdminSection {
  overview,
  users,
  products,
  categories,
  sales,
  archived,
  activity,
  settings,
}

// ============================================================
// SHARED CONSTANTS
// ============================================================

const List<String> kProductUnits = [
  'piece',
  'pack',
  'bottle',
  'can',
  'box',
  'sachet',
  'kg',
  'gram',
  'liter',
];

const List<String> kDecimalUnits = ['kg', 'gram', 'liter'];

const double kDefaultLowStockThreshold = 5;

const List<String> _kMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// ============================================================
// FORMAT HELPERS
// ============================================================

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

String formatPesoCompact(double value) {
  if (value.abs() >= 1000000) {
    return '₱${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value.abs() >= 1000) {
    return '₱${(value / 1000).toStringAsFixed(1)}k';
  }
  return '₱${value.toStringAsFixed(0)}';
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

String formatTime(DateTime? dt) {
  if (dt == null) return '—';
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String formatShortDate(DateTime dt) => '${dt.day} ${_kMonths[dt.month - 1]}';

/// e.g. "Sep 2026"
String formatMonthYear(int year, int month) => '${_kMonths[month - 1]} $year';

/// e.g. "12–18 Sep" or, if the week crosses a month boundary, "28 Sep – 4 Oct"
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

// ============================================================
// MODELS
// ============================================================

enum AdminRole { admin, owner, employee, customer }

extension AdminRoleLabel on AdminRole {
  String get label {
    switch (this) {
      case AdminRole.admin: return 'Admin';
      case AdminRole.owner: return 'Owner';
      case AdminRole.employee: return 'Employee';
      case AdminRole.customer: return 'Customer';
    }
  }
}

@immutable
class AdminUser {
  const AdminUser({
    required this.id,
    required this.firstName,
    required this.middleInitial,
    required this.surname,
    required this.username,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    this.password,
    this.createdAt,
    this.updatedAt,
    this.isArchived = false,
    this.archivedAt,
    this.archivedBy,
  });

  final String id;
  final String firstName;
  final String middleInitial;
  final String surname;
  final String username;
  final String email;
  final String phone;
  final AdminRole role;
  final String status;
  final String? password;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isArchived;
  final DateTime? archivedAt;
  final String? archivedBy;

  String get fullName => '$firstName ${middleInitial.isNotEmpty ? '$middleInitial. ' : ''}$surname'.trim();

  bool get isActive => status == 'Enabled';

  String get initials {
    if (firstName.isEmpty || surname.isEmpty) return '?';
    return (firstName[0] + surname[0]).toUpperCase();
  }

  AdminUser copyWith({
    String? firstName,
    String? middleInitial,
    String? surname,
    String? username,
    String? email,
    String? phone,
    AdminRole? role,
    String? status,
    String? password,
    DateTime? updatedAt,
    bool? isArchived,
    DateTime? archivedAt,
    String? archivedBy,
    bool clearArchiveMeta = false,
  }) {
    return AdminUser(
      id: id,
      firstName: firstName ?? this.firstName,
      middleInitial: middleInitial ?? this.middleInitial,
      surname: surname ?? this.surname,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
      password: password ?? this.password,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: clearArchiveMeta ? null : (archivedAt ?? this.archivedAt),
      archivedBy: clearArchiveMeta ? null : (archivedBy ?? this.archivedBy),
    );
  }
}

@immutable
class AdminProduct {
  const AdminProduct({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    required this.price,
    required this.cost,
    required this.quantity,
    required this.unit,
    required this.barcode,
    required this.expirationDate,
    this.lowStockThreshold = kDefaultLowStockThreshold,
    this.image,
    this.createdAt,
    this.updatedAt,
    this.isArchived = false,
    this.archivedAt,
    this.archivedBy,
  });

  final String id;
  final String name;
  final String categoryId;
  final String categoryName;
  final String description;
  final double price;
  final double cost;
  final double quantity;
  final String unit;
  final String barcode;
  final DateTime? expirationDate;
  final double lowStockThreshold;
  final String? image;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isArchived;
  final DateTime? archivedAt;
  final String? archivedBy;

  bool get isOutOfStock => quantity <= 0;
  bool get isLowStock => quantity > 0 && quantity <= lowStockThreshold;
  bool get isExpired => expirationDate != null && expirationDate!.isBefore(DateTime.now());
  bool get isExpiringSoon => expirationDate != null && !isExpired && expirationDate!.difference(DateTime.now()).inDays <= 30;

  double get margin => price - cost;
  double get marginPercent => price == 0 ? 0 : (margin / price) * 100;
  double get stockValue => quantity * cost;

  AdminProduct copyWith({
    String? name,
    String? categoryId,
    String? categoryName,
    String? description,
    double? price,
    double? cost,
    double? quantity,
    String? unit,
    String? barcode,
    DateTime? expirationDate,
    double? lowStockThreshold,
    String? image,
    DateTime? updatedAt,
    bool? isArchived,
    DateTime? archivedAt,
    String? archivedBy,
    bool clearExpiration = false,
    bool clearArchiveMeta = false,
  }) {
    return AdminProduct(
      id: id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      description: description ?? this.description,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      barcode: barcode ?? this.barcode,
      expirationDate: clearExpiration ? null : (expirationDate ?? this.expirationDate),
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      image: image ?? this.image,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: clearArchiveMeta ? null : (archivedAt ?? this.archivedAt),
      archivedBy: clearArchiveMeta ? null : (archivedBy ?? this.archivedBy),
    );
  }
}

@immutable
class AdminCategory {
  const AdminCategory({
    required this.id,
    required this.name,
    required this.description,
    this.createdAt,
    this.updatedAt,
    this.isArchived = false,
    this.archivedAt,
    this.archivedBy,
  });

  final String id;
  final String name;
  final String description;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isArchived;
  final DateTime? archivedAt;
  final String? archivedBy;

  AdminCategory copyWith({
    String? name,
    String? description,
    DateTime? updatedAt,
    bool? isArchived,
    DateTime? archivedAt,
    String? archivedBy,
    bool clearArchiveMeta = false,
  }) {
    return AdminCategory(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: clearArchiveMeta ? null : (archivedAt ?? this.archivedAt),
      archivedBy: clearArchiveMeta ? null : (archivedBy ?? this.archivedBy),
    );
  }
}

enum PaymentMethod { cash, gcash, maya, card }

extension PaymentMethodLabel on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash: return 'Cash';
      case PaymentMethod.gcash: return 'GCash';
      case PaymentMethod.maya: return 'Maya';
      case PaymentMethod.card: return 'Card';
    }
  }
}

enum SaleStatus { completed, voided, refunded }

extension SaleStatusLabel on SaleStatus {
  String get label {
    switch (this) {
      case SaleStatus.completed: return 'Completed';
      case SaleStatus.voided: return 'Voided';
      case SaleStatus.refunded: return 'Refunded';
    }
  }
}

@immutable
class SaleItem {
  const SaleItem({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.unitPrice,
    required this.unitCost,
    required this.quantity,
  });

  final String productId;
  final String productName;
  final String unit;
  final double unitPrice;
  final double unitCost;
  final double quantity;

  double get lineTotal => unitPrice * quantity;
  double get lineProfit => (unitPrice - unitCost) * quantity;
}

@immutable
class AdminSale {
  const AdminSale({
    required this.id,
    required this.receiptNumber,
    required this.cashierId,
    required this.cashierName,
    required this.customerName,
    required this.items,
    required this.discount,
    required this.paymentMethod,
    required this.amountPaid,
    required this.timestamp,
    this.status = SaleStatus.completed,
    this.voidReason,
    this.voidedBy,
    this.voidedAt,
  });

  final String id;
  final String receiptNumber;
  final String cashierId;
  final String cashierName;
  final String customerName;
  final List<SaleItem> items;
  final double discount;
  final PaymentMethod paymentMethod;
  final double amountPaid;
  final DateTime timestamp;
  final SaleStatus status;
  final String? voidReason;
  final String? voidedBy;
  final DateTime? voidedAt;

  double get subtotal => items.fold<double>(0, (sum, item) => sum + item.lineTotal);
  double get total {
    final net = subtotal - discount;
    return net < 0 ? 0 : net;
  }
  double get change {
    final diff = amountPaid - total;
    return diff < 0 ? 0 : diff;
  }
  double get profit => items.fold<double>(0, (sum, item) => sum + item.lineProfit) - discount;
  int get lineCount => items.length;
  double get unitsSold => items.fold<double>(0, (sum, item) => sum + item.quantity);
  bool get isCompleted => status == SaleStatus.completed;

  AdminSale copyWith({
    SaleStatus? status,
    String? voidReason,
    String? voidedBy,
    DateTime? voidedAt,
  }) {
    return AdminSale(
      id: id,
      receiptNumber: receiptNumber,
      cashierId: cashierId,
      cashierName: cashierName,
      customerName: customerName,
      items: items,
      discount: discount,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
      timestamp: timestamp,
      status: status ?? this.status,
      voidReason: voidReason ?? this.voidReason,
      voidedBy: voidedBy ?? this.voidedBy,
      voidedAt: voidedAt ?? this.voidedAt,
    );
  }
}

String buildReceiptText(AdminSale sale, {String storeName = 'Sari-Sari Hub'}) {
  const width = 34;
  final buffer = StringBuffer();
  String center(String text) {
    if (text.length >= width) return text;
    final pad = ((width - text.length) / 2).floor();
    return ' ' * pad + text;
  }
  String spread(String left, String right) {
    final gap = width - left.length - right.length;
    return gap <= 0 ? '$left $right' : left + ' ' * gap + right;
  }
  buffer.writeln(center(storeName.toUpperCase()));
  buffer.writeln(center('Bacoor, Cavite'));
  buffer.writeln(center('Thank you for shopping!'));
  buffer.writeln('-' * width);
  buffer.writeln(spread('Receipt', sale.receiptNumber));
  buffer.writeln(spread('Date', formatDateTime(sale.timestamp)));
  buffer.writeln(spread('Cashier', sale.cashierName));
  buffer.writeln(spread('Customer', sale.customerName));
  buffer.writeln('-' * width);
  for (final item in sale.items) {
    buffer.writeln(item.productName);
    buffer.writeln(spread('  ${formatQuantity(item.quantity, item.unit)} x ${formatPeso(item.unitPrice)}', formatPeso(item.lineTotal)));
  }
  buffer.writeln('-' * width);
  buffer.writeln(spread('Subtotal', formatPeso(sale.subtotal)));
  if (sale.discount > 0) buffer.writeln(spread('Discount', '-${formatPeso(sale.discount)}'));
  buffer.writeln(spread('TOTAL', formatPeso(sale.total)));
  buffer.writeln(spread(sale.paymentMethod.label, formatPeso(sale.amountPaid)));
  buffer.writeln(spread('Change', formatPeso(sale.change)));
  buffer.writeln('-' * width);
  if (!sale.isCompleted) {
    buffer.writeln(center('*** ${sale.status.label.toUpperCase()} ***'));
    if (sale.voidReason != null) buffer.writeln(center(sale.voidReason!));
  }
  buffer.writeln(center('This is not an official receipt'));
  return buffer.toString();
}

@immutable
class ProductSalesStat {
  const ProductSalesStat({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.unitsSold,
    required this.revenue,
  });
  final String productId;
  final String productName;
  final String unit;
  final double unitsSold;
  final double revenue;
}

@immutable
class DaySales {
  const DaySales(this.day, this.total, this.orders);
  final DateTime day;
  final double total;
  final int orders;
}

/// Sales total for a Monday-to-Sunday calendar week.
@immutable
class WeekSales {
  const WeekSales(this.weekStart, this.weekEnd, this.total, this.orders);
  final DateTime weekStart;
  final DateTime weekEnd;
  final double total;
  final int orders;
}

/// Sales total for a calendar month.
@immutable
class MonthSales {
  const MonthSales(this.year, this.month, this.total, this.orders);
  final int year;
  final int month;
  final double total;
  final int orders;
}

enum AuditAction { create, update, archive, restore, permanentDelete, voidSale }

extension AuditActionLabel on AuditAction {
  String get label {
    switch (this) {
      case AuditAction.create: return 'Created';
      case AuditAction.update: return 'Updated';
      case AuditAction.archive: return 'Archived';
      case AuditAction.restore: return 'Restored';
      case AuditAction.permanentDelete: return 'Deleted';
      case AuditAction.voidSale: return 'Voided';
    }
  }
}

@immutable
class AdminAuditLog {
  const AdminAuditLog({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.performedBy,
    required this.timestamp,
    required this.previousStatus,
    required this.newStatus,
    this.note,
  });
  final String id;
  final AuditAction action;
  final String entityType;
  final String entityId;
  final String entityName;
  final String performedBy;
  final DateTime timestamp;
  final String previousStatus;
  final String newStatus;
  final String? note;
}

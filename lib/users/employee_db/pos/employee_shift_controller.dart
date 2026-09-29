import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'employee_pos_controller.dart' show EmployeePaymentMethod;

/// Cash Float & Shift Reconciliation.
///
/// Kept deliberately separate from [EmployeePosController]: the opening
/// drawer float and any manual cash movements during the day are NOT
/// sales, so they must never touch gross sales totals. This file owns
/// its own running totals and only reads sale amounts that the POS layer
/// hands it via [EmployeeShiftController.recordSale].

enum CashAdjustmentType { cashIn, cashOut }

extension CashAdjustmentTypeLabel on CashAdjustmentType {
  String get label => this == CashAdjustmentType.cashIn ? 'Cash In' : 'Cash Out';
}

/// A single non-sales cash movement during a shift (e.g. adding coins for
/// change, or pulling cash out for a supplier payment). Always carries a
/// mandatory reason so it shows up clearly on the audit trail.
@immutable
class CashAdjustment {
  const CashAdjustment({
    required this.id,
    required this.type,
    required this.amount,
    required this.reason,
    required this.timestamp,
  });

  final String id;
  final CashAdjustmentType type;
  final double amount;
  final String reason;
  final DateTime timestamp;

  /// Positive for Cash In, negative for Cash Out — sums directly into a
  /// shift's net adjustments.
  double get signedAmount => type == CashAdjustmentType.cashIn ? amount : -amount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'reason': reason,
    'timestamp': timestamp.toIso8601String(),
  };

  factory CashAdjustment.fromJson(Map<String, dynamic> json) {
    return CashAdjustment(
      id: json['id']?.toString() ?? '',
      type: json['type'] == 'cashOut' ? CashAdjustmentType.cashOut : CashAdjustmentType.cashIn,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// The currently open, in-progress shift/session.
class Shift {
  Shift({
    required this.id,
    required this.startingFloat,
    required this.openedAt,
    this.openedBy,
  });

  final String id;

  /// Starting Cash Float (panukli) — excluded from gross sales.
  final double startingFloat;
  final DateTime openedAt;
  final String? openedBy;

  double cashSalesTotal = 0.0;
  double nonCashSalesTotal = 0.0;
  int transactionCount = 0;
  final List<CashAdjustment> adjustments = [];

  double get netAdjustments => adjustments.fold(0.0, (sum, a) => sum + a.signedAmount);

  /// Starting Float + Cash Sales + Net Adjustments.
  double get expectedCash => startingFloat + cashSalesTotal + netAdjustments;

  Map<String, dynamic> toJson() => {
    'id': id,
    'startingFloat': startingFloat,
    'openedAt': openedAt.toIso8601String(),
    'openedBy': openedBy,
    'cashSalesTotal': cashSalesTotal,
    'nonCashSalesTotal': nonCashSalesTotal,
    'transactionCount': transactionCount,
    'adjustments': adjustments.map((a) => a.toJson()).toList(),
  };

  factory Shift.fromJson(Map<String, dynamic> json) {
    final shift = Shift(
      id: json['id']?.toString() ?? '',
      startingFloat: (json['startingFloat'] as num?)?.toDouble() ?? 0.0,
      openedAt: DateTime.tryParse(json['openedAt']?.toString() ?? '') ?? DateTime.now(),
      openedBy: json['openedBy']?.toString(),
    );
    shift.cashSalesTotal = (json['cashSalesTotal'] as num?)?.toDouble() ?? 0.0;
    shift.nonCashSalesTotal = (json['nonCashSalesTotal'] as num?)?.toDouble() ?? 0.0;
    shift.transactionCount = (json['transactionCount'] as num?)?.toInt() ?? 0;
    if (json['adjustments'] is List) {
      for (final adj in json['adjustments'] as List) {
        if (adj is Map<String, dynamic>) {
          shift.adjustments.add(CashAdjustment.fromJson(adj));
        }
      }
    }
    return shift;
  }
}

/// A saved, closed-out shift — kept for owner auditing of past
/// discrepancies and missing cash/sales.
@immutable
class ShiftReport {
  const ShiftReport({
    required this.id,
    required this.openedAt,
    required this.closedAt,
    required this.startingFloat,
    required this.cashSalesTotal,
    required this.nonCashSalesTotal,
    required this.transactionCount,
    required this.adjustments,
    required this.expectedCash,
    required this.actualCash,
    this.openedBy,
    this.closedBy,
  });

  final String id;
  final DateTime openedAt;
  final DateTime closedAt;
  final double startingFloat;
  final double cashSalesTotal;
  final double nonCashSalesTotal;
  final int transactionCount;
  final List<CashAdjustment> adjustments;

  /// Starting Float + Cash Sales + Net Adjustments, computed when the
  /// shift was closed.
  final double expectedCash;

  /// What the employee actually counted in the drawer.
  final double actualCash;
  final String? openedBy;
  final String? closedBy;

  double get netAdjustments => adjustments.fold(0.0, (sum, a) => sum + a.signedAmount);

  /// Actual Cash − Expected Cash. Positive = Over, negative = Short.
  double get discrepancy => actualCash - expectedCash;

  bool get isBalanced => discrepancy.abs() < 0.005;
  bool get isShort => discrepancy < -0.005;
  bool get isOver => discrepancy > 0.005;

  String get discrepancyLabel {
    if (isBalanced) return 'Balanced';
    return isShort ? 'Short' : 'Over';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'openedAt': openedAt.toIso8601String(),
    'closedAt': closedAt.toIso8601String(),
    'startingFloat': startingFloat,
    'cashSalesTotal': cashSalesTotal,
    'nonCashSalesTotal': nonCashSalesTotal,
    'transactionCount': transactionCount,
    'adjustments': adjustments.map((a) => a.toJson()).toList(),
    'expectedCash': expectedCash,
    'actualCash': actualCash,
    'openedBy': openedBy,
    'closedBy': closedBy,
  };

  factory ShiftReport.fromJson(Map<String, dynamic> json) {
    final adjList = <CashAdjustment>[];
    if (json['adjustments'] is List) {
      for (final adj in json['adjustments'] as List) {
        if (adj is Map<String, dynamic>) {
          adjList.add(CashAdjustment.fromJson(adj));
        }
      }
    }
    return ShiftReport(
      id: json['id']?.toString() ?? '',
      openedAt: DateTime.tryParse(json['openedAt']?.toString() ?? '') ?? DateTime.now(),
      closedAt: DateTime.tryParse(json['closedAt']?.toString() ?? '') ?? DateTime.now(),
      startingFloat: (json['startingFloat'] as num?)?.toDouble() ?? 0.0,
      cashSalesTotal: (json['cashSalesTotal'] as num?)?.toDouble() ?? 0.0,
      nonCashSalesTotal: (json['nonCashSalesTotal'] as num?)?.toDouble() ?? 0.0,
      transactionCount: (json['transactionCount'] as num?)?.toInt() ?? 0,
      adjustments: adjList,
      expectedCash: (json['expectedCash'] as num?)?.toDouble() ?? 0.0,
      actualCash: (json['actualCash'] as num?)?.toDouble() ?? 0.0,
      openedBy: json['openedBy']?.toString(),
      closedBy: json['closedBy']?.toString(),
    );
  }
}

/// Owns the Starting Change Tracker feature end-to-end: opening a shift
/// with a starting float, logging mid-shift cash-in/cash-out
/// adjustments, and closing a shift into a [ShiftReport] the owner can
/// review later.
class EmployeeShiftController extends ChangeNotifier {
  EmployeeShiftController._() {
    _loadFromPrefs();
  }

  static final EmployeeShiftController instance = EmployeeShiftController._();

  factory EmployeeShiftController() => instance;

  static const String _keyCurrentShift = 'pos_active_shift_v1';
  static const String _keyShiftHistory = 'pos_shift_history_v1';
  static const String _keyShiftCounter = 'pos_shift_counter_v1';

  Shift? _currentShift;
  final List<ShiftReport> _history = [];
  int _shiftCounter = 1;
  int _adjustmentCounter = 1;

  Shift? get currentShift => _currentShift;
  bool get isShiftOpen => _currentShift != null;

  /// Past shift reports, most recently closed first.
  List<ShiftReport> get history => List.unmodifiable(_history.reversed);

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _shiftCounter = prefs.getInt(_keyShiftCounter) ?? 1;

      // Load history
      final historyJson = prefs.getStringList(_keyShiftHistory);
      if (historyJson != null) {
        _history.clear();
        for (final str in historyJson) {
          try {
            final map = jsonDecode(str) as Map<String, dynamic>;
            _history.add(ShiftReport.fromJson(map));
          } catch (e) {
            debugPrint('Error parsing shift report from prefs: $e');
          }
        }
      }

      // Load active current shift
      final activeJson = prefs.getString(_keyCurrentShift);
      if (activeJson != null && activeJson.isNotEmpty) {
        final map = jsonDecode(activeJson) as Map<String, dynamic>;
        final loadedShift = Shift.fromJson(map);

        final now = DateTime.now();
        final openedAt = loadedShift.openedAt;

        // Check if shift belongs to TODAY (same calendar day)
        final isSameDay = openedAt.year == now.year &&
            openedAt.month == now.month &&
            openedAt.day == now.day;

        if (isSameDay) {
          _currentShift = loadedShift;
          debugPrint('Restored active shift #${loadedShift.id} opened at ${loadedShift.openedAt}');
        } else {
          // Unclosed shift from a previous day -> Daily Auto-Reset into History
          debugPrint('Shift #${loadedShift.id} was from a previous day. Auto-closing for new day.');
          final autoClosedReport = ShiftReport(
            id: loadedShift.id,
            openedAt: loadedShift.openedAt,
            closedAt: DateTime(openedAt.year, openedAt.month, openedAt.day, 23, 59, 59),
            startingFloat: loadedShift.startingFloat,
            cashSalesTotal: loadedShift.cashSalesTotal,
            nonCashSalesTotal: loadedShift.nonCashSalesTotal,
            transactionCount: loadedShift.transactionCount,
            adjustments: List.of(loadedShift.adjustments),
            expectedCash: loadedShift.expectedCash,
            actualCash: loadedShift.expectedCash,
            openedBy: loadedShift.openedBy,
            closedBy: 'System (Daily Auto-Reset)',
          );
          _history.add(autoClosedReport);
          _currentShift = null;
          await _saveHistoryToPrefs(prefs);
          await prefs.remove(_keyCurrentShift);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load shift state from prefs: $e');
    }
  }

  Future<void> _saveActiveShiftToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentShift != null) {
        await prefs.setString(_keyCurrentShift, jsonEncode(_currentShift!.toJson()));
      } else {
        await prefs.remove(_keyCurrentShift);
      }
      await prefs.setInt(_keyShiftCounter, _shiftCounter);
    } catch (e) {
      debugPrint('Failed to save active shift to prefs: $e');
    }
  }

  Future<void> _saveHistoryToPrefs(SharedPreferences? prefsInstance) async {
    try {
      final prefs = prefsInstance ?? await SharedPreferences.getInstance();
      final historyStrings = _history.map((r) => jsonEncode(r.toJson())).toList();
      await prefs.setStringList(_keyShiftHistory, historyStrings);
    } catch (e) {
      debugPrint('Failed to save shift history to prefs: $e');
    }
  }

  /// Opens a new shift with a Starting Cash Float. No-op if a shift is
  /// already open.
  void openShift({required double startingFloat, String? openedBy}) {
    if (_currentShift != null || startingFloat < 0) return;
    _currentShift = Shift(
      id: 'SH${_shiftCounter.toString().padLeft(4, '0')}',
      startingFloat: startingFloat,
      openedAt: DateTime.now(),
      openedBy: openedBy,
    );
    _shiftCounter++;
    notifyListeners();
    _saveActiveShiftToPrefs();
  }

  /// Called by the POS checkout flow after a sale completes, so the
  /// shift's running Total Cash Sales / non-cash sales stay in sync.
  /// Never adds to [Shift.startingFloat] or the reverse — sales and float
  /// are tracked completely separately.
  void recordSale({required EmployeePaymentMethod paymentMethod, required double amount}) {
    final shift = _currentShift;
    if (shift == null) return;
    if (paymentMethod == EmployeePaymentMethod.cash) {
      shift.cashSalesTotal += amount;
    } else {
      shift.nonCashSalesTotal += amount;
    }
    shift.transactionCount++;
    notifyListeners();
    _saveActiveShiftToPrefs();
  }

  /// Logs a mid-shift Cash In / Cash Out adjustment. [reason] is
  /// mandatory and required non-blank.
  bool addCashAdjustment({
    required CashAdjustmentType type,
    required double amount,
    required String reason,
  }) {
    final shift = _currentShift;
    final trimmedReason = reason.trim();
    if (shift == null || amount <= 0 || trimmedReason.isEmpty) return false;

    shift.adjustments.add(CashAdjustment(
      id: 'ADJ${_adjustmentCounter.toString().padLeft(4, '0')}',
      type: type,
      amount: amount,
      reason: trimmedReason,
      timestamp: DateTime.now(),
    ));
    _adjustmentCounter++;
    notifyListeners();
    _saveActiveShiftToPrefs();
    return true;
  }

  /// Ends the current shift: computes the discrepancy against
  /// [actualCash] and saves a [ShiftReport] for owner review. Returns
  /// null if no shift was open.
  ShiftReport? closeShift({required double actualCash, String? closedBy}) {
    final shift = _currentShift;
    if (shift == null) return null;

    final report = ShiftReport(
      id: shift.id,
      openedAt: shift.openedAt,
      closedAt: DateTime.now(),
      startingFloat: shift.startingFloat,
      cashSalesTotal: shift.cashSalesTotal,
      nonCashSalesTotal: shift.nonCashSalesTotal,
      transactionCount: shift.transactionCount,
      adjustments: List.of(shift.adjustments),
      expectedCash: shift.expectedCash,
      actualCash: actualCash,
      openedBy: shift.openedBy,
      closedBy: closedBy,
    );

    _history.add(report);
    _currentShift = null;
    notifyListeners();
    _saveHistoryToPrefs(null);
    _saveActiveShiftToPrefs();
    return report;
  }
}

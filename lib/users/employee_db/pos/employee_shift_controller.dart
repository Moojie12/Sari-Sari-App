import 'package:flutter/foundation.dart';

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
}

/// Owns the Starting Change Tracker feature end-to-end: opening a shift
/// with a starting float, logging mid-shift cash-in/cash-out
/// adjustments, and closing a shift into a [ShiftReport] the owner can
/// review later.
class EmployeeShiftController extends ChangeNotifier {
  EmployeeShiftController._();

  static final EmployeeShiftController instance = EmployeeShiftController._();

  factory EmployeeShiftController() => instance;

  Shift? _currentShift;
  final List<ShiftReport> _history = [];
  int _shiftCounter = 1;
  int _adjustmentCounter = 1;

  Shift? get currentShift => _currentShift;
  bool get isShiftOpen => _currentShift != null;

  /// Past shift reports, most recently closed first.
  List<ShiftReport> get history => List.unmodifiable(_history.reversed);

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
    return report;
  }
}
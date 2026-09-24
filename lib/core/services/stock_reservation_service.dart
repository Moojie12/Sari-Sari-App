import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/payment_status.dart';

class ReservedItem {
  final String productId;
  final String productName;
  final double quantity;

  const ReservedItem({
    required this.productId,
    required this.productName,
    required this.quantity,
  });
}

class StockReservation {
  final String reservationId;
  final String userId;
  final List<ReservedItem> items;
  final DateTime createdAt;
  final DateTime expiresAt;
  OrderPaymentStatus paymentStatus;
  Timer? expirationTimer;

  StockReservation({
    required this.reservationId,
    required this.userId,
    required this.items,
    required this.createdAt,
    required this.expiresAt,
    this.paymentStatus = OrderPaymentStatus.pending,
    this.expirationTimer,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  int get remainingSeconds => expiresAt.difference(DateTime.now()).inSeconds;
}

class StockReservationService extends ChangeNotifier {
  StockReservationService._();
  static final StockReservationService instance = StockReservationService._();
  factory StockReservationService() => instance;

  static const Duration defaultReservationDuration = Duration(minutes: 10);

  final Map<String, StockReservation> _reservations = {};

  List<StockReservation> get activeReservations =>
      _reservations.values.where((r) => !r.isExpired).toList();

  /// Total reserved quantity across active unexpired reservations for a product.
  double getReservedQuantity(String productId) {
    double total = 0.0;
    final now = DateTime.now();

    for (final reservation in _reservations.values) {
      if (reservation.paymentStatus == OrderPaymentStatus.pending &&
          now.isBefore(reservation.expiresAt)) {
        for (final item in reservation.items) {
          if (item.productId == productId) {
            total += item.quantity;
          }
        }
      }
    }
    return total;
  }

  /// Calculates available stock after accounting for active reservations.
  double getAvailableStock(String productId, double totalActiveStock) {
    final reserved = getReservedQuantity(productId);
    final available = totalActiveStock - reserved;
    return available < 0 ? 0 : available;
  }

  /// Reserve stock for a checkout session with a 10-minute fallback timer.
  StockReservation reserveStock({
    required String reservationId,
    required String userId,
    required List<ReservedItem> items,
    Duration duration = defaultReservationDuration,
    Function(String reservationId)? onExpired,
  }) {
    // Release any existing reservation under the same ID
    releaseReservation(reservationId);

    final now = DateTime.now();
    final expiresAt = now.add(duration);

    final reservation = StockReservation(
      reservationId: reservationId,
      userId: userId,
      items: items,
      createdAt: now,
      expiresAt: expiresAt,
      paymentStatus: OrderPaymentStatus.pending,
    );

    // Schedule 10-minute fallback auto-release
    reservation.expirationTimer = Timer(duration, () {
      _handleReservationExpired(reservationId, onExpired);
    });

    _reservations[reservationId] = reservation;
    notifyListeners();
    return reservation;
  }

  void _handleReservationExpired(
    String reservationId,
    Function(String reservationId)? onExpired,
  ) {
    final res = _reservations[reservationId];
    if (res != null && res.paymentStatus == OrderPaymentStatus.pending) {
      res.paymentStatus = OrderPaymentStatus.expired;
      res.expirationTimer?.cancel();
      debugPrint('Stock reservation $reservationId expired after 10 minutes. Releasing stock back to pool.');
      notifyListeners();
      if (onExpired != null) {
        onExpired(reservationId);
      }
    }
  }

  /// Confirms payment and finalizes the reservation into permanent deduction.
  bool confirmPaymentAndDeduct(String reservationId) {
    final res = _reservations[reservationId];
    if (res == null) return false;

    res.expirationTimer?.cancel();
    res.paymentStatus = OrderPaymentStatus.paid;
    _reservations.remove(reservationId);
    notifyListeners();
    debugPrint('Stock reservation $reservationId paid and confirmed.');
    return true;
  }

  /// Manually release reservation back to available stock.
  void releaseReservation(String reservationId) {
    final res = _reservations.remove(reservationId);
    if (res != null) {
      res.expirationTimer?.cancel();
      notifyListeners();
      debugPrint('Stock reservation $reservationId released manually.');
    }
  }

  /// Check reservation by ID.
  StockReservation? getReservation(String reservationId) => _reservations[reservationId];

  @visibleForTesting
  void clearReservationsForTesting() {
    for (final res in _reservations.values) {
      res.expirationTimer?.cancel();
    }
    _reservations.clear();
    notifyListeners();
  }
}

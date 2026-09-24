import 'package:flutter/foundation.dart';
import '../../models/payment_status.dart';
import 'stock_reservation_service.dart';
import 'supabase_service.dart';

/// Payment Webhook Handler Stub — acts as a placeholder for receiving
/// future PayMongo `payment.paid` or `payment.failed` webhooks.
class PaymentWebhookStub {
  PaymentWebhookStub._();
  static final PaymentWebhookStub instance = PaymentWebhookStub._();
  factory PaymentWebhookStub() => instance;

  final StockReservationService _reservationService = StockReservationService.instance;
  final SupabaseService _supabaseService = SupabaseService();

  /// Simulates receiving a `payment.paid` webhook from PayMongo or manual testing trigger.
  Future<bool> handlePaymentSuccess({
    required String orderId,
    required String paymentReference,
  }) async {
    debugPrint('[PaymentWebhook] Received payment.paid webhook for order $orderId (Ref: $paymentReference)');

    // 1. Confirm reservation & finalize stock deduction
    final reservationConfirmed = _reservationService.confirmPaymentAndDeduct(orderId);

    // 2. Update DB order payment status to PAID
    try {
      await _supabaseService.updateOrderStatusInDb(
        orderId,
        'confirmed',
        OrderPaymentStatus.paid.toDbValue(),
      );
    } catch (e) {
      debugPrint('[PaymentWebhook] Error updating DB payment status to PAID: $e');
    }

    return reservationConfirmed;
  }

  /// Simulates receiving a `payment.failed` webhook from PayMongo or payment cancellation.
  Future<bool> handlePaymentFailed({
    required String orderId,
    required String failureReason,
  }) async {
    debugPrint('[PaymentWebhook] Received payment.failed webhook for order $orderId: $failureReason');

    // 1. Release reserved stock back to active pool
    _reservationService.releaseReservation(orderId);

    // 2. Update DB order payment status to FAILED
    try {
      await _supabaseService.updateOrderStatusInDb(
        orderId,
        'cancelled',
        OrderPaymentStatus.failed.toDbValue(),
      );
    } catch (e) {
      debugPrint('[PaymentWebhook] Error updating DB payment status to FAILED: $e');
    }

    return true;
  }
}

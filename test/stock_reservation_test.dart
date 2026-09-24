import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/core/services/payment_webhook_stub.dart';
import 'package:sari_sari/core/services/stock_reservation_service.dart';
import 'package:sari_sari/models/payment_status.dart';

void main() {
  group('StockReservationService Tests', () {
    late StockReservationService reservationService;

    setUp(() {
      reservationService = StockReservationService.instance;
      reservationService.clearReservationsForTesting();
    });

    test('Reserving stock reduces available stock correctly', () {
      const productId = 'prod_001';
      const totalActiveStock = 10.0;

      expect(reservationService.getReservedQuantity(productId), 0.0);
      expect(reservationService.getAvailableStock(productId, totalActiveStock), 10.0);

      reservationService.reserveStock(
        reservationId: 'order_101',
        userId: 'user_1',
        items: const [
          ReservedItem(productId: productId, productName: 'Item A', quantity: 3.0),
        ],
      );

      expect(reservationService.getReservedQuantity(productId), 3.0);
      expect(reservationService.getAvailableStock(productId, totalActiveStock), 7.0);
    });

    test('Short timer auto-releases reserved stock upon expiration', () async {
      const productId = 'prod_002';
      const totalActiveStock = 5.0;

      bool expiredCalled = false;

      reservationService.reserveStock(
        reservationId: 'order_102',
        userId: 'user_1',
        items: const [
          ReservedItem(productId: productId, productName: 'Item B', quantity: 2.0),
        ],
        duration: const Duration(milliseconds: 100),
        onExpired: (id) {
          expiredCalled = true;
        },
      );

      expect(reservationService.getAvailableStock(productId, totalActiveStock), 3.0);

      await Future.delayed(const Duration(milliseconds: 200));

      expect(expiredCalled, isTrue);
      expect(reservationService.getAvailableStock(productId, totalActiveStock), 5.0);
    });

    test('PAID payment status confirms reservation and converts to deduction', () async {
      const productId = 'prod_003';
      const totalActiveStock = 8.0;

      reservationService.reserveStock(
        reservationId: 'order_103',
        userId: 'user_2',
        items: const [
          ReservedItem(productId: productId, productName: 'Item C', quantity: 4.0),
        ],
      );

      expect(reservationService.getReservedQuantity(productId), 4.0);

      final confirmed = await PaymentWebhookStub.instance.handlePaymentSuccess(
        orderId: 'order_103',
        paymentReference: 'pay_ref_123',
      );

      expect(confirmed, isTrue);
      expect(reservationService.getReservedQuantity(productId), 0.0);
      final res = reservationService.getReservation('order_103');
      expect(res, isNull);
    });

    test('FAILED payment status releases reservation back to active pool', () async {
      const productId = 'prod_004';
      const totalActiveStock = 6.0;

      reservationService.reserveStock(
        reservationId: 'order_104',
        userId: 'user_3',
        items: const [
          ReservedItem(productId: productId, productName: 'Item D', quantity: 2.0),
        ],
      );

      expect(reservationService.getAvailableStock(productId, totalActiveStock), 4.0);

      await PaymentWebhookStub.instance.handlePaymentFailed(
        orderId: 'order_104',
        failureReason: 'Insufficient funds',
      );

      expect(reservationService.getAvailableStock(productId, totalActiveStock), 6.0);
    });
  });
}

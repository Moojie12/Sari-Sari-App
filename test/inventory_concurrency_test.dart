import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/core/services/stock_reservation_service.dart';

void main() {
  group('Inventory Concurrency Tests', () {
    late StockReservationService reservationService;

    setUp(() {
      reservationService = StockReservationService.instance;
      reservationService.clearReservationsForTesting();
    });

    test('Simultaneous checkout attempts with stock = 1 result in exactly 1 success and 1 rejection', () async {
      const productId = 'limited_item_1';
      double activeStock = 1.0;

      Future<bool> attemptCheckout(String orderId, String userId) async {
        final available = reservationService.getAvailableStock(productId, activeStock);
        if (available < 1.0) {
          return false; // Out of stock
        }

        reservationService.reserveStock(
          reservationId: orderId,
          userId: userId,
          items: const [
            ReservedItem(productId: productId, productName: 'Limited Edition Item', quantity: 1.0),
          ],
        );
        return true;
      }

      // Simulate 2 customers clicking "Buy Now" simultaneously
      final results = await Future.wait([
        attemptCheckout('order_customer_a', 'user_a'),
        attemptCheckout('order_customer_b', 'user_b'),
      ]);

      final successes = results.where((r) => r == true).length;
      final rejections = results.where((r) => r == false).length;

      expect(successes, equals(1), reason: 'Exactly one customer should succeed');
      expect(rejections, equals(1), reason: 'Second customer should receive out of stock rejection');

      expect(reservationService.getReservedQuantity(productId), equals(1.0));
      expect(reservationService.getAvailableStock(productId, activeStock), equals(0.0));
    });
  });
}

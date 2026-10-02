import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_controller.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
import 'package:sari_sari/users/employee_db/orders/employee_orders_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Order Account Isolation Tests', () {
    late EmployeeOrderController sharedController;
    late CustomerOrderController customerController;

    setUp(() {
      sharedController = EmployeeOrderController.instance;
      customerController = CustomerOrderController.instance;
      sharedController.clearOrdersForTesting();
    });

    CustomerOrder createOrderForUser({
      required String orderId,
      required String userId,
      required String customerName,
    }) {
      return CustomerOrder(
        orderId: orderId,
        customerName: customerName,
        orderDate: DateTime.now(),
        items: const [
          CustomerOrderItem(
            productId: 'prod-001',
            productName: 'Instant Noodles',
            price: 15.0,
            capital: 10.0,
            quantity: 2,
            subtotal: 30.0,
          ),
        ],
        orderType: OrderType.pickup,
        paymentMethod: PaymentMethod.cashOnDelivery,
        paymentStatus: PaymentStatus.unpaid,
        subtotal: 30.0,
        deliveryFee: 0.0,
        totalAmount: 30.0,
        status: OrderStatus.pending,
        userId: userId,
      );
    }

    test('Orders are distinct per user ID and do not leak to other accounts', () {
      final userAOrder = createOrderForUser(
        orderId: 'ORD-USER-A-001',
        userId: 'user_uid_aaa',
        customerName: 'User A',
      );

      final userBOrder = createOrderForUser(
        orderId: 'ORD-USER-B-001',
        userId: 'user_uid_bbb',
        customerName: 'User B',
      );

      customerController.placeOrder(userAOrder);
      customerController.placeOrder(userBOrder);

      // Verify sharedController (store view) has both orders
      expect(sharedController.orders.length, 2);

      // Filter by User A
      final userAOrders = sharedController.orders.where((o) => o.userId == 'user_uid_aaa').toList();
      expect(userAOrders.length, 1);
      expect(userAOrders.first.orderId, 'ORD-USER-A-001');

      // Filter by User B
      final userBOrders = sharedController.orders.where((o) => o.userId == 'user_uid_bbb').toList();
      expect(userBOrders.length, 1);
      expect(userBOrders.first.orderId, 'ORD-USER-B-001');

      // Filter by Brand New User (no orders)
      final newAccountOrders = sharedController.orders.where((o) => o.userId == 'new_user_uid_ccc').toList();
      expect(newAccountOrders, isEmpty);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/users/customer_db/customer_cart_controller.dart';
import 'package:sari_sari/users/customer_db/home/customer_home_page.dart';
import 'package:sari_sari/users/customer_db/home/customer_product_card.dart';
import 'package:sari_sari/users/customer_db/home/customer_product_details_page.dart';
import 'package:sari_sari/users/customer_db/home/customer_product_model.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_controller.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
import 'package:sari_sari/users/employee_db/employee_inventory_controller.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_batch_model.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_product_model.dart';
import 'package:sari_sari/users/employee_db/orders/employee_orders_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final prodCoke = EmployeeProduct(
    id: 'PROD-COKE',
    name: 'Coca-Cola 1.5L',
    barcode: '100001',
    category: 'Beverages',
    price: 65.0,
    capital: 50.0,
    batches: [
      ProductBatch(
        id: 'B-COKE',
        quantity: 50.0,
        expiryDate: DateTime.now().add(const Duration(days: 90)),
      ),
    ],
  );

  final prodPiattos = EmployeeProduct(
    id: 'PROD-PIATTOS',
    name: 'Piattos Cheese 40g',
    barcode: '100002',
    category: 'Snacks',
    price: 22.0,
    capital: 17.0,
    batches: [
      ProductBatch(
        id: 'B-PIATTOS',
        quantity: 40.0,
        expiryDate: DateTime.now().add(const Duration(days: 90)),
      ),
    ],
  );

  final prodSardines = EmployeeProduct(
    id: 'PROD-SARDINES',
    name: '555 Sardines 155g',
    barcode: '100003',
    category: 'Canned Goods',
    price: 27.0,
    capital: 21.0,
    batches: [
      ProductBatch(
        id: 'B-SARDINES',
        quantity: 30.0,
        expiryDate: DateTime.now().add(const Duration(days: 90)),
      ),
    ],
  );

  setUp(() {
    EmployeeInventoryController.instance.setProductsForTesting([
      prodCoke,
      prodPiattos,
      prodSardines,
    ]);
    EmployeeOrderController.instance.clearOrdersForTesting();
  });

  group('Best Seller Analytics & Order Stats Tests', () {
    test('EmployeeOrderController computes units sold per product correctly', () {
      final ordersController = EmployeeOrderController.instance;

      ordersController.addOrderForTesting(
        CustomerOrder(
          orderId: 'ORD-001',
          customerName: 'Customer A',
          orderDate: DateTime.now(),
          items: const [
            CustomerOrderItem(
              productId: 'PROD-PIATTOS',
              productName: 'Piattos Cheese 40g',
              price: 22.0,
              capital: 17.0,
              quantity: 12,
              subtotal: 264.0,
            ),
            CustomerOrderItem(
              productId: 'PROD-COKE',
              productName: 'Coca-Cola 1.5L',
              price: 65.0,
              capital: 50.0,
              quantity: 3,
              subtotal: 195.0,
            ),
          ],
          orderType: OrderType.pickup,
          paymentMethod: PaymentMethod.cashOnDelivery,
          paymentStatus: PaymentStatus.paid,
          subtotal: 459.0,
          deliveryFee: 0.0,
          totalAmount: 459.0,
          status: OrderStatus.completed,
        ),
      );

      final unitsSold = ordersController.getProductUnitsSold();
      expect(unitsSold['PROD-PIATTOS'], 12);
      expect(unitsSold['PROD-COKE'], 3);
      expect(unitsSold['PROD-SARDINES'], isNull);

      final piattosSold = ordersController.getUnitsSoldForProduct(
        productId: 'PROD-PIATTOS',
        productName: 'Piattos Cheese 40g',
      );
      expect(piattosSold, 12);
    });
  });

  group('Customer Home Best Seller Sorting & Fire Icon Tests', () {
    testWidgets('Best selling product appears at the top of customer product list with fire icon', (tester) async {
      final ordersController = EmployeeOrderController.instance;

      // Add a completed order making Piattos the top seller (15 units) and Coke 2nd (4 units)
      ordersController.addOrderForTesting(
        CustomerOrder(
          orderId: 'ORD-TOP-1',
          customerName: 'Customer Best',
          orderDate: DateTime.now(),
          items: const [
            CustomerOrderItem(
              productId: 'PROD-PIATTOS',
              productName: 'Piattos Cheese 40g',
              price: 22.0,
              capital: 17.0,
              quantity: 15,
              subtotal: 330.0,
            ),
            CustomerOrderItem(
              productId: 'PROD-COKE',
              productName: 'Coca-Cola 1.5L',
              price: 65.0,
              capital: 50.0,
              quantity: 4,
              subtotal: 260.0,
            ),
          ],
          orderType: OrderType.pickup,
          paymentMethod: PaymentMethod.cashOnDelivery,
          paymentStatus: PaymentStatus.paid,
          subtotal: 590.0,
          deliveryFee: 0.0,
          totalAmount: 590.0,
          status: OrderStatus.completed,
        ),
      );

      final cart = CustomerCartController();
      final orderController = CustomerOrderController.instance;

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerHomePage(
            cartController: cart,
            orderController: orderController,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Locate all CustomerProductCard instances rendered in the grid
      final cardFinder = find.byType(CustomerProductCard);
      expect(cardFinder, findsWidgets);

      // The FIRST card at the top must be the best seller (Piattos)
      final firstCard = tester.widget<CustomerProductCard>(cardFinder.first);
      expect(firstCard.product.name, 'Piattos Cheese 40g');
      expect(firstCard.product.isBestSeller, isTrue);

      // The fire icon should be rendered for the best seller
      expect(find.byIcon(Icons.local_fire_department_rounded), findsWidgets);
      expect(find.text('Best Seller'), findsWidgets);
    });

    testWidgets('CustomerProductDetailsPage displays Best Seller badge with fire icon', (tester) async {
      const bestProduct = CustomerProduct(
        id: 'PROD-PIATTOS',
        name: 'Piattos Cheese 40g',
        category: 'Snacks',
        price: 22.0,
        capital: 17.0,
        sellableQuantity: 40.0,
        image: '',
        availability: CustomerProductAvailability.inStock,
        isBestSeller: true,
        totalSold: 25,
      );

      final cart = CustomerCartController();
      final orderController = CustomerOrderController.instance;

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerProductDetailsPage(
            product: bestProduct,
            cartController: cart,
            orderController: orderController,
          ),
        ),
      );

      await tester.pump();

      // Should display Best Seller with fire icon
      expect(find.text('Best Seller'), findsWidgets);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsWidgets);
    });
  });
}

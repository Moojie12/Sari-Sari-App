import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/models/sale_deal_model.dart';
import 'package:sari_sari/core/services/sale_deal_controller.dart';
import 'package:sari_sari/users/customer_db/customer_cart_controller.dart';
import 'package:sari_sari/users/customer_db/home/customer_product_model.dart';
import 'package:sari_sari/users/customer_db/home/customer_home_page.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_controller.dart';
import 'package:sari_sari/users/employee_db/employee_inventory_controller.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_batch_model.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_product_model.dart';
import 'package:sari_sari/users/owner_db/promotions/owner_sale_management_page.dart';
import 'package:sari_sari/users/owner_db/promotions/owner_edit_sale_deal_page.dart';
import 'package:sari_sari/users/owner_db/profile/owner_profile_page.dart';
import 'package:sari_sari/shared/widgets/product_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final inventory = EmployeeInventoryController.instance;
    final dealController = SaleDealController.instance;

    inventory.setProductsForTesting([
      EmployeeProduct(
        id: 'PROD-PIATTOS',
        name: 'Piattos Cheese 40g',
        barcode: '111111',
        category: 'Snacks',
        price: 22.0,
        capital: 17.0,
        batches: [
          ProductBatch(
            id: 'B1',
            quantity: 15.0,
            expiryDate: DateTime.now().add(const Duration(days: 3)), // Near expiry!
          ),
        ],
      ),
      EmployeeProduct(
        id: 'PROD-SARDINES',
        name: '555 Sardines 155g',
        barcode: '222222',
        category: 'Canned Goods',
        price: 27.0,
        capital: 21.0,
        batches: [
          ProductBatch(
            id: 'B2',
            quantity: 20.0,
            expiryDate: DateTime.now().add(const Duration(days: 120)),
          ),
        ],
      ),
      EmployeeProduct(
        id: 'PROD-EXPIRED-MILK',
        name: 'Bear Brand Milk',
        barcode: '333333',
        category: 'Beverages',
        price: 15.0,
        capital: 11.0,
        batches: [
          ProductBatch(
            id: 'B3',
            quantity: 5.0,
            expiryDate: DateTime.now().subtract(const Duration(days: 2)), // Expired!
          ),
        ],
      ),
    ]);

    dealController.setDealsForTesting([
      SaleDealModel(
        id: 'DEAL-COMBO-1',
        title: 'Merienda Combo: 1 Piattos + 2 Sardines',
        description: 'Great snack combo discount',
        salePrice: 55.0,
        items: const [
          SaleDealItem(
            productId: 'PROD-PIATTOS',
            productName: 'Piattos Cheese 40g',
            quantity: 1,
            originalPrice: 22.0,
          ),
          SaleDealItem(
            productId: 'PROD-SARDINES',
            productName: '555 Sardines 155g',
            quantity: 2,
            originalPrice: 27.0,
          ),
        ],
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ]);
  });

  group('Sale Deal Model & Pricing Tests', () {
    test('Calculates original total, savings, and discount percentage correctly', () {
      final deal = SaleDealModel(
        id: 'D1',
        title: 'Snack Combo',
        salePrice: 50.0,
        items: const [
          SaleDealItem(
            productId: 'P1',
            productName: 'Piattos',
            quantity: 1,
            originalPrice: 20.0,
          ),
          SaleDealItem(
            productId: 'P2',
            productName: 'Sardines',
            quantity: 2,
            originalPrice: 30.0,
          ),
        ],
        createdAt: DateTime(2026, 9, 30),
      );

      // Original: (1 * 20) + (2 * 30) = 80.0
      expect(deal.originalTotalPrice, 80.0);
      // Savings: 80 - 50 = 30.0
      expect(deal.discountSavings, 30.0);
      // Discount percentage: (30 / 80) * 100 = 37.5% -> round to 38%
      expect(deal.discountPercentage, 38);
      // Total items: 1 + 2 = 3
      expect(deal.totalItemQuantity, 3);
    });

    test('Serializes to and from Map accurately', () {
      final now = DateTime.now();
      final deal = SaleDealModel(
        id: 'TEST-DEAL-JSON',
        title: 'Breakfast Deal',
        description: 'Special Morning Promo',
        salePrice: 42.0,
        items: const [
          SaleDealItem(
            productId: 'P1',
            productName: 'Coffee',
            quantity: 2,
            originalPrice: 15.0,
          ),
        ],
        isActive: true,
        createdAt: now,
      );

      final map = deal.toMap();
      final revived = SaleDealModel.fromMap(map);

      expect(revived.id, deal.id);
      expect(revived.title, deal.title);
      expect(revived.salePrice, 42.0);
      expect(revived.items.length, 1);
      expect(revived.items.first.quantity, 2);
      expect(revived.isActive, true);
    });
  });

  group('Sale Deal Controller Tests', () {
    test('Saves, toggles status, and deletes deals', () async {
      final controller = SaleDealController.instance;

      final newDeal = SaleDealModel(
        id: 'DEAL-NEW-01',
        title: 'Single Item Clearance',
        salePrice: 15.0,
        items: const [
          SaleDealItem(
            productId: 'PROD-PIATTOS',
            productName: 'Piattos Cheese 40g',
            quantity: 1,
            originalPrice: 22.0,
          ),
        ],
        isActive: true,
        createdAt: DateTime.now(),
      );

      await controller.saveDeal(newDeal);
      expect(controller.deals.any((d) => d.id == 'DEAL-NEW-01'), isTrue);

      // Toggle inactive
      await controller.toggleDealStatus('DEAL-NEW-01', false);
      expect(controller.deals.firstWhere((d) => d.id == 'DEAL-NEW-01').isActive, isFalse);
      expect(controller.activeDeals.any((d) => d.id == 'DEAL-NEW-01'), isFalse);

      // Delete
      await controller.deleteDeal('DEAL-NEW-01');
      expect(controller.deals.any((d) => d.id == 'DEAL-NEW-01'), isFalse);
    });
  });

  group('Customer Cart Deal Integration Tests', () {
    test('Adding a sale deal adds items with proportional discounted price', () {
      final cart = CustomerCartController();
      final deal = SaleDealController.instance.deals.first;

      final products = <CustomerProduct>[
        const CustomerProduct(
          id: 'PROD-PIATTOS',
          name: 'Piattos Cheese 40g',
          category: 'Snacks',
          price: 22.0,
          capital: 17.0,
          sellableQuantity: 10.0,
          image: '',
          availability: CustomerProductAvailability.inStock,
        ),
        const CustomerProduct(
          id: 'PROD-SARDINES',
          name: '555 Sardines 155g',
          category: 'Canned Goods',
          price: 27.0,
          capital: 21.0,
          sellableQuantity: 10.0,
          image: '',
          availability: CustomerProductAvailability.inStock,
        ),
      ];

      final success = cart.addSaleDeal(deal, products);
      expect(success, isTrue);
      expect(cart.items.length, 2);

      // Sum of subtotals in cart matches deal salePrice (55.0 approx within rounding)
      expect(cart.totalAmount, closeTo(55.0, 0.1));
      expect(cart.items.first.isOnSalePromo, isTrue);
    });
  });

  group('Owner Profile & Sale Management UI Tests', () {
    testWidgets('OwnerProfilePage contains Customize On-Sale Deals button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OwnerProfilePage(),
        ),
      );
      await tester.pump();

      final menuFinder = find.text('Customize On-Sale Deals');
      await tester.scrollUntilVisible(menuFinder, 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      expect(menuFinder, findsOneWidget);
    });

    testWidgets('OwnerSaleManagementPage lists active deals with Edit and Delete options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OwnerSaleManagementPage(),
        ),
      );
      await tester.pump();

      expect(find.text('Customize On-Sale Deals'), findsOneWidget);
      expect(find.text('Merienda Combo: 1 Piattos + 2 Sardines'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsWidgets);
    });

    testWidgets('OwnerEditSaleDealPage prioritizes Expired and Near-Expiry products', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OwnerEditSaleDealPage(),
        ),
      );
      await tester.pump();

      expect(find.text('Create On-Sale Deal'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('EXPIRED STOCK'), 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('EXPIRED STOCK'), findsOneWidget);
      expect(find.text('NEAR EXPIRY'), findsOneWidget);
    });

    testWidgets('OwnerEditSaleDealPage performs live validation with 50-char max and numbers only price', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OwnerEditSaleDealPage(),
        ),
      );
      await tester.pump();

      final titleField = find.widgetWithText(TextFormField, 'Sale Deal Name *');
      final priceField = find.widgetWithText(TextFormField, 'Sale / Promo Price *');

      // Type title with 60 chars - verify limited to 50
      final longText = 'A' * 60;
      await tester.enterText(titleField, longText);
      await tester.pump();

      final titleWidget = tester.widget<TextFormField>(titleField);
      expect(titleWidget.controller!.text.length, 50);
      expect(find.text('50/50'), findsOneWidget);

      // Clear title and type valid name "Chloe Temple"
      await tester.enterText(titleField, 'Chloe Temple');
      await tester.pump();
      expect(find.text('Please enter a name for this sale'), findsNothing);

      // Type valid price "400"
      await tester.enterText(priceField, '400');
      await tester.pump();
      expect(find.text('Please enter a sale price'), findsNothing);
      expect(find.text('Numbers only allowed'), findsNothing);
    });

    testWidgets('OwnerEditSaleDealPage shows preview and confirmation dialog before publishing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OwnerEditSaleDealPage(),
        ),
      );
      await tester.pump();

      // Enter valid title and price
      final titleField = find.widgetWithText(TextFormField, 'Sale Deal Name *');
      final priceField = find.widgetWithText(TextFormField, 'Sale / Promo Price *');
      await tester.enterText(titleField, 'Piattos Super Sale');
      await tester.enterText(priceField, '18');
      await tester.pump();

      // Select product
      final productTile = find.text('Piattos Cheese 40g');
      await tester.scrollUntilVisible(productTile, 200, scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
      await tester.pumpAndSettle();
      await tester.tap(productTile);
      await tester.pumpAndSettle();

      // Tap Publish Sale Deal button
      final publishBtn = find.text('Publish Sale Deal');
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      // Verify preview dialog is visible
      expect(find.text('Preview & Confirm Deal'), findsOneWidget);
      expect(find.text('Piattos Super Sale'), findsWidgets);
      expect(find.text('Included Products'), findsOneWidget);
      expect(find.text('1x'), findsWidgets);
      expect(find.text('Promo Sale Price:'), findsOneWidget);
      expect(find.text('₱18.00'), findsWidgets);
      expect(find.text('Back to Edit'), findsOneWidget);
      expect(find.text('Confirm & Publish'), findsOneWidget);

      // Tap 'Back to Edit' first to ensure it cancels without saving
      await tester.tap(find.text('Back to Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Preview & Confirm Deal'), findsNothing);

      // Tap Publish again and tap Confirm & Publish
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();
      expect(find.text('Preview & Confirm Deal'), findsOneWidget);

      await tester.tap(find.text('Confirm & Publish'));
      await tester.pumpAndSettle();

      // Verify deal was saved to controller
      expect(SaleDealController.instance.deals.any((d) => d.title == 'Piattos Super Sale'), isTrue);
    });

    testWidgets('OwnerEditSaleDealPage renders photo picker section and opens photo options bottom sheet', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OwnerEditSaleDealPage(),
        ),
      );
      await tester.pump();

      // Check photo picker placeholder
      expect(find.text('Add Promotional Photo (Optional)'), findsOneWidget);
      expect(find.text('Max 5MB • Crop & Preview available'), findsOneWidget);

      // Tap photo picker
      await tester.tap(find.text('Add Promotional Photo (Optional)'));
      await tester.pumpAndSettle();

      // Bottom sheet options
      expect(find.text('Promotional Deal Photo'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
    });

    testWidgets('OwnerEditSaleDealPage with existing image displays image and preview confirmation with image', (tester) async {
      final existingDeal = SaleDealModel(
        id: 'DEAL-IMG-1',
        title: 'Promo with Photo',
        image: 'assets/images/placeholder.png',
        salePrice: 25.0,
        items: const [
          SaleDealItem(
            productId: 'PROD-PIATTOS',
            productName: 'Piattos Cheese 40g',
            quantity: 1,
            originalPrice: 22.0,
          ),
        ],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OwnerEditSaleDealPage(initialDeal: existingDeal),
        ),
      );
      await tester.pump();

      // Image change/remove controls should be visible
      expect(find.text('Change'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsWidgets);

      // Tap Save Changes to open preview dialog
      final saveBtn = find.text('Save Changes');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Preview Changes'), findsOneWidget);
      expect(find.byType(ProductImage), findsWidgets);
    });
  });

  group('Customer Home On-Sale Deals Display Tests', () {
    testWidgets('CustomerHomePage displays On-Sale Deals & Promos section with deal card', (tester) async {
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
      // Wait for mock loading
      await tester.pump(const Duration(milliseconds: 1100));

      expect(find.text('On Sale Deals & Promos'), findsOneWidget);
      expect(find.text('HOT DEALS'), findsOneWidget);
      expect(find.text('Merienda Combo: 1 Piattos + 2 Sardines'), findsOneWidget);
    });
  });
}

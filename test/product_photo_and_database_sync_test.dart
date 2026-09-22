import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sari_sari/core/services/supabase_service.dart';
import 'package:sari_sari/users/customer_db/profile/customer_address_controller.dart';
import 'package:sari_sari/users/customer_db/profile/customer_address_model.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_product_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      publishableKey: 'mock-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
      ),
    );
  });

  group('Product Photo 5MB Validation & Storage Strategy Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sari_sari_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Rejects file exceeding 5MB limit', () async {
      final largeFile = File('${tempDir.path}/large_image.jpg');
      // Create a dummy file of size 5MB + 1024 bytes (5,243,904 bytes)
      const overLimitSize = (5 * 1024 * 1024) + 1024;
      final sink = largeFile.openWrite();
      sink.add(Uint8List(overLimitSize));
      await sink.close();

      expect(await largeFile.length(), greaterThan(5 * 1024 * 1024));

      final service = SupabaseService();
      // Should throw or fail gracefully returning null due to size validation
      final result = await service.uploadProductImage('test_prod_1', largeFile);
      expect(result, isNull);
    });

    test('Processes file within 5MB limit and produces valid fallback Base64 data URI', () async {
      final validFile = File('${tempDir.path}/valid_product.jpg');
      // 100 KB test payload
      const validSize = 100 * 1024;
      final bytes = Uint8List(validSize);
      for (int i = 0; i < bytes.length; i++) {
        bytes[i] = i % 256;
      }
      await validFile.writeAsBytes(bytes);

      expect(await validFile.length(), lessThanOrEqualTo(5 * 1024 * 1024));

      final service = SupabaseService();
      final result = await service.uploadProductImage('test_prod_2', validFile);

      // In mock environment without live Supabase storage credentials,
      // it must gracefully produce the fallback Base64 Data URI
      expect(result, isNotNull);
      expect(result!.startsWith('data:image/') || result.startsWith('http'), isTrue);

      if (result.startsWith('data:image/')) {
        expect(result.contains(';base64,'), isTrue);
        final base64Part = result.split(';base64,')[1];
        final decodedBytes = base64Decode(base64Part);
        expect(decodedBytes.length, equals(validSize));
      }
    });

    test('EmployeeProduct model preserves uploaded image URL/data URI', () {
      const mockImageUrl = 'https://supabase.co/storage/v1/object/public/products/items/coke.jpg';
      final product = EmployeeProduct(
        id: 'p_101',
        name: 'Coca Cola 1.5L',
        category: 'Beverages',
        price: 75.0,
        capital: 60.0,
        barcode: '4800016644',
        unit: 'bottle',
        image: mockImageUrl,
        batches: const [],
      );

      expect(product.image, equals(mockImageUrl));
    });
  });

  group('Database Processes & Audit Connections', () {
    test('Walk-in orders are properly filtered from online pickup/delivery orders', () {
      final now = DateTime.now();
      final walkInOrder = CustomerOrder(
        orderId: 'RC-00001',
        customerName: 'Walk-in',
        orderDate: now,
        items: const [],
        orderType: OrderType.pickup,
        paymentMethod: PaymentMethod.cashOnDelivery,
        paymentStatus: PaymentStatus.paid,
        subtotal: 150.0,
        deliveryFee: 0,
        totalAmount: 150.0,
        status: OrderStatus.completed,
      );

      final pickupOrder = CustomerOrder(
        orderId: 'SS-0001',
        customerName: 'Maria Santos',
        orderDate: now,
        items: const [],
        orderType: OrderType.pickup,
        paymentMethod: PaymentMethod.gCash,
        paymentStatus: PaymentStatus.paid,
        subtotal: 300.0,
        deliveryFee: 0,
        totalAmount: 300.0,
        status: OrderStatus.completed,
      );

      final deliveryOrder = CustomerOrder(
        orderId: 'SS-0002',
        customerName: 'Pedro Cruz',
        orderDate: now,
        items: const [],
        orderType: OrderType.delivery,
        paymentMethod: PaymentMethod.cashOnDelivery,
        paymentStatus: PaymentStatus.unpaid,
        subtotal: 500.0,
        deliveryFee: 40.0,
        totalAmount: 540.0,
        status: OrderStatus.pending,
      );

      final allOrders = [walkInOrder, pickupOrder, deliveryOrder];

      // Test walk-in filter used by Owner History Walk-in tab
      final walkIns = allOrders
          .where((o) => o.customerName == 'Walk-in' && o.status == OrderStatus.completed)
          .toList();
      expect(walkIns.length, equals(1));
      expect(walkIns.first.orderId, equals('RC-00001'));

      // Test customer pickup filter (excluding Walk-in)
      final customerPickups = allOrders
          .where((o) => o.orderType == OrderType.pickup && o.customerName != 'Walk-in' && o.status == OrderStatus.completed)
          .toList();
      expect(customerPickups.length, equals(1));
      expect(customerPickups.first.customerName, equals('Maria Santos'));
    });

    test('CustomerAddressController validates and serializes correctly', () {
      final controller = CustomerAddressController.instance;

      // Validation: empty address must be rejected
      final invalidAddress = const CustomerAddress(
        id: 'bad_1',
        type: '',
        address: '   ',
      );
      final added = controller.addAddress(invalidAddress);
      expect(added, isFalse);

      // Validation: valid address must be accepted
      final validAddress = const CustomerAddress(
        id: 'addr_99',
        type: 'Condo',
        address: 'Tower 2, Unit 504, Pasig City',
        isDefault: true,
      );
      final validAdded = controller.addAddress(validAddress);
      expect(validAdded, isTrue);

      final json = validAddress.toJson();
      expect(json['id'], equals('addr_99'));
      expect(json['type'], equals('Condo'));
      expect(json['isDefault'], isTrue);

      final deserialized = CustomerAddress.fromJson(json);
      expect(deserialized.id, equals('addr_99'));
      expect(deserialized.address, equals('Tower 2, Unit 504, Pasig City'));
      expect(deserialized.isDefault, isTrue);
    });
  });
}

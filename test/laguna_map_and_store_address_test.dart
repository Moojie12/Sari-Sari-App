import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sari_sari/core/constants/laguna_bounds.dart';
import 'package:sari_sari/core/services/delivery_tracking_service.dart';
import 'package:sari_sari/users/customer_db/profile/customer_address_model.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
import 'package:sari_sari/users/owner_db/profile/shop_settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 1 & 6: Laguna Province Boundary & Validation Tests', () {
    test('Identifies valid coordinates within Laguna Province', () {
      // Santa Rosa, Laguna
      expect(LagunaBounds.contains(const LatLng(14.3122, 121.1114)), isTrue);
      // Biñan, Laguna
      expect(LagunaBounds.contains(const LatLng(14.3414, 121.0803)), isTrue);
      // Calamba, Laguna
      expect(LagunaBounds.contains(const LatLng(14.2117, 121.1656)), isTrue);
      // San Pablo, Laguna
      expect(LagunaBounds.contains(const LatLng(14.0683, 121.3256)), isTrue);
      // Santa Maria, Laguna (Northern boundary)
      expect(LagunaBounds.contains(const LatLng(14.4703, 121.4258)), isTrue);
      // Cavinti, Laguna (Eastern boundary)
      expect(LagunaBounds.contains(const LatLng(14.2492, 121.5075)), isTrue);
    });

    test('Strictly rejects coordinates outside Laguna Province', () {
      // Manila (Outside Laguna)
      expect(LagunaBounds.contains(const LatLng(14.5995, 120.9842)), isFalse);
      // Quezon City (Outside Laguna)
      expect(LagunaBounds.contains(const LatLng(14.6760, 121.0437)), isFalse);
      // Cebu (Outside Laguna)
      expect(LagunaBounds.contains(const LatLng(10.3157, 123.8854)), isFalse);
      // Batangas City (Outside Laguna)
      expect(LagunaBounds.contains(const LatLng(13.7565, 121.0583)), isFalse);
    });

    test('Clamps coordinates to stay within Laguna boundaries', () {
      final outPoint = const LatLng(15.0, 122.0); // Outside
      final clamped = LagunaBounds.clamp(outPoint);
      expect(LagunaBounds.contains(clamped), isTrue);
      expect(clamped.latitude, LagunaBounds.maxLat);
      expect(clamped.longitude, LagunaBounds.maxLng);
    });

    test('Retrieves correct postal codes for Laguna cities and municipalities', () {
      expect(LagunaBounds.getPostalCode('Santa Rosa'), '4026');
      expect(LagunaBounds.getPostalCode('City of Santa Rosa'), '4026');
      expect(LagunaBounds.getPostalCode('Biñan'), '4024');
      expect(LagunaBounds.getPostalCode('City of Biñan'), '4024');
      expect(LagunaBounds.getPostalCode('Calamba'), '4027');
      expect(LagunaBounds.getPostalCode('San Pedro'), '4023');
      expect(LagunaBounds.getPostalCode('San Pablo'), '4000');
      expect(LagunaBounds.getPostalCode('Unknown Place'), isNull);
    });
  });

  group('Feature 1 & 5: Customer Delivery Address Model & Coordinates', () {
    test('CustomerAddress saves and deserializes latitude, longitude, and postal code', () {
      const address = CustomerAddress(
        id: 'addr-001',
        type: 'Home',
        address: 'Doctor Zavalla Street, Malusak, Santa Rosa, Laguna, 4026, Philippines',
        region: 'Region IV-A (CALABARZON)',
        province: 'Laguna',
        city: 'Santa Rosa',
        cityCode: '043428000',
        barangay: 'Malusak',
        streetDetails: 'Doctor Zavalla Street',
        postalCode: '4026',
        latitude: 14.3122,
        longitude: 121.1114,
        isDefault: true,
      );

      final json = address.toJson();
      expect(json['id'], 'addr-001');
      expect(json['type'], 'Home');
      expect(json['latitude'], 14.3122);
      expect(json['longitude'], 121.1114);
      expect(json['postalCode'], '4026');
      expect(json['region'], 'Region IV-A (CALABARZON)');
      expect(json['province'], 'Laguna');

      final restored = CustomerAddress.fromJson(json);
      expect(restored.latitude, 14.3122);
      expect(restored.longitude, 121.1114);
      expect(restored.postalCode, '4026');
      expect(restored.region, 'Region IV-A (CALABARZON)');
      expect(restored.city, 'Santa Rosa');
    });

    test('CustomerAddress copyWith preserves and updates coordinates and details', () {
      const address = CustomerAddress(
        id: 'addr-002',
        type: 'Home',
        address: 'Old Address',
        latitude: 14.3100,
        longitude: 121.1100,
      );

      final updated = address.copyWith(
        address: 'New Street, Tagapo, Santa Rosa, Laguna',
        latitude: 14.3150,
        longitude: 121.1150,
        postalCode: '4026',
      );

      expect(updated.id, 'addr-002');
      expect(updated.address, 'New Street, Tagapo, Santa Rosa, Laguna');
      expect(updated.latitude, 14.3150);
      expect(updated.longitude, 121.1150);
      expect(updated.postalCode, '4026');
    });
  });

  group('Feature 2: Owner Store Address & Location in Database', () {
    test('ShopSettingsController provides default store address and Laguna coordinates', () {
      final settings = ShopSettingsController.instance;
      expect(settings.storeAddress, isNotEmpty);
      expect(settings.storeLocation.latitude, closeTo(14.3122, 0.5));
      expect(settings.storeLocation.longitude, closeTo(121.1114, 0.5));
      expect(LagunaBounds.contains(settings.storeLocation), isTrue);
    });

    test('ShopSettingsController updates store location and validates Laguna boundary', () async {
      final settings = ShopSettingsController.instance;

      // Update to valid location in Biñan, Laguna
      await settings.updateStoreAddress(
        address: 'National Highway, San Antonio, City of Biñan, Laguna, 4024',
        latitude: 14.3414,
        longitude: 121.0803,
        city: 'City of Biñan',
        barangay: 'San Antonio',
        street: 'National Highway',
        postalCode: '4024',
      );

      expect(settings.storeAddress, contains('Biñan'));
      expect(settings.storeLatitude, 14.3414);
      expect(settings.storeLongitude, 121.0803);
      expect(settings.storeCity, 'City of Biñan');
      expect(settings.storePostalCode, '4024');

      // Attempt update with coordinate outside Laguna should throw ArgumentError
      expect(
        settings.updateStoreAddress(
          address: 'Rizal Avenue, Manila',
          latitude: 14.5995,
          longitude: 120.9842, // Manila
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('DeliveryTrackingService dynamically references ShopSettingsController store location', () {
      final storeLoc = DeliveryTrackingService.storeLocation;
      expect(storeLoc, equals(ShopSettingsController.instance.storeLocation));
      expect(LagunaBounds.contains(storeLoc), isTrue);
    });
  });

  group('Feature 3, 4 & 5: Pickup vs Delivery Destination and Store Map', () {
    test('CustomerOrder differentiates Delivery confirmed location vs Store pickup location', () {
      // 1. Delivery order with confirmed customer pin coordinates
      final deliveryOrder = CustomerOrder(
        orderId: 'ORD-DEL-001',
        customerName: 'Juan Dela Cruz',
        orderDate: DateTime.now(),
        items: const [],
        orderType: OrderType.delivery,
        paymentMethod: PaymentMethod.cashOnDelivery,
        paymentStatus: PaymentStatus.unpaid,
        deliveryAddress: 'Block 1 Lot 2, Santa Rosa, Laguna',
        deliveryLatitude: 14.3180,
        deliveryLongitude: 121.1150,
        subtotal: 100.0,
        deliveryFee: 15.0,
        totalAmount: 115.0,
        status: OrderStatus.outForDelivery,
      );

      expect(deliveryOrder.orderType, OrderType.delivery);
      expect(deliveryOrder.deliveryLatitude, 14.3180);
      expect(deliveryOrder.deliveryLongitude, 121.1150);
      expect(deliveryOrder.deliveryAddress, contains('Santa Rosa'));

      // 2. Pickup order uses the store address and store coordinates
      final storeLoc = ShopSettingsController.instance.storeLocation;
      final storeAddr = ShopSettingsController.instance.storeAddress;

      final pickupOrder = CustomerOrder(
        orderId: 'ORD-PICKUP-001',
        customerName: 'Maria Santos',
        orderDate: DateTime.now(),
        items: const [],
        orderType: OrderType.pickup,
        paymentMethod: PaymentMethod.gCash,
        paymentStatus: PaymentStatus.paid,
        deliveryAddress: storeAddr,
        deliveryLatitude: storeLoc.latitude,
        deliveryLongitude: storeLoc.longitude,
        subtotal: 100.0,
        deliveryFee: 0.0,
        totalAmount: 100.0,
        status: OrderStatus.readyForPickup,
      );

      expect(pickupOrder.orderType, OrderType.pickup);
      expect(pickupOrder.status, OrderStatus.readyForPickup);
      expect(pickupOrder.deliveryLatitude, storeLoc.latitude);
      expect(pickupOrder.deliveryLongitude, storeLoc.longitude);
      expect(pickupOrder.deliveryAddress, storeAddr);
    });

    test('Pickup order status readiness verification', () {
      final pickupOrderPending = CustomerOrder(
        orderId: 'ORD-P-PENDING',
        customerName: 'Test Customer',
        orderDate: DateTime.now(),
        items: const [],
        orderType: OrderType.pickup,
        paymentMethod: PaymentMethod.cashOnDelivery,
        paymentStatus: PaymentStatus.unpaid,
        subtotal: 50.0,
        deliveryFee: 0.0,
        totalAmount: 50.0,
        status: OrderStatus.pending,
      );

      // Pending order should NOT show ready-for-pickup store map
      expect(pickupOrderPending.status == OrderStatus.readyForPickup, isFalse);

      final pickupOrderReady = pickupOrderPending.copyWith(
        status: OrderStatus.readyForPickup,
      );

      // Ready for Pickup order displays store pickup map
      expect(pickupOrderReady.status == OrderStatus.readyForPickup, isTrue);
      expect(pickupOrderReady.orderType == OrderType.pickup, isTrue);
    });
  });
}

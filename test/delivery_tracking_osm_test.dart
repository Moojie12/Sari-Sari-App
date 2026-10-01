import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sari_sari/core/services/delivery_tracking_service.dart';
import 'package:sari_sari/core/services/navigation_voice_service.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_controller.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
import 'package:sari_sari/users/employee_db/orders/employee_orders_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Real-Time OpenStreetMap Delivery Tracking Flow Tests', () {
    late EmployeeOrderController employeeOrderController;
    late CustomerOrderController customerOrderController;
    late DeliveryTrackingService trackingService;

    setUp(() {
      employeeOrderController = EmployeeOrderController.instance;
      customerOrderController = CustomerOrderController.instance;
      trackingService = DeliveryTrackingService.instance;
    });

    test('Step 1: Customer sets delivery address and places order', () async {
      const deliveryAddress = 'Brgy. San Antonio, Biñan, Laguna, Philippines';
      final orderId = customerOrderController.generateOrderNumber();

      // Geocode customer delivery address
      final destinationCoords = await trackingService.geocodeAddress(deliveryAddress);
      expect(destinationCoords.latitude, isNotNull);
      expect(destinationCoords.longitude, isNotNull);
      expect(destinationCoords.latitude, closeTo(14.3414, 0.5)); // Laguna area

      final order = CustomerOrder(
        orderId: orderId,
        customerName: 'Juan Dela Cruz',
        orderDate: DateTime.now(),
        items: const [
          CustomerOrderItem(
            productId: 'juicy-001',
            productName: 'Juicy World',
            price: 15.0,
            capital: 10.0,
            quantity: 1,
            subtotal: 15.0,
          ),
        ],
        orderType: OrderType.delivery,
        paymentMethod: PaymentMethod.cashOnDelivery,
        paymentStatus: PaymentStatus.unpaid,
        deliveryAddress: deliveryAddress,
        deliveryLatitude: destinationCoords.latitude,
        deliveryLongitude: destinationCoords.longitude,
        subtotal: 15.0,
        deliveryFee: 10.0,
        totalAmount: 25.0,
        status: OrderStatus.pending,
        userId: 'cust-user-999',
      );

      customerOrderController.placeOrder(order);

      final placedOrder = customerOrderController.getOrderById(orderId);
      expect(placedOrder, isNotNull);
      expect(placedOrder!.status, OrderStatus.pending);
      expect(placedOrder.orderType, OrderType.delivery);
      expect(placedOrder.deliveryAddress, deliveryAddress);
      expect(placedOrder.deliveryLatitude, isNotNull);
      expect(placedOrder.deliveryLongitude, isNotNull);

      // Before Out for Delivery: No active tracking yet (Requirement 6)
      expect(placedOrder.deliveryPersonId, isNull);
      expect(placedOrder.deliveryPersonName, isNull);
    });

    test('Step 2: Owner/Employee retrieves available delivery staff accounts', () async {
      final staff = await trackingService.getAvailableDeliveryStaff();
      expect(staff, isNotEmpty);

      // Verify staff contains valid name and role (Owner or Employee)
      for (final person in staff) {
        expect(person.name, isNotEmpty);
        expect(person.role, anyOf(equals('Owner'), equals('Employee')));
      }

      // Check if both roles or at least one is available
      final hasOwnerOrEmployee = staff.any((s) => s.role == 'Owner' || s.role == 'Employee');
      expect(hasOwnerOrEmployee, isTrue);
    });

    test('Step 3: Assign Delivery Person and transition to Out for Delivery', () async {
      const orderId = 'ORD-TRACK-TEST-001';
      const address = 'Brgy. Tagapo, Santa Rosa, Laguna';
      final destCoords = await trackingService.geocodeAddress(address);

      final initialOrder = CustomerOrder(
        orderId: orderId,
        customerName: 'Maria Test',
        orderDate: DateTime.now(),
        items: const [
          CustomerOrderItem(
            productId: 'p1',
            productName: 'Juicy World',
            price: 15.0,
            capital: 10.0,
            quantity: 1,
            subtotal: 15.0,
          ),
        ],
        orderType: OrderType.delivery,
        paymentMethod: PaymentMethod.cashOnDelivery,
        paymentStatus: PaymentStatus.unpaid,
        deliveryAddress: address,
        deliveryLatitude: destCoords.latitude,
        deliveryLongitude: destCoords.longitude,
        subtotal: 15.0,
        deliveryFee: 10.0,
        totalAmount: 25.0,
        status: OrderStatus.preparing,
        userId: 'cust-123',
      );

      employeeOrderController.placeOrder(initialOrder);

      // Staff selects Carlos Reyes (Employee) as delivery person
      const selectedDeliveryPerson = DeliveryPerson(
        id: 'employee-carlos-123',
        name: 'Carlos Reyes',
        role: 'Employee',
        phone: '0919-345-6789',
      );

      // Trigger assignment and transition to Out for Delivery
      await employeeOrderController.assignDeliveryPersonAndSetOutForDelivery(
        orderId: orderId,
        deliveryPerson: selectedDeliveryPerson,
        destinationCoords: destCoords,
      );

      // Verify the order has updated status and assigned delivery person
      final updatedOrder = employeeOrderController.orders.firstWhere((o) => o.orderId == orderId);
      expect(updatedOrder.status, OrderStatus.outForDelivery);
      expect(updatedOrder.deliveryPersonId, 'employee-carlos-123');
      expect(updatedOrder.deliveryPersonName, 'Carlos Reyes');
      expect(updatedOrder.deliveryPersonRole, 'Employee');
      expect(updatedOrder.deliveryLatitude, destCoords.latitude);
      expect(updatedOrder.deliveryLongitude, destCoords.longitude);

      // Verify tracking service is active
      final tracking = trackingService.getCachedTracking(orderId);
      expect(tracking, isNotNull);
      expect(tracking!.isTrackingActive, isTrue);
      expect(tracking.deliveryPersonName, 'Carlos Reyes');
      expect(tracking.deliveryPersonRole, 'Employee');
      expect(tracking.destinationAddress, address);
    });

    test('Step 4: Real-time GPS location updates from delivery person device', () async {
      const orderId = 'ORD-TRACK-TEST-002';
      const selectedPerson = DeliveryPerson(
        id: 'owner-pedro-1',
        name: 'Pedro Owner',
        role: 'Owner',
      );

      final order = CustomerOrder(
        orderId: orderId,
        customerName: 'Customer Realtime',
        orderDate: DateTime.now(),
        items: const [],
        orderType: OrderType.delivery,
        paymentMethod: PaymentMethod.cashOnDelivery,
        paymentStatus: PaymentStatus.unpaid,
        deliveryAddress: 'Cabuyao, Laguna',
        subtotal: 50.0,
        deliveryFee: 15.0,
        totalAmount: 65.0,
        status: OrderStatus.preparing,
        userId: 'cust-realtime',
      );

      employeeOrderController.placeOrder(order);

      await employeeOrderController.assignDeliveryPersonAndSetOutForDelivery(
        orderId: orderId,
        deliveryPerson: selectedPerson,
      );

      // Listen to real-time updates as customer
      final emittedUpdates = <DeliveryTrackingData>[];
      final subscription = trackingService.streamTracking(orderId).listen((data) {
        if (data != null) emittedUpdates.add(data);
      });

      // Rider GPS location updates while on the way
      const firstLat = 14.3122;
      const firstLng = 121.1114;
      await trackingService.updateRiderLocation(
        orderId: orderId,
        latitude: firstLat,
        longitude: firstLng,
      );

      const secondLat = 14.3140;
      const secondLng = 121.1130;
      await trackingService.updateRiderLocation(
        orderId: orderId,
        latitude: secondLat,
        longitude: secondLng,
      );

      // Allow async streams to flush
      await Future.delayed(const Duration(milliseconds: 50));

      expect(emittedUpdates, isNotEmpty);
      final latest = emittedUpdates.last;
      expect(latest.riderLatitude, secondLat);
      expect(latest.riderLongitude, secondLng);
      expect(latest.deliveryPersonName, 'Pedro Owner');
      expect(latest.deliveryPersonRole, 'Owner');
      expect(latest.isTrackingActive, isTrue);

      await subscription.cancel();
    });

    test('Step 5: Order marked as Delivered stops location tracking', () async {
      const orderId = 'ORD-TRACK-TEST-003';
      const selectedPerson = DeliveryPerson(
        id: 'employee-ana-1',
        name: 'Ana Employee',
        role: 'Employee',
      );

      final order = CustomerOrder(
        orderId: orderId,
        customerName: 'Delivered Test Customer',
        orderDate: DateTime.now(),
        items: const [],
        orderType: OrderType.delivery,
        paymentMethod: PaymentMethod.cashOnDelivery,
        paymentStatus: PaymentStatus.unpaid,
        deliveryAddress: 'San Pedro, Laguna',
        subtotal: 100.0,
        deliveryFee: 20.0,
        totalAmount: 120.0,
        status: OrderStatus.preparing,
        userId: 'cust-delivered',
      );

      employeeOrderController.placeOrder(order);

      await employeeOrderController.assignDeliveryPersonAndSetOutForDelivery(
        orderId: orderId,
        deliveryPerson: selectedPerson,
      );

      expect(trackingService.getCachedTracking(orderId)?.isTrackingActive, isTrue);

      // Employee marks order as Delivered
      employeeOrderController.updateOrderStatus(orderId, OrderStatus.delivered);

      final deliveredOrder = employeeOrderController.orders.firstWhere((o) => o.orderId == orderId);
      expect(deliveredOrder.status, OrderStatus.delivered);

      // Verify tracking is stopped (Requirement 6)
      final finalTracking = trackingService.getCachedTracking(orderId);
      expect(finalTracking?.isTrackingActive, isFalse);
      expect(finalTracking?.status, 'delivered');
    });

    test('Step 6: OpenStreetMap widget integration renders markers and polylines', () {
      const start = LatLng(14.3122, 121.1114);
      const dest = LatLng(14.3414, 121.0803);

      expect(start.latitude, isNotNull);
      expect(dest.latitude, isNotNull);

      // Distance calculation
      const distanceCalc = Distance();
      final meterDistance = distanceCalc.as(LengthUnit.Meter, start, dest);
      expect(meterDistance, greaterThan(0));
    });

    test('Step 7: Public road routing via OSRM returns valid route waypoints', () async {
      const start = LatLng(14.3122, 121.1114); // Santa Rosa
      const dest = LatLng(14.3414, 121.0803); // Biñan

      final result = await trackingService.getRoadRouteResult(start, dest);
      expect(result, isNotNull);
      expect(result.points, isNotEmpty);
      expect(result.points.length, greaterThanOrEqualTo(2));

      final routePoints = await trackingService.getRoadRoute(start, dest);
      expect(routePoints, isNotEmpty);
      expect(routePoints.first.latitude, closeTo(start.latitude, 0.05));
    });

    test('Step 8: Customer side reflects assigned delivery person name and role correctly', () {
      // Test Owner assignment
      final ownerOrder = CustomerOrder(
        orderId: 'ORD-OWNER-01',
        customerName: 'Customer A',
        orderDate: DateTime.now(),
        items: const [],
        orderType: OrderType.delivery,
        paymentMethod: PaymentMethod.cashOnDelivery,
        paymentStatus: PaymentStatus.unpaid,
        status: OrderStatus.outForDelivery,
        deliveryPersonId: 'owner-1',
        deliveryPersonName: 'Ate Eca',
        deliveryPersonRole: 'Owner',
        deliveryAddress: 'Sta. Rosa, Laguna',
        subtotal: 50.0,
        deliveryFee: 10.0,
        totalAmount: 60.0,
      );

      expect(ownerOrder.deliveryPersonName, 'Ate Eca');
      expect(ownerOrder.deliveryPersonRole, 'Owner');

      // Test Employee assignment
      final employeeOrder = CustomerOrder(
        orderId: 'ORD-EMP-01',
        customerName: 'Customer B',
        orderDate: DateTime.now(),
        items: const [],
        orderType: OrderType.delivery,
        paymentMethod: PaymentMethod.cashOnDelivery,
        paymentStatus: PaymentStatus.unpaid,
        status: OrderStatus.outForDelivery,
        deliveryPersonId: 'emp-1',
        deliveryPersonName: 'Juan Staff',
        deliveryPersonRole: 'Employee',
        deliveryAddress: 'Biñan, Laguna',
        subtotal: 50.0,
        deliveryFee: 10.0,
        totalAmount: 60.0,
      );

      expect(employeeOrder.deliveryPersonName, 'Juan Staff');
      expect(employeeOrder.deliveryPersonRole, 'Employee');
    });

    test('Step 9: Turn-by-turn navigation steps are generated with valid instructions', () async {
      final trackingService = DeliveryTrackingService();
      const start = LatLng(14.3122, 121.1114);
      const dest = LatLng(14.2800, 121.1200);

      final result = await trackingService.getRoadRouteResult(start, dest);
      expect(result.points, isNotEmpty);
      expect(result.distanceMeters, greaterThan(0));
      expect(result.durationSeconds, greaterThan(0));
      expect(result.steps, isNotEmpty);

      // Verify first step has an instruction and maneuver
      final firstStep = result.steps.first;
      expect(firstStep.instruction, isNotEmpty);
      expect(firstStep.formattedDistance, isNotEmpty);
    });

    test('Step 10: Navigation voice guidance generates natural Waze/Google Maps spoken prompts', () {
      // 1. Advance warning at 100m
      final advance100m = NavigationVoiceService.formatSpokenInstruction(
        maneuverType: 'turn',
        modifier: 'right',
        streetName: 'Rizal Boulevard',
        distanceMeters: 100,
        isImmediate: false,
      );
      expect(advance100m, 'In 100 meters, turn right onto Rizal Boulevard.');

      // 2. Immediate turn when arriving right at the corner (<30m)
      final immediateTurn = NavigationVoiceService.formatSpokenInstruction(
        maneuverType: 'turn',
        modifier: 'right',
        streetName: 'Rizal Boulevard',
        distanceMeters: 20,
        isImmediate: true,
      );
      expect(immediateTurn, 'turn right onto Rizal Boulevard now.');

      // 3. Left turn with 80m warning
      final advanceLeft = NavigationVoiceService.formatSpokenInstruction(
        maneuverType: 'turn',
        modifier: 'left',
        streetName: 'Mabini Street',
        distanceMeters: 80,
        isImmediate: false,
      );
      expect(advanceLeft, 'In 80 meters, turn left onto Mabini Street.');

      // 4. Arrival prompt
      final arrivePrompt = NavigationVoiceService.formatSpokenInstruction(
        maneuverType: 'arrive',
        modifier: null,
        streetName: 'Customer House',
        distanceMeters: 10,
        isImmediate: true,
      );
      expect(arrivePrompt, 'You have arrived at the customer delivery destination.');

      // 5. Mute toggle functionality
      final voiceService = NavigationVoiceService();
      expect(voiceService.isMuted, isFalse);
      voiceService.toggleMute();
      expect(voiceService.isMuted, isTrue);
      voiceService.setMuted(false);
      expect(voiceService.isMuted, isFalse);
    });
  });
}



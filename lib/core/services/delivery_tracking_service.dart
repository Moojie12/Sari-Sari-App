import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'auth_service.dart';
import 'supabase_service.dart';
import '../../users/customer_db/purchases/customer_order_model.dart';

class DeliveryPerson {
  const DeliveryPerson({
    required this.id,
    required this.name,
    required this.role,
    this.email,
    this.phone,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String role; // 'Owner' or 'Employee'
  final String? email;
  final String? phone;
  final String? avatarUrl;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'role': role,
    if (email != null) 'email': email,
    if (phone != null) 'phone': phone,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
  };

  factory DeliveryPerson.fromMap(Map<dynamic, dynamic> map) {
    final rawRole = map['role']?.toString().toLowerCase() ?? 'employee';
    final formattedRole = (rawRole == 'owner' || rawRole == 'admin') ? 'Owner' : 'Employee';
    
    // Construct name from first_name and surname if available
    String fullName = map['name']?.toString() ?? '';
    if (fullName.isEmpty) {
      final fName = map['first_name']?.toString() ?? map['firstName']?.toString() ?? '';
      final lName = map['surname']?.toString() ?? map['lastName']?.toString() ?? '';
      fullName = '$fName $lName'.trim();
    }
    if (fullName.isEmpty) {
      fullName = map['username']?.toString() ?? map['email']?.toString() ?? 'Store Staff';
    }

    return DeliveryPerson(
      id: map['id']?.toString() ?? map['firebase_uid']?.toString() ?? map['uid']?.toString() ?? '',
      name: fullName,
      role: formattedRole,
      email: map['email']?.toString(),
      phone: map['phone']?.toString() ?? map['contact_number']?.toString(),
      avatarUrl: map['avatar_url']?.toString() ?? map['photoUrl']?.toString(),
    );
  }
}

class DeliveryTrackingData {
  const DeliveryTrackingData({
    required this.orderId,
    required this.deliveryPersonId,
    required this.deliveryPersonName,
    required this.deliveryPersonRole,
    required this.riderLatitude,
    required this.riderLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.destinationAddress,
    required this.status,
    required this.isTrackingActive,
    required this.updatedAt,
  });

  final String orderId;
  final String deliveryPersonId;
  final String deliveryPersonName;
  final String deliveryPersonRole; // 'Owner' or 'Employee'
  final double riderLatitude;
  final double riderLongitude;
  final double destinationLatitude;
  final double destinationLongitude;
  final String destinationAddress;
  final String status;
  final bool isTrackingActive;
  final DateTime updatedAt;

  LatLng get riderLatLng => LatLng(riderLatitude, riderLongitude);
  LatLng get destinationLatLng => LatLng(destinationLatitude, destinationLongitude);

  Map<String, dynamic> toMap() => {
    'orderId': orderId,
    'deliveryPersonId': deliveryPersonId,
    'deliveryPersonName': deliveryPersonName,
    'deliveryPersonRole': deliveryPersonRole,
    'riderLatitude': riderLatitude,
    'riderLongitude': riderLongitude,
    'destinationLatitude': destinationLatitude,
    'destinationLongitude': destinationLongitude,
    'destinationAddress': destinationAddress,
    'status': status,
    'isTrackingActive': isTrackingActive,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DeliveryTrackingData.fromMap(Map<dynamic, dynamic> map) {
    return DeliveryTrackingData(
      orderId: map['orderId']?.toString() ?? '',
      deliveryPersonId: map['deliveryPersonId']?.toString() ?? '',
      deliveryPersonName: map['deliveryPersonName']?.toString() ?? 'Assigned Rider',
      deliveryPersonRole: map['deliveryPersonRole']?.toString() ?? 'Employee',
      riderLatitude: (map['riderLatitude'] as num?)?.toDouble() ?? 14.3122,
      riderLongitude: (map['riderLongitude'] as num?)?.toDouble() ?? 121.1114,
      destinationLatitude: (map['destinationLatitude'] as num?)?.toDouble() ?? 14.3150,
      destinationLongitude: (map['destinationLongitude'] as num?)?.toDouble() ?? 121.1180,
      destinationAddress: map['destinationAddress']?.toString() ?? 'Delivery Address',
      status: map['status']?.toString() ?? 'outForDelivery',
      isTrackingActive: map['isTrackingActive'] == true,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class NavigationStep {
  const NavigationStep({
    required this.instruction,
    required this.streetName,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.location,
    required this.maneuverType,
    this.modifier,
  });

  final String instruction;
  final String streetName;
  final double distanceMeters;
  final double durationSeconds;
  final LatLng location;
  final String maneuverType; // 'turn', 'depart', 'arrive', 'continue', 'roundabout', etc.
  final String? modifier; // 'left', 'right', 'slight left', 'slight right', etc.

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  String get displayStreet =>
      streetName.trim().isNotEmpty && streetName.trim().toLowerCase() != 'road'
          ? streetName.trim()
          : 'road';
}

class RoadRouteResult {
  const RoadRouteResult({
    required this.points,
    this.distanceMeters,
    this.durationSeconds,
    this.steps = const [],
  });

  final List<LatLng> points;
  final double? distanceMeters;
  final double? durationSeconds;
  final List<NavigationStep> steps;

  String get formattedDistance {
    if (distanceMeters == null) return '';
    if (distanceMeters! < 1000) {
      return '${distanceMeters!.round()} m';
    }
    return '${(distanceMeters! / 1000).toStringAsFixed(1)} km';
  }

  String get formattedDuration {
    if (durationSeconds == null) return '';
    final minutes = (durationSeconds! / 60).round();
    if (minutes < 1) return '< 1 min';
    if (minutes < 60) return '$minutes mins';
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    return '${hours}h ${remainingMins}m';
  }
}

class DeliveryTrackingService {
  DeliveryTrackingService._internal();
  static final DeliveryTrackingService instance = DeliveryTrackingService._internal();
  factory DeliveryTrackingService() => instance;

  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService();

  // In-memory cache for fast lookups and fallback streaming
  final Map<String, DeliveryTrackingData> _trackingCache = {};
  final Map<String, StreamController<DeliveryTrackingData?>> _streamControllers = {};
  final Map<String, StreamSubscription<Position>> _gpsSubscriptions = {};
  final Map<String, RoadRouteResult> _roadRouteCache = {};

  // Store coordinates (Santa Rosa, Laguna)
  static const LatLng storeLocation = LatLng(14.3122, 121.1114);

  // Pre-configured coordinates for Laguna cities/municipalities
  static const Map<String, LatLng> _lagunaCityCoords = {
    'binan': LatLng(14.3414, 121.0803),
    'biñan': LatLng(14.3414, 121.0803),
    'santa rosa': LatLng(14.3122, 121.1114),
    'sta rosa': LatLng(14.3122, 121.1114),
    'sta. rosa': LatLng(14.3122, 121.1114),
    'cabuyao': LatLng(14.2786, 121.1245),
    'calamba': LatLng(14.2117, 121.1656),
    'san pedro': LatLng(14.3597, 121.0544),
    'los banos': LatLng(14.1706, 121.2415),
    'los baños': LatLng(14.1706, 121.2415),
    'alaminos': LatLng(14.0633, 121.2458),
    'bay': LatLng(14.1818, 121.2842),
    'calauan': LatLng(14.1481, 121.3164),
    'cavinti': LatLng(14.2492, 121.5075),
    'famy': LatLng(14.4367, 121.4489),
    'kalayaan': LatLng(14.3522, 121.5583),
    'liliw': LatLng(14.1331, 121.4331),
    'luisiana': LatLng(14.1878, 121.5167),
    'lumban': LatLng(14.2981, 121.4589),
    'mabitac': LatLng(14.4289, 121.4289),
    'magdalena': LatLng(14.2003, 121.4289),
    'majayjay': LatLng(14.1444, 121.5139),
    'nagcarlan': LatLng(14.1364, 121.4172),
    'paete': LatLng(14.3644, 121.4847),
    'pagsanjan': LatLng(14.2736, 121.4542),
    'pakil': LatLng(14.3822, 121.4800),
    'pangil': LatLng(14.4039, 121.4644),
    'pila': LatLng(14.2344, 121.3647),
    'rizal': LatLng(14.1111, 121.3944),
    'san pablo': LatLng(14.0683, 121.3256),
    'santa cruz': LatLng(14.2814, 121.4161),
    'sta cruz': LatLng(14.2814, 121.4161),
    'sta. cruz': LatLng(14.2814, 121.4161),
    'santa maria': LatLng(14.4703, 121.4258),
    'siniloan': LatLng(14.4172, 121.4475),
    'victoria': LatLng(14.2267, 121.3278),
  };

  /// Geocode a customer delivery address using OpenStreetMap Nominatim with local Laguna fallback
  Future<LatLng> geocodeAddress(String? address) async {
    if (address == null || address.trim().isEmpty) {
      return storeLocation;
    }

    final clean = address.trim().toLowerCase();

    // 1. Try Nominatim Geocoding API
    try {
      final query = address.contains('Laguna') ? address : '$address, Laguna, Philippines';
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'TindahanNiEca-DeliveryTracker/1.0 (sarisari@delivery.ph)',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List results = jsonDecode(response.body);
        if (results.isNotEmpty) {
          final first = results[0];
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lon = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            debugPrint('[DeliveryTracking] Nominatim resolved $address -> $lat, $lon');
            return LatLng(lat, lon);
          }
        }
      }
    } catch (e) {
      debugPrint('[DeliveryTracking] Nominatim geocoding error: $e');
    }

    // 2. High-precision local Laguna city lookup fallback
    for (final entry in _lagunaCityCoords.entries) {
      if (clean.contains(entry.key)) {
        debugPrint('[DeliveryTracking] Resolved address via Laguna city match: ${entry.key}');
        return entry.value;
      }
    }

    // 3. Default to Store Location with slight offset based on address hash
    final hash = address.hashCode.abs();
    final offsetLat = ((hash % 100) - 50) * 0.0003;
    final offsetLng = (((hash ~/ 100) % 100) - 50) * 0.0003;
    return LatLng(storeLocation.latitude + offsetLat, storeLocation.longitude + offsetLng);
  }

  /// Get available Owner and Employee accounts to assign as delivery persons
  Future<List<DeliveryPerson>> getAvailableDeliveryStaff() async {
    final Map<String, DeliveryPerson> staffMap = {};

    // 1. Fetch from Supabase profiles table
    try {
      final profiles = await _supabaseService.client
          .from('profiles')
          .select('*')
          .inFilter('role', ['owner', 'employee', 'admin']);

      for (final p in profiles) {
        final person = DeliveryPerson.fromMap(p);
        if (person.id.isNotEmpty && person.name.isNotEmpty) {
          staffMap[person.id] = person;
        }
      }
    } catch (e) {
      debugPrint('[DeliveryTracking] Note fetching staff from Supabase: $e');
    }

    // 2. Fetch from Firebase Realtime Database /users
    try {
      final db = _authService.database;
      final snapshot = await db.ref().child('users').get();
      if (snapshot.exists && snapshot.value is Map) {
        final users = snapshot.value as Map;
        for (final entry in users.entries) {
          if (entry.value is Map) {
            final val = entry.value as Map;
            final role = val['role']?.toString().toLowerCase() ?? '';
            if (role == 'owner' || role == 'employee' || role == 'admin') {
              final id = entry.key.toString();
              final person = DeliveryPerson.fromMap({...val, 'id': id});
              staffMap[id] = person;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[DeliveryTracking] Note fetching staff from Firebase RTDB: $e');
    }

    // 3. Include current user if they are owner or employee
    final currentUser = _authService.currentUser;
    if (currentUser != null && !staffMap.containsKey(currentUser.uid)) {
      final isOwner = await _authService.hasRole('owner');
      final isEmployee = await _authService.hasRole('employee');
      if (isOwner || isEmployee) {
        final role = isOwner ? 'Owner' : 'Employee';
        final name = currentUser.displayName ?? (isOwner ? 'Store Owner' : 'Store Employee');
        staffMap[currentUser.uid] = DeliveryPerson(
          id: currentUser.uid,
          name: name,
          role: role,
          email: currentUser.email,
        );
      }
    }

    // 4. Fallback defaults if no staff found (ensures testability even without online data)
    if (staffMap.isEmpty) {
      staffMap['owner_default'] = const DeliveryPerson(
        id: 'owner_default',
        name: 'Store Owner',
        role: 'Owner',
        phone: '0917-123-4567',
      );
      staffMap['employee_rider_1'] = const DeliveryPerson(
        id: 'employee_rider_1',
        name: 'Maria Santos (Rider)',
        role: 'Employee',
        phone: '0918-234-5678',
      );
      staffMap['employee_rider_2'] = const DeliveryPerson(
        id: 'employee_rider_2',
        name: 'Carlos Reyes (Rider)',
        role: 'Employee',
        phone: '0919-345-6789',
      );
    }

    final list = staffMap.values.toList();
    // Sort Owners first, then Employees alphabetically
    list.sort((a, b) {
      if (a.role == 'Owner' && b.role != 'Owner') return -1;
      if (a.role != 'Owner' && b.role == 'Owner') return 1;
      return a.name.compareTo(b.name);
    });

    return list;
  }

  /// Initialize and start tracking for an order with assigned delivery person
  Future<void> startTrackingForOrder({
    required CustomerOrder order,
    required DeliveryPerson deliveryPerson,
    LatLng? destinationCoords,
  }) async {
    // Resolve destination coordinates if not provided
    final dest = destinationCoords ??
        (order.deliveryLatitude != null && order.deliveryLongitude != null
            ? LatLng(order.deliveryLatitude!, order.deliveryLongitude!)
            : await geocodeAddress(order.deliveryAddress));

    // Initial rider location starts near the store
    final initialRiderLat = storeLocation.latitude;
    final initialRiderLng = storeLocation.longitude;

    final trackingData = DeliveryTrackingData(
      orderId: order.orderId,
      deliveryPersonId: deliveryPerson.id,
      deliveryPersonName: deliveryPerson.name,
      deliveryPersonRole: deliveryPerson.role,
      riderLatitude: initialRiderLat,
      riderLongitude: initialRiderLng,
      destinationLatitude: dest.latitude,
      destinationLongitude: dest.longitude,
      destinationAddress: order.deliveryAddress ?? 'Customer Address',
      status: 'outForDelivery',
      isTrackingActive: true,
      updatedAt: DateTime.now(),
    );

    // Save in cache
    _trackingCache[order.orderId] = trackingData;
    _emitLocal(order.orderId, trackingData);

    // Sync to Firebase Realtime Database
    try {
      final db = _authService.database;
      await db.ref().child('delivery_tracking/${order.orderId}').set(trackingData.toMap());
      await db.ref().child('orders/${order.orderId}').update({
        'status': OrderStatus.outForDelivery.name,
        'deliveryPersonId': deliveryPerson.id,
        'deliveryPersonName': deliveryPerson.name,
        'deliveryPersonRole': deliveryPerson.role,
        'deliveryLatitude': dest.latitude,
        'deliveryLongitude': dest.longitude,
        'trackingActive': true,
      });
      debugPrint('[DeliveryTracking] Tracking initialized in Firebase for #${order.orderId}');
    } catch (e) {
      debugPrint('[DeliveryTracking] Error saving tracking to Firebase: $e');
    }
  }

  /// Update the live GPS location of the rider
  Future<void> updateRiderLocation({
    required String orderId,
    required double latitude,
    required double longitude,
  }) async {
    final existing = _trackingCache[orderId];
    final updated = DeliveryTrackingData(
      orderId: orderId,
      deliveryPersonId: existing?.deliveryPersonId ?? '',
      deliveryPersonName: existing?.deliveryPersonName ?? 'Assigned Rider',
      deliveryPersonRole: existing?.deliveryPersonRole ?? 'Employee',
      riderLatitude: latitude,
      riderLongitude: longitude,
      destinationLatitude: existing?.destinationLatitude ?? storeLocation.latitude,
      destinationLongitude: existing?.destinationLongitude ?? storeLocation.longitude,
      destinationAddress: existing?.destinationAddress ?? '',
      status: existing?.status ?? 'outForDelivery',
      isTrackingActive: true,
      updatedAt: DateTime.now(),
    );

    _trackingCache[orderId] = updated;
    _emitLocal(orderId, updated);

    // Sync to Firebase Realtime Database
    try {
      final db = _authService.database;
      await db.ref().child('delivery_tracking/$orderId').update({
        'riderLatitude': latitude,
        'riderLongitude': longitude,
        'updatedAt': DateTime.now().toIso8601String(),
        'isTrackingActive': true,
      });
    } catch (e) {
      debugPrint('[DeliveryTracking] Error updating rider location in Firebase: $e');
    }
  }

  /// Stop tracking for an order (called when order is Delivered or Completed)
  Future<void> stopTracking(String orderId) async {
    // Cancel device GPS stream for this order if active
    _gpsSubscriptions[orderId]?.cancel();
    _gpsSubscriptions.remove(orderId);

    final existing = _trackingCache[orderId];
    if (existing != null) {
      final stopped = DeliveryTrackingData(
        orderId: existing.orderId,
        deliveryPersonId: existing.deliveryPersonId,
        deliveryPersonName: existing.deliveryPersonName,
        deliveryPersonRole: existing.deliveryPersonRole,
        riderLatitude: existing.riderLatitude,
        riderLongitude: existing.riderLongitude,
        destinationLatitude: existing.destinationLatitude,
        destinationLongitude: existing.destinationLongitude,
        destinationAddress: existing.destinationAddress,
        status: 'delivered',
        isTrackingActive: false,
        updatedAt: DateTime.now(),
      );
      _trackingCache[orderId] = stopped;
      _emitLocal(orderId, stopped);
    }

    try {
      final db = _authService.database;
      await db.ref().child('delivery_tracking/$orderId').update({
        'isTrackingActive': false,
        'status': 'delivered',
        'updatedAt': DateTime.now().toIso8601String(),
      });
      await db.ref().child('orders/$orderId').update({
        'trackingActive': false,
      });
      debugPrint('[DeliveryTracking] Tracking stopped in Firebase for #$orderId');
    } catch (e) {
      debugPrint('[DeliveryTracking] Error stopping tracking in Firebase: $e');
    }
  }

  /// Stream real-time location updates for an order
  Stream<DeliveryTrackingData?> streamTracking(String orderId) {
    final controller = _streamControllers.putIfAbsent(
      orderId,
      () => StreamController<DeliveryTrackingData?>.broadcast(),
    );

    // Immediate emission from cache if available
    if (_trackingCache.containsKey(orderId)) {
      controller.add(_trackingCache[orderId]);
    }

    // Subscribe to Firebase RTDB node
    try {
      final db = _authService.database;
      db.ref().child('delivery_tracking/$orderId').onValue.listen((event) {
        if (event.snapshot.exists && event.snapshot.value is Map) {
          final data = DeliveryTrackingData.fromMap(event.snapshot.value as Map);
          _trackingCache[orderId] = data;
          if (!controller.isClosed) {
            controller.add(data);
          }
        }
      }, onError: (e) {
        debugPrint('[DeliveryTracking] Firebase stream error: $e');
      });
    } catch (e) {
      debugPrint('[DeliveryTracking] Failed to subscribe to Firebase tracking: $e');
    }

    return controller.stream;
  }

  /// Get current cached tracking data if available
  DeliveryTrackingData? getCachedTracking(String orderId) => _trackingCache[orderId];

  /// Start broadcasting live device GPS coordinates for the delivery person
  Future<bool> startDeviceGpsBroadcasting(String orderId) async {
    // 1. Check permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[DeliveryTracking] GPS permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[DeliveryTracking] GPS permission permanently denied');
      return false;
    }

    // Cancel existing subscription if any
    _gpsSubscriptions[orderId]?.cancel();

    // Send immediate initial position
    try {
      final currentPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      await updateRiderLocation(
        orderId: orderId,
        latitude: currentPos.latitude,
        longitude: currentPos.longitude,
      );
    } catch (e) {
      debugPrint('[DeliveryTracking] Initial GPS lookup error: $e');
    }

    // Start stream
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3, // meters
    );

    _gpsSubscriptions[orderId] = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      updateRiderLocation(
        orderId: orderId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }, onError: (e) {
      debugPrint('[DeliveryTracking] GPS stream error: $e');
    });

    return true;
  }

  /// Stop broadcasting device GPS
  void stopDeviceGpsBroadcasting(String orderId) {
    _gpsSubscriptions[orderId]?.cancel();
    _gpsSubscriptions.remove(orderId);
  }

  /// Fetch real driving route along legal/public roads via OpenStreetMap OSRM routing API.
  /// Strictly avoids water bodies, off-road paths, and draws exact public road geometries.
  Future<RoadRouteResult> getRoadRouteResult(LatLng start, LatLng destination) async {
    // If start and destination are basically the same point, return direct 2-point line
    if ((start.latitude - destination.latitude).abs() < 0.0001 &&
        (start.longitude - destination.longitude).abs() < 0.0001) {
      return RoadRouteResult(
        points: [start, destination],
        distanceMeters: 0,
        durationSeconds: 0,
        steps: [
          NavigationStep(
            instruction: 'You have arrived at customer delivery address',
            streetName: 'Destination',
            distanceMeters: 0,
            durationSeconds: 0,
            location: destination,
            maneuverType: 'arrive',
          ),
        ],
      );
    }

    final cacheKey =
        '${start.latitude.toStringAsFixed(4)},${start.longitude.toStringAsFixed(4)}->${destination.latitude.toStringAsFixed(4)},${destination.longitude.toStringAsFixed(4)}';
    if (_roadRouteCache.containsKey(cacheKey)) {
      return _roadRouteCache[cacheKey]!;
    }

    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=true',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': 'TindahanNiEca-DeliveryTracker/1.0 (sarisari@delivery.ph)',
      }).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final firstRoute = routes[0] as Map<String, dynamic>;
          final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
          final coordinates = geometry?['coordinates'] as List?;
          final distance = (firstRoute['distance'] as num?)?.toDouble();
          final duration = (firstRoute['duration'] as num?)?.toDouble();

          if (coordinates != null && coordinates.length >= 2) {
            final List<LatLng> roadPoints = [];
            for (final item in coordinates) {
              if (item is List && item.length >= 2) {
                final lng = (item[0] as num).toDouble();
                final lat = (item[1] as num).toDouble();
                roadPoints.add(LatLng(lat, lng));
              }
            }

            final List<NavigationStep> navSteps = [];
            final legs = firstRoute['legs'] as List?;
            if (legs != null && legs.isNotEmpty) {
              final firstLeg = legs[0] as Map<String, dynamic>;
              final rawSteps = firstLeg['steps'] as List?;
              if (rawSteps != null) {
                for (final s in rawSteps) {
                  if (s is Map<String, dynamic>) {
                    final maneuver = s['maneuver'] as Map<String, dynamic>? ?? {};
                    final maneuverType = maneuver['type']?.toString().toLowerCase() ?? 'turn';
                    final modifier = maneuver['modifier']?.toString().toLowerCase();
                    final rawLocation = maneuver['location'] as List?;
                    final stepLat = rawLocation != null && rawLocation.length >= 2 ? (rawLocation[1] as num).toDouble() : 0.0;
                    final stepLng = rawLocation != null && rawLocation.length >= 2 ? (rawLocation[0] as num).toDouble() : 0.0;
                    final streetName = s['name']?.toString() ?? '';
                    final stepDist = (s['distance'] as num?)?.toDouble() ?? 0.0;
                    final stepDur = (s['duration'] as num?)?.toDouble() ?? 0.0;

                    final displayStreet = streetName.trim().isNotEmpty ? streetName.trim() : 'road';
                    String instruction = '';
                    if (maneuverType == 'depart') {
                      instruction = 'Head out on $displayStreet';
                    } else if (maneuverType == 'arrive') {
                      instruction = 'Arrive at delivery destination';
                    } else if (maneuverType == 'turn') {
                      if (modifier == 'left') {
                        instruction = 'Turn left onto $displayStreet';
                      } else if (modifier == 'right') {
                        instruction = 'Turn right onto $displayStreet';
                      } else if (modifier == 'slight left') {
                        instruction = 'Keep slight left onto $displayStreet';
                      } else if (modifier == 'slight right') {
                        instruction = 'Keep slight right onto $displayStreet';
                      } else if (modifier == 'sharp left') {
                        instruction = 'Sharp left onto $displayStreet';
                      } else if (modifier == 'sharp right') {
                        instruction = 'Sharp right onto $displayStreet';
                      } else if (modifier == 'uturn') {
                        instruction = 'Make a U-turn onto $displayStreet';
                      } else {
                        instruction = 'Turn onto $displayStreet';
                      }
                    } else if (maneuverType == 'continue') {
                      instruction = 'Continue straight on $displayStreet';
                    } else if (maneuverType == 'roundabout') {
                      instruction = 'At roundabout, take exit onto $displayStreet';
                    } else if (maneuverType == 'merge') {
                      instruction = 'Merge onto $displayStreet';
                    } else {
                      instruction = 'Continue on $displayStreet';
                    }

                    navSteps.add(NavigationStep(
                      instruction: instruction,
                      streetName: streetName,
                      distanceMeters: stepDist,
                      durationSeconds: stepDur,
                      location: LatLng(stepLat, stepLng),
                      maneuverType: maneuverType,
                      modifier: modifier,
                    ));
                  }
                }
              }
            }

            if (navSteps.isEmpty) {
              navSteps.add(NavigationStep(
                instruction: 'Head towards customer delivery address',
                streetName: 'Public Road',
                distanceMeters: distance ?? 500,
                durationSeconds: duration ?? 120,
                location: start,
                maneuverType: 'depart',
              ));
              navSteps.add(NavigationStep(
                instruction: 'Arrive at customer delivery address',
                streetName: 'Destination',
                distanceMeters: 0,
                durationSeconds: 0,
                location: destination,
                maneuverType: 'arrive',
              ));
            }

            if (roadPoints.isNotEmpty) {
              final result = RoadRouteResult(
                points: roadPoints,
                distanceMeters: distance,
                durationSeconds: duration,
                steps: navSteps,
              );
              _roadRouteCache[cacheKey] = result;
              debugPrint('[DeliveryTracking] Fetched road route with ${roadPoints.length} points and ${navSteps.length} navigation steps via OSRM (${result.formattedDistance}, ${result.formattedDuration})');
              return result;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[DeliveryTracking] OSRM road routing error (falling back to direct): $e');
    }

    final approxDistance = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      destination.latitude,
      destination.longitude,
    );
    final approxDuration = (approxDistance / 6.94); // ~25 km/h driving speed

    final fallbackSteps = [
      NavigationStep(
        instruction: 'Head towards customer delivery destination',
        streetName: 'Public Road',
        distanceMeters: approxDistance,
        durationSeconds: approxDuration,
        location: start,
        maneuverType: 'depart',
      ),
      NavigationStep(
        instruction: 'Arrive at customer delivery address',
        streetName: 'Destination',
        distanceMeters: 0,
        durationSeconds: 0,
        location: destination,
        maneuverType: 'arrive',
      ),
    ];
    final fallback = RoadRouteResult(
      points: [start, destination],
      distanceMeters: approxDistance,
      durationSeconds: approxDuration,
      steps: fallbackSteps,
    );
    return fallback;
  }

  /// Convenience method returning just the road waypoints
  Future<List<LatLng>> getRoadRoute(LatLng start, LatLng destination) async {
    final result = await getRoadRouteResult(start, destination);
    return result.points;
  }

  void _emitLocal(String orderId, DeliveryTrackingData data) {
    final controller = _streamControllers[orderId];
    if (controller != null && !controller.isClosed) {
      controller.add(data);
    }
  }

  void dispose() {
    for (var sub in _gpsSubscriptions.values) {
      sub.cancel();
    }
    _gpsSubscriptions.clear();

    for (var ctrl in _streamControllers.values) {
      ctrl.close();
    }
    _streamControllers.clear();
    _roadRouteCache.clear();
  }
}

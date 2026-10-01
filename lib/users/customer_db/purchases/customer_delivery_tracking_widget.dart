import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/delivery_tracking_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/osm_delivery_map.dart';
import 'customer_order_model.dart';

class CustomerDeliveryTrackingWidget extends StatefulWidget {
  const CustomerDeliveryTrackingWidget({
    super.key,
    required this.order,
  });

  final CustomerOrder order;

  @override
  State<CustomerDeliveryTrackingWidget> createState() => _CustomerDeliveryTrackingWidgetState();
}

class _CustomerDeliveryTrackingWidgetState extends State<CustomerDeliveryTrackingWidget> {
  final DeliveryTrackingService _trackingService = DeliveryTrackingService.instance;
  StreamSubscription<DeliveryTrackingData?>? _trackingSub;
  DeliveryTrackingData? _trackingData;

  LatLng _riderPos = DeliveryTrackingService.storeLocation;
  LatLng _destPos = DeliveryTrackingService.storeLocation;

  @override
  void initState() {
    super.initState();
    _initTracking();
  }

  Future<void> _initTracking() async {
    // 1. Resolve destination
    if (widget.order.deliveryLatitude != null && widget.order.deliveryLongitude != null) {
      _destPos = LatLng(widget.order.deliveryLatitude!, widget.order.deliveryLongitude!);
    } else {
      _destPos = await _trackingService.geocodeAddress(widget.order.deliveryAddress);
    }

    // 2. Read cached tracking if available
    final cached = _trackingService.getCachedTracking(widget.order.orderId);
    if (cached != null) {
      _trackingData = cached;
      _riderPos = cached.riderLatLng;
      _destPos = cached.destinationLatLng;
    } else {
      _riderPos = DeliveryTrackingService.storeLocation;
    }

    if (mounted) setState(() {});

    // 3. Listen to real-time updates from Firebase RTDB
    _trackingSub = _trackingService.streamTracking(widget.order.orderId).listen((data) {
      if (data != null && mounted) {
        setState(() {
          _trackingData = data;
          _riderPos = data.riderLatLng;
          _destPos = data.destinationLatLng;
        });
      }
    });
  }

  @override
  void dispose() {
    _trackingSub?.cancel();
    super.dispose();
  }

  void _openFullScreenMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _CustomerFullScreenMapPage(
          order: widget.order,
          initialTracking: _trackingData,
          initialRiderPos: _riderPos,
          initialDestPos: _destPos,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final riderName = _trackingData?.deliveryPersonName ??
        widget.order.deliveryPersonName ??
        'Assigned Rider';
    final riderRole = _trackingData?.deliveryPersonRole ??
        widget.order.deliveryPersonRole ??
        'Employee';
    final isOwner = riderRole.toLowerCase() == 'owner';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Map Container Card
        Container(
          height: 220,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // OpenStreetMap widget
              Positioned.fill(
                child: OsmDeliveryMap(
                  riderLocation: _riderPos,
                  destinationLocation: _destPos,
                  riderName: riderName,
                  riderRole: riderRole,
                  destinationAddress: widget.order.deliveryAddress ?? 'Customer Address',
                  showControls: false,
                  interactive: false,
                ),
              ),

              // "Rider is on the way" chip (matches reference image)
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.two_wheeler, color: AppColors.primaryOrange, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Rider is on the way',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.darkText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tap to View Interactive Map Button (matches reference image)
              Positioned(
                bottom: 12,
                right: 12,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  elevation: 3,
                  shadowColor: Colors.black.withValues(alpha: 0.25),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _openFullScreenMap,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fullscreen, color: AppColors.primaryOrange, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Tap for Full Map',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Delivery Person Info Card (Requirement 4)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isOwner ? Colors.amber.shade100 : Colors.blue.shade100,
                    child: Icon(
                      isOwner ? Icons.storefront : Icons.two_wheeler,
                      color: isOwner ? Colors.orange.shade800 : Colors.blue.shade800,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delivery Person',
                          style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          riderName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.darkText),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOwner ? Colors.amber.shade100 : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOwner ? Icons.verified : Icons.badge,
                          size: 14,
                          color: isOwner ? Colors.orange.shade900 : Colors.blue.shade900,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          riderRole,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isOwner ? Colors.orange.shade900 : Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_pin, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delivery Address',
                          style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
                        ),
                        Text(
                          widget.order.deliveryAddress ?? 'No address provided',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkText),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomerFullScreenMapPage extends StatefulWidget {
  const _CustomerFullScreenMapPage({
    required this.order,
    this.initialTracking,
    required this.initialRiderPos,
    required this.initialDestPos,
  });

  final CustomerOrder order;
  final DeliveryTrackingData? initialTracking;
  final LatLng initialRiderPos;
  final LatLng initialDestPos;

  @override
  State<_CustomerFullScreenMapPage> createState() => _CustomerFullScreenMapPageState();
}

class _CustomerFullScreenMapPageState extends State<_CustomerFullScreenMapPage> {
  final DeliveryTrackingService _trackingService = DeliveryTrackingService.instance;
  StreamSubscription<DeliveryTrackingData?>? _trackingSub;
  late LatLng _riderPos;
  late LatLng _destPos;
  DeliveryTrackingData? _trackingData;

  @override
  void initState() {
    super.initState();
    _riderPos = widget.initialRiderPos;
    _destPos = widget.initialDestPos;
    _trackingData = widget.initialTracking;

    _trackingSub = _trackingService.streamTracking(widget.order.orderId).listen((data) {
      if (data != null && mounted) {
        setState(() {
          _trackingData = data;
          _riderPos = data.riderLatLng;
          _destPos = data.destinationLatLng;
        });
      }
    });
  }

  @override
  void dispose() {
    _trackingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final riderName = _trackingData?.deliveryPersonName ??
        widget.order.deliveryPersonName ??
        'Assigned Rider';
    final riderRole = _trackingData?.deliveryPersonRole ??
        widget.order.deliveryPersonRole ??
        'Employee';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'Live Delivery Tracking',
              style: TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Order #${widget.order.displayOrderId}',
              style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.darkText),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: OsmDeliveryMap(
              riderLocation: _riderPos,
              destinationLocation: _destPos,
              riderName: riderName,
              riderRole: riderRole,
              destinationAddress: widget.order.deliveryAddress ?? 'Customer Address',
              showControls: true,
              interactive: true,
            ),
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.lightBackground,
                    child: const Icon(Icons.two_wheeler, color: AppColors.primaryOrange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          riderName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          'Delivery Person ($riderRole) is on the way',
                          style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.green, size: 8),
                        SizedBox(width: 4),
                        Text('LIVE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

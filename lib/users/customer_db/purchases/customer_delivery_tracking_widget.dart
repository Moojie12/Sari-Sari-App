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
        'Store Staff';
    final riderRole = _trackingData?.deliveryPersonRole ??
        widget.order.deliveryPersonRole ??
        'Employee';
    final isOwner = riderRole.trim().toLowerCase() == 'owner';
    final formattedRole = isOwner ? 'Store Owner' : 'Store Employee';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Map Container Card
        Container(
          height: 230,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
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
              // OpenStreetMap widget tracing public road network
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

              // "Rider is on the way" chip
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Out for Delivery',
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

              // Tap to View Interactive Map Button
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
                          Icon(Icons.fullscreen, color: AppColors.primaryOrange, size: 18),
                          SizedBox(width: 4),
                          Text(
                            'Open Full Map',
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
        const SizedBox(height: 14),

        // Assigned Delivery Person Info Card (Requirement 4)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOwner ? Colors.amber.shade200 : Colors.blue.shade100,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar with distinct Owner / Employee iconography
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: isOwner ? Colors.amber.shade100 : Colors.blue.shade100,
                    child: Icon(
                      isOwner ? Icons.storefront : Icons.two_wheeler,
                      color: isOwner ? Colors.amber.shade900 : Colors.blue.shade800,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assigned Delivery Person',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          riderName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Prominent Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isOwner ? Colors.amber.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isOwner ? Colors.amber.shade400 : Colors.blue.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOwner ? Icons.verified : Icons.badge,
                          size: 13,
                          color: isOwner ? Colors.amber.shade900 : Colors.blue.shade800,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedRole,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isOwner ? Colors.amber.shade900 : Colors.blue.shade800,
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
                  const Icon(Icons.location_on, size: 20, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Destination Address',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.order.deliveryAddress ?? 'No address provided',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.darkText,
                          ),
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
  bool _isCardExpanded = false;

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
        'Store Staff';
    final riderRole = _trackingData?.deliveryPersonRole ??
        widget.order.deliveryPersonRole ??
        'Employee';
    final isOwner = riderRole.trim().toLowerCase() == 'owner';
    final formattedRole = isOwner ? 'Store Owner' : 'Store Employee';

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
          // Bottom Delivery Details (Collapsible: only opens when tapped so map controls are not blocked)
          if (!_isCardExpanded)
            Positioned(
              bottom: 16,
              left: 14,
              right: 76, // Leaves room for map controls on the right
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => setState(() => _isCardExpanded = true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: isOwner ? Colors.amber.shade100 : Colors.blue.shade100,
                          child: Icon(
                            isOwner ? Icons.storefront : Icons.two_wheeler,
                            color: isOwner ? Colors.amber.shade900 : Colors.blue.shade800,
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      riderName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppColors.darkText,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '($formattedRole)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isOwner ? Colors.amber.shade900 : Colors.blue.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const Text(
                                'Tap to view details',
                                style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: AppColors.primaryOrange, size: 7),
                              SizedBox(width: 3),
                              Text('LIVE', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold, fontSize: 10)),
                              SizedBox(width: 2),
                              Icon(Icons.keyboard_arrow_up, size: 14, color: AppColors.primaryOrange),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Positioned(
              bottom: 16,
              left: 14,
              right: 14,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                elevation: 6,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: isOwner ? Colors.amber.shade100 : Colors.blue.shade100,
                            child: Icon(
                              isOwner ? Icons.storefront : Icons.two_wheeler,
                              color: isOwner ? Colors.amber.shade900 : Colors.blue.shade800,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        riderName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppColors.darkText,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isOwner ? Colors.amber.shade50 : Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isOwner ? Colors.amber.shade300 : Colors.blue.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        formattedRole,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isOwner ? Colors.amber.shade900 : Colors.blue.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isOwner
                                      ? 'Store Owner is personally delivering your order'
                                      : 'Store Employee is delivering your order',
                                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, color: AppColors.primaryOrange, size: 8),
                                SizedBox(width: 4),
                                Text(
                                  'LIVE GPS',
                                  style: TextStyle(
                                    color: AppColors.primaryOrange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.secondaryText),
                            tooltip: 'Hide details',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () => setState(() => _isCardExpanded = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.red),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.order.deliveryAddress ?? 'Customer Address',
                              style: const TextStyle(fontSize: 12, color: AppColors.darkText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

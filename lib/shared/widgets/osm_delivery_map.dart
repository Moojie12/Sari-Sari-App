import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/services/delivery_tracking_service.dart';
import '../../core/theme/app_colors.dart';

class OsmDeliveryMap extends StatefulWidget {
  const OsmDeliveryMap({
    super.key,
    required this.riderLocation,
    required this.destinationLocation,
    this.routePoints,
    this.riderName = 'Delivery Rider',
    this.riderRole = 'Employee',
    this.destinationAddress = 'Customer Address',
    this.showControls = true,
    this.interactive = true,
    this.initialZoom = 14.5,
    this.isNavigationMode = false,
    this.onRouteCalculated,
  });

  final LatLng riderLocation;
  final LatLng destinationLocation;
  final List<LatLng>? routePoints;
  final String riderName;
  final String riderRole;
  final String destinationAddress;
  final bool showControls;
  final bool interactive;
  final double initialZoom;
  final bool isNavigationMode;
  final ValueChanged<RoadRouteResult>? onRouteCalculated;

  @override
  State<OsmDeliveryMap> createState() => _OsmDeliveryMapState();
}

class _OsmDeliveryMapState extends State<OsmDeliveryMap> {
  late final MapController _mapController;
  List<LatLng> _routePoints = [];
  RoadRouteResult? _routeResult;
  bool _isLoadingRoute = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    if (widget.routePoints != null && widget.routePoints!.isNotEmpty) {
      _routePoints = widget.routePoints!;
    } else {
      _fetchRoadRoute();
    }
  }

  @override
  void didUpdateWidget(covariant OsmDeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isNavigationMode != oldWidget.isNavigationMode) {
      if (widget.isNavigationMode) {
        _recenterNavigation();
      } else {
        _fitBounds();
      }
    } else if (widget.isNavigationMode &&
        (widget.riderLocation.latitude != oldWidget.riderLocation.latitude ||
            widget.riderLocation.longitude != oldWidget.riderLocation.longitude)) {
      _recenterNavigation();
    }

    if (widget.routePoints != null && widget.routePoints!.isNotEmpty) {
      final wasEmpty = _routePoints.isEmpty;
      _routePoints = widget.routePoints!;
      if (widget.isNavigationMode && wasEmpty) {
        _recenterNavigation();
      }
      return;
    }

    // Check if rider moved by more than ~25 meters or destination changed
    final riderDistMoved = (oldWidget.riderLocation.latitude - widget.riderLocation.latitude).abs() +
        (oldWidget.riderLocation.longitude - widget.riderLocation.longitude).abs();
    final destDistMoved = (oldWidget.destinationLocation.latitude - widget.destinationLocation.latitude).abs() +
        (oldWidget.destinationLocation.longitude - widget.destinationLocation.longitude).abs();

    if (riderDistMoved > 0.00025 || destDistMoved > 0.00025) {
      _fetchRoadRoute();
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * (math.pi / 180.0);
    final lon1 = start.longitude * (math.pi / 180.0);
    final lat2 = end.latitude * (math.pi / 180.0);
    final lon2 = end.longitude * (math.pi / 180.0);

    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final rad = math.atan2(y, x);
    return (rad * 180.0 / math.pi + 360.0) % 360.0;
  }

  /// Calculates the heading angle strictly along the road/route ahead
  /// so the rider faces their immediate path rather than diagonally to destination
  double _getHeadingAngle() {
    if (_routePoints.length >= 2) {
      int closestIdx = 0;
      double minDiff = double.infinity;
      for (int i = 0; i < _routePoints.length; i++) {
        final p = _routePoints[i];
        final diff = (p.latitude - widget.riderLocation.latitude).abs() +
            (p.longitude - widget.riderLocation.longitude).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closestIdx = i;
        }
      }

      // Look ahead along the road route for the next point along the forward direction
      for (int j = closestIdx + 1; j < _routePoints.length; j++) {
        final nextP = _routePoints[j];
        final dist = (nextP.latitude - _routePoints[closestIdx].latitude).abs() +
            (nextP.longitude - _routePoints[closestIdx].longitude).abs();
        // At least ~8-10 meters ahead along the road
        if (dist > 0.00008) {
          return _calculateBearing(_routePoints[closestIdx], nextP);
        }
      }

      // If near the end of the route, take the bearing of the final road segment
      if (closestIdx + 1 < _routePoints.length) {
        return _calculateBearing(_routePoints[closestIdx], _routePoints[closestIdx + 1]);
      } else if (closestIdx > 0) {
        return _calculateBearing(_routePoints[closestIdx - 1], _routePoints[closestIdx]);
      }
    }

    return _calculateBearing(widget.riderLocation, widget.destinationLocation);
  }

  void _recenterNavigation() {
    final heading = _getHeadingAngle();
    final rotation = (360.0 - heading) % 360.0;
    _mapController.moveAndRotate(widget.riderLocation, 17.5, rotation);
  }

  Future<void> _fetchRoadRoute() async {
    if (_isLoadingRoute) return;
    _isLoadingRoute = true;

    try {
      final result = await DeliveryTrackingService.instance.getRoadRouteResult(
        widget.riderLocation,
        widget.destinationLocation,
      );

      if (mounted) {
        setState(() {
          _routeResult = result;
          _routePoints = result.points;
          _isLoadingRoute = false;
        });

        widget.onRouteCalculated?.call(result);

        if (widget.isNavigationMode) {
          _recenterNavigation();
        } else {
          // Re-fit camera to the newly fetched road route curves
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted && !widget.isNavigationMode) _fitBounds();
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingRoute = false);
      }
    }
  }

  void _fitBounds() {
    if (widget.isNavigationMode) {
      _recenterNavigation();
      return;
    }
    _mapController.rotate(0.0);
    final pointsToFit = _routePoints.isNotEmpty
        ? _routePoints
        : [widget.riderLocation, widget.destinationLocation];

    double south = pointsToFit.first.latitude;
    double north = pointsToFit.first.latitude;
    double west = pointsToFit.first.longitude;
    double east = pointsToFit.first.longitude;

    for (final p in pointsToFit) {
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }

    // Include rider and destination specifically
    south = math.min(south, math.min(widget.riderLocation.latitude, widget.destinationLocation.latitude));
    north = math.max(north, math.max(widget.riderLocation.latitude, widget.destinationLocation.latitude));
    west = math.min(west, math.min(widget.riderLocation.longitude, widget.destinationLocation.longitude));
    east = math.max(east, math.max(widget.riderLocation.longitude, widget.destinationLocation.longitude));

    final bounds = LatLngBounds(
      LatLng(south, west),
      LatLng(north, east),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(52),
        maxZoom: 16.0,
      ),
    );
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  void _centerOnRider() {
    _mapController.move(widget.riderLocation, 15.5);
  }

  void _centerOnDestination() {
    _mapController.move(widget.destinationLocation, 15.5);
  }

  @override
  Widget build(BuildContext context) {
    // Initial center between rider and destination
    final centerLat = (widget.riderLocation.latitude + widget.destinationLocation.latitude) / 2;
    final centerLng = (widget.riderLocation.longitude + widget.destinationLocation.longitude) / 2;
    final center = LatLng(centerLat, centerLng);

    final isOwner = widget.riderRole.trim().toLowerCase() == 'owner';
    final activeRoute = _routePoints.isNotEmpty
        ? _routePoints
        : [widget.riderLocation, widget.destinationLocation];

    final heading = _getHeadingAngle();
    double currentCamRot = 0.0;
    try {
      currentCamRot = _mapController.camera.rotation;
    } catch (_) {
      currentCamRot = 0.0;
    }
    final arrowScreenAngle = ((heading + currentCamRot) % 360.0) * math.pi / 180.0;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: widget.initialZoom,
            minZoom: 5.0,
            maxZoom: 18.0,
            interactionOptions: InteractionOptions(
              flags: widget.interactive ? InteractiveFlag.all : InteractiveFlag.none,
            ),
            onMapEvent: (event) {
              if (event is MapEventRotate || event is MapEventMove) {
                if (mounted) setState(() {});
              }
            },
            onMapReady: () {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (!mounted) return;
                if (widget.isNavigationMode) {
                  _recenterNavigation();
                } else {
                  _fitBounds();
                }
              });
            },
          ),
          children: [
            // OpenStreetMap Standard Tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.sarisari.store.app',
              maxNativeZoom: 19,
              tileBuilder: (context, tileWidget, tile) {
                return tileWidget;
              },
            ),

            // Road Route Polyline - follows public/legal roads
            PolylineLayer(
              polylines: [
                // 1. Soft Route Shadow/Casing
                Polyline(
                  points: activeRoute,
                  color: AppColors.primaryOrange.withValues(alpha: 0.35),
                  strokeWidth: 8.0,
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                ),
                // 2. High-contrast Public Road Route Line
                Polyline(
                  points: activeRoute,
                  color: AppColors.primaryOrange,
                  strokeWidth: 4.5,
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                ),
              ],
            ),

            // Map Markers: Customer Destination & Assigned Delivery Person
            MarkerLayer(
              markers: [
                // 1. Customer Destination Marker
                Marker(
                  point: widget.destinationLocation,
                  width: 140,
                  height: 72,
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: Colors.red.shade300, width: 1.2),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.home, size: 12, color: Colors.red),
                            SizedBox(width: 4),
                            Text(
                              'Destination',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 38,
                      ),
                    ],
                  ),
                ),

                // 2. Assigned Delivery Person Marker (Shows clear heading arrow along the road!)
                Marker(
                  point: widget.riderLocation,
                  width: 170,
                  height: 100,
                  rotate: true,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Rider Name & Role Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isOwner ? const Color(0xFFD97706) : AppColors.primaryOrange,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                widget.riderName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isOwner ? Icons.verified : Icons.badge,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    widget.riderRole,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Directional Navigation Puck with Visible Facing Arrow
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            // Outer glow ring
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (isOwner ? const Color(0xFFD97706) : AppColors.primaryOrange)
                                    .withValues(alpha: 0.25),
                              ),
                            ),
                            // Main navigation beacon
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isOwner ? const Color(0xFFD97706) : AppColors.primaryOrange,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 7,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                // Rotates strictly along the road forward direction
                                child: Transform.rotate(
                                  angle: arrowScreenAngle,
                                  child: const Icon(
                                    Icons.navigation,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                            // Small Role Mini-Badge (Storefront for Owner, Moto for Employee)
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 17,
                                height: 17,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isOwner ? const Color(0xFFD97706) : AppColors.primaryOrange,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    isOwner ? Icons.storefront : Icons.two_wheeler,
                                    size: 10,
                                    color: isOwner ? const Color(0xFFD97706) : AppColors.primaryOrange,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        // Road Route Summary Pill (Legal Public Road Routing - hidden in navigation mode)
        if (!widget.isNavigationMode && _routeResult != null && _routeResult!.formattedDistance.isNotEmpty)
          Positioned(
            top: widget.showControls ? 56 : 14,
            left: 14,
            child: Material(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(16),
              elevation: 3,
              shadowColor: Colors.black.withValues(alpha: 0.15),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _fitBounds,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.alt_route, color: AppColors.primaryOrange, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _routeResult!.formattedDistance,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.darkText,
                                ),
                              ),
                              if (_routeResult!.formattedDuration.isNotEmpty) ...[
                                const Text(' • ', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                Text(
                                  _routeResult!.formattedDuration,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.primaryOrange,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const Text(
                            'Public Roads (OSM)',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.secondaryText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Dedicated Floating "Re-center" Button in Navigation Mode (Theme Orange)
        if (widget.isNavigationMode)
          Positioned(
            right: 14,
            bottom: 195, // Floating clearly above the bottom navigation HUD
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              elevation: 5,
              shadowColor: Colors.black.withValues(alpha: 0.25),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _recenterNavigation,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.my_location, color: AppColors.primaryOrange, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Re-center',
                        style: TextStyle(
                          color: AppColors.primaryOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Controls overlay (zoom, center, fit) in Overview Mode
        if (!widget.isNavigationMode && widget.showControls && widget.interactive)
          Positioned(
            right: 12,
            bottom: 95,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapControlButton(
                  icon: Icons.crop_free,
                  tooltip: 'Fit route',
                  onTap: _fitBounds,
                ),
                const SizedBox(height: 6),
                _MapControlButton(
                  icon: Icons.two_wheeler,
                  tooltip: 'Center on rider',
                  onTap: _centerOnRider,
                ),
                const SizedBox(height: 6),
                _MapControlButton(
                  icon: Icons.home,
                  tooltip: 'Center on destination',
                  onTap: _centerOnDestination,
                ),
                const SizedBox(height: 6),
                _MapControlButton(
                  icon: Icons.add,
                  tooltip: 'Zoom in',
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 6),
                _MapControlButton(
                  icon: Icons.remove,
                  tooltip: 'Zoom out',
                  onTap: _zoomOut,
                ),
              ],
            ),
          ),

        // OpenStreetMap attribution badge
        Positioned(
          left: 8,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(icon, size: 18, color: AppColors.darkText),
          ),
        ),
      ),
    );
  }
}

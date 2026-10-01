import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';

class OsmDeliveryMap extends StatefulWidget {
  const OsmDeliveryMap({
    super.key,
    required this.riderLocation,
    required this.destinationLocation,
    this.riderName = 'Rider',
    this.riderRole = 'Employee',
    this.destinationAddress = 'Customer Address',
    this.showControls = true,
    this.interactive = true,
    this.initialZoom = 14.5,
  });

  final LatLng riderLocation;
  final LatLng destinationLocation;
  final String riderName;
  final String riderRole;
  final String destinationAddress;
  final bool showControls;
  final bool interactive;
  final double initialZoom;

  @override
  State<OsmDeliveryMap> createState() => _OsmDeliveryMapState();
}

class _OsmDeliveryMapState extends State<OsmDeliveryMap> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant OsmDeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Smoothly update map center when rider moves if they were changed
    if (oldWidget.riderLocation.latitude != widget.riderLocation.latitude ||
        oldWidget.riderLocation.longitude != widget.riderLocation.longitude) {
      // Optional: keep map alive or follow rider
    }
  }

  void _fitBounds() {
    final south = math.min(widget.riderLocation.latitude, widget.destinationLocation.latitude);
    final north = math.max(widget.riderLocation.latitude, widget.destinationLocation.latitude);
    final west = math.min(widget.riderLocation.longitude, widget.destinationLocation.longitude);
    final east = math.max(widget.riderLocation.longitude, widget.destinationLocation.longitude);

    final bounds = LatLngBounds(
      LatLng(south, west),
      LatLng(north, east),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
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
    // Calculate initial center between rider and destination
    final centerLat = (widget.riderLocation.latitude + widget.destinationLocation.latitude) / 2;
    final centerLng = (widget.riderLocation.longitude + widget.destinationLocation.longitude) / 2;
    final center = LatLng(centerLat, centerLng);

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
              flags: widget.interactive
                  ? InteractiveFlag.all
                  : InteractiveFlag.none,
            ),
            onMapReady: () {
              // Automatically fit bounds once map tiles are ready
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) _fitBounds();
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

            // Route Polyline between Rider and Customer Destination
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [
                    widget.riderLocation,
                    widget.destinationLocation,
                  ],
                  color: AppColors.primaryOrange.withValues(alpha: 0.85),
                  strokeWidth: 4.0,
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                ),
              ],
            ),

            // Map Markers: Destination & Delivery Person
            MarkerLayer(
              markers: [
                // 1. Customer Destination Marker
                Marker(
                  point: widget.destinationLocation,
                  width: 140,
                  height: 70,
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
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: Colors.red.shade300, width: 1),
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
                        size: 36,
                      ),
                    ],
                  ),
                ),

                // 2. Rider / Delivery Person Marker
                Marker(
                  point: widget.riderLocation,
                  width: 150,
                  height: 75,
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.riderName,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.riderRole,
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryOrange, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.two_wheeler,
                            color: AppColors.primaryOrange,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        // Controls overlay (zoom, center, fit)
        if (widget.showControls && widget.interactive)
          Positioned(
            right: 12,
            bottom: 12,
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
              color: Colors.white.withValues(alpha: 0.8),
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

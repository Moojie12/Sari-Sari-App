import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/laguna_bounds.dart';
import '../../core/theme/app_colors.dart';
import '../utils/top_notification.dart';

class LagunaAddressMapPicker extends StatefulWidget {
  const LagunaAddressMapPicker({
    super.key,
    required this.initialLocation,
    required this.isConfirmed,
    required this.onLocationChanged,
    required this.onLocationConfirmed,
    this.title = 'Delivery Location Pin',
    this.pinLabel = 'Delivery Destination',
    this.pinIcon = Icons.location_on,
    this.height = 300,
    this.allowFullScreen = true,
  });

  final LatLng initialLocation;
  final bool isConfirmed;
  final ValueChanged<LatLng> onLocationChanged;
  final void Function(LatLng location, LagunaGeocodedPlace? details) onLocationConfirmed;
  final String title;
  final String pinLabel;
  final IconData pinIcon;
  final double height;
  final bool allowFullScreen;

  @override
  State<LagunaAddressMapPicker> createState() => _LagunaAddressMapPickerState();
}

class _LagunaAddressMapPickerState extends State<LagunaAddressMapPicker> {
  late final MapController _mapController;
  late LatLng _currentLocation;
  late bool _isConfirmed;
  bool _isReverseGeocoding = false;
  String? _resolvedAddressPreview;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentLocation = LagunaBounds.clamp(widget.initialLocation);
    _isConfirmed = widget.isConfirmed;
  }

  @override
  void didUpdateWidget(covariant LagunaAddressMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLocation != oldWidget.initialLocation) {
      final clamped = LagunaBounds.clamp(widget.initialLocation);
      if ((clamped.latitude - _currentLocation.latitude).abs() > 0.0001 ||
          (clamped.longitude - _currentLocation.longitude).abs() > 0.0001) {
        setState(() {
          _currentLocation = clamped;
          _isConfirmed = widget.isConfirmed;
        });
        _mapController.move(_currentLocation, _mapController.camera.zoom);
      }
    }
    if (widget.isConfirmed != oldWidget.isConfirmed) {
      setState(() => _isConfirmed = widget.isConfirmed);
    }
  }

  /// Programmatically move the pin and map to a new location within Laguna
  void moveToLocation(LatLng newLocation, {double? zoom}) {
    if (!LagunaBounds.contains(newLocation)) {
      TopNotification.show(context, 'Location must be within Laguna province.', isError: true);
      return;
    }
    setState(() {
      _currentLocation = newLocation;
      _isConfirmed = false;
    });
    _mapController.move(newLocation, zoom ?? 15.5);
    widget.onLocationChanged(newLocation);
    _reverseGeocodePreview(newLocation);
  }

    Future<void> _onPinPlaced(LatLng point) async {
    setState(() {
      _currentLocation = point;
      _isReverseGeocoding = true;
      _isConfirmed = true;
    });
    widget.onLocationChanged(point);

    final place = await LagunaBounds.reverseGeocode(point);
    if (!mounted) return;

    setState(() {
      _isReverseGeocoding = false;
      if (place != null) {
        _resolvedAddressPreview = place.displayName;
      }
    });

    widget.onLocationConfirmed(point, place);
  }

  Future<void> _reverseGeocodePreview(LatLng point) async {
    setState(() => _isReverseGeocoding = true);
    final place = await LagunaBounds.reverseGeocode(point);
    if (mounted) {
      setState(() {
        _isReverseGeocoding = false;
        if (place != null) {
          _resolvedAddressPreview = place.displayName;
        }
      });
    }
  }

  Future<void> _confirmCurrentPin() async {
    if (!LagunaBounds.contains(_currentLocation)) {
      TopNotification.show(
        context,
        'Selected location is outside Laguna province. Please position the pin within Laguna.',
        isError: true,
      );
      return;
    }

    setState(() => _isReverseGeocoding = true);
    final place = await LagunaBounds.reverseGeocode(_currentLocation);
    if (!mounted) return;

    setState(() {
      _isReverseGeocoding = false;
      _isConfirmed = true;
      if (place != null) {
        _resolvedAddressPreview = place.displayName;
      }
    });

    widget.onLocationConfirmed(_currentLocation, place);
    TopNotification.show(
      context,
      'Pin location confirmed (${_currentLocation.latitude.toStringAsFixed(4)}, ${_currentLocation.longitude.toStringAsFixed(4)})',
    );
  }

  Future<void> _useCurrentGps() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) TopNotification.show(context, 'Location permission denied', isError: true);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) TopNotification.show(context, 'Location permissions are permanently denied', isError: true);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final point = LatLng(position.latitude, position.longitude);
      if (!LagunaBounds.contains(point)) {
        if (mounted) {
          TopNotification.show(
            context,
            'Your current GPS location is outside Laguna. Map location must be within Laguna.',
            isError: true,
          );
        }
        return;
      }

      moveToLocation(point, zoom: 16.5);
    } catch (e) {
      if (mounted) TopNotification.show(context, 'Unable to get GPS location: $e', isError: true);
    }
  }

  void _zoomIn() {
    final curZoom = _mapController.camera.zoom;
    if (curZoom < LagunaBounds.defaultMaxZoom) {
      _mapController.move(_mapController.camera.center, (curZoom + 1).clamp(LagunaBounds.defaultMinZoom, LagunaBounds.defaultMaxZoom));
    }
  }

  void _zoomOut() {
    final curZoom = _mapController.camera.zoom;
    if (curZoom > LagunaBounds.defaultMinZoom) {
      _mapController.move(_mapController.camera.center, (curZoom - 1).clamp(LagunaBounds.defaultMinZoom, LagunaBounds.defaultMaxZoom));
    }
  }

  void _openFullScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenMapPickerPage(
          initialLocation: _currentLocation,
          isConfirmed: _isConfirmed,
          pinLabel: widget.pinLabel,
          pinIcon: widget.pinIcon,
          onConfirmed: (loc, details) {
            setState(() {
              _currentLocation = loc;
              _isConfirmed = true;
              if (details != null) _resolvedAddressPreview = details.displayName;
            });
            _mapController.move(loc, 16.0);
            widget.onLocationConfirmed(loc, details);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Minimalist header with status indicator (No overflow)
        Row(
          children: [
            Icon(widget.pinIcon, size: 18, color: AppColors.primaryOrange),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _isConfirmed ? Colors.green.shade50 : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _isConfirmed ? Colors.green.shade300 : AppColors.primaryOrange.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isConfirmed ? Icons.check_circle : Icons.touch_app,
                    size: 11,
                    color: _isConfirmed ? Colors.green.shade700 : AppColors.primaryOrange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isConfirmed ? 'Pinned' : 'Tap Map',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _isConfirmed ? Colors.green.shade800 : AppColors.primaryOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Tap or drag the map pin to select exact location in Laguna. Confirm the pin before saving.',
          style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
        ),
        const SizedBox(height: 10),

        // Map container
        Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isConfirmed ? Colors.green.shade400 : AppColors.primaryOrange.withValues(alpha: 0.5),
              width: _isConfirmed ? 1.5 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentLocation,
                  initialZoom: 15.0,
                  minZoom: LagunaBounds.defaultMinZoom,
                  maxZoom: LagunaBounds.defaultMaxZoom,
                  cameraConstraint: const CameraConstraint.unconstrained(),
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture && !LagunaBounds.contains(camera.center)) {
                      final clamped = LagunaBounds.clamp(camera.center);
                      _mapController.move(clamped, camera.zoom);
                    }
                  },
                  onTap: (tapPosition, point) {
                    if (LagunaBounds.contains(point)) {
                      _onPinPlaced(point);
                    } else {
                      TopNotification.show(
                        context,
                        'Please tap within Laguna Province boundaries.',
                        isError: true,
                      );
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.sarisari.store.app',
                    maxNativeZoom: 19,
                  ),

                  // Pin Marker
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation,
                        width: 140,
                        height: 70,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            // Dragging gesture adjustment
                            final camera = _mapController.camera;
                            final currentPt = camera.latLngToScreenOffset(_currentLocation);
                            final newPt = Offset(currentPt.dx + details.delta.dx, currentPt.dy + details.delta.dy);
                            final newCoord = camera.offsetToCrs(newPt);
                            if (LagunaBounds.contains(newCoord)) {
                              setState(() {
                                _currentLocation = newCoord;
                                _isConfirmed = false;
                              });
                              widget.onLocationChanged(newCoord);
                            }
                          },
                          onPanEnd: (_) {
                            _onPinPlaced(_currentLocation);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: _isConfirmed ? Colors.green : AppColors.primaryOrange,
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isConfirmed ? Icons.check : Icons.touch_app,
                                      size: 11,
                                      color: _isConfirmed ? Colors.green : AppColors.primaryOrange,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      widget.pinLabel,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: _isConfirmed ? Colors.green.shade900 : AppColors.darkText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Icon(
                                Icons.location_on,
                                size: 36,
                                color: _isConfirmed ? Colors.green.shade700 : AppColors.primaryOrange,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Top Laguna Scope Tag
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined, size: 12, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Laguna Only',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Control buttons overlay (Zoom & GPS)
              Positioned(
                top: 8,
                right: 8,
                child: Column(
                  children: [
                    if (widget.allowFullScreen)
                      _MapIconButton(
                        icon: Icons.fullscreen,
                        tooltip: 'Full Screen',
                        onTap: _openFullScreen,
                      ),
                    if (widget.allowFullScreen) const SizedBox(height: 6),
                    _MapIconButton(
                      icon: Icons.my_location,
                      tooltip: 'My Location',
                      onTap: _useCurrentGps,
                    ),
                    const SizedBox(height: 6),
                    _MapIconButton(
                      icon: Icons.add,
                      tooltip: 'Zoom In',
                      onTap: _zoomIn,
                    ),
                    const SizedBox(height: 4),
                    _MapIconButton(
                      icon: Icons.remove,
                      tooltip: 'Zoom Out',
                      onTap: _zoomOut,
                    ),
                  ],
                ),
              ),

              // Bottom Coordinate bar
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pin_drop, size: 13, color: Colors.white70),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${_currentLocation.latitude.toStringAsFixed(5)}, ${_currentLocation.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace'),
                        ),
                      ),
                      if (_isReverseGeocoding)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Sleek minimalist confirmation button
        SizedBox(
          width: double.infinity,
          height: 38,
          child: OutlinedButton.icon(
            onPressed: _confirmCurrentPin,
            icon: Icon(
              _isConfirmed ? Icons.check_circle : Icons.pin_drop_outlined,
              size: 16,
              color: _isConfirmed ? Colors.green.shade700 : AppColors.primaryOrange,
            ),
            label: Text(
              _isConfirmed ? 'Pin Location Confirmed' : 'Confirm Selected Pin',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: _isConfirmed ? Colors.green.shade800 : AppColors.primaryOrange,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: _isConfirmed ? Colors.green.shade50 : Colors.white,
              side: BorderSide(
                color: _isConfirmed ? Colors.green.shade300 : AppColors.primaryOrange,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),

        if (_resolvedAddressPreview != null && _resolvedAddressPreview!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Detected: $_resolvedAddressPreview',
            style: const TextStyle(fontSize: 11, color: AppColors.secondaryText, fontStyle: FontStyle.italic),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.darkText),
        ),
      ),
    );
  }
}

/// Full screen view of the Laguna location picker for high-precision placement
class _FullScreenMapPickerPage extends StatefulWidget {
  const _FullScreenMapPickerPage({
    required this.initialLocation,
    required this.isConfirmed,
    required this.pinLabel,
    required this.pinIcon,
    required this.onConfirmed,
  });

  final LatLng initialLocation;
  final bool isConfirmed;
  final String pinLabel;
  final IconData pinIcon;
  final void Function(LatLng location, LagunaGeocodedPlace? details) onConfirmed;

  @override
  State<_FullScreenMapPickerPage> createState() => _FullScreenMapPickerPageState();
}

class _FullScreenMapPickerPageState extends State<_FullScreenMapPickerPage> {
  late final MapController _mapController;
  late LatLng _currentLocation;
  bool _isConfirmed = false;
  bool _isGeocoding = false;
  String? _addressText;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentLocation = LagunaBounds.clamp(widget.initialLocation);
    _isConfirmed = widget.isConfirmed;
    _reverseGeocode(_currentLocation);
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isGeocoding = true);
    final place = await LagunaBounds.reverseGeocode(point);
    if (mounted) {
      setState(() {
        _isGeocoding = false;
        if (place != null) _addressText = place.displayName;
      });
    }
  }

  Future<void> _useCurrentGps() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final pt = LatLng(pos.latitude, pos.longitude);
      if (LagunaBounds.contains(pt)) {
        setState(() {
          _currentLocation = pt;
          _isConfirmed = false;
        });
        _mapController.move(pt, 16.5);
        _reverseGeocode(pt);
      } else {
        if (mounted) TopNotification.show(context, 'Current GPS is outside Laguna', isError: true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exact Location Picker (Laguna)', style: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.darkText),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: AppColors.primaryOrange),
            onPressed: _useCurrentGps,
            tooltip: 'My Location',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 16.0,
              minZoom: LagunaBounds.defaultMinZoom,
              maxZoom: LagunaBounds.defaultMaxZoom,
              cameraConstraint: const CameraConstraint.unconstrained(),
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && !LagunaBounds.contains(camera.center)) {
                  final clamped = LagunaBounds.clamp(camera.center);
                  _mapController.move(clamped, camera.zoom);
                }
              },
              onTap: (tapPosition, point) {
                if (LagunaBounds.contains(point)) {
                  setState(() {
                    _currentLocation = point;
                    _isConfirmed = false;
                  });
                  _reverseGeocode(point);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sarisari.store.app',
                maxNativeZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    width: 150,
                    height: 80,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
                            ],
                            border: Border.all(color: _isConfirmed ? Colors.green : AppColors.primaryOrange, width: 1.2),
                          ),
                          child: Text(
                            widget.pinLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _isConfirmed ? Colors.green.shade800 : AppColors.primaryOrange,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Icon(
                          Icons.location_on,
                          size: 42,
                          color: _isConfirmed ? Colors.green.shade700 : AppColors.primaryOrange,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Bottom Sheet with address details & confirm button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, -3)),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(widget.pinIcon, size: 20, color: AppColors.primaryOrange),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Selected Location (Laguna, PH)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkText),
                          ),
                        ),
                        if (_isGeocoding)
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryOrange)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _addressText ?? 'Resolving address details...',
                      style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Coordinates: ${_currentLocation.latitude.toStringAsFixed(6)}, ${_currentLocation.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.primaryOrange, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final place = await LagunaBounds.reverseGeocode(_currentLocation);
                          widget.onConfirmed(_currentLocation, place);
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_circle, size: 20),
                        label: const Text('CONFIRM THIS LOCATION', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
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

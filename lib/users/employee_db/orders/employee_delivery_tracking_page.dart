import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/delivery_tracking_service.dart';
import '../../../core/services/navigation_voice_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/osm_delivery_map.dart';
import '../../customer_db/purchases/customer_order_model.dart';
import '../messages/employee_chat_page.dart';
import '../messages/employee_messages_controller.dart';
import 'employee_orders_controller.dart';

class EmployeeDeliveryTrackingPage extends StatefulWidget {
  const EmployeeDeliveryTrackingPage({
    super.key,
    required this.order,
  });

  final CustomerOrder order;

  @override
  State<EmployeeDeliveryTrackingPage> createState() => _EmployeeDeliveryTrackingPageState();
}

class _EmployeeDeliveryTrackingPageState extends State<EmployeeDeliveryTrackingPage> {
  final DeliveryTrackingService _trackingService = DeliveryTrackingService.instance;
  final EmployeeOrderController _ordersController = EmployeeOrderController.instance;
  final NavigationVoiceService _voiceService = NavigationVoiceService();

  StreamSubscription<DeliveryTrackingData?>? _trackingSub;
  DeliveryTrackingData? _currentTracking;
  bool _isGpsActive = false;
  bool _isLoadingGps = false;
  bool _isGpsBannerExpanded = false;
  bool _isBottomCardExpanded = false;
  bool _isNavigating = false;
  int _currentNavStepIndex = 0;
  RoadRouteResult? _routeResult;
  LatLng _riderPos = DeliveryTrackingService.storeLocation;
  LatLng _destPos = DeliveryTrackingService.storeLocation;

  // Voice guidance state (Waze / Google Maps style)
  bool _hasSpoken100mWarning = false;
  bool _hasSpokenImmediateTurn = false;
  int _lastVoiceStepIndex = -1;

  @override
  void initState() {
    super.initState();
    _initTracking();
    _fetchInitialRoute();
  }

  Future<void> _fetchInitialRoute() async {
    try {
      final res = await _trackingService.getRoadRouteResult(_riderPos, _destPos);
      if (mounted) {
        setState(() => _routeResult = res);
      }
    } catch (_) {}
  }

  void _startNavigation() {
    final steps = _routeResult?.steps ?? [];
    int initialIndex = 0;
    // If first step is 'depart' and there's a subsequent step, point directly to upcoming maneuver
    if (steps.length > 1 && steps[0].maneuverType.toLowerCase() == 'depart') {
      initialIndex = 1;
    }

    setState(() {
      _isNavigating = true;
      _currentNavStepIndex = initialIndex;
      _hasSpoken100mWarning = false;
      _hasSpokenImmediateTurn = false;
      _lastVoiceStepIndex = initialIndex;
      _isGpsBannerExpanded = false;
      _isBottomCardExpanded = false;
    });

    _voiceService.init();

    // Voice announcement when starting navigation
    if (steps.isNotEmpty && initialIndex < steps.length) {
      final step = steps[initialIndex];
      final dist = Geolocator.distanceBetween(
        _riderPos.latitude,
        _riderPos.longitude,
        step.location.latitude,
        step.location.longitude,
      ).round();
      _voiceService.speak('Starting navigation. In $dist meters, ${step.instruction}.');
    } else {
      _voiceService.speak('Starting navigation. Follow the route to customer delivery destination.');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.navigation, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Turn-by-turn navigation started with voice guidance.'),
          ],
        ),
        backgroundColor: AppColors.primaryOrange,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _stopNavigation() {
    _voiceService.stop();
    setState(() {
      _isNavigating = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Navigation paused. Press "Start Guide" to resume anytime.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Automated GPS proximity tracking (like Waze & Google Maps)
  /// Triggers voice at ~100m before turn, at the turn (<30m), and auto-advances to the next step
  void _updateNavigationProgress(LatLng riderPos) {
    if (!_isNavigating) return;
    final steps = _routeResult?.steps ?? [];
    if (steps.isEmpty || _currentNavStepIndex >= steps.length) return;

    final currentStep = steps[_currentNavStepIndex];

    // Distance in meters from rider to the current step's maneuver location
    final distToManeuver = Geolocator.distanceBetween(
      riderPos.latitude,
      riderPos.longitude,
      currentStep.location.latitude,
      currentStep.location.longitude,
    );

    // Reset flags if step index changed
    if (_currentNavStepIndex != _lastVoiceStepIndex) {
      _lastVoiceStepIndex = _currentNavStepIndex;
      _hasSpoken100mWarning = false;
      _hasSpokenImmediateTurn = false;
    }

    // 1. Advance warning voice prompt (~70m - 130m before the turn)
    // E.g. "In 100 meters, turn right onto Rizal Boulevard"
    if (distToManeuver <= 130 && distToManeuver >= 35 && !_hasSpoken100mWarning) {
      _hasSpoken100mWarning = true;
      final spoken = NavigationVoiceService.formatSpokenInstruction(
        maneuverType: currentStep.maneuverType,
        modifier: currentStep.modifier,
        streetName: currentStep.streetName,
        distanceMeters: distToManeuver.round(),
        isImmediate: false,
      );
      _voiceService.speak(spoken);
    }

    // 2. Immediate turn voice prompt (< 30m before/at the turn)
    // E.g. "Turn right now onto Rizal Boulevard"
    if (distToManeuver < 30 && !_hasSpokenImmediateTurn) {
      _hasSpokenImmediateTurn = true;
      final spoken = NavigationVoiceService.formatSpokenInstruction(
        maneuverType: currentStep.maneuverType,
        modifier: currentStep.modifier,
        streetName: currentStep.streetName,
        distanceMeters: distToManeuver.round(),
        isImmediate: true,
      );
      _voiceService.speak(spoken);
    }

    // 3. Automated step advancement:
    // When the rider gets within 18 meters of the maneuver or passes it towards the next waypoint
    if (_currentNavStepIndex < steps.length - 1) {
      final nextStep = steps[_currentNavStepIndex + 1];
      final distToNext = Geolocator.distanceBetween(
        riderPos.latitude,
        riderPos.longitude,
        nextStep.location.latitude,
        nextStep.location.longitude,
      );

      final hasCompletedManeuver = distToManeuver <= 18 || (distToNext < distToManeuver && distToManeuver < 40);

      if (hasCompletedManeuver) {
        setState(() {
          _currentNavStepIndex++;
          _lastVoiceStepIndex = _currentNavStepIndex;
          _hasSpoken100mWarning = false;
          _hasSpokenImmediateTurn = false;
        });

        // Announce upcoming continuation if there's substantial distance to next maneuver
        final newStep = steps[_currentNavStepIndex];
        final newDist = Geolocator.distanceBetween(
          riderPos.latitude,
          riderPos.longitude,
          newStep.location.latitude,
          newStep.location.longitude,
        );

        if (newDist > 160) {
          _voiceService.speak('Continue on ${newStep.displayStreet} for ${(newDist / 100).round() * 100} meters.');
        }
      }
    } else {
      // Final step: Arrive at customer address
      if (distToManeuver <= 25 && !_hasSpokenImmediateTurn) {
        _hasSpokenImmediateTurn = true;
        _voiceService.speak('You have arrived at the customer delivery destination.');
      }
    }
  }

  IconData _getManeuverIcon(NavigationStep step) {
    final type = step.maneuverType.toLowerCase();
    final mod = step.modifier?.toLowerCase() ?? '';
    if (type == 'arrive') return Icons.place;
    if (type == 'depart') return Icons.navigation;
    if (type == 'roundabout') return Icons.roundabout_right;
    if (mod.contains('sharp left')) return Icons.turn_sharp_left;
    if (mod.contains('sharp right')) return Icons.turn_sharp_right;
    if (mod.contains('slight left')) return Icons.turn_slight_left;
    if (mod.contains('slight right')) return Icons.turn_slight_right;
    if (mod.contains('uturn')) return Icons.u_turn_left;
    if (mod.contains('left')) return Icons.turn_left;
    if (mod.contains('right')) return Icons.turn_right;
    return Icons.straight;
  }

  Future<void> _initTracking() async {
    // 1. Resolve destination
    if (widget.order.deliveryLatitude != null && widget.order.deliveryLongitude != null) {
      _destPos = LatLng(widget.order.deliveryLatitude!, widget.order.deliveryLongitude!);
    } else {
      _destPos = await _trackingService.geocodeAddress(widget.order.deliveryAddress);
    }

    // 2. Read initial or cached tracking
    final cached = _trackingService.getCachedTracking(widget.order.orderId);
    if (cached != null) {
      _currentTracking = cached;
      _riderPos = cached.riderLatLng;
      _destPos = cached.destinationLatLng;
      _isGpsActive = cached.isTrackingActive;
    } else {
      _riderPos = DeliveryTrackingService.storeLocation;
    }

    if (mounted) setState(() {});

    // 3. Listen to real-time updates
    _trackingSub = _trackingService.streamTracking(widget.order.orderId).listen((data) {
      if (data != null && mounted) {
        setState(() {
          _currentTracking = data;
          _riderPos = data.riderLatLng;
          _destPos = data.destinationLatLng;
        });
        _updateNavigationProgress(data.riderLatLng);
      }
    });

    // If order is out for delivery, automatically start device GPS broadcasting
    if (widget.order.status == OrderStatus.outForDelivery) {
      _toggleGpsSharing(true);
    }
  }

  @override
  void dispose() {
    _voiceService.stop();
    _trackingSub?.cancel();
    super.dispose();
  }

  Future<void> _toggleGpsSharing(bool enable) async {
    setState(() => _isLoadingGps = true);

    if (enable) {
      final success = await _trackingService.startDeviceGpsBroadcasting(widget.order.orderId);
      if (mounted) {
        setState(() {
          _isGpsActive = success;
          _isLoadingGps = false;
        });
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not access device GPS. Please enable Location/GPS permission in your device settings.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } else {
      _trackingService.stopDeviceGpsBroadcasting(widget.order.orderId);
      if (mounted) {
        setState(() {
          _isGpsActive = false;
          _isLoadingGps = false;
        });
      }
    }
  }

  void _markAsDelivered() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Order Delivery'),
        content: Text(
          'Mark Order #${widget.order.displayOrderId} as Delivered? Live GPS tracking will stop.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _voiceService.stop();
              _ordersController.updateOrderStatus(widget.order.orderId, OrderStatus.delivered);
              _trackingService.stopTracking(widget.order.orderId);
              if (mounted) {
                Navigator.pop(context); // Return to order details
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Order #${widget.order.displayOrderId} marked as Delivered!'),
                    backgroundColor: AppColors.primaryOrange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Delivered'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final riderName = _currentTracking?.deliveryPersonName ?? widget.order.deliveryPersonName ?? 'Delivery Rider';
    final riderRole = _currentTracking?.deliveryPersonRole ?? widget.order.deliveryPersonRole ?? 'Employee';
    final isOutForDelivery = widget.order.status == OrderStatus.outForDelivery;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'Order #${widget.order.displayOrderId}',
              style: const TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Assigned to $riderName ($riderRole)',
              style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.darkText),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: AppColors.primaryOrange),
            tooltip: 'Sync Device GPS',
            onPressed: () => _toggleGpsSharing(true),
          ),
        ],
      ),
      body: Stack(
        children: [
          // OpenStreetMap Full View
          Positioned.fill(
            child: OsmDeliveryMap(
              riderLocation: _riderPos,
              destinationLocation: _destPos,
              routePoints: _routeResult?.points,
              riderName: riderName,
              riderRole: riderRole,
              destinationAddress: widget.order.deliveryAddress ?? 'Customer Address',
              showControls: true,
              interactive: true,
              isNavigationMode: _isNavigating,
              onRouteCalculated: (res) {
                if (mounted) {
                  setState(() => _routeResult = res);
                }
              },
            ),
          ),

          // TURN-BY-TURN NAVIGATION MODE: TOP BANNER
          if (_isNavigating) ...[
            Builder(
              builder: (context) {
                final steps = _routeResult?.steps ?? [];
                final currentStep = steps.isNotEmpty && _currentNavStepIndex < steps.length
                    ? steps[_currentNavStepIndex]
                    : null;
                final nextStep = steps.isNotEmpty && _currentNavStepIndex + 1 < steps.length
                    ? steps[_currentNavStepIndex + 1]
                    : null;

                final double? liveDistMeters = currentStep != null
                    ? Geolocator.distanceBetween(
                        _riderPos.latitude,
                        _riderPos.longitude,
                        currentStep.location.latitude,
                        currentStep.location.longitude,
                      )
                    : null;

                final isTurnImminent = liveDistMeters != null && liveDistMeters < 30;

                return Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: Material(
                    color: const Color(0xFF0F172A), // Deep Slate Navigation Background
                    borderRadius: BorderRadius.circular(18),
                    elevation: 8,
                    shadowColor: Colors.black.withValues(alpha: 0.35),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isTurnImminent ? const Color(0xFFF59E0B) : AppColors.primaryOrange,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (isTurnImminent ? Colors.amber : AppColors.primaryOrange).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                currentStep != null
                                    ? _getManeuverIcon(currentStep)
                                    : Icons.navigation,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        liveDistMeters != null
                                            ? (liveDistMeters < 30
                                                ? 'Turn now'
                                                : (liveDistMeters < 1000
                                                    ? 'In ${liveDistMeters.round()} m'
                                                    : 'In ${(liveDistMeters / 1000).toStringAsFixed(1)} km'))
                                            : (currentStep?.formattedDistance ?? ''),
                                        style: TextStyle(
                                          color: isTurnImminent
                                              ? const Color(0xFFFDE68A)
                                              : const Color(0xFFFFB366),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_routeResult?.formattedDuration.isNotEmpty == true) ...[
                                      const Text(' • ', style: TextStyle(color: Colors.grey)),
                                      Text(
                                        '${_routeResult?.formattedDuration} left',
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isTurnImminent
                                      ? (currentStep != null
                                          ? '${currentStep.instruction.replaceFirst(RegExp(r'^(In \d+ m,?\s*)', caseSensitive: false), '')} now'
                                          : 'Turn now')
                                      : (currentStep?.instruction ?? 'Proceed to customer address'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (nextStep != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Then: ${nextStep.instruction}',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Compact Vertical Action Controls (Eliminates horizontal overflow completely!)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Exit Guide Button (Circle)
                              Material(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _stopNavigation,
                                  child: const Tooltip(
                                    message: 'Exit Guide',
                                    child: Padding(
                                      padding: EdgeInsets.all(7),
                                      child: Icon(Icons.close, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Voice Mute / Unmute Button (Circle)
                              Material(
                                color: _voiceService.isMuted
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : AppColors.primaryOrange.withValues(alpha: 0.35),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () {
                                    setState(() {
                                      _voiceService.toggleMute();
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          _voiceService.isMuted
                                              ? 'Voice guidance muted'
                                              : 'Voice guidance unmuted',
                                        ),
                                        duration: const Duration(seconds: 1),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: AppColors.primaryOrange,
                                      ),
                                    );
                                  },
                                  child: Tooltip(
                                    message: _voiceService.isMuted ? 'Unmute Voice' : 'Mute Voice',
                                    child: Padding(
                                      padding: const EdgeInsets.all(7),
                                      child: Icon(
                                        _voiceService.isMuted ? Icons.volume_off : Icons.volume_up,
                                        color: _voiceService.isMuted ? Colors.white60 : const Color(0xFFFFB366),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // TURN-BY-TURN NAVIGATION MODE: BOTTOM CONTROLS (Automated GPS HUD - Orange Theme)
            Builder(
              builder: (context) {
                final steps = _routeResult?.steps ?? [];

                return Positioned(
                  bottom: 16,
                  left: 14,
                  right: 14,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    elevation: 6,
                    shadowColor: Colors.black.withValues(alpha: 0.2),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.lightPeach,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.navigation_rounded, color: AppColors.primaryOrange, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          steps.isNotEmpty
                                              ? 'Maneuver ${_currentNavStepIndex + 1} of ${steps.length}'
                                              : 'Auto-Navigating',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkText),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.lightPeach,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Auto GPS',
                                            style: TextStyle(
                                              color: AppColors.primaryOrange,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.order.deliveryAddress ?? 'Customer Destination',
                                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (_routeResult?.formattedDistance.isNotEmpty == true)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _routeResult!.formattedDistance,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppColors.darkText,
                                      ),
                                    ),
                                    Text(
                                      _routeResult!.formattedDuration,
                                      style: const TextStyle(
                                        color: AppColors.primaryOrange,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _stopNavigation,
                                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                                  label: const Text('Stop Guide'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red.shade700,
                                    side: BorderSide(color: Colors.red.shade300),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _markAsDelivered,
                                  icon: const Icon(Icons.check_circle_outline, size: 18),
                                  label: const Text('Mark Delivered'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryOrange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ] else ...[
            // REGULAR OVERVIEW MODE: TOP GPS STATUS (Collapsible)
            if (!_isGpsBannerExpanded)
              Positioned(
                top: 14,
                left: 14,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  elevation: 3,
                  shadowColor: Colors.black.withValues(alpha: 0.15),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _isGpsBannerExpanded = true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isGpsActive ? AppColors.primaryOrange : Colors.grey,
                              boxShadow: _isGpsActive
                                  ? [BoxShadow(color: AppColors.primaryOrange.withValues(alpha: 0.5), blurRadius: 4, spreadRadius: 1)]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _isGpsActive ? 'Live GPS Active' : 'GPS Inactive',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _isGpsActive ? AppColors.primaryOrange : AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.secondaryText),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 6,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isGpsActive ? AppColors.primaryOrange : Colors.grey,
                            boxShadow: _isGpsActive
                                ? [BoxShadow(color: AppColors.primaryOrange.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 2)]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isGpsActive ? 'Live Device GPS Active' : 'Location Sharing Inactive',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _isGpsActive ? AppColors.primaryOrange : AppColors.secondaryText,
                                ),
                              ),
                              Text(
                                _isGpsActive
                                    ? 'Coordinates: ${_riderPos.latitude.toStringAsFixed(4)}, ${_riderPos.longitude.toStringAsFixed(4)}'
                                    : 'Turn on switch to broadcast GPS',
                                style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                              ),
                            ],
                          ),
                        ),
                        if (_isLoadingGps)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Switch(
                            value: _isGpsActive,
                            activeTrackColor: AppColors.lightPeach,
                            activeThumbColor: AppColors.primaryOrange,
                            onChanged: isOutForDelivery ? (val) => _toggleGpsSharing(val) : null,
                          ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: AppColors.secondaryText),
                          tooltip: 'Hide GPS details',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => setState(() => _isGpsBannerExpanded = false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // REGULAR OVERVIEW MODE: BOTTOM CONTROLS
            if (!_isBottomCardExpanded) ...[
              // Collapsed Order Actions Pill (Left)
              Positioned(
                bottom: 16,
                left: 14,
                right: 145, // Leaves room for the Start Guide button on the right
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  elevation: 4,
                  shadowColor: Colors.black.withValues(alpha: 0.18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => setState(() => _isBottomCardExpanded = true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 13,
                            backgroundColor: AppColors.lightBackground,
                            child: Icon(Icons.person, size: 15, color: AppColors.primaryOrange),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.order.customerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.darkText,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text(
                                  'Tap for actions',
                                  style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_up, size: 16, color: AppColors.secondaryText),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // PROMINENT "START GUIDE" BUTTON (Right)
              Positioned(
                bottom: 16,
                right: 14,
                child: Material(
                  color: AppColors.primaryOrange,
                  borderRadius: BorderRadius.circular(24),
                  elevation: 4,
                  shadowColor: Colors.black.withValues(alpha: 0.22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _startNavigation,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.navigation, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Start Guide',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ] else
              // Expanded Order Details & Actions Card
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
                        // Customer Header with Minimize button
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: AppColors.lightBackground,
                              child: Icon(Icons.person, color: AppColors.primaryOrange),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.order.customerName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    widget.order.deliveryAddress ?? 'No delivery address provided',
                                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryOrange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.order.status.label,
                                style: const TextStyle(
                                  color: AppColors.primaryOrange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.secondaryText),
                              tooltip: 'Hide actions',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () => setState(() => _isBottomCardExpanded = false),
                            ),
                          ],
                        ),
                        const Divider(height: 18),

                        // Actions: Start Guide, Chat, Deliver Button
                        Row(
                          children: [
                            // Start Navigation Guide
                            ElevatedButton.icon(
                              onPressed: _startNavigation,
                              icon: const Icon(Icons.navigation, size: 16),
                              label: const Text('Start Guide'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryOrange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                elevation: 0,
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Chat with customer
                            OutlinedButton.icon(
                              onPressed: () {
                                final messagesController = EmployeeMessagesController.instance;
                                final recipientId = widget.order.userId ??
                                    'cust_${widget.order.customerName.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';
                                final thread = messagesController.getOrCreateThread(
                                  recipientId: recipientId,
                                  name: widget.order.customerName,
                                  role: 'Customer',
                                  isCustomer: true,
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EmployeeChatPage(
                                      recipientId: thread.recipient.id,
                                      recipientName: thread.recipient.name,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.chat_bubble_outline, size: 16),
                              label: const Text('Chat'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.darkText,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Complete Delivery Button
                            if (isOutForDelivery)
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _markAsDelivered,
                                  icon: const Icon(Icons.check_circle_outline, size: 18),
                                  label: const Text('Delivered', style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryOrange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    elevation: 0,
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Status: ${widget.order.status.label}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryText),
                                  ),
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
        ],
      ),
    );
  }
}

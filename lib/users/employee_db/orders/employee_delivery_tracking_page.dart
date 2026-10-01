import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/delivery_tracking_service.dart';
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

  StreamSubscription<DeliveryTrackingData?>? _trackingSub;
  DeliveryTrackingData? _currentTracking;
  bool _isGpsActive = false;
  bool _isSimulating = false;
  bool _isLoadingGps = false;
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
      }
    });

    // If order is out for delivery, automatically start device GPS broadcasting
    if (widget.order.status == OrderStatus.outForDelivery) {
      _toggleGpsSharing(true);
    }
  }

  @override
  void dispose() {
    _trackingSub?.cancel();
    if (_isSimulating) {
      _trackingService.stopSimulatedMovement(widget.order.orderId);
    }
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
              content: Text('Could not access device GPS. You can use simulation mode for testing.'),
              behavior: SnackBarBehavior.floating,
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

  void _toggleSimulation() {
    if (_isSimulating) {
      _trackingService.stopSimulatedMovement(widget.order.orderId);
      setState(() => _isSimulating = false);
    } else {
      _trackingService.startSimulatedMovement(
        orderId: widget.order.orderId,
        start: _riderPos,
        destination: _destPos,
        stepInterval: const Duration(seconds: 2),
        totalSteps: 15,
      );
      setState(() => _isSimulating = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Simulated movement started. Rider position will update every 2s.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
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
              _ordersController.updateOrderStatus(widget.order.orderId, OrderStatus.delivered);
              _trackingService.stopTracking(widget.order.orderId);
              if (mounted) {
                Navigator.pop(context); // Return to order details
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Order #${widget.order.displayOrderId} marked as Delivered!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
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
          // Simulation toggle for testing
          IconButton(
            icon: Icon(
              _isSimulating ? Icons.stop_circle : Icons.play_circle_outline,
              color: _isSimulating ? Colors.red : AppColors.primaryOrange,
            ),
            tooltip: _isSimulating ? 'Stop simulation' : 'Test simulate movement',
            onPressed: _toggleSimulation,
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
              riderName: riderName,
              riderRole: riderRole,
              destinationAddress: widget.order.deliveryAddress ?? 'Customer Address',
              showControls: true,
              interactive: true,
            ),
          ),

          // Top GPS Status Banner
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isGpsActive ? Colors.green : Colors.grey,
                      boxShadow: _isGpsActive
                          ? [BoxShadow(color: Colors.green.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 2)]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isGpsActive
                              ? (_isSimulating ? 'Simulating Live Movement' : 'GPS Location Sharing Active')
                              : 'Location Sharing Inactive',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _isGpsActive ? Colors.green.shade800 : AppColors.secondaryText,
                          ),
                        ),
                        Text(
                          '${_riderPos.latitude.toStringAsFixed(4)}, ${_riderPos.longitude.toStringAsFixed(4)}',
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
                      activeTrackColor: Colors.green.shade200,
                      activeThumbColor: Colors.green,
                      onChanged: isOutForDelivery ? (val) => _toggleGpsSharing(val) : null,
                    ),
                ],
              ),
            ),
          ),

          // Bottom Floating Customer & Delivery Action Card
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Customer Header
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.order.status.label,
                          style: const TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Actions: Chat, Deliver Button
                  Row(
                    children: [
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
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Chat'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.darkText,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Complete Delivery Button
                      if (isOutForDelivery)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _markAsDelivered,
                            icon: const Icon(Icons.check_circle_outline, size: 20),
                            label: const Text('Mark as Delivered', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
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
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/laguna_bounds.dart';
import '../../../core/theme/app_colors.dart';
import '../../owner_db/profile/shop_settings_controller.dart';
import 'customer_order_model.dart';

class CustomerPickupStoreMapWidget extends StatefulWidget {
  const CustomerPickupStoreMapWidget({super.key, required this.order});
  final CustomerOrder order;

  @override
  State<CustomerPickupStoreMapWidget> createState() => _CustomerPickupStoreMapWidgetState();
}

class _CustomerPickupStoreMapWidgetState extends State<CustomerPickupStoreMapWidget> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
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

  void _recenterStore() {
    final storePos = ShopSettingsController.instance.storeLocation;
    _mapController.move(storePos, 16.0);
  }

  void _openFullScreenMap(BuildContext context, LatLng storePos, String storeAddress) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenStoreMapPage(
          storePos: storePos,
          storeAddress: storeAddress,
          order: widget.order,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ShopSettingsController.instance,
      builder: (context, _) {
        final settings = ShopSettingsController.instance;
        final storePos = settings.storeLocation;
        final storeAddress = settings.storeAddress;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ready for Pickup banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ready for Pickup!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkText),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Your order is ready. Please proceed to Tindahan ni Eca to collect your items.',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Store Map Card
            Container(
              height: 250,
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
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: storePos,
                      initialZoom: 16.0,
                      minZoom: LagunaBounds.defaultMinZoom,
                      maxZoom: LagunaBounds.defaultMaxZoom,
                      cameraConstraint: CameraConstraint.containCenter(bounds: LagunaBounds.bounds),
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
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
                            point: storePos,
                            width: 170,
                            height: 84,
                            alignment: Alignment.topCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 5),
                                    ],
                                    border: Border.all(color: AppColors.primaryOrange, width: 1.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.store, size: 13, color: AppColors.primaryOrange),
                                      SizedBox(width: 4),
                                      Text(
                                        'Tindahan ni Eca (Store)',
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
                                  color: AppColors.primaryOrange,
                                  size: 42,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Map controls overlay
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Column(
                      children: [
                        _MapBtn(
                          icon: Icons.fullscreen,
                          onTap: () => _openFullScreenMap(context, storePos, storeAddress),
                        ),
                        const SizedBox(height: 6),
                        _MapBtn(
                          icon: Icons.my_location,
                          onTap: _recenterStore,
                        ),
                        const SizedBox(height: 6),
                        _MapBtn(icon: Icons.add, onTap: _zoomIn),
                        const SizedBox(height: 4),
                        _MapBtn(icon: Icons.remove, onTap: _zoomOut),
                      ],
                    ),
                  ),

                  // Laguna Scope badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.storefront, size: 12, color: AppColors.primaryOrange),
                          const SizedBox(width: 4),
                          Text(
                            'Store Location (Laguna)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Complete store address details card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.pin_drop, size: 16, color: AppColors.primaryOrange),
                      SizedBox(width: 6),
                      Text(
                        'Complete Store Address:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.secondaryText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    storeAddress,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.darkText),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.my_location, size: 12, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'GPS Coordinates: ${storePos.latitude.toStringAsFixed(5)}, ${storePos.longitude.toStringAsFixed(5)}',
                        style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.green.shade800, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MapBtn extends StatelessWidget {
  const _MapBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

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
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.darkText),
        ),
      ),
    );
  }
}

/// Full screen view of the store pickup location
class _FullScreenStoreMapPage extends StatelessWidget {
  const _FullScreenStoreMapPage({
    required this.storePos,
    required this.storeAddress,
    required this.order,
  });

  final LatLng storePos;
  final String storeAddress;
  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Pickup Location', style: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.darkText),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: storePos,
              initialZoom: 16.5,
              minZoom: LagunaBounds.defaultMinZoom,
              maxZoom: LagunaBounds.defaultMaxZoom,
              cameraConstraint: CameraConstraint.containCenter(bounds: LagunaBounds.bounds),
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
                    point: storePos,
                    width: 180,
                    height: 90,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6),
                            ],
                            border: Border.all(color: AppColors.primaryOrange, width: 2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.store, size: 14, color: AppColors.primaryOrange),
                              SizedBox(width: 4),
                              Text(
                                'Tindahan ni Eca',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.darkText),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Icon(Icons.location_on, color: AppColors.primaryOrange, size: 48),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Bottom Details card
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pickup Store Location',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.darkText),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Text(
                          'Ready for Pickup',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(storeAddress, style: const TextStyle(fontSize: 13, color: AppColors.darkText)),
                  const SizedBox(height: 6),
                  Text(
                    'Order ID: ${order.displayOrderId}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryText),
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

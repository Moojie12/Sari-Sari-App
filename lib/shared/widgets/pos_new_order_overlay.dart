import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/firebase_notification_service.dart';
import '../../core/services/pos_audio_service.dart';
import '../../core/theme/app_colors.dart';
import '../../users/customer_db/purchases/customer_order_model.dart';
import '../../users/employee_db/orders/employee_order_details_page.dart';
import '../../users/employee_db/orders/employee_orders_controller.dart';

/// Interactive in-app overlay alert shown when a new order is received
/// on the active POS and Admin screens.
class PosNewOrderOverlay extends StatefulWidget {
  const PosNewOrderOverlay({
    super.key,
    required this.order,
    required this.onDismiss,
    required this.onViewOrder,
  });

  final CustomerOrder order;
  final VoidCallback onDismiss;
  final VoidCallback onViewOrder;

  /// Global static helper to show the interactive alert overlay on top of any active screen
  static OverlayEntry? _currentEntry;

  static void showGlobal(CustomerOrder order) {
    // Play alert sound & chimes
    PosAudioService.playOrderChime();

    final overlayState = FirebaseNotificationService.navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    // Remove existing overlay if present
    dismissGlobal();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => PosNewOrderOverlay(
        order: order,
        onDismiss: () => dismissGlobal(),
        onViewOrder: () {
          dismissGlobal();
          final nav = FirebaseNotificationService.navigatorKey.currentState;
          if (nav != null) {
            nav.push(
              MaterialPageRoute(
                builder: (_) => EmployeeOrderDetailsPage(
                  order: order,
                  controller: EmployeeOrderController.instance,
                ),
              ),
            );
          }
        },
      ),
    );

    _currentEntry = entry;
    overlayState.insert(entry);
  }

  static void dismissGlobal() {
    try {
      _currentEntry?.remove();
    } catch (_) {}
    _currentEntry = null;
  }

  @override
  State<PosNewOrderOverlay> createState() => _PosNewOrderOverlayState();
}

class _PosNewOrderOverlayState extends State<PosNewOrderOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();

    // Auto-dismiss after 20 seconds if unattended
    _autoDismissTimer = Timer(const Duration(seconds: 20), () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() {
    _autoDismissTimer?.cancel();
    _animController.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final totalAmountStr = '₱${order.totalAmount.toStringAsFixed(2)}';
    final itemCount = order.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final isDelivery = order.orderType == OrderType.delivery;

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                constraints: const BoxConstraints(maxWidth: 550),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryOrange.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withValues(alpha: 0.25),
                      blurRadius: 18,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top banner header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryOrange,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'NEW ORDER RECEIVED!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isDelivery ? 'Delivery' : 'Pickup',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: _dismiss,
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Order #${order.displayOrderId}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkText,
                                ),
                              ),
                              Text(
                                totalAmountStr,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryOrange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 15, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  order.customerName.isNotEmpty
                                      ? order.customerName
                                      : 'Online Customer',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$itemCount item${itemCount > 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _dismiss,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey.shade700,
                                    side: BorderSide(color: Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  child: const Text('Dismiss'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _autoDismissTimer?.cancel();
                                    widget.onViewOrder();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryOrange,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  icon: const Icon(Icons.receipt_long, size: 18),
                                  label: const Text(
                                    'View Order',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

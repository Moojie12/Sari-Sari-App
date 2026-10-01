import 'package:flutter/material.dart';
import '../../../core/services/delivery_tracking_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../customer_db/purchases/customer_order_model.dart';
import 'employee_orders_controller.dart';

class AssignDeliveryPersonSheet extends StatefulWidget {
  const AssignDeliveryPersonSheet({
    super.key,
    required this.order,
    required this.controller,
    this.onAssigned,
  });

  final CustomerOrder order;
  final EmployeeOrderController controller;
  final VoidCallback? onAssigned;

  static Future<bool?> show(
    BuildContext context, {
    required CustomerOrder order,
    required EmployeeOrderController controller,
    VoidCallback? onAssigned,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AssignDeliveryPersonSheet(
        order: order,
        controller: controller,
        onAssigned: onAssigned,
      ),
    );
  }

  @override
  State<AssignDeliveryPersonSheet> createState() => _AssignDeliveryPersonSheetState();
}

class _AssignDeliveryPersonSheetState extends State<AssignDeliveryPersonSheet> {
  final DeliveryTrackingService _trackingService = DeliveryTrackingService.instance;
  List<DeliveryPerson> _staffList = [];
  DeliveryPerson? _selectedPerson;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);
    try {
      final staff = await _trackingService.getAvailableDeliveryStaff();
      if (!mounted) return;
      setState(() {
        _staffList = staff;
        // Default select previous delivery person or the first one in list
        if (widget.order.deliveryPersonId != null) {
          _selectedPerson = staff.where((s) => s.id == widget.order.deliveryPersonId).firstOrNull;
        }
        _selectedPerson ??= staff.isNotEmpty ? staff.first : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmAssignment() async {
    if (_selectedPerson == null) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.controller.assignDeliveryPersonAndSetOutForDelivery(
        orderId: widget.order.orderId,
        deliveryPerson: _selectedPerson!,
      );

      if (mounted) {
        Navigator.pop(context, true);
        widget.onAssigned?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #${widget.order.displayOrderId} assigned to ${_selectedPerson!.name} and is now Out for Delivery.'),
            backgroundColor: AppColors.primaryOrange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign delivery person: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assign Delivery Person',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Order #${widget.order.displayOrderId} • Out for Delivery',
                      style: const TextStyle(
                        color: AppColors.primaryOrange,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Notice requirement
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select who will deliver this order. Live OpenStreetMap GPS tracking will begin once assigned.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7A5400)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Destination summary
          if (widget.order.deliveryAddress != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delivery Destination:',
                          style: TextStyle(fontSize: 11, color: AppColors.secondaryText, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          widget.order.deliveryAddress!,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkText),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          const Text(
            'Available Staff (Owner / Employees)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkText),
          ),
          const SizedBox(height: 10),

          // Staff selection list
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_staffList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No Owner or Employee accounts found.',
                  style: TextStyle(color: AppColors.secondaryText),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _staffList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final staff = _staffList[index];
                  final isSelected = _selectedPerson?.id == staff.id;
                  final isOwner = staff.role.toLowerCase() == 'owner';

                  return InkWell(
                    onTap: () {
                      setState(() => _selectedPerson = staff);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryOrange.withValues(alpha: 0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryOrange : AppColors.borderColor,
                          width: isSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: isOwner ? Colors.amber.shade100 : Colors.blue.shade100,
                            child: Icon(
                              isOwner ? Icons.storefront : Icons.badge,
                              color: isOwner ? Colors.orange.shade800 : Colors.blue.shade800,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Name and Role
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  staff.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: AppColors.darkText,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isOwner
                                            ? Colors.amber.withValues(alpha: 0.2)
                                            : Colors.blue.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        staff.role,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isOwner ? Colors.orange.shade900 : Colors.blue.shade800,
                                        ),
                                      ),
                                    ),
                                    if (staff.phone != null && staff.phone!.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        staff.phone!,
                                        style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Radio indicator
                          Radio<String>(
                            value: staff.id,
                            groupValue: _selectedPerson?.id,
                            activeColor: AppColors.primaryOrange,
                            onChanged: (val) {
                              setState(() => _selectedPerson = staff);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 20),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_isSubmitting || _selectedPerson == null) ? null : _confirmAssignment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Confirm & Start Delivery',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
            ),
          ),
        ],
      ),
    );
  }
}

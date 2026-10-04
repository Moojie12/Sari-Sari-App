import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../shared/utils/gcash_ocr_helper.dart';
import '../../../shared/widgets/product_image.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/delivery_tracking_service.dart';
import '../../../core/services/rate_limiter_service.dart';
import '../../../core/services/stock_reservation_service.dart';
import '../../owner_db/profile/shop_settings_controller.dart';
import 'package:sari_sari/users/customer_db/customer_cart_controller.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_controller.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
import '../../employee_db/employee_inventory_controller.dart';
import '../profile/customer_address_model.dart';
import '../profile/customer_address_controller.dart';
import '../profile/customer_add_edit_address_page.dart';
import '../profile/customer_profile_controller.dart';
import '../../../shared/utils/top_notification.dart';
import 'package:sari_sari/users/customer_db/checkout/customer_order_confirmation_page.dart';

class CustomerCheckoutPage extends StatefulWidget {
  const CustomerCheckoutPage({
    super.key,
    required this.cartController,
    required this.orderController,
  });

  final CustomerCartController cartController;
  final CustomerOrderController orderController;

  @override
  State<CustomerCheckoutPage> createState() => _CustomerCheckoutPageState();
}

class _CustomerCheckoutPageState extends State<CustomerCheckoutPage> {
  OrderType _orderType = OrderType.pickup;
  PaymentMethod _paymentMethod = PaymentMethod.cashOnDelivery;
  double? _calculatedDistanceMeters;

  CustomerAddress? _selectedAddress;
  File? _gcashProofFile;
  String? _gcashProofBase64;
  bool _isVerifyingOcr = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickGcashScreenshot() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );

    if (image == null) return;

    if (mounted) setState(() => _isVerifyingOcr = true);

    try {
      final bytes = await image.readAsBytes();
      final fileSizeBytes = bytes.length;

      // 1. File Size Check (5MB Limit)
      if (fileSizeBytes > GcashOcrHelper.maxFileSizeBytes) {
        final mb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
        if (mounted) {
          setState(() => _isVerifyingOcr = false);
          TopNotification.show(
            context,
            'Image size ($mb MB) exceeds 5MB limit. Please upload a smaller screenshot.',
            isError: true,
          );
        }
        return;
      }

      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      String? extractedRef;

      // 2. OCR Text Recognition on Mobile Platforms (Non-Web)
      if (!kIsWeb) {
        List<OcrTextItem> ocrItems = [];
        try {
          final ocrService = MlKitOcrService();
          ocrItems = await ocrService.processImage(image.path);
          ocrService.dispose();
        } catch (e) {
          debugPrint('[OCR Service Exception]: $e');
        }

        if (ocrItems.isNotEmpty) {
          final validation = GcashOcrHelper.validateReceipt(
            items: ocrItems,
            fileSizeBytes: fileSizeBytes,
          );

          if (!validation.isValid) {
            if (mounted) {
              setState(() => _isVerifyingOcr = false);
              TopNotification.show(
                context,
                validation.errorMessage ?? 'Uploaded image is not a valid GCash payment receipt.',
                isError: true,
              );
            }
            return;
          }

          extractedRef = validation.extractedRefNumber;
        }
      }

      if (mounted) {
        setState(() {
          _isVerifyingOcr = false;
          _gcashProofFile = File(image.path);
          _gcashProofBase64 = base64Image;
        });
        TopNotification.show(
          context,
          extractedRef != null
              ? 'GCash Receipt verified! Ref #: ${GcashOcrHelper.formatRefNumber(extractedRef)}'
              : 'GCash Payment Receipt screenshot attached!',
        );
      }
    } catch (e) {
      debugPrint('[GCash Screenshot Upload Exception]: $e');
      if (mounted) {
        setState(() => _isVerifyingOcr = false);
        TopNotification.show(
          context,
          'Failed to verify receipt image. Please select a clear GCash screenshot.',
          isError: true,
        );
      }
    } finally {
      if (mounted && _isVerifyingOcr) {
        setState(() => _isVerifyingOcr = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedAddress = CustomerAddressController.instance.defaultAddress;
    _updateDistanceAndFee();
  }

  Future<void> _updateDistanceAndFee() async {
    if (_selectedAddress == null) {
      if (mounted) setState(() => _calculatedDistanceMeters = null);
      return;
    }
    try {
      final destCoords = await DeliveryTrackingService.instance.geocodeAddress(_selectedAddress!.address);
      final storeLoc = DeliveryTrackingService.storeLocation;
      final distMeters = Geolocator.distanceBetween(
        storeLoc.latitude,
        storeLoc.longitude,
        destCoords.latitude,
        destCoords.longitude,
      );
      if (mounted) {
        setState(() {
          _calculatedDistanceMeters = distMeters;
        });
      }
      return;
    } catch (_) {}
    if (mounted) {
      setState(() {
        _calculatedDistanceMeters = 500;
      });
    }
  }

  double get _deliveryFee {
    if (_calculatedDistanceMeters != null) {
      return ShopSettingsController.instance.calculateDeliveryFee(_calculatedDistanceMeters!);
    }
    return ShopSettingsController.instance.calculateDeliveryFee(500);
  }

  String get _deliveryFeeLabel {
    if (_calculatedDistanceMeters != null && _calculatedDistanceMeters! > 0) {
      final km = _calculatedDistanceMeters! / 1000.0;
      if (km < 1) {
        return 'Delivery Fee (${_calculatedDistanceMeters!.round()} m)';
      }
      return 'Delivery Fee (${km.toStringAsFixed(1)} km)';
    }
    return 'Delivery Fee';
  }

  double get _total => widget.cartController.totalAmount + (_orderType == OrderType.delivery ? _deliveryFee : 0);

  Future<void> _handlePlaceOrder() async {
    if (_orderType == OrderType.delivery && _selectedAddress == null) {
      TopNotification.show(context, 'Please select a delivery address', isError: true);
      return;
    }

    if (_paymentMethod == PaymentMethod.gCash) {
      final storeQr = ShopSettingsController.instance.gcashQrUrl;
      final isGcashAvailable = storeQr != null && storeQr.trim().isNotEmpty && !storeQr.contains('wikimedia.org');

      if (!isGcashAvailable) {
        TopNotification.show(
          context,
          'GCash payment is currently unavailable because the store owner has not set a store GCash QR code yet. Please choose Cash on Delivery.',
          isError: true,
        );
        return;
      }

      if (_gcashProofBase64 == null || _gcashProofBase64!.isEmpty) {
        TopNotification.show(
          context,
          'Please attach your GCash payment receipt screenshot before placing your order.',
          isError: true,
        );
        return;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Place Order', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to place this order for ₱${_total.toStringAsFixed(2)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Get current user ID for the order / rate limiter
    final currentUser = AuthService().currentUser;
    final userId = currentUser?.uid ?? 'guest';

    // Rate Limit Check
    final rateLimit = await RateLimiterService.instance.checkAndRecord(
      RateLimitAction.checkout,
      userId,
    );

    if (!rateLimit.isAllowed) {
      if (mounted) {
        TopNotification.show(
          context,
          rateLimit.message ?? 'Too many checkout attempts. Please wait before trying again.',
          isError: true,
        );
      }
      return;
    }

    // Price & Stock Re-validation against live inventory
    final liveProducts = EmployeeInventoryController.instance.products;
    for (final cartItem in widget.cartController.items) {
      if (!cartItem.isDeal) {
        try {
          final liveProd = liveProducts.firstWhere((p) => p.id == cartItem.product.id);
          if (liveProd.price != cartItem.unitPrice) {
            if (mounted) {
              TopNotification.show(
                context,
                'Price updated for "${cartItem.displayName}". Please review your cart.',
                isError: true,
              );
            }
            return;
          }
        } catch (_) {}
      }
    }

    final orderId = widget.orderController.generateOrderNumber();
    final items = widget.cartController.items.map<CustomerOrderItem>((item) {
      if (item.isDeal && item.deal != null) {
        return CustomerOrderItem(
          productId: item.id,
          productName: '${item.deal!.title} (Promo Bundle)',
          price: item.deal!.salePrice,
          capital: item.deal!.items.fold(0.0, (sum, i) => sum + (i.originalPrice * 0.7 * i.quantity)),
          quantity: item.quantity,
          subtotal: item.subtotal,
        );
      }
      return CustomerOrderItem(
        productId: item.product.id,
        productName: item.product.name,
        price: item.unitPrice,
        capital: item.product.capital,
        quantity: item.quantity,
        subtotal: item.subtotal,
      );
    }).toList();

    // Reserve stock with 10-minute fallback timer
    final reservedItems = <ReservedItem>[];
    for (final item in widget.cartController.items) {
      if (item.isDeal && item.deal != null) {
        for (final dealItem in item.deal!.items) {
          reservedItems.add(
            ReservedItem(
              productId: dealItem.productId,
              productName: dealItem.productName,
              quantity: (dealItem.quantity * item.quantity).toDouble(),
            ),
          );
        }
      } else {
        reservedItems.add(
          ReservedItem(
            productId: item.product.id,
            productName: item.product.name,
            quantity: item.quantity.toDouble(),
          ),
        );
      }
    }

    StockReservationService.instance.reserveStock(
      reservationId: orderId,
      userId: userId,
      items: reservedItems,
    );

    LatLng? destCoords;
    if (_orderType == OrderType.delivery && _selectedAddress?.address != null) {
      destCoords = await DeliveryTrackingService.instance.geocodeAddress(_selectedAddress!.address);
    }

    final order = CustomerOrder(
      customerName: CustomerProfileController.instance.profile.fullName.isEmpty ? 'Customer' : CustomerProfileController.instance.profile.fullName,
      orderId: orderId,
      orderDate: DateTime.now(),
      items: items,
      orderType: _orderType,
      paymentMethod: _paymentMethod,
      paymentStatus: _paymentMethod == PaymentMethod.cashOnDelivery ? PaymentStatus.unpaid : PaymentStatus.paid,
      deliveryAddress: _orderType == OrderType.delivery ? _selectedAddress?.address : null,
      subtotal: widget.cartController.totalAmount,
      deliveryFee: _orderType == OrderType.delivery ? _deliveryFee : 0,
      totalAmount: _total,
      status: OrderStatus.pending,
      userId: userId, // Set the user ID
      deliveryLatitude: destCoords?.latitude,
      deliveryLongitude: destCoords?.longitude,
      paymentProofUrl: _paymentMethod == PaymentMethod.gCash ? _gcashProofBase64 : null,
    );

    widget.orderController.placeOrder(order);
    widget.cartController.clearCart();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CustomerOrderConfirmationPage(order: order),
        ),
      );
    }
  }

  void _showAddressModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddressSelectionModal(
        addresses: CustomerAddressController.instance.addresses,
        selectedAddress: _selectedAddress,
        onAddressSelected: (address) {
          setState(() => _selectedAddress = address);
          _updateDistanceAndFee();
          Navigator.pop(context);
        },
        onAddNewAddress: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CustomerAddEditAddressPage()),
          ).then((_) {
            if (_selectedAddress == null) {
              setState(() => _selectedAddress = CustomerAddressController.instance.defaultAddress);
            }
            _updateDistanceAndFee();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CustomerAddressController.instance,
      builder: (context, _) {
        if (_selectedAddress != null && 
            !CustomerAddressController.instance.addresses.any((a) => a.id == _selectedAddress!.id)) {
          _selectedAddress = CustomerAddressController.instance.defaultAddress;
        }

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            title: const Text(
              'Checkout',
              style: TextStyle(color: AppColors.darkText, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: AppColors.darkText),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: 'Order Summary'),
                const SizedBox(height: 12),
                _OrderSummaryList(items: widget.cartController.items),
                const SizedBox(height: 32),
                
                _SectionHeader(title: 'Order Type'),
                const SizedBox(height: 12),
                _OrderTypeSelector(
                  selectedType: _orderType,
                  onChanged: (type) => setState(() => _orderType = type),
                ),
                const SizedBox(height: 32),

                if (_orderType == OrderType.delivery) ...[
                  _SectionHeader(title: 'Delivery Information'),
                  const SizedBox(height: 12),
                  if (_selectedAddress == null)
                    _AddLocationButton(onTap: _showAddressModal)
                  else
                    _DeliveryInfoCard(
                      address: _selectedAddress!,
                      onTap: _showAddressModal,
                    ),
                  const SizedBox(height: 32),
                ],

                _SectionHeader(title: 'Payment Method'),
                const SizedBox(height: 12),
                _PaymentMethodSelector(
                  selectedMethod: _paymentMethod,
                  onChanged: (method) => setState(() => _paymentMethod = method),
                ),
                if (_paymentMethod == PaymentMethod.gCash) ...[
                  const SizedBox(height: 16),
                  _GcashPaymentProofUploadCard(
                    proofFile: _gcashProofFile,
                    proofBase64: _gcashProofBase64,
                    onPickScreenshot: _pickGcashScreenshot,
                    totalAmount: _total,
                    isVerifyingOcr: _isVerifyingOcr,
                  ),
                ],
                const SizedBox(height: 32),

                _SectionHeader(title: 'Price Summary'),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: ShopSettingsController.instance,
                  builder: (context, _) {
                    return _PriceSummaryCard(
                      subtotal: widget.cartController.totalAmount,
                      deliveryFee: _orderType == OrderType.delivery ? _deliveryFee : 0,
                      total: _total,
                      deliveryFeeLabel: _deliveryFeeLabel,
                    );
                  },
                ),
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handlePlaceOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('PLACE ORDER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
    );
  }
}

class _OrderSummaryList extends StatelessWidget {
  const _OrderSummaryList({required this.items});
  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.displayName} x${item.quantity}',
                        style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w600),
                      ),
                      if (item.isDeal && item.dealInclusions != null)
                        Text(
                          item.dealInclusions!,
                          style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                Text(
                  '₱${item.subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OrderTypeSelector extends StatelessWidget {
  const _OrderTypeSelector({required this.selectedType, required this.onChanged});
  final OrderType selectedType;
  final ValueChanged<OrderType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SelectableCard(
            title: 'Pickup',
            isSelected: selectedType == OrderType.pickup,
            onTap: () => onChanged(OrderType.pickup),
            icon: Icons.storefront,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SelectableCard(
            title: 'Delivery',
            isSelected: selectedType == OrderType.delivery,
            onTap: () => onChanged(OrderType.delivery),
            icon: Icons.delivery_dining,
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({required this.selectedMethod, required this.onChanged});
  final PaymentMethod selectedMethod;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PaymentOption(
          title: 'Cash on Delivery',
          isSelected: selectedMethod == PaymentMethod.cashOnDelivery,
          onTap: () => onChanged(PaymentMethod.cashOnDelivery),
          icon: Icons.money,
        ),
        const SizedBox(height: 12),
        _PaymentOption(
          title: 'GCash',
          isSelected: selectedMethod == PaymentMethod.gCash,
          onTap: () => onChanged(PaymentMethod.gCash),
          icon: Icons.account_balance_wallet,
        ),
      ],
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({required this.title, required this.isSelected, required this.onTap, required this.icon});
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryOrange.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText,
            )),
          ],
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({required this.title, required this.isSelected, required this.onTap, required this.icon});
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.darkText : AppColors.secondaryText,
            )),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.primaryOrange),
          ],
        ),
      ),
    );
  }
}

class _DeliveryInfoCard extends StatelessWidget {
  const _DeliveryInfoCard({required this.address, required this.onTap});
  final CustomerAddress address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: AppColors.primaryOrange),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(address.type, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    address.address,
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.placeholderColor),
          ],
        ),
      ),
    );
  }
}

class _AddLocationButton extends StatelessWidget {
  const _AddLocationButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_location_alt_outlined),
      label: const Text('Add Delivery Location'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryOrange,
        side: const BorderSide(color: AppColors.primaryOrange),
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _AddressSelectionModal extends StatelessWidget {
  const _AddressSelectionModal({
    required this.addresses,
    required this.selectedAddress,
    required this.onAddressSelected,
    required this.onAddNewAddress,
  });

  final List<CustomerAddress> addresses;
  final CustomerAddress? selectedAddress;
  final ValueChanged<CustomerAddress> onAddressSelected;
  final VoidCallback onAddNewAddress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Delivery Address',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...addresses.map((address) {
            final isSelected = selectedAddress?.id == address.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => onAddressSelected(address),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryOrange.withValues(alpha: 0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primaryOrange : AppColors.borderColor,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        address.type == 'Home' ? Icons.home_outlined : Icons.work_outline,
                        color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              address.type,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppColors.primaryOrange : AppColors.darkText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              address.address,
                              style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: AppColors.primaryOrange),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onAddNewAddress,
            icon: const Icon(Icons.add),
            label: const Text('Add New Address'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryOrange,
              side: const BorderSide(color: AppColors.primaryOrange),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceSummaryCard extends StatelessWidget {
  const _PriceSummaryCard({
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    this.deliveryFeeLabel = 'Delivery Fee',
  });

  final double subtotal;
  final double deliveryFee;
  final double total;
  final String deliveryFeeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _PriceRow(label: 'Subtotal', value: subtotal),
          const SizedBox(height: 8),
          _PriceRow(label: deliveryFeeLabel, value: deliveryFee),
          const Divider(height: 24),
          _PriceRow(label: 'Total', value: total, isBold: true),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.value, this.isBold = false});
  final String label;
  final double value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          color: isBold ? AppColors.darkText : AppColors.secondaryText,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: isBold ? 18 : 14,
        )),
        Text('₱${value.toStringAsFixed(2)}', style: TextStyle(
          color: isBold ? AppColors.primaryOrange : AppColors.darkText,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: isBold ? 18 : 14,
        )),
      ],
    );
  }
}

class _GcashPaymentProofUploadCard extends StatelessWidget {
  const _GcashPaymentProofUploadCard({
    required this.proofFile,
    required this.proofBase64,
    required this.onPickScreenshot,
    required this.totalAmount,
    this.isVerifyingOcr = false,
  });

  final File? proofFile;
  final String? proofBase64;
  final VoidCallback onPickScreenshot;
  final double totalAmount;
  final bool isVerifyingOcr;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ShopSettingsController.instance,
      builder: (context, _) {
        final storeQr = ShopSettingsController.instance.gcashQrUrl;
        final isGcashAvailable = storeQr != null && storeQr.trim().isNotEmpty && !storeQr.contains('wikimedia.org');

        if (!isGcashAvailable) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'GCash Payment Currently Unavailable',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'The store owner has not set a store GCash QR code yet. GCash payment is temporarily unavailable. Please choose Cash on Delivery to complete your order.',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade800, height: 1.4),
                ),
              ],
            ),
          );
        }

        final hasProof = (proofBase64 != null && proofBase64!.isNotEmpty) || proofFile != null;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.lightPeach.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasProof ? Colors.green.shade400 : AppColors.primaryOrange,
              width: hasProof ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasProof ? Icons.check_circle_rounded : Icons.add_a_photo_outlined,
                    color: hasProof ? Colors.green : AppColors.primaryOrange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasProof ? 'GCash Receipt Screenshot Verified' : 'Attach GCash Payment Screenshot * (Max 5MB)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: hasProof ? Colors.green.shade900 : AppColors.darkText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Please scan the store GCash QR code below using your GCash App to pay ₱${totalAmount.toStringAsFixed(2)}, then attach your payment receipt screenshot before placing your order:',
                style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 12),
              Center(
                child: ProductImage(
                  image: storeQr,
                  height: 160,
                  width: 160,
                  borderRadius: 12,
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text('Scan & Pay via GCash App', style: TextStyle(fontSize: 11, color: AppColors.secondaryText, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 14),
              if (hasProof) ...[
                if (proofBase64 != null && proofBase64!.isNotEmpty)
                  ProductImage(
                    image: proofBase64!,
                    height: 160,
                    width: double.infinity,
                    borderRadius: 12,
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isVerifyingOcr ? null : onPickScreenshot,
                    icon: isVerifyingOcr
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryOrange))
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(isVerifyingOcr ? 'Verifying Receipt (OCR)...' : 'Change Payment Screenshot'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryOrange,
                      side: const BorderSide(color: AppColors.primaryOrange),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isVerifyingOcr ? null : onPickScreenshot,
                    icon: isVerifyingOcr
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text(isVerifyingOcr ? 'Verifying Receipt (OCR)...' : 'Upload Payment Screenshot'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

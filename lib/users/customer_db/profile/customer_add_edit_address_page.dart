import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/laguna_location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import 'customer_address_controller.dart';
import 'customer_address_model.dart';

class CustomerAddEditAddressPage extends StatefulWidget {
  const CustomerAddEditAddressPage({super.key, this.address});
  final CustomerAddress? address;

  @override
  State<CustomerAddEditAddressPage> createState() => _CustomerAddEditAddressPageState();
}

class _CustomerAddEditAddressPageState extends State<CustomerAddEditAddressPage> {
  final _formKey = GlobalKey<FormState>();

  // Address Type
  static const List<String> _addressTypes = ['Home', 'Work', 'Office', 'School', 'Other'];
  String _selectedType = 'Home';
  late final TextEditingController _customTypeController;

  // Laguna Location API state
  final LagunaLocationService _locationService = LagunaLocationService.instance;
  List<LagunaCity> _cities = [];
  List<LagunaBarangay> _barangays = [];

  LagunaCity? _selectedCity;
  LagunaBarangay? _selectedBarangay;

  bool _isLoadingCities = true;
  bool _isLoadingBarangays = false;
  String? _cityLoadError;
  String? _barangayLoadError;

  // Street / House / Landmark details
  late final TextEditingController _streetDetailsController;
  bool _isDefault = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    final existing = widget.address;

    if (existing != null) {
      if (_addressTypes.contains(existing.type)) {
        _selectedType = existing.type;
        _customTypeController = TextEditingController();
      } else {
        _selectedType = 'Other';
        _customTypeController = TextEditingController(text: existing.type);
      }
      _streetDetailsController = TextEditingController(text: existing.streetDetails ?? '');
      _isDefault = existing.isDefault;
    } else {
      _selectedType = 'Home';
      _customTypeController = TextEditingController();
      _streetDetailsController = TextEditingController();
      _isDefault = false;
    }

    _loadCities();
  }

  @override
  void dispose() {
    _customTypeController.dispose();
    _streetDetailsController.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    setState(() {
      _isLoadingCities = true;
      _cityLoadError = null;
    });

    try {
      final cities = await _locationService.getLagunaCities();
      if (!mounted) return;

      setState(() {
        _cities = cities;
        _isLoadingCities = false;
      });

      // If editing an existing address, try to match the city
      if (widget.address != null) {
        final existing = widget.address!;
        LagunaCity? matchedCity;
        if (existing.cityCode != null) {
          matchedCity = cities.where((c) => c.code == existing.cityCode).firstOrNull;
        }
        if (matchedCity == null && existing.city != null) {
          matchedCity = cities.where((c) =>
              c.name.toLowerCase() == existing.city!.toLowerCase() ||
              c.name.toLowerCase().contains(existing.city!.toLowerCase())).firstOrNull;
        }

        if (matchedCity != null) {
          _onCityChanged(matchedCity, initialBarangayCode: existing.barangayCode, initialBarangayName: existing.barangay);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingCities = false;
        _cityLoadError = 'Failed to load cities: $e';
      });
    }
  }

  Future<void> _onCityChanged(LagunaCity? city, {String? initialBarangayCode, String? initialBarangayName}) async {
    if (city == null) return;

    setState(() {
      _selectedCity = city;
      _selectedBarangay = null;
      _barangays = [];
      _isLoadingBarangays = true;
      _barangayLoadError = null;
    });

    try {
      final barangays = await _locationService.getBarangays(city.code);
      if (!mounted) return;

      LagunaBarangay? matchedBarangay;
      if (initialBarangayCode != null) {
        matchedBarangay = barangays.where((b) => b.code == initialBarangayCode).firstOrNull;
      }
      if (matchedBarangay == null && initialBarangayName != null) {
        matchedBarangay = barangays.where((b) =>
            b.name.toLowerCase() == initialBarangayName.toLowerCase()).firstOrNull;
      }

      setState(() {
        _barangays = barangays;
        _selectedBarangay = matchedBarangay;
        _isLoadingBarangays = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingBarangays = false;
        _barangayLoadError = 'Failed to load barangays for ${city.name}';
      });
    }
  }

  String _buildFormattedAddress() {
    final parts = <String>[];
    final street = _streetDetailsController.text.trim();
    if (street.isNotEmpty) {
      parts.add(street);
    }
    if (_selectedBarangay != null) {
      parts.add('Brgy. ${_selectedBarangay!.name}');
    }
    if (_selectedCity != null) {
      parts.add(_selectedCity!.name);
    }
    parts.add('Laguna');
    parts.add('Philippines');

    return parts.join(', ');
  }

  Future<void> _save() async {
    setState(() {
      _autovalidateMode = AutovalidateMode.onUserInteraction;
    });

    if (!_formKey.currentState!.validate()) {
      TopNotification.show(context, 'Please complete all required fields', isError: true);
      return;
    }

    if (_selectedCity == null) {
      TopNotification.show(context, 'Please select your City / Municipality', isError: true);
      return;
    }

    if (_selectedBarangay == null) {
      TopNotification.show(context, 'Please select your Barangay', isError: true);
      return;
    }

    final isEditing = widget.address != null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isEditing ? 'Confirm Address Update' : 'Confirm New Address',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText),
        ),
        content: Text(
          isEditing
              ? 'Are you sure you want to save changes to this address?'
              : 'Are you sure you want to add this new delivery address?',
          style: const TextStyle(color: AppColors.darkText),
        ),
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
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isEditing ? 'Save' : 'Add', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final type = _selectedType == 'Other'
        ? (_customTypeController.text.trim().isEmpty ? 'Other' : _customTypeController.text.trim())
        : _selectedType;

    final street = _streetDetailsController.text.trim();
    final fullAddress = _buildFormattedAddress();

    if (widget.address == null) {
      final newAddress = CustomerAddress(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        address: fullAddress,
        province: LagunaLocationService.provinceName,
        city: _selectedCity!.name,
        cityCode: _selectedCity!.code,
        barangay: _selectedBarangay!.name,
        barangayCode: _selectedBarangay!.code,
        streetDetails: street.isNotEmpty ? street : null,
        isDefault: _isDefault,
      );
      CustomerAddressController.instance.addAddress(newAddress);
      TopNotification.show(context, 'Address added successfully');
    } else {
      final updated = widget.address!.copyWith(
        type: type,
        address: fullAddress,
        province: LagunaLocationService.provinceName,
        city: _selectedCity!.name,
        cityCode: _selectedCity!.code,
        barangay: _selectedBarangay!.name,
        barangayCode: _selectedBarangay!.code,
        streetDetails: street.isNotEmpty ? street : null,
        isDefault: _isDefault,
      );
      CustomerAddressController.instance.updateAddress(updated);
      TopNotification.show(context, 'Address updated successfully');
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.address != null;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Address' : 'Add New Address',
          style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkText),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidateMode,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Scope banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined, color: AppColors.primaryOrange, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Coverage Scope: Laguna, Philippines',
                            style: TextStyle(
                              color: AppColors.darkText,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Exclusive to all towns and cities in Laguna using the official PSGC Location API.',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 1. Address Type Dropdown
              const Text('Address Type / Label',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.bookmark_outline, color: AppColors.primaryOrange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                ),
                items: _addressTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type, style: const TextStyle(color: AppColors.darkText)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedType = val);
                  }
                },
              ),
              if (_selectedType == 'Other') ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _customTypeController,
                  maxLength: 30,
                  inputFormatters: [_SingleSpaceFormatter()],
                  decoration: InputDecoration(
                    hintText: 'e.g. Grandma\'s House, Dorm, Warehouse',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                    ),
                  ),
                  validator: (v) {
                    if (_selectedType == 'Other') {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please specify label';
                      }
                      if (v.trim().length < 2) {
                        return 'Label must be at least 2 characters';
                      }
                      if (v.trim().length > 30) {
                        return 'Label must not exceed 30 characters';
                      }
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 20),

              // 2. Province (Locked to Laguna)
              const Text('Province',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F1F1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.primaryOrange, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Laguna, Region IV-A (CALABARZON), Philippines',
                        style: TextStyle(
                          color: AppColors.darkText,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Text(
                        'Fixed Scope',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. City / Municipality Dropdown (via API)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('City / Municipality',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
                  if (_isLoadingCities)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryOrange),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_cityLoadError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_cityLoadError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: _loadCities,
                        child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<LagunaCity>(
                  value: _selectedCity,
                  isExpanded: true,
                  hint: Text(_isLoadingCities ? 'Fetching list from API...' : 'Select City / Municipality'),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.location_city, color: AppColors.primaryOrange),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                    ),
                  ),
                  items: _cities.map((city) {
                    return DropdownMenuItem<LagunaCity>(
                      value: city,
                      child: Text(
                        city.name,
                        style: const TextStyle(color: AppColors.darkText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (city) {
                    if (city != null && city != _selectedCity) {
                      _onCityChanged(city);
                    }
                  },
                  validator: (v) => v == null ? 'Please select your City or Municipality' : null,
                ),
              const SizedBox(height: 20),

              // 4. Barangay Dropdown (via API)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Barangay',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
                  if (_isLoadingBarangays)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryOrange),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_barangayLoadError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_barangayLoadError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () => _onCityChanged(_selectedCity),
                        child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<LagunaBarangay>(
                  value: _selectedBarangay,
                  isExpanded: true,
                  hint: Text(
                    _selectedCity == null
                        ? 'Select City / Municipality first'
                        : (_isLoadingBarangays ? 'Fetching barangays from API...' : 'Select Barangay'),
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.holiday_village_outlined, color: AppColors.primaryOrange),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                    ),
                  ),
                  items: _barangays.map((b) {
                    return DropdownMenuItem<LagunaBarangay>(
                      value: b,
                      child: Text(
                        b.name,
                        style: const TextStyle(color: AppColors.darkText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _selectedCity == null || _isLoadingBarangays
                      ? null
                      : (b) {
                          setState(() {
                            _selectedBarangay = b;
                          });
                        },
                  validator: (v) => v == null ? 'Please select your Barangay' : null,
                ),
              const SizedBox(height: 20),

              // 5. House / Unit No. & Street / Landmark
              const Text('House No., Street Name, or Landmark',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
              const SizedBox(height: 4),
              const Text(
                'Additional information for delivery rider (e.g. Blk 4 Lot 10, Amber St., in front of store)',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _streetDetailsController,
                maxLength: 120,
                inputFormatters: [_SingleSpaceFormatter()],
                decoration: InputDecoration(
                  hintText: 'e.g. Blk 12 Lot 5, Phase 2, Mabini St.',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.home_outlined, color: AppColors.primaryOrange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter house no., street name, or landmark';
                  }
                  if (v.trim().length < 5) {
                    return 'Address details must be at least 5 characters long';
                  }
                  if (v.trim().length > 120) {
                    return 'Address details must not exceed 120 characters';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),

              // 6. Address Preview Card
              if (_selectedCity != null || _selectedBarangay != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.pin_drop_rounded, size: 16, color: AppColors.primaryOrange),
                          SizedBox(width: 6),
                          Text('Address Preview:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.secondaryText)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _buildFormattedAddress(),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkText, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 7. Set as Default Checkbox
              Row(
                children: [
                  Checkbox(
                    value: _isDefault,
                    onChanged: (v) => setState(() => _isDefault = v ?? false),
                    activeColor: AppColors.primaryOrange,
                  ),
                  const Text('Set as default delivery address', style: TextStyle(color: AppColors.secondaryText)),
                ],
              ),
              const SizedBox(height: 32),

              // 8. Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isEditing ? 'SAVE CHANGES' : 'ADD ADDRESS',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SingleSpaceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.startsWith(' ')) {
      return oldValue;
    }
    if (newValue.text.contains('  ')) {
      return oldValue;
    }
    return newValue;
  }
}

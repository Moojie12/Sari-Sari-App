import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/laguna_bounds.dart';
import '../../../core/services/laguna_location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../../../shared/widgets/laguna_address_map_picker.dart';
import 'shop_settings_controller.dart';

class OwnerStoreAddressPage extends StatefulWidget {
  const OwnerStoreAddressPage({super.key});

  @override
  State<OwnerStoreAddressPage> createState() => _OwnerStoreAddressPageState();
}

class _OwnerStoreAddressPageState extends State<OwnerStoreAddressPage> {
  final _formKey = GlobalKey<FormState>();

  // Search Address input (Laguna Only)
  final TextEditingController _searchController = TextEditingController();
  List<LagunaGeocodedPlace> _searchSuggestions = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

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

  // Form controllers
  late final TextEditingController _streetDetailsController;
  late final TextEditingController _postalCodeController;
  final String _region = 'Region IV-A (CALABARZON)';
  final String _province = 'Laguna';

  // Map & Pin Coordinates
  late LatLng _currentLocation;
  bool _isPinConfirmed = true; // Initially true for saved store address
  bool _isSaving = false;

  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    final settings = ShopSettingsController.instance;

    _streetDetailsController = TextEditingController(text: settings.storeStreet);
    _postalCodeController = TextEditingController(text: settings.storePostalCode);
    _currentLocation = settings.storeLocation;

    _loadCities();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _streetDetailsController.dispose();
    _postalCodeController.dispose();
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

      final settings = ShopSettingsController.instance;
      LagunaCity? matchedCity;

      if (settings.storeCityCode != null) {
        matchedCity = cities.where((c) => c.code == settings.storeCityCode).firstOrNull;
      }
      if (matchedCity == null && settings.storeCity.isNotEmpty) {
        matchedCity = cities.where((c) =>
            c.name.toLowerCase() == settings.storeCity.toLowerCase() ||
            c.name.toLowerCase().contains(settings.storeCity.toLowerCase()) ||
            settings.storeCity.toLowerCase().contains(c.name.toLowerCase())).firstOrNull;
      }

      if (matchedCity != null) {
        _onCityChanged(
          matchedCity,
          initialBarangayCode: settings.storeBarangayCode,
          initialBarangayName: settings.storeBarangay,
          moveMap: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingCities = false;
        _cityLoadError = 'Failed to load cities: $e';
      });
    }
  }

  Future<void> _onCityChanged(
    LagunaCity? city, {
    String? initialBarangayCode,
    String? initialBarangayName,
    bool moveMap = true,
  }) async {
    if (city == null) return;

    final postalCode = LagunaBounds.getPostalCode(city.name);
    setState(() {
      _selectedCity = city;
      _selectedBarangay = null;
      _barangays = [];
      _isLoadingBarangays = true;
      _barangayLoadError = null;
      if (postalCode != null && (_postalCodeController.text.trim().isEmpty || _postalCodeController.text.length != 4)) {
        _postalCodeController.text = postalCode;
      }
    });

    if (moveMap) {
      final query = '${city.name}, Laguna, Philippines';
      LagunaBounds.searchLaguna(query).then((results) {
        if (mounted && results.isNotEmpty) {
          setState(() {
            _currentLocation = results.first.location;
            _isPinConfirmed = false;
          });
        }
      });
    }

    try {
      final barangays = await _locationService.getBarangays(city.code);
      if (!mounted) return;

      LagunaBarangay? matchedBarangay;
      if (initialBarangayCode != null) {
        matchedBarangay = barangays.where((b) => b.code == initialBarangayCode).firstOrNull;
      }
      if (matchedBarangay == null && initialBarangayName != null) {
        final cleanTarget = initialBarangayName.toLowerCase()
            .replaceAll('barangay', '')
            .replaceAll('brgy.', '')
            .replaceAll('brgy', '')
            .trim();
        matchedBarangay = barangays.where((b) {
          final bClean = b.name.toLowerCase()
              .replaceAll('barangay', '')
              .replaceAll('brgy.', '')
              .replaceAll('brgy', '')
              .trim();
          return bClean == cleanTarget || bClean.contains(cleanTarget) || cleanTarget.contains(bClean);
        }).firstOrNull;
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

  void _onBarangayChanged(LagunaBarangay? barangay) {
    if (barangay == null) return;
    setState(() {
      _selectedBarangay = barangay;
      _isPinConfirmed = false;
    });

    if (_selectedCity != null) {
      final query = '${barangay.name}, ${_selectedCity!.name}, Laguna, Philippines';
      LagunaBounds.searchLaguna(query).then((results) {
        if (mounted && results.isNotEmpty) {
          setState(() {
            _currentLocation = results.first.location;
          });
        }
      });
    }
  }

  void _onSearchQueryChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 3) {
      if (_searchSuggestions.isNotEmpty) {
        setState(() => _searchSuggestions = []);
      }
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearching = true);
      final results = await LagunaBounds.searchLaguna(query);
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchSuggestions = results;
        });
      }
    });
  }

  void _selectSearchSuggestion(LagunaGeocodedPlace place) {
    FocusScope.of(context).unfocus();
    _searchSuggestions.clear();
    _searchController.clear();

    setState(() {
      _currentLocation = place.location;
      _isPinConfirmed = false;
      if (place.street != null && place.street!.isNotEmpty) {
        _streetDetailsController.text = place.street!;
      }
      if (place.postalCode != null && place.postalCode!.isNotEmpty) {
        _postalCodeController.text = place.postalCode!;
      }
    });

    if (place.city != null && _cities.isNotEmpty) {
      final cleanCity = place.city!.toLowerCase().replaceAll('city of ', '').trim();
      final matchedCity = _cities.where((c) {
        final cClean = c.name.toLowerCase().replaceAll('city of ', '').trim();
        return cClean == cleanCity || cClean.contains(cleanCity) || cleanCity.contains(cClean);
      }).firstOrNull;

      if (matchedCity != null) {
        _onCityChanged(matchedCity, initialBarangayName: place.barangay, moveMap: false);
      }
    }

    TopNotification.show(
      context,
      'Store location updated on map. Please confirm your pin location below.',
    );
  }

  void _onLocationConfirmedFromPicker(LatLng location, LagunaGeocodedPlace? details) {
    setState(() {
      _currentLocation = location;
      _isPinConfirmed = true;

      if (details != null) {
        if (details.street != null && details.street!.isNotEmpty) {
          _streetDetailsController.text = details.street!;
        } else if (details.displayName.isNotEmpty) {
          final parts = details.displayName.split(',');
          if (parts.isNotEmpty) {
            _streetDetailsController.text = parts.first.trim();
          }
        }

        if (details.postalCode != null && details.postalCode!.isNotEmpty) {
          _postalCodeController.text = details.postalCode!;
        }

        // Auto-match city
        if (details.city != null && _cities.isNotEmpty) {
          final cleanCity = details.city!.toLowerCase().replaceAll('city of ', '').replaceAll('city', '').trim();
          final matchedCity = _cities.where((c) {
            final cClean = c.name.toLowerCase().replaceAll('city of ', '').replaceAll('city', '').trim();
            return cClean == cleanCity || cClean.contains(cleanCity) || cleanCity.contains(cClean);
          }).firstOrNull;

          if (matchedCity != null) {
            _onCityChanged(matchedCity, initialBarangayName: details.barangay, moveMap: false);
          }
        }
      }
    });
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
    parts.add(_province);
    if (_postalCodeController.text.trim().isNotEmpty) {
      parts.add(_postalCodeController.text.trim());
    }
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
      TopNotification.show(context, 'Please select store City / Municipality in Laguna', isError: true);
      return;
    }

    if (_selectedBarangay == null) {
      TopNotification.show(context, 'Please select store Barangay', isError: true);
      return;
    }

    if (!LagunaBounds.contains(_currentLocation)) {
      TopNotification.show(
        context,
        'Store location must be within Laguna province.',
        isError: true,
      );
      return;
    }

    if (!_isPinConfirmed) {
      TopNotification.show(
        context,
        'Please confirm the store pin location on the map before saving.',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Update Store Address', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to update the store address and location? This will be used as the official store pickup point and origin for deliveries.',
              style: TextStyle(color: AppColors.darkText),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.store, size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Store Pin: ${_currentLocation.latitude.toStringAsFixed(4)}, ${_currentLocation.longitude.toStringAsFixed(4)} (Laguna)',
                      style: TextStyle(fontSize: 11, color: Colors.green.shade900, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            child: const Text('Save Store Location', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isSaving = true);

    try {
      final street = _streetDetailsController.text.trim();
      final postal = _postalCodeController.text.trim();
      final fullAddress = _buildFormattedAddress();

      await ShopSettingsController.instance.updateStoreAddress(
        address: fullAddress,
        latitude: _currentLocation.latitude,
        longitude: _currentLocation.longitude,
        region: _region,
        province: _province,
        city: _selectedCity!.name,
        cityCode: _selectedCity!.code,
        barangay: _selectedBarangay!.name,
        barangayCode: _selectedBarangay!.code,
        street: street,
        postalCode: postal,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);
      TopNotification.show(context, 'Store address and pin location updated successfully!');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      TopNotification.show(context, 'Failed to update store address: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Store Address & Location',
          style: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 18),
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
              

              // Search Laguna Addresses Bar
              const Text('Search Store Location / Landmark (Laguna)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _searchController,
                onChanged: _onSearchQueryChanged,
                decoration: InputDecoration(
                  hintText: 'e.g. Doctor Zavalla, Malusak, Santa Rosa City Hall',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.search, color: AppColors.primaryOrange),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryOrange),
                          ),
                        )
                      : (_searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchSuggestions = []);
                              },
                            )
                          : null),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
                  ),
                ),
              ),

              if (_searchSuggestions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderColor),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _searchSuggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _searchSuggestions[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.store, color: AppColors.primaryOrange, size: 18),
                        title: Text(item.displayName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${item.city ?? 'Laguna'} • ${item.location.latitude.toStringAsFixed(4)}, ${item.location.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 10, color: AppColors.secondaryText),
                        ),
                        onTap: () => _selectSearchSuggestion(item),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Interactive OpenStreetMap Location Picker
              LagunaAddressMapPicker(
                initialLocation: _currentLocation,
                isConfirmed: _isPinConfirmed,
                onLocationChanged: (loc) {
                  setState(() {
                    _currentLocation = loc;
                    _isPinConfirmed = false;
                  });
                },
                onLocationConfirmed: _onLocationConfirmedFromPicker,
                title: 'Store Pin Location (OpenStreetMap)',
                pinLabel: 'Store: Tindahan ni Eca',
                pinIcon: Icons.store,
                height: 280,
              ),

              const SizedBox(height: 24),

              // Region & Province (Minimalist)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.location_on_outlined, size: 16, color: AppColors.primaryOrange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Region IV-A (CALABARZON) • Laguna',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // City / Municipality Dropdown
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
                  hint: Text(_isLoadingCities ? 'Fetching Laguna cities...' : 'Select City / Municipality'),
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
                  validator: (v) => v == null ? 'Please select City or Municipality' : null,
                ),
              const SizedBox(height: 20),

              // Barangay Dropdown
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
                        : (_isLoadingBarangays ? 'Fetching barangays...' : 'Select Barangay'),
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
                  onChanged: _selectedCity == null || _isLoadingBarangays ? null : _onBarangayChanged,
                  validator: (v) => v == null ? 'Please select Barangay' : null,
                ),
              const SizedBox(height: 20),

              // Street details
              const Text('Store Street, Building, or Exact Landmark',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _streetDetailsController,
                maxLength: 120,
                inputFormatters: [_SingleSpaceFormatter()],
                decoration: InputDecoration(
                  hintText: 'e.g. Doctor Zavalla Street, Near Public Market',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.store_outlined, color: AppColors.primaryOrange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter store street or landmark';
                  }
                  if (v.trim().length < 3) {
                    return 'Street details must be at least 3 characters';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // Postal Code
              const Text('Postal Code',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _postalCodeController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: 'e.g. 4026',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.markunread_mailbox_outlined, color: AppColors.primaryOrange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),

              // Address Preview Card
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
                          Icon(Icons.storefront, size: 16, color: AppColors.primaryOrange),
                          SizedBox(width: 6),
                          Text('Store Address Preview:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.secondaryText)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _buildFormattedAddress(),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkText, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Store Coordinates: ${_currentLocation.latitude.toStringAsFixed(5)}, ${_currentLocation.longitude.toStringAsFixed(5)}',
                        style: TextStyle(fontSize: 11, color: _isPinConfirmed ? Colors.green.shade700 : Colors.amber.shade900, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text(
                          'SAVE STORE ADDRESS & LOCATION',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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

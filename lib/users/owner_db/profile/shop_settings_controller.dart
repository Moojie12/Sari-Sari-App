import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/constants/laguna_bounds.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';

class ShopSettingsController extends ChangeNotifier {
  ShopSettingsController._() {
    _initAndListen();
  }

  static final ShopSettingsController instance = ShopSettingsController._();

  factory ShopSettingsController() => instance;

  double _deliveryFeePer500m = 5.0; // Default value
  int _lowStockThreshold = 10;
  int _expiryMonitoringDays = 30;
  String? _gcashQrUrl;
  bool _isInitialized = false;

  // Store Address fields (default: Santa Rosa, Laguna)
  String _storeAddress = 'Doctor Zavalla Street, Malusak, Santa Rosa, Laguna, 4026';
  double _storeLatitude = 14.3122;
  double _storeLongitude = 121.1114;
  String _storeRegion = 'Region IV-A (CALABARZON)';
  String _storeProvince = 'Laguna';
  String _storeCity = 'City of Santa Rosa';
  String? _storeCityCode = '043428000';
  String _storeBarangay = 'Malusak';
  String? _storeBarangayCode;
  String _storeStreet = 'Doctor Zavalla Street';
  String _storePostalCode = '4026';
  bool _hasCustomStoreAddress = false;

  StreamSubscription<DatabaseEvent>? _subscription;

  double get deliveryFeePer500m => _deliveryFeePer500m;
  int get lowStockThreshold => _lowStockThreshold;
  int get expiryMonitoringDays => _expiryMonitoringDays;
  String? get gcashQrUrl => _gcashQrUrl;
  bool get isInitialized => _isInitialized;

  // Store Address getters
  String get storeAddress => _storeAddress;
  double get storeLatitude => _storeLatitude;
  double get storeLongitude => _storeLongitude;
  LatLng get storeLocation => LatLng(_storeLatitude, _storeLongitude);
  String get storeRegion => _storeRegion;
  String get storeProvince => _storeProvince;
  String get storeCity => _storeCity;
  String? get storeCityCode => _storeCityCode;
  String get storeBarangay => _storeBarangay;
  String? get storeBarangayCode => _storeBarangayCode;
  String get storeStreet => _storeStreet;
  String get storePostalCode => _storePostalCode;
  bool get hasCustomStoreAddress => _hasCustomStoreAddress;

  void _initAndListen() {
    _loadFromLocalCache();
    _listenToFirebase();
  }

  Future<void> _loadFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _deliveryFeePer500m = (prefs.getDouble('system_deliveryFeePer500m') ?? _deliveryFeePer500m).clamp(0.0, 99.0);
      _lowStockThreshold = (prefs.getInt('system_lowStockThreshold') ?? _lowStockThreshold).clamp(0, 99);
      _expiryMonitoringDays = prefs.getInt('system_expiryMonitoringDays') ?? _expiryMonitoringDays;
      final cachedQr = prefs.getString('system_gcashQrUrl');
      if (cachedQr != null && cachedQr.trim().isNotEmpty && !cachedQr.contains('wikimedia.org')) {
        _gcashQrUrl = cachedQr.trim();
      } else {
        _gcashQrUrl = null;
      }

      // Store address
      final cachedAddr = prefs.getString('system_storeAddress');
      if (cachedAddr != null && cachedAddr.trim().isNotEmpty) {
        _storeAddress = cachedAddr.trim();
        _hasCustomStoreAddress = true;
      }
      final cachedLat = prefs.getDouble('system_storeLatitude');
      final cachedLng = prefs.getDouble('system_storeLongitude');
      if (cachedLat != null && cachedLng != null) {
        final point = LatLng(cachedLat, cachedLng);
        if (LagunaBounds.contains(point)) {
          _storeLatitude = cachedLat;
          _storeLongitude = cachedLng;
        }
      }
      _storeRegion = prefs.getString('system_storeRegion') ?? _storeRegion;
      _storeProvince = prefs.getString('system_storeProvince') ?? _storeProvince;
      _storeCity = prefs.getString('system_storeCity') ?? _storeCity;
      _storeCityCode = prefs.getString('system_storeCityCode') ?? _storeCityCode;
      _storeBarangay = prefs.getString('system_storeBarangay') ?? _storeBarangay;
      _storeBarangayCode = prefs.getString('system_storeBarangayCode') ?? _storeBarangayCode;
      _storeStreet = prefs.getString('system_storeStreet') ?? _storeStreet;
      _storePostalCode = prefs.getString('system_storePostalCode') ?? _storePostalCode;

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[ShopSettingsController] Cache load error: $e');
    }
  }

  void _listenToFirebase() {
    try {
      final db = AuthService().database;
      _subscription?.cancel();
      _subscription = db.ref().child('system_settings').onValue.listen((event) {
        if (event.snapshot.exists && event.snapshot.value is Map) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          
          if (data.containsKey('deliveryFeePer500m')) {
            _deliveryFeePer500m = ((data['deliveryFeePer500m'] as num).toDouble()).clamp(0.0, 99.0);
          }
          if (data.containsKey('lowStockThreshold')) {
            _lowStockThreshold = ((data['lowStockThreshold'] as num).toInt()).clamp(0, 99);
          }
          if (data.containsKey('expiryMonitoringDays')) {
            _expiryMonitoringDays = (data['expiryMonitoringDays'] as num).toInt();
          }
          if (data.containsKey('gcashQrUrl') && data['gcashQrUrl'] != null) {
            final qr = data['gcashQrUrl'].toString().trim();
            if (qr.isNotEmpty && !qr.contains('wikimedia.org')) {
              _gcashQrUrl = qr;
            } else {
              _gcashQrUrl = null;
            }
          } else {
            _gcashQrUrl = null;
          }

          // Store address sync from Firebase RTDB
          if (data.containsKey('storeAddress') && data['storeAddress'] != null) {
            final addr = data['storeAddress'].toString().trim();
            if (addr.isNotEmpty) {
              _storeAddress = addr;
              _hasCustomStoreAddress = true;
            }
          }
          if (data.containsKey('storeLatitude') && data.containsKey('storeLongitude')) {
            final lat = (data['storeLatitude'] as num?)?.toDouble();
            final lng = (data['storeLongitude'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              final pt = LatLng(lat, lng);
              if (LagunaBounds.contains(pt)) {
                _storeLatitude = lat;
                _storeLongitude = lng;
              }
            }
          }
          if (data.containsKey('storeRegion') && data['storeRegion'] != null) {
            _storeRegion = data['storeRegion'].toString();
          }
          if (data.containsKey('storeProvince') && data['storeProvince'] != null) {
            _storeProvince = data['storeProvince'].toString();
          }
          if (data.containsKey('storeCity') && data['storeCity'] != null) {
            _storeCity = data['storeCity'].toString();
          }
          if (data.containsKey('storeCityCode') && data['storeCityCode'] != null) {
            _storeCityCode = data['storeCityCode'].toString();
          }
          if (data.containsKey('storeBarangay') && data['storeBarangay'] != null) {
            _storeBarangay = data['storeBarangay'].toString();
          }
          if (data.containsKey('storeBarangayCode') && data['storeBarangayCode'] != null) {
            _storeBarangayCode = data['storeBarangayCode'].toString();
          }
          if (data.containsKey('storeStreet') && data['storeStreet'] != null) {
            _storeStreet = data['storeStreet'].toString();
          }
          if (data.containsKey('storePostalCode') && data['storePostalCode'] != null) {
            _storePostalCode = data['storePostalCode'].toString();
          }

          _saveToLocalCache();
          notifyListeners();
        }
      }, onError: (err) {
        debugPrint('[ShopSettingsController] RTDB error: $err');
      });
    } catch (e) {
      debugPrint('[ShopSettingsController] Firebase listener setup error: $e');
    }
  }

  Future<void> _saveToLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('system_deliveryFeePer500m', _deliveryFeePer500m);
      await prefs.setInt('system_lowStockThreshold', _lowStockThreshold);
      await prefs.setInt('system_expiryMonitoringDays', _expiryMonitoringDays);
      if (_gcashQrUrl != null) {
        await prefs.setString('system_gcashQrUrl', _gcashQrUrl!);
      } else {
        await prefs.remove('system_gcashQrUrl');
      }

      await prefs.setString('system_storeAddress', _storeAddress);
      await prefs.setDouble('system_storeLatitude', _storeLatitude);
      await prefs.setDouble('system_storeLongitude', _storeLongitude);
      await prefs.setString('system_storeRegion', _storeRegion);
      await prefs.setString('system_storeProvince', _storeProvince);
      await prefs.setString('system_storeCity', _storeCity);
      if (_storeCityCode != null) await prefs.setString('system_storeCityCode', _storeCityCode!);
      await prefs.setString('system_storeBarangay', _storeBarangay);
      if (_storeBarangayCode != null) await prefs.setString('system_storeBarangayCode', _storeBarangayCode!);
      await prefs.setString('system_storeStreet', _storeStreet);
      await prefs.setString('system_storePostalCode', _storePostalCode);
    } catch (e) {
      debugPrint('[ShopSettingsController] Cache save error: $e');
    }
  }

  Future<void> _syncToFirebase() async {
    try {
      final db = AuthService().database;
      await db.ref().child('system_settings').update({
        'deliveryFeePer500m': _deliveryFeePer500m,
        'lowStockThreshold': _lowStockThreshold,
        'expiryMonitoringDays': _expiryMonitoringDays,
        'gcashQrUrl': _gcashQrUrl,
        'storeAddress': _storeAddress,
        'storeLatitude': _storeLatitude,
        'storeLongitude': _storeLongitude,
        'storeRegion': _storeRegion,
        'storeProvince': _storeProvince,
        'storeCity': _storeCity,
        'storeCityCode': _storeCityCode,
        'storeBarangay': _storeBarangay,
        'storeBarangayCode': _storeBarangayCode,
        'storeStreet': _storeStreet,
        'storePostalCode': _storePostalCode,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[ShopSettingsController] Firebase sync error: $e');
    }
  }

  void updateDeliveryFee(double fee) {
    _deliveryFeePer500m = fee.clamp(0.0, 99.0);
    notifyListeners();
    _saveToLocalCache();
    _syncToFirebase();
  }

  void updateLowStockThreshold(int threshold) {
    _lowStockThreshold = threshold.clamp(0, 99);
    notifyListeners();
    _saveToLocalCache();
    _syncToFirebase();
  }

  void updateExpiryMonitoringDays(int days) {
    _expiryMonitoringDays = days;
    notifyListeners();
    _saveToLocalCache();
    _syncToFirebase();
  }

  void updateGcashQrUrl(String? url) {
    _gcashQrUrl = url;
    notifyListeners();
    _saveToLocalCache();
    _syncToFirebase();
  }

  /// Update the Owner's store address and confirmed location coordinates
  Future<void> updateStoreAddress({
    required String address,
    required double latitude,
    required double longitude,
    String? region,
    String? province,
    String? city,
    String? cityCode,
    String? barangay,
    String? barangayCode,
    String? street,
    String? postalCode,
  }) async {
    // Validate Laguna bounds
    final point = LatLng(latitude, longitude);
    if (!LagunaBounds.contains(point)) {
      throw ArgumentError('Store location must be within Laguna province.');
    }

    _storeAddress = address.trim();
    _storeLatitude = latitude;
    _storeLongitude = longitude;
    if (region != null && region.isNotEmpty) _storeRegion = region;
    if (province != null && province.isNotEmpty) _storeProvince = province;
    if (city != null && city.isNotEmpty) _storeCity = city;
    if (cityCode != null) _storeCityCode = cityCode;
    if (barangay != null && barangay.isNotEmpty) _storeBarangay = barangay;
    if (barangayCode != null) _storeBarangayCode = barangayCode;
    if (street != null && street.isNotEmpty) _storeStreet = street;
    if (postalCode != null && postalCode.isNotEmpty) _storePostalCode = postalCode;
    _hasCustomStoreAddress = true;

    notifyListeners();
    await _saveToLocalCache();
    await _syncToFirebase();

    // Also update Supabase shop_settings if available
    try {
      await SupabaseService().updateShopSettings({
        'store_address': _storeAddress,
      });
    } catch (e) {
      debugPrint('[ShopSettingsController] Note updating Supabase shop_settings: $e');
    }
  }

  /// Calculates delivery fee based on distance in meters.
  /// Distance is divided into 500m chunks (0.5 km) rounded up.
  /// Minimum fee is 1 x deliveryFeePer500m if distance > 0.
  double calculateDeliveryFee(double distanceMeters) {
    if (distanceMeters <= 0) return 0.0;
    final chunks = (distanceMeters / 500.0).ceil();
    final count = chunks < 1 ? 1 : chunks;
    return count * _deliveryFeePer500m;
  }

  /// Uploads GCash QR image to Firebase Storage / Base64 fallback and syncs.
  Future<String?> uploadGcashQrImage(dynamic imageSource) async {
    try {
      String? downloadUrl;
      if (imageSource is String) {
        downloadUrl = imageSource;
      } else if (kIsWeb || imageSource is Uint8List || imageSource is XFile) {
        Uint8List bytes;
        if (imageSource is Uint8List) {
          bytes = imageSource;
        } else if (imageSource is XFile) {
          bytes = await imageSource.readAsBytes();
        } else {
          final file = imageSource as File;
          bytes = await file.readAsBytes();
        }
        downloadUrl = 'data:image/png;base64,${base64Encode(bytes)}';
      } else if (imageSource is File) {
        try {
          final ext = imageSource.path.split('.').last.toLowerCase();
          final fileName = 'gcash_qr_${DateTime.now().millisecondsSinceEpoch}.$ext';
          final storageRef = FirebaseStorage.instance.ref().child('settings/$fileName');
          await storageRef.putFile(imageSource);
          downloadUrl = await storageRef.getDownloadURL();
        } catch (_) {
          final bytes = await imageSource.readAsBytes();
          downloadUrl = 'data:image/png;base64,${base64Encode(bytes)}';
        }
      }

      if (downloadUrl != null) {
        updateGcashQrUrl(downloadUrl);
        return downloadUrl;
      }
    } catch (e) {
      debugPrint('[ShopSettingsController] Upload QR error: $e');
      if (imageSource is String) {
        updateGcashQrUrl(imageSource);
        return imageSource;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

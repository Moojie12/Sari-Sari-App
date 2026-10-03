import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/services/auth_service.dart';

class ShopSettingsController extends ChangeNotifier {
  ShopSettingsController._() {
    _initAndListen();
  }

  static final ShopSettingsController instance = ShopSettingsController._();

  factory ShopSettingsController() => instance;

  double _deliveryFeePer500m = 5.0; // Default value
  int _lowStockThreshold = 10;
  int _expiryMonitoringDays = 30;
  String? _gcashQrUrl = 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/QR_code_for_mobile_English_Wikipedia.svg/1200px-QR_code_for_mobile_English_Wikipedia.svg.png';
  bool _isInitialized = false;

  StreamSubscription<DatabaseEvent>? _subscription;

  double get deliveryFeePer500m => _deliveryFeePer500m;
  int get lowStockThreshold => _lowStockThreshold;
  int get expiryMonitoringDays => _expiryMonitoringDays;
  String? get gcashQrUrl => _gcashQrUrl;
  bool get isInitialized => _isInitialized;

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
      _gcashQrUrl = prefs.getString('system_gcashQrUrl') ?? _gcashQrUrl;
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
            _gcashQrUrl = data['gcashQrUrl'].toString();
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
      if (imageSource is File) {
        final ext = imageSource.path.split('.').last.toLowerCase();
        final fileName = 'gcash_qr_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final storageRef = FirebaseStorage.instance.ref().child('settings/$fileName');
        await storageRef.putFile(imageSource);
        downloadUrl = await storageRef.getDownloadURL();
      } else if (imageSource is Uint8List) {
        final fileName = 'gcash_qr_${DateTime.now().millisecondsSinceEpoch}.png';
        final storageRef = FirebaseStorage.instance.ref().child('settings/$fileName');
        await storageRef.putData(imageSource, SettableMetadata(contentType: 'image/png'));
        downloadUrl = await storageRef.getDownloadURL();
      } else if (imageSource is String) {
        downloadUrl = imageSource;
      }

      if (downloadUrl != null) {
        updateGcashQrUrl(downloadUrl);
        return downloadUrl;
      }
    } catch (e) {
      debugPrint('[ShopSettingsController] Upload QR error: $e');
      if (imageSource is File) {
        try {
          final bytes = await imageSource.readAsBytes();
          final base64Str = 'data:image/png;base64,${base64Encode(bytes)}';
          updateGcashQrUrl(base64Str);
          return base64Str;
        } catch (_) {}
      } else if (imageSource is Uint8List) {
        final base64Str = 'data:image/png;base64,${base64Encode(imageSource)}';
        updateGcashQrUrl(base64Str);
        return base64Str;
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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/auth_service.dart';
import 'customer_address_model.dart';

class CustomerAddressController extends ChangeNotifier {
  CustomerAddressController._() {
    _loadAddresses();
  }

  static final CustomerAddressController instance = CustomerAddressController._();
  factory CustomerAddressController() => instance;

  static const _storageKey = 'customer_saved_addresses_v1';

  final List<CustomerAddress> _addresses = [
    const CustomerAddress(
      id: '1',
      type: 'Home',
      address: '123 Sampaguita Street, Brgy. 456, Manila City, Metro Manila',
      isDefault: true,
    ),
    const CustomerAddress(
      id: '2',
      type: 'Office',
      address: '456 Narra Avenue, Makati Business District, Makati City',
    ),
  ];

  List<CustomerAddress> get addresses => List.unmodifiable(_addresses);

  CustomerAddress? get defaultAddress => 
      _addresses.where((a) => a.isDefault).firstOrNull ?? _addresses.firstOrNull;

  Future<void> _loadAddresses() async {
    // 1. Load local cache from SharedPreferences first for immediate display
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          _addresses.clear();
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              _addresses.add(CustomerAddress.fromJson(item));
            }
          }
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error loading customer addresses from local storage: $e');
    }

    // 2. Fetch latest addresses from Firebase Realtime Database
    await loadFromFirebase();
  }

  /// Load addresses from Firebase Realtime Database for the current authenticated user
  Future<void> loadFromFirebase() async {
    final user = AuthService().currentUser;
    if (user == null) return;

    try {
      final db = AuthService().database;
      final snapshot = await db.ref().child('users/${user.uid}/addresses').get();
      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value;
        final List<CustomerAddress> remoteList = [];
        if (data is Map) {
          data.forEach((key, val) {
            if (val is Map) {
              remoteList.add(CustomerAddress.fromJson(Map<String, dynamic>.from(val)));
            }
          });
        } else if (data is List) {
          for (final item in data) {
            if (item is Map) {
              remoteList.add(CustomerAddress.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }

        if (remoteList.isNotEmpty) {
          _addresses.clear();
          _addresses.addAll(remoteList);
          notifyListeners();
          _saveToLocalOnly();
        }
      }
    } catch (e) {
      debugPrint('Error loading addresses from Firebase RTDB: $e');
    }
  }

  Future<void> _saveToLocalOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _addresses.map((a) => a.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving addresses locally: $e');
    }
  }

  Future<void> _saveAddresses() async {
    await _saveToLocalOnly();

    // Persist to Firebase Realtime Database
    final user = AuthService().currentUser;
    if (user != null) {
      try {
        final db = AuthService().database;
        final mapData = <String, dynamic>{};
        for (final a in _addresses) {
          mapData[a.id] = a.toJson();
        }
        await db.ref().child('users/${user.uid}/addresses').set(mapData);
        debugPrint('Saved ${_addresses.length} addresses to Firebase RTDB for user ${user.uid}');
      } catch (e) {
        debugPrint('Error saving addresses to Firebase RTDB: $e');
      }
    }
  }

  bool addAddress(CustomerAddress address) {
    if (address.address.trim().isEmpty || address.type.trim().isEmpty) {
      return false;
    }

    if (address.isDefault) {
      _clearDefaults();
    }
    _addresses.add(address);
    notifyListeners();
    _saveAddresses();
    return true;
  }

  bool updateAddress(CustomerAddress updated) {
    if (updated.address.trim().isEmpty || updated.type.trim().isEmpty) {
      return false;
    }

    final index = _addresses.indexWhere((a) => a.id == updated.id);
    if (index >= 0) {
      if (updated.isDefault) {
        _clearDefaults();
      }
      _addresses[index] = updated;
      notifyListeners();
      _saveAddresses();
      return true;
    }
    return false;
  }

  void deleteAddress(String id) {
    _addresses.removeWhere((a) => a.id == id);
    if (_addresses.isNotEmpty && !_addresses.any((a) => a.isDefault)) {
      _addresses[0] = _addresses[0].copyWith(isDefault: true);
    }
    notifyListeners();
    _saveAddresses();
  }

  void setDefault(String id) {
    final index = _addresses.indexWhere((a) => a.id == id);
    if (index >= 0) {
      _clearDefaults();
      _addresses[index] = _addresses[index].copyWith(isDefault: true);
      notifyListeners();
      _saveAddresses();
    }
  }

  void _clearDefaults() {
    for (int i = 0; i < _addresses.length; i++) {
      if (_addresses[i].isDefault) {
        _addresses[i] = _addresses[i].copyWith(isDefault: false);
      }
    }
  }
}

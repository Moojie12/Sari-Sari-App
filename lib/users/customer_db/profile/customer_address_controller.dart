import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/auth_service.dart';
import 'customer_address_model.dart';

class CustomerAddressController extends ChangeNotifier {
  CustomerAddressController._() {
    _initAuthListener();
    _loadAddresses();
  }

  static final CustomerAddressController instance = CustomerAddressController._();
  factory CustomerAddressController() => instance;

  String? _currentUserId;
  final List<CustomerAddress> _addresses = [];

  String _getStorageKey(String uid) => 'customer_saved_addresses_$uid';

  void _initAuthListener() {
    try {
      AuthService().authStateChanges.listen((user) {
        if (user == null) {
          clear();
        } else if (_currentUserId != user.uid) {
          loadAddressesForUser(user.uid);
        }
      });
    } catch (e) {
      debugPrint('Error attaching authStateChanges listener in CustomerAddressController: $e');
    }
  }

  /// Clears in-memory address state (e.g. on logout)
  void clear() {
    _currentUserId = null;
    _addresses.clear();
    notifyListeners();
  }

  /// Ensures addresses in-memory match the currently logged-in user
  void ensureAddressesForActiveUser() {
    final activeUser = AuthService().currentUser;
    if (activeUser != null && _currentUserId != activeUser.uid) {
      loadAddressesForUser(activeUser.uid);
    }
  }

  List<CustomerAddress> get addresses {
    ensureAddressesForActiveUser();
    return List.unmodifiable(_addresses);
  }

  CustomerAddress? get defaultAddress {
    ensureAddressesForActiveUser();
    return _addresses.where((a) => a.isDefault).firstOrNull ?? _addresses.firstOrNull;
  }

  Future<void> _loadAddresses() async {
    final user = AuthService().currentUser;
    if (user != null) {
      await loadAddressesForUser(user.uid);
    } else {
      clear();
    }
  }

  /// Load addresses for a specific user ID
  Future<void> loadAddressesForUser(String uid) async {
    _currentUserId = uid;

    // 1. Load local cache from SharedPreferences for this specific user
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clean up legacy global key if it exists to prevent cross-account pollution
      if (prefs.containsKey('customer_saved_addresses_v1')) {
        await prefs.remove('customer_saved_addresses_v1');
      }

      final jsonStr = prefs.getString(_getStorageKey(uid));
      _addresses.clear();
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              _addresses.add(CustomerAddress.fromJson(item));
            }
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading customer addresses from local storage: $e');
    }

    // 2. Fetch latest addresses from Firebase Realtime Database if authenticated
    if (AuthService().currentUser != null) {
      await loadFromFirebase();
    }
  }

  /// Load addresses from Firebase Realtime Database for the current authenticated user
  Future<void> loadFromFirebase() async {
    final user = AuthService().currentUser;
    if (user == null) return;

    final uid = user.uid;
    _currentUserId = uid;

    try {
      final db = AuthService().database;
      final snapshot = await db.ref().child('users/$uid/addresses').get();
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

        _addresses.clear();
        _addresses.addAll(remoteList);
        notifyListeners();
        await _saveToLocalOnly(uid);
      } else {
        // User has no addresses in Firebase RTDB (new account or all deleted).
        // Clear both memory and local cache for this user so no stale addresses appear!
        _addresses.clear();
        notifyListeners();
        await _saveToLocalOnly(uid);
      }
    } catch (e) {
      debugPrint('Error loading addresses from Firebase RTDB: $e');
    }
  }

  Future<void> _saveToLocalOnly([String? uid]) async {
    final activeUserId = uid ?? _currentUserId ?? AuthService().currentUser?.uid;
    if (activeUserId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(activeUserId);
      if (_addresses.isEmpty) {
        await prefs.remove(key);
      } else {
        final jsonList = _addresses.map((a) => a.toJson()).toList();
        await prefs.setString(key, jsonEncode(jsonList));
      }
    } catch (e) {
      debugPrint('Error saving addresses locally: $e');
    }
  }

  Future<void> saveAddresses() async {
    final user = AuthService().currentUser;
    final uid = user?.uid ?? _currentUserId;
    if (uid != null) {
      await _saveToLocalOnly(uid);
    }

    // Persist to Firebase Realtime Database
    if (user != null) {
      try {
        final db = AuthService().database;
        if (_addresses.isEmpty) {
          await db.ref().child('users/${user.uid}/addresses').remove();
        } else {
          final mapData = <String, dynamic>{};
          for (final a in _addresses) {
            mapData[a.id] = a.toJson();
          }
          await db.ref().child('users/${user.uid}/addresses').set(mapData);
        }
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

    if (address.isDefault || _addresses.isEmpty) {
      _clearDefaults();
      address = address.copyWith(isDefault: true);
    }
    _addresses.add(address);
    notifyListeners();
    saveAddresses();
    return true;
  }

  bool updateAddress(CustomerAddress updated) {
    if (updated.address.trim().isEmpty || updated.type.trim().isEmpty) {
      return false;
    }

    final index = _addresses.indexWhere((a) => a.id == updated.id);
    if (index >= 0) {
      if (updated.isDefault || _addresses.length == 1) {
        _clearDefaults();
        updated = updated.copyWith(isDefault: true);
      }
      _addresses[index] = updated;
      notifyListeners();
      saveAddresses();
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
    saveAddresses();
  }

  void setDefault(String id) {
    final index = _addresses.indexWhere((a) => a.id == id);
    if (index >= 0) {
      _clearDefaults();
      _addresses[index] = _addresses[index].copyWith(isDefault: true);
      notifyListeners();
      saveAddresses();
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

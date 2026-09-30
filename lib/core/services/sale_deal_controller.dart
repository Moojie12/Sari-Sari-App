import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/sale_deal_model.dart';
import 'auth_service.dart';

/// Controller managing all custom On-Sale deals with local SharedPreferences cache
/// and real-time Firebase RTDB synchronization.
class SaleDealController extends ChangeNotifier {
  static const String _storageKey = 'cached_sale_deals_v1';

  SaleDealController._internal() {
    _loadLocalDeals();
    _initRealtimeSync();
  }

  static final SaleDealController instance = SaleDealController._internal();
  factory SaleDealController() => instance;

  final AuthService _authService = AuthService();
  StreamSubscription? _subscription;

  List<SaleDealModel> _deals = [];
  bool _isLoading = true;

  List<SaleDealModel> get deals => List.unmodifiable(_deals);
  List<SaleDealModel> get activeDeals => _deals.where((d) => d.isActive).toList();
  bool get isLoading => _isLoading;

  /// Loads cached deals from local SharedPreferences so data is immediately available
  Future<void> _loadLocalDeals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          final loaded = <SaleDealModel>[];
          for (final item in decoded) {
            if (item is Map) {
              try {
                loaded.add(SaleDealModel.fromMap(item));
              } catch (e) {
                debugPrint('Error parsing cached sale deal: $e');
              }
            }
          }
          if (loaded.isNotEmpty) {
            _deals = loaded;
            _isLoading = false;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading cached sale deals: $e');
    }
  }

  /// Persists the current in-memory deals to local SharedPreferences
  Future<void> _saveLocalDeals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_deals.map((d) => d.toMap()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('Error saving sale deals to local cache: $e');
    }
  }

  void _initRealtimeSync() {
    try {
      final db = _authService.database;
      final ref = db.ref().child('sale_deals');

      _subscription = ref.onValue.listen(
        (event) {
          final data = event.snapshot.value;
          if (data == null) {
            // Do not wipe locally cached deals if Firebase is empty or uninitialized
            if (_deals.isEmpty) {
              _isLoading = false;
              notifyListeners();
            }
            return;
          }

          final loaded = <SaleDealModel>[];
          if (data is Map) {
            data.forEach((key, value) {
              if (value is Map) {
                try {
                  loaded.add(SaleDealModel.fromMap(value, key.toString()));
                } catch (e) {
                  debugPrint('Error parsing sale deal $key: $e');
                }
              }
            });
          }

          // Sort by creation time newest first
          loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          _deals = loaded;
          _isLoading = false;
          notifyListeners();
          _saveLocalDeals();
        },
        onError: (error) {
          debugPrint('Firebase RTDB sale_deals error: $error');
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Note: Firebase RTDB initialization skipped or not available: $e');
      _isLoading = false;
    }
  }

  /// Saves (creates or updates) a sale deal to local cache, memory, and Firebase RTDB.
  Future<bool> saveDeal(SaleDealModel deal) async {
    final index = _deals.indexWhere((d) => d.id == deal.id);
    if (index >= 0) {
      _deals[index] = deal;
    } else {
      _deals.insert(0, deal);
    }
    _isLoading = false;
    notifyListeners();
    await _saveLocalDeals();

    try {
      final db = _authService.database;
      final ref = db.ref().child('sale_deals/${deal.id}');
      await ref.set(deal.toMap());
      return true;
    } catch (e) {
      debugPrint('Failed to save sale deal to Firebase: $e');
      // Still successfully preserved in local SharedPreferences and memory
      return true;
    }
  }

  /// Deletes a sale deal from Firebase RTDB, local cache, and memory.
  Future<bool> deleteDeal(String dealId) async {
    _deals.removeWhere((d) => d.id == dealId);
    notifyListeners();
    await _saveLocalDeals();

    try {
      final db = _authService.database;
      final ref = db.ref().child('sale_deals/$dealId');
      await ref.remove();
      return true;
    } catch (e) {
      debugPrint('Failed to delete sale deal from Firebase: $e');
      return true;
    }
  }

  /// Toggles whether a deal is active (visible to customers).
  Future<bool> toggleDealStatus(String dealId, bool isActive) async {
    final index = _deals.indexWhere((d) => d.id == dealId);
    if (index >= 0) {
      final updated = _deals[index].copyWith(isActive: isActive, updatedAt: DateTime.now());
      _deals[index] = updated;
      notifyListeners();
      await _saveLocalDeals();

      try {
        final db = _authService.database;
        await db.ref().child('sale_deals/$dealId/isActive').set(isActive);
        await db.ref().child('sale_deals/$dealId/updatedAt').set(updated.updatedAt!.toIso8601String());
        return true;
      } catch (e) {
        debugPrint('Failed to toggle sale deal status in Firebase: $e');
        return true;
      }
    }
    return false;
  }

  /// Helper for testing
  void setDealsForTesting(List<SaleDealModel> deals) {
    _deals = List.from(deals);
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sari_sari/models/sale_deal_model.dart';
import 'auth_service.dart';
import 'supabase_service.dart';

/// Controller managing all custom On-Sale deals with local SharedPreferences cache
/// and real-time Firebase RTDB synchronization.
class SaleDealController extends ChangeNotifier {
  static const String _storageKey = 'cached_sale_deals_v1';

  SaleDealController._internal() {
    _init();
  }

  static final SaleDealController instance = SaleDealController._internal();
  factory SaleDealController() => instance;

  final AuthService _authService = AuthService();
  StreamSubscription? _subscription;

  List<SaleDealModel> _deals = [];
  bool _isLoading = true;

  static int _compareDeals(SaleDealModel a, SaleDealModel b) {
    if (a.isActive != b.isActive) {
      return a.isActive ? -1 : 1; // Active promos at the top
    }
    return b.createdAt.compareTo(a.createdAt); // Newer first
  }

  List<SaleDealModel> get deals {
    final list = List<SaleDealModel>.from(_deals);
    list.sort(_compareDeals);
    return List.unmodifiable(list);
  }
  List<SaleDealModel> get activeDeals => deals.where((d) => d.isActive).toList();
  bool get isLoading => _isLoading;

  Future<void> loadDeals() async {
    await _loadLocalDeals();
  }

  Future<void> _init() async {
    await _loadLocalDeals();
    _initRealtimeSync();
  }

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
            final map = {for (final d in loaded) d.id: d};
            for (final local in _deals) {
              if (!map.containsKey(local.id)) {
                map[local.id] = local;
              }
            }
            final combined = map.values.toList()
              ..sort(_compareDeals);
            _deals = combined;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading cached sale deals: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
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
            _deals = [];
            _isLoading = false;
            notifyListeners();
            _saveLocalDeals();
            return;
          }

          final remoteDeals = <SaleDealModel>[];
          if (data is Map) {
            data.forEach((key, value) {
              if (value is Map) {
                try {
                  remoteDeals.add(SaleDealModel.fromMap(value, key.toString()));
                } catch (e) {
                  debugPrint('Error parsing sale deal $key: $e');
                }
              }
            });
          } else if (data is List) {
            for (int i = 0; i < data.length; i++) {
              final value = data[i];
              if (value is Map) {
                try {
                  remoteDeals.add(SaleDealModel.fromMap(value, 'deal-$i'));
                } catch (e) {
                  debugPrint('Error parsing sale deal index $i: $e');
                }
              }
            }
          }

          remoteDeals.sort(_compareDeals);
          _deals = remoteDeals;
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
      notifyListeners();
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
    _deals.sort(_compareDeals);
    _isLoading = false;
    notifyListeners();
    await _saveLocalDeals();

    try {
      final db = _authService.database;
      final ref = db.ref().child('sale_deals/${deal.id}');
      await ref.set(deal.toMap()).timeout(const Duration(seconds: 4));
      return true;
    } catch (e) {
      debugPrint('Failed to save sale deal to Firebase: $e');
      return true;
    }
  }

  /// Deletes a sale deal from Firebase RTDB, local cache, and memory,
  /// and removes any uploaded promo images from Supabase and Firebase storage.
  Future<bool> deleteDeal(String dealId) async {
    final dealToDelete = _deals.where((d) => d.id == dealId).firstOrNull;
    final imgUrl = dealToDelete?.image;

    _deals.removeWhere((d) => d.id == dealId);
    _deals.sort(_compareDeals);
    notifyListeners();
    await _saveLocalDeals();

    // Clean up uploaded images from Supabase storage and Firebase storage
    try {
      if (imgUrl != null && imgUrl.isNotEmpty) {
        await SupabaseService().deleteDealImages(dealId, imgUrl);
      } else {
        await SupabaseService().deleteDealImages(dealId);
      }
    } catch (e) {
      debugPrint('Error cleaning up deal images from storage: $e');
    }

    try {
      final db = _authService.database;
      final ref = db.ref().child('sale_deals/$dealId');
      await ref.remove().timeout(const Duration(seconds: 4));
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
      _deals.sort(_compareDeals);
      notifyListeners();
      await _saveLocalDeals();

      try {
        final db = _authService.database;
        final ref = db.ref().child('sale_deals/$dealId');
        await ref.update({
          'isActive': isActive,
          'is_active': isActive,
          'active': isActive,
          'updatedAt': updated.updatedAt!.toIso8601String(),
        }).timeout(const Duration(seconds: 4));
        return true;
      } catch (e) {
        debugPrint('Failed to toggle sale deal status in Firebase: $e');
        return true;
      }
    }
    return false;
  }

  /// Records the purchase of a deal bundle, updating the sold count and persisting
  Future<void> recordDealPurchase(String dealId, int quantity) async {
    final index = _deals.indexWhere((d) => d.id == dealId);
    if (index >= 0) {
      final deal = _deals[index];
      final newSoldCount = deal.soldCount + quantity;
      final updated = deal.copyWith(
        soldCount: newSoldCount,
        updatedAt: DateTime.now(),
      );
      _deals[index] = updated;
      notifyListeners();
      await _saveLocalDeals();

      try {
        final db = _authService.database;
        await db.ref().child('sale_deals/$dealId/soldCount').set(newSoldCount);
        await db.ref().child('sale_deals/$dealId/updatedAt').set(updated.updatedAt!.toIso8601String());
      } catch (e) {
        debugPrint('Failed to sync sold count to Firebase: $e');
      }
    }
  }

  /// Restores deal purchase sold count if an order was cancelled
  Future<void> restoreDealPurchase(String dealId, int quantity) async {
    final index = _deals.indexWhere((d) => d.id == dealId);
    if (index >= 0) {
      final deal = _deals[index];
      final newSoldCount = (deal.soldCount - quantity).clamp(0, 999999);
      final updated = deal.copyWith(
        soldCount: newSoldCount,
        updatedAt: DateTime.now(),
      );
      _deals[index] = updated;
      notifyListeners();
      await _saveLocalDeals();

      try {
        final db = _authService.database;
        await db.ref().child('sale_deals/$dealId/soldCount').set(newSoldCount);
        await db.ref().child('sale_deals/$dealId/updatedAt').set(updated.updatedAt!.toIso8601String());
      } catch (e) {
        debugPrint('Failed to sync restored sold count to Firebase: $e');
      }
    }
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

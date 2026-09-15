import 'package:flutter/foundation.dart';

class ShopSettingsController extends ChangeNotifier {
  ShopSettingsController._();

  static final ShopSettingsController instance = ShopSettingsController._();

  factory ShopSettingsController() => instance;

  double _deliveryFeePer500m = 5.0; // Default value
  int _lowStockThreshold = 10;
  int _expiryMonitoringDays = 30;

  double get deliveryFeePer500m => _deliveryFeePer500m;
  int get lowStockThreshold => _lowStockThreshold;
  int get expiryMonitoringDays => _expiryMonitoringDays;

  void updateDeliveryFee(double fee) {
    _deliveryFeePer500m = fee;
    notifyListeners();
  }

  void updateLowStockThreshold(int threshold) {
    _lowStockThreshold = threshold;
    notifyListeners();
  }

  void updateExpiryMonitoringDays(int days) {
    _expiryMonitoringDays = days;
    notifyListeners();
  }
}

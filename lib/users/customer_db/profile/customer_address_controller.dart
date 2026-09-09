import 'package:flutter/material.dart';
import 'customer_address_model.dart';

class CustomerAddressController extends ChangeNotifier {
  CustomerAddressController._();
  static final CustomerAddressController instance = CustomerAddressController._();
  factory CustomerAddressController() => instance;

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

  void addAddress(CustomerAddress address) {
    if (address.isDefault) {
      _clearDefaults();
    }
    _addresses.add(address);
    notifyListeners();
  }

  void updateAddress(CustomerAddress updated) {
    final index = _addresses.indexWhere((a) => a.id == updated.id);
    if (index >= 0) {
      if (updated.isDefault) {
        _clearDefaults();
      }
      _addresses[index] = updated;
      notifyListeners();
    }
  }

  void deleteAddress(String id) {
    _addresses.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  void setDefault(String id) {
    _clearDefaults();
    final index = _addresses.indexWhere((a) => a.id == id);
    if (index >= 0) {
      _addresses[index] = _addresses[index].copyWith(isDefault: true);
      notifyListeners();
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

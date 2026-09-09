import 'package:flutter/foundation.dart';

@immutable
class CustomerAddress {
  const CustomerAddress({
    required this.id,
    required this.type,
    required this.address,
    this.isDefault = false,
  });

  final String id;
  final String type; // e.g., 'Home', 'Office'
  final String address;
  final bool isDefault;

  CustomerAddress copyWith({
    String? type,
    String? address,
    bool? isDefault,
  }) {
    return CustomerAddress(
      id: id,
      type: type ?? this.type,
      address: address ?? this.address,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

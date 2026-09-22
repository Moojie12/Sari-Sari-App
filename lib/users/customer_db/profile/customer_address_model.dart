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

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'address': address,
    'isDefault': isDefault,
  };

  factory CustomerAddress.fromJson(Map<String, dynamic> json) => CustomerAddress(
    id: json['id']?.toString() ?? '',
    type: json['type']?.toString() ?? 'Home',
    address: json['address']?.toString() ?? '',
    isDefault: json['isDefault'] == true,
  );
}

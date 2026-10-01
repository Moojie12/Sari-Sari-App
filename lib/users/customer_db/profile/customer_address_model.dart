import 'package:flutter/foundation.dart';

@immutable
class CustomerAddress {
  const CustomerAddress({
    required this.id,
    required this.type,
    required this.address,
    this.province = 'Laguna',
    this.city,
    this.cityCode,
    this.barangay,
    this.barangayCode,
    this.streetDetails,
    this.isDefault = false,
  });

  final String id;
  final String type; // e.g., 'Home', 'Work', 'Office', 'School'
  final String address;
  final String province;
  final String? city;
  final String? cityCode;
  final String? barangay;
  final String? barangayCode;
  final String? streetDetails;
  final bool isDefault;

  CustomerAddress copyWith({
    String? type,
    String? address,
    String? province,
    String? city,
    String? cityCode,
    String? barangay,
    String? barangayCode,
    String? streetDetails,
    bool? isDefault,
  }) {
    return CustomerAddress(
      id: id,
      type: type ?? this.type,
      address: address ?? this.address,
      province: province ?? this.province,
      city: city ?? this.city,
      cityCode: cityCode ?? this.cityCode,
      barangay: barangay ?? this.barangay,
      barangayCode: barangayCode ?? this.barangayCode,
      streetDetails: streetDetails ?? this.streetDetails,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'address': address,
    'province': province,
    if (city != null) 'city': city,
    if (cityCode != null) 'cityCode': cityCode,
    if (barangay != null) 'barangay': barangay,
    if (barangayCode != null) 'barangayCode': barangayCode,
    if (streetDetails != null) 'streetDetails': streetDetails,
    'isDefault': isDefault,
  };

  factory CustomerAddress.fromJson(Map<String, dynamic> json) => CustomerAddress(
    id: json['id']?.toString() ?? '',
    type: json['type']?.toString() ?? 'Home',
    address: json['address']?.toString() ?? '',
    province: json['province']?.toString() ?? 'Laguna',
    city: json['city']?.toString(),
    cityCode: json['cityCode']?.toString(),
    barangay: json['barangay']?.toString(),
    barangayCode: json['barangayCode']?.toString(),
    streetDetails: json['streetDetails']?.toString(),
    isDefault: json['isDefault'] == true,
  );
}

import 'package:flutter/foundation.dart';

/// A sari-sari store product.
@immutable
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.capital,
    this.barcode,
    this.unit = 'pcs',
    this.image,
    required this.lowStockThreshold,
    required this.isWeightBased,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String category;
  final double price;
  final double capital;
  final String? barcode;
  final String unit;
  final String? image;
  final double lowStockThreshold;
  final bool isWeightBased;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Factory method to create a Product from Supabase JSON response
  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        price: (json['price'] as num).toDouble(),
        capital: (json['capital'] as num).toDouble(),
        barcode: json['barcode'] as String?,
        unit: json['unit'] as String? ?? 'pcs',
        image: json['image'] as String?,
        lowStockThreshold: (json['low_stock_threshold'] as num).toDouble(),
        isWeightBased: json['is_weight_based'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  /// Converts the Product to a JSON map suitable for Supabase
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'price': price,
        'capital': capital,
        'barcode': barcode,
        'unit': unit,
        'image': image,
        'low_stock_threshold': lowStockThreshold,
        'is_weight_based': isWeightBased,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  /// Creates a copy of this product with optional field replacements
  Product copyWith({
    String? id,
    String? name,
    String? category,
    double? price,
    double? capital,
    String? barcode,
    String? unit,
    String? image,
    double? lowStockThreshold,
    bool? isWeightBased,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      capital: capital ?? this.capital,
      barcode: barcode ?? this.barcode,
      unit: unit ?? this.unit,
      image: image ?? this.image,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      isWeightBased: isWeightBased ?? this.isWeightBased,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          category == other.category &&
          price == other.price &&
          capital == other.capital &&
          barcode == other.barcode &&
          unit == other.unit &&
          image == other.image &&
          lowStockThreshold == other.lowStockThreshold &&
          isWeightBased == other.isWeightBased &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      category.hashCode ^
      price.hashCode ^
      capital.hashCode ^
      barcode.hashCode ^
      unit.hashCode ^
      image.hashCode ^
      lowStockThreshold.hashCode ^
      isWeightBased.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() {
    return 'Product(id: $id, name: $name, category: $category)';
  }
}
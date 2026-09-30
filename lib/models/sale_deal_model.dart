import 'dart:math';

/// A product item included inside a customized on-sale deal or bundle.
class SaleDealItem {
  final String productId;
  final String productName;
  final int quantity;
  final double originalPrice;
  final String? image;
  final String? unit;

  const SaleDealItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.originalPrice,
    this.image,
    this.unit,
  });

  double get totalOriginalPrice => originalPrice * quantity;

  SaleDealItem copyWith({
    String? productId,
    String? productName,
    int? quantity,
    double? originalPrice,
    String? image,
    String? unit,
  }) {
    return SaleDealItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      originalPrice: originalPrice ?? this.originalPrice,
      image: image ?? this.image,
      unit: unit ?? this.unit,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'originalPrice': originalPrice,
      'image': image ?? '',
      'unit': unit ?? '',
    };
  }

  factory SaleDealItem.fromMap(Map<dynamic, dynamic> map) {
    return SaleDealItem(
      productId: (map['productId'] ?? '').toString(),
      productName: (map['productName'] ?? '').toString(),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      originalPrice: (map['originalPrice'] as num?)?.toDouble() ?? 0.0,
      image: map['image']?.toString(),
      unit: map['unit']?.toString(),
    );
  }
}

/// A customized on-sale deal created by the Owner that displays in the customer's "On Sale" section.
class SaleDealModel {
  final String id;
  final String title;
  final String description;
  final String? image;
  final double salePrice;
  final List<SaleDealItem> items;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const SaleDealModel({
    required this.id,
    required this.title,
    this.description = '',
    this.image,
    required this.salePrice,
    required this.items,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Returns the custom promo image, or falls back to the first item image with a photo
  String? get effectiveImage {
    if (image != null && image!.trim().isNotEmpty) {
      return image;
    }
    for (final item in items) {
      if (item.image != null && item.image!.trim().isNotEmpty) {
        return item.image;
      }
    }
    return null;
  }

  /// Total regular cost of all items in the bundle before promo discount
  double get originalTotalPrice {
    return items.fold(0.0, (sum, item) => sum + item.totalOriginalPrice);
  }

  /// Total money saved by customer
  double get discountSavings {
    return max(0.0, originalTotalPrice - salePrice);
  }

  /// Percentage of discount applied
  int get discountPercentage {
    if (originalTotalPrice <= 0) return 0;
    final pct = ((discountSavings / originalTotalPrice) * 100).round();
    return pct.clamp(0, 100);
  }

  /// Total count of physical units included (e.g. 1 Piattos + 2 Sardines = 3 pcs)
  int get totalItemQuantity {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  SaleDealModel copyWith({
    String? id,
    String? title,
    String? description,
    String? image,
    double? salePrice,
    List<SaleDealItem>? items,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SaleDealModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      image: image ?? this.image,
      salePrice: salePrice ?? this.salePrice,
      items: items ?? this.items,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image': image ?? '',
      'salePrice': salePrice,
      'items': items.map((item) => item.toMap()).toList(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory SaleDealModel.fromMap(Map<dynamic, dynamic> map, [String? fallbackId]) {
    final rawItems = map['items'];
    final parsedItems = <SaleDealItem>[];

    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map) {
          parsedItems.add(SaleDealItem.fromMap(raw));
        }
      }
    } else if (rawItems is Map) {
      for (final val in rawItems.values) {
        if (val is Map) {
          parsedItems.add(SaleDealItem.fromMap(val));
        }
      }
    }

    final createdStr = map['createdAt']?.toString();
    final updatedStr = map['updatedAt']?.toString();

    return SaleDealModel(
      id: (map['id'] ?? fallbackId ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      image: map['image']?.toString(),
      salePrice: (map['salePrice'] as num?)?.toDouble() ?? 0.0,
      items: parsedItems,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: createdStr != null ? (DateTime.tryParse(createdStr) ?? DateTime.now()) : DateTime.now(),
      updatedAt: updatedStr != null ? DateTime.tryParse(updatedStr) : null,
    );
  }
}

import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';

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
    int parseQty(dynamic val) {
      if (val is num) return val.toInt();
      if (val != null) {
        final parsed = int.tryParse(val.toString());
        if (parsed != null) return parsed;
      }
      return 1;
    }

    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val != null) {
        final parsed = double.tryParse(val.toString());
        if (parsed != null) return parsed;
      }
      return 0.0;
    }

    return SaleDealItem(
      productId: (map['productId'] ?? '').toString(),
      productName: (map['productName'] ?? '').toString(),
      quantity: parseQty(map['quantity']),
      originalPrice: parseDouble(map['originalPrice']),
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

  /// Returns the custom promo image, or falls back to the first item image with a valid photo
  String? get effectiveImage {
    final promoImg = _validDisplayImage(image);
    if (promoImg != null) {
      return promoImg;
    }
    for (final item in items) {
      final itemImg = _validDisplayImage(item.image);
      if (itemImg != null) {
        return itemImg;
      }
    }
    return null;
  }

  static String? _validDisplayImage(String? img) {
    if (img == null) return null;
    final trimmed = img.trim();
    if (trimmed.isEmpty) return null;

    // Remote network URLs, Base64 data URIs, and assets are universally valid across devices
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:image/') ||
        trimmed.startsWith('assets/')) {
      return trimmed;
    }

    // Local file path: only valid if it actually exists on THIS device.
    // If it's a local device path from another device (/data/user/0/...), return null to fall back!
    if (!kIsWeb) {
      String cleanPath = trimmed;
      if (cleanPath.startsWith('file://')) {
        cleanPath = cleanPath.substring(7);
      }
      try {
        if (File(cleanPath).existsSync()) {
          return cleanPath;
        }
      } catch (_) {}
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
          try {
            parsedItems.add(SaleDealItem.fromMap(raw));
          } catch (e) {
            debugPrint('Error parsing SaleDealItem: $e');
          }
        }
      }
    } else if (rawItems is Map) {
      for (final val in rawItems.values) {
        if (val is Map) {
          try {
            parsedItems.add(SaleDealItem.fromMap(val));
          } catch (e) {
            debugPrint('Error parsing SaleDealItem from map value: $e');
          }
        }
      }
    }

    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val != null) {
        final parsed = double.tryParse(val.toString());
        if (parsed != null) return parsed;
      }
      return 0.0;
    }

    final createdStr = map['createdAt']?.toString();
    final updatedStr = map['updatedAt']?.toString();

    final isActiveRaw = map['isActive'];
    final bool isActive = isActiveRaw is bool
        ? isActiveRaw
        : (isActiveRaw?.toString().toLowerCase() != 'false');

    return SaleDealModel(
      id: (map['id'] ?? fallbackId ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      image: map['image']?.toString(),
      salePrice: parseDouble(map['salePrice']),
      items: parsedItems,
      isActive: isActive,
      createdAt: createdStr != null ? (DateTime.tryParse(createdStr) ?? DateTime.now()) : DateTime.now(),
      updatedAt: updatedStr != null ? DateTime.tryParse(updatedStr) : null,
    );
  }
}

import 'package:flutter/foundation.dart';

/// A sari-sari store product category.
@immutable
class Category {
  const Category({
    required this.id,
    required this.name,
    this.description,
    required this.isArchived,
    this.archivedAt,
    this.archivedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final bool isArchived;
  final DateTime? archivedAt;
  final String? archivedBy; // References profiles.id
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Gets the display name for the category (used in UI)
  String get displayName => name;

  /// Checks if the category is active (not archived)
  bool get isActive => !isArchived;

  /// Factory method to create a Category from Supabase JSON response
  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        isArchived: json['is_archived'] as bool? ?? false,
        archivedAt: json['archived_at'] != null
            ? DateTime.parse(json['archived_at'] as String)
            : null,
        archivedBy: json['archived_by'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  /// Converts the Category to a JSON map suitable for Supabase
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'is_archived': isArchived,
        'archived_at': archivedAt?.toIso8601String(),
        'archived_by': archivedBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  /// Creates a copy of this category with optional field replacements
  Category copyWith({
    String? id,
    String? name,
    String? description,
    bool? isArchived,
    DateTime? archivedAt,
    String? archivedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      archivedBy: archivedBy ?? this.archivedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          isArchived == other.isArchived &&
          archivedAt == other.archivedAt &&
          archivedBy == other.archivedBy &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      description.hashCode ^
      isArchived.hashCode ^
      archivedAt.hashCode ^
      archivedBy.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() {
    return 'Category(id: $id, name: $name, isArchived: $isArchived)';
  }
}
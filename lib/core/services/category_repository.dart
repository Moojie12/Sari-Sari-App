import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/category.dart';

/// Repository for managing product categories in Supabase.
class CategoryRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Gets all active (non-archived) categories, ordered by name.
  Future<List<Category>> getActiveCategories() async {
    final response = await _supabase
        .from('categories')
        .select()
        .eq('is_archived', false)
        .order('name');

    return (response as List)
        .map((json) => Category.fromJson(json))
        .toList();
  }

  /// Gets all categories (including archived), ordered by name.
  Future<List<Category>> getAllCategories() async {
    final response = await _supabase
        .from('categories')
        .select()
        .order('name');

    return (response as List)
        .map((json) => Category.fromJson(json))
        .toList();
  }

  /// Creates a new category.
  ///
  /// [createdByProfileId] should be the profiles.id of the user creating the category.
  Future<Category> createCategory({
    required String name,
    String? description,
    required String createdByProfileId,
  }) async {
    // Validate input
    if (name.trim().isEmpty) {
      throw Exception('Category name cannot be empty');
    }
    if (name.trim().length < 2) {
      throw Exception('Category name must be at least 2 characters');
    }

    final response = await _supabase
        .from('categories')
        .insert({
          'name': name.trim(),
          'description': description?.trim(),
          'created_by': createdByProfileId,
          'updated_by': createdByProfileId,
        })
        .select()
        .single();

    return Category.fromJson(response);
  }

  /// Updates an existing category.
  ///
  /// [updatedByProfileId] should be the profiles.id of the user updating the category.
  Future<Category> updateCategory({
    required String id,
    required String name,
    String? description,
    required String updatedByProfileId,
  }) async {
    // Validate input
    if (name.trim().isEmpty) {
      throw Exception('Category name cannot be empty');
    }
    if (name.trim().length < 2) {
      throw Exception('Category name must be at least 2 characters');
    }

    final response = await _supabase
        .from('categories')
        .update({
          'name': name.trim(),
          'description': description?.trim(),
          'updated_by': updatedByProfileId,
        })
        .eq('id', id)
        .select()
        .single();

    return Category.fromJson(response);
  }

  /// Archives a category (soft delete).
  ///
  /// [archivedByProfileId] should be the profiles.id of the user archiving the category.
  Future<void> archiveCategory({
    required String id,
    required String archivedByProfileId,
  }) async {
    await _supabase
        .from('categories')
        .update({
          'is_archived': true,
          'archived_at': DateTime.now().toIso8601String(),
          'archived_by': archivedByProfileId,
          'updated_by': archivedByProfileId,
        })
        .eq('id', id);
  }

  /// Restores an archived category to active state.
  ///
  /// [restoredByProfileId] should be the profiles.id of the user restoring the category.
  Future<void> restoreCategory({
    required String id,
    required String restoredByProfileId,
  }) async {
    await _supabase
        .from('categories')
        .update({
          'is_archived': false,
          'archived_at': null,
          'archived_by': null,
          'updated_by': restoredByProfileId,
        })
        .eq('id', id);
  }

  /// Permanently deletes a category from the database.
  ///
  /// Use with caution - this removes the category permanently.
  /// Only use if no products are associated with this category.
  Future<void> deleteCategoryPermanently({
    required String id,
  }) async {
    await _supabase.from('categories').delete().eq('id', id);
  }

  /// Checks if a category name already exists (case-insensitive).
  ///
  /// [excludeId] is optional - if provided, ignores that category ID in the check
  /// (useful for update operations).
  Future<bool> categoryNameExists({
    required String name,
    String? excludeId,
  }) async {
    final query = _supabase
        .from('categories')
        .select('id')
        .ilike('name', name.trim());

    if (excludeId != null) {
      final response = await query.neq('id', excludeId);
      return (response as List).isNotEmpty;
    } else {
      final response = await query;
      return (response as List).isNotEmpty;
    }
  }
}
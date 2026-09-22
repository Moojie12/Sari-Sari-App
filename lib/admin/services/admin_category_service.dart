import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_models.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';

/// Service for handling category operations using Supabase as the data source
class AdminCategoryService extends ChangeNotifier {
  AdminCategoryService({
    SupabaseService? supabaseService,
    AuthService? authService,
  }) : _supabaseService = supabaseService ?? SupabaseService(),
       _authService = authService ?? AuthService() {
    initialize();
  }

  final SupabaseService _supabaseService;
  final AuthService _authService;

  // Cached data
  List<AdminCategory> _categories = [];

  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _realtimeChannel;

  // ==================== GETTERS ====================

  List<AdminCategory> get allCategories => List.unmodifiable(_categories);

  List<AdminCategory> get activeCategories =>
      _categories.where((c) => !c.isArchived).toList();

  List<AdminCategory> get archivedCategories =>
      _categories.where((c) => c.isArchived).toList();

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ==================== INITIALIZATION ====================

  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadCategories();
      _subscribeToRealtime();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeToRealtime() {
    if (_realtimeChannel != null) return;
    try {
      _realtimeChannel = _supabaseService.client
          .channel('public:admin_categories')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'categories',
            callback: (payload) {
              _loadCategories().then((_) => notifyListeners()).catchError((e) {
                debugPrint('Realtime category reload failed: $e');
              });
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Failed to subscribe to Supabase realtime in AdminCategoryService: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final supabaseCategories = await _supabaseService.getAllCategories();
      _categories = supabaseCategories.map(_fromSupabaseCategory).toList();
    } catch (e) {
      _error = 'Failed to load categories: $e';
      rethrow;
    }
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadCategories();
      _subscribeToRealtime();
      _isInitialized = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== CATEGORY OPERATIONS ====================

  AdminCategory categoryById(String id) =>
    _categories.firstWhere((c) => c.id == id, orElse: () => throw StateError('Category with id $id not found'));

  Future<String?> createCategory({
    required String name,
    required String description,
  }) async {
    try {
      if (name.trim().isEmpty) return 'Enter a category name.';
      if (name.trim().length < 2) return 'Category name needs at least 2 characters.';

      // Check if category already exists
      final exists = await _supabaseService.categoryNameExists(name: name.trim());
      if (exists) return 'A category with that name already exists.';

      // Get current user ID for created_by field
      final currentUserId = _authService.currentUser?.uid ?? 'system';

      final result = await _supabaseService.createCategory(
        name: name.trim(),
        description: description.trim(),
        createdByProfileId: currentUserId,
      );

      final newCategory = _fromSupabaseCategory(result);
      _categories.add(newCategory);
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to create category: $e';
    }
  }

  Future<String?> updateCategory({
    required String id,
    required String name,
    required String description,
  }) async {
    try {
      final index = _categories.indexWhere((c) => c.id == id);
      if (index == -1) return 'That category no longer exists.';

      if (name.trim().isEmpty) return 'Enter a category name.';
      if (name.trim().length < 2) return 'Category name needs at least 2 characters.';

      // Check if category name already exists (excluding current)
      final exists = await _supabaseService.categoryNameExists(
        name: name.trim(),
        excludeId: id,
      );
      if (exists) return 'A category with that name already exists.';

      // Get current user ID for updated_by field
      final currentUserId = 'current_user_id'; // TODO: Get from auth

      await _supabaseService.updateCategory(
        id: id,
        name: name.trim(),
        description: description.trim(),
        updatedByProfileId: currentUserId,
      );

      final updatedCategory = _categories[index].copyWith(
        name: name.trim(),
        description: description.trim(),
        updatedAt: DateTime.now(),
      );

      _categories[index] = updatedCategory;

      // Update categoryName in products that belong to this category
      // This would typically be done by querying products and updating them
      // For now, we'll note that products need to be updated separately
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to update category: $e';
    }
  }

  Future<String?> archiveCategory(String id) async {
    try {
      final index = _categories.indexWhere((c) => c.id == id);
      if (index == -1) return 'That category no longer exists.';

      final category = _categories[index];
      if (category.isArchived) return 'That category is already archived.';

      // Check if any active products are in this category
      // This would require getting product count from a product service
      // For now, we'll skip this check and let the UI handle it
      final currentUserId = 'current_user_id'; // TODO: Get from auth

      await _supabaseService.archiveCategory(
        id: id,
        archivedByProfileId: currentUserId,
      );

      final updatedCategory = category.copyWith(
        isArchived: true,
        archivedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _categories[index] = updatedCategory;
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to archive category: $e';
    }
  }

  Future<String?> restoreCategory(String id) async {
    try {
      final index = _categories.indexWhere((c) => c.id == id);
      if (index == -1) return 'That category no longer exists.';

      final category = _categories[index];
      if (!category.isArchived) return 'That category is already active.';

      // Get current user ID for restored_by field
      final currentUserId = 'current_user_id'; // TODO: Get from auth

      await _supabaseService.restoreCategory(
        id: id,
        restoredByProfileId: currentUserId,
      );

      final updatedCategory = category.copyWith(
        isArchived: false,
        archivedAt: null,
        updatedAt: DateTime.now(),
      );

      _categories[index] = updatedCategory;
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to restore category: $e';
    }
  }

  Future<String?> permanentlyDeleteCategory(String id) async {
    try {
      final category = categoryById(id);

      if (!category.isArchived) return 'Archive the category before deleting it.';

      // Check if any products are assigned to this category
      // This would require getting product count from a product service
      // For now, we'll skip this check and let the UI handle it
      await _supabaseService.deleteCategory(id: id); // Assuming this method exists

      _categories.removeWhere((c) => c.id == id);
      notifyListeners();

      return null;
    } catch (e) {
      return 'Failed to delete category: $e';
    }
  }

  // For now, we'll return 0 since we don't have access to product service
  // In a full implementation, this would query the product service
  // The sections that need this info have access to both services
  int getActiveProductCountForCategory(String categoryId) => 0;
  int getProductCountForCategory(String categoryId) => 0;

  // ==================== DATA TRANSFORMATION ====================

  AdminCategory _fromSupabaseCategory(Map<String, dynamic> data) {
    return AdminCategory(
      id: data['id'] as String,
      name: data['name'] as String,
      description: data['description'] as String ?? '',
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : null,
      updatedAt: data['updated_at'] != null
          ? DateTime.parse(data['updated_at'] as String)
          : null,
      isArchived: data['is_archived'] as bool? ?? false,
      archivedAt: data['archived_at'] != null
          ? DateTime.parse(data['archived_at'] as String)
          : null,
      archivedBy: data['archived_by'] as String?,
    );
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}
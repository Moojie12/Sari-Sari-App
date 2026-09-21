# Phase 4: Categories Implementation Plan

## 1. Inspect Existing Implementation

### Current Category Usage:
- **File**: `lib/users/employee_db/employee_inventory_controller.dart`
  - Uses `kEmployeeProductCategories` (List<String>) for category filtering in UI
  - Methods: `addCategory(String category)`, `removeCategory(String category)`
  - Categories stored as simple strings in a list

- **File**: `lib/users/customer_db/home/customer_dummy_products.dart`
  - Uses `kCustomerProductCategories` (List<String>) for customer-facing category filtering
  - Same category list as employee side

- **No persistent storage** - categories are hardcoded/lists in memory
- **No archiving/deletion logic** - just add/remove from list

### Current Category-Related Files:
1. `lib/users/employee_db/employee_inventory_controller.dart` - category list management
2. `lib/users/customer_db/home/customer_dummy_products.dart` - customer category list
3. Various UI files that use these category lists for filtering/dropdowns

## 2. Explain What Will Change

### From:
- In-memory List<String> for categories
- Hardcoded category values
- No persistence
- No archiving (just remove from list)
- No audit trail
- No user tracking for category changes

### To:
- Supabase `categories` table with proper schema
- Persistent storage with UUIDs
- Soft delete archiving (is_archived flag)
- Track who created/updated/archived categories
- Maintain created_at/updated_at timestamps
- Category name uniqueness constraint
- Ability to restore archived categories
- Proper foreign key relationships

## 3. Identify Files That Will Be Modified

### New Files to Create:
1. `supabase/migrations/001_create_categories_table.sql` - Migration file
2. `lib/core/services/category_repository.dart` - Supabase repository for categories
3. `lib/models/category.dart` - Dart model matching Supabase table
4. `lib/core/services/database_service.dart` - Supabase client wrapper (if not exists)

### Existing Files to Modify:
1. `lib/users/employee_db/employee_inventory_controller.dart` 
   - Replace `List<String> _categories` with repository calls
   - Update `addCategory()`, `removeCategory()`, `categories` getter
   - Remove `kEmployeeProductCategories` dependency

2. `lib/users/customer_db/home/customer_dummy_products.dart`
   - Replace `List<String> kCustomerProductCategories` with repository call
   - May need to create a customer-specific category service

3. UI files that consume category lists (to be updated incrementally):
   - Various filter dropdowns and category pickers throughout the app

## 4. Identify Files That Must Remain Untouched

### Core Business Logic (Should Work Unchanged):
- Product category validation logic
- UI components that display categories (only data source changes)
- Category-based filtering logic in products/inventory
- Product model's category_id/category_name fields

### Firebase/Services:
- Auth service (unchanged)
- Storage service (unchanged)
- Other service layers

## 5. Implement the Smallest Safe Change

### Step 1: Create Supabase Migration
```sql
-- supabase/migrations/002_create_categories_table.sql
create table categories (
  id uuid primary key default uuid_generate_v4(),
  name text unique not null,
  description text,
  is_archived boolean default false,
  archived_at timestamptz null,
  archived_by uuid references profiles(id) null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Indexes
create index idx_categories_name on categories(name);
create index idx_categories_is_archived on categories(is_archived);

-- Enable RLS (will add policies in Phase 13)
alter table categories enable row level security;
```

### Step 2: Create Category Model
```dart
// lib/models/category.dart
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

  // Factory to create from Supabase JSON
  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        isArchived: json['is_archived'],
        archivedAt: json['archived_at'] != null 
            ? DateTime.parse(json['archived_at']) 
            : null,
        archivedBy: json['archived_by'],
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'is_archived': isArchived,
        'archived_at': archivedAt?.toIso8601String(),
        'archivedBy': archivedBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
```

### Step 3: Create Category Repository
```dart
// lib/core/services/category_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category.dart';

class CategoryRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get all active categories (not archived)
  Future<List<Category>> getActiveCategories() async {
    final response = await _supabase
        .from('categories')
        .select()
        .eq('is_archived', false)
        .order('name');

    return (response.data as List)
        .map((json) => Category.fromJson(json))
        .toList();
  }

  // Get all categories (including archived)
  Future<List<Category>> getAllCategories() async {
    final response = await _supabase
        .from('categories')
        .select()
        .order('name');

    return (response.data as List)
        .map((json) => Category.fromJson(json))
        .toList();
  }

  // Create new category
  Future<Category> createCategory({
    required String name,
    String? description,
    required String createdByProfileId,
  }) async {
    final response = await _supabase
        .from('categories')
        .insert({
          'name': name,
          'description': description,
          'created_by': createdByProfileId,
          'updated_by': createdByProfileId,
        })
        .select()
        .single();

    return Category.fromJson(response.data);
  }

  // Update category
  Future<Category> updateCategory({
    required String id,
    required String name,
    String? description,
    required String updatedByProfileId,
  }) async {
    final response = await _supabase
        .from('categories')
        .update({
          'name': name,
          'description': description,
          'updated_by': updatedByProfileId,
        })
        .eq('id', id)
        .select()
        .single();

    return Category.fromJson(response.data);
  }

  // Archive category (soft delete)
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

  // Restore category
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
}
```

### Step 4: Update Employee Inventory Controller
Replace the category list management with repository calls.

## 6. Test the Feature
- Verify categories can be created, read, updated, archived, restored
- Check that UI reflects changes from Supabase
- Ensure archived categories don't appear in active lists
- Verify timestamps are set correctly

## 7. Verify Existing Mobile Functionality
- Product categorization still works
- Inventory filtering by category still functions
- UI dropdowns populate correctly
- No regression in existing features

## 8. Proceed to Next Phase
Once categories are working, move to Phase 5: Products
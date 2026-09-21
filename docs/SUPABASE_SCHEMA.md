# Supabase Database Schema Design

## Overview
This document defines the Supabase/PostgreSQL database schema for the Sari-Sari Store Management System migration.

## Core Principles
1. Firebase Authentication remains the auth provider
2. Supabase stores business data as the source of truth
3. Firebase UID is mapped to Supabase profiles via a text field (not treated as UUID)
4. Row Level Security (RLS) will be enforced on all tables
5. Schema designed to prevent data duplication and maintain integrity

## 1. Profiles Table

Maps Firebase users to Supabase identities with business profile data.

```sql
create table profiles (
  id uuid primary key default uuid_generate_v4(),
  firebase_uid text unique not null,
  first_name text not null,
  middle_initial text default '',
  surname text not null,
  email text unique not null,
  phone text,
  role text not null check (role in ('admin', 'owner', 'employee', 'customer')),
  status text not null default 'Enabled' check (status in ('Enabled', 'Disabled')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Indexes for performance
create index idx_profiles_firebase_uid on profiles(firebase_uid);
create index idx_profiles_role on profiles(role);
create index idx_profiles_status on profiles(status);
```

## 2. Categories Table

Product categorization system with archiving support.

```sql
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

-- Indexes for performance
create index idx_categories_name on categories(name);
create index idx_categories_is_archived on categories(is_archived);
```

### Columns Explanation:
- `id`: Internal Supabase UUID
- `name`: Unique category name (e.g., "Beverages", "Snacks")
- `description`: Optional category description
- `is_archived`: Soft delete flag for archiving
- `archived_at`: Timestamp when archived
- `archived_by`: Reference to profile who performed archiving
- `created_at`/`updated_at`: Audit timestamps

### Category Lifecycle:
```
Active
 ↓
Archived (can be restored)
 ↓
Permanently Deleted (removed from table)
```

### Supported Operations:
- Create category
- Update category (name/description)
- Archive category (soft delete)
- Restore category (from archived to active)
- Permanently delete category (hard delete - use with caution)
```

## 3. Roles & Status Implementation

Roles and status are implemented as text columns with CHECK constraints rather than separate tables to:
- Simplicity (fixed set of values)
- Performance (no joins needed for role/status checks)
- Flexibility (easy to modify constraints if needed)

### Supported Roles:
- `admin`: Administrative access
- `owner`: Full business access
- `employee`: POS and inventory operations
- `customer`: Customer-facing access

### Account Status:
- `Enabled`: Normal access
- `Disabled`: No access to protected operations

## 4. Timestamps Pattern
All tables will include:
- `created_at timestamptz default now()`
- `updated_at timestamptz default now()`

With a trigger function to automatically update `updated_at` on modifications.

## 5. Relationship to Firebase Auth
```
Firebase Authentication
        |
        | firebase_uid (string)
        ↓
Supabase profiles.firebase_uid
        |
        | profiles.id (uuid)
        ↓
Business Tables (products, orders, etc.)
```

This preserves:
- Firebase as the source of truth for authentication
- Stable database identity (profiles.id) for relationships
- Ability to change Firebase UID if needed (though uncommon)
- No exposure of Firebase UID as business data

## 6. Security Considerations
- RLS policies will be added in Phase 13
- No sensitive data (passwords, tokens) stored in profiles or categories
- Firebase UID treated as external identifier, not secret
- Role and status validated by database constraints
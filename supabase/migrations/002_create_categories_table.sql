-- Create categories table for Phase 4
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

-- Enable Row Level Security (policies will be added in Phase 13)
alter table categories enable row level security;
-- Create profiles table for Phase 3 and Identity Bridge
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

-- Enable Row Level Security (policies will be added in 009_create_rls_policies.sql)
alter table profiles enable row level security;

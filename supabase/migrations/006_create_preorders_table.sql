-- Create pre_orders table for Phase 9
create table pre_orders (
  id uuid primary key default uuid_generate_v4(),
  user_id text not null references auth.users(id) on delete restrict, -- Firebase UID
  order_number text unique not null,
  status text not null check (status in ('active', 'completed', 'cancelled')) default 'active',
  expected_date date not null,
  total_amount numeric(10,2) not null check (total_amount >= 0),
  total_items integer not null check (total_items >= 0),
  customer_name text,
  customer_contact text, -- phone or email
  delivery_address text,
  order_notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Create pre_order_items table
create table pre_order_items (
  id uuid primary key default uuid_generate_v4(),
  pre_order_id uuid not null references pre_orders(id) on delete cascade,
  product_id uuid not null references products(id) on delete restrict,
  product_name text not null, -- denormalized for easy reporting
  quantity double precision not null check (quantity > 0),
  unit_price numeric(10,2) not null check (unit_price >= 0),
  total_price numeric(10,2) not null check (total_price >= 0),
  created_at timestamptz default now()
);

-- Indexes for performance
create index idx_pre_orders_user_id on pre_orders(user_id);
create index idx_pre_orders_order_number on pre_orders(order_number);
create index idx_pre_orders_status on pre_orders(status);
create index idx_pre_orders_expected_date on pre_orders(expected_date);
create index idx_pre_order_items_pre_order_id on pre_order_items(pre_order_id);
create index idx_pre_order_items_product_id on pre_order_items(product_id);

-- Enable Row Level Security (policies will be added in Phase 13)
alter table pre_orders enable row level security;
alter table pre_order_items enable row level security;
-- Create orders table for Phase 8
create table orders (
  id uuid primary key default uuid_generate_v4(),
  user_id text not null references auth.users(id) on delete restrict, -- Firebase UID
  order_number text unique not null,
  status text not null check (status in ('pending', 'processing', 'completed', 'cancelled', 'refunded')) default 'pending',
  total_amount numeric(10,2) not null check (total_amount >= 0),
  total_items integer not null check (total_items >= 0),
  customer_name text,
  customer_contact text, -- phone or email
  delivery_address text,
  order_notes text,
  placed_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Create order_items table
create table order_items (
  id uuid primary key default uuid_generate_v4(),
  order_id uuid not null references orders(id) on delete cascade,
  product_id uuid not null references products(id) on delete restrict,
  product_name text not null, -- denormalized for easy reporting
  quantity double precision not null check (quantity > 0),
  unit_price numeric(10,2) not null check (unit_price >= 0),
  total_price numeric(10,2) not null check (total_price >= 0),
  created_at timestamptz default now()
);

-- Indexes for performance
create index idx_orders_user_id on orders(user_id);
create index idx_orders_order_number on orders(order_number);
create index idx_orders_status on orders(status);
create index idx_orders_placed_at on orders(placed_at);
create index idx_order_items_order_id on order_items(order_id);
create index idx_order_items_product_id on order_items(product_id);

-- Enable Row Level Security (policies will be added in Phase 13)
alter table orders enable row level security;
alter table order_items enable row level security;
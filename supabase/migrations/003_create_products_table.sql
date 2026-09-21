-- Create products table for Phase 5
create table products (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  category text not null references categories(name) on delete restrict,
  price numeric(10,2) not null check (price >= 0),
  capital numeric(10,2) not null check (capital >= 0),
  barcode text unique,
  unit text default 'pcs',
  image text,
  low_stock_threshold numeric(10,2) default 10.0 check (low_stock_threshold >= 0),
  is_weight_based boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Create product_batches table
create table product_batches (
  id uuid primary key default uuid_generate_v4(),
  product_id uuid not null references products(id) on delete cascade,
  quantity numeric(10,2) not null check (quantity >= 0),
  expiry_date timestamptz null,
  supplier text,
  notes text,
  received_date timestamptz default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Indexes for performance
create index idx_products_name on products(name);
create index idx_products_category on products(category);
create index idx_products_barcode on products(barcode);
create index idx_product_batches_product_id on product_batches(product_id);
create index idx_product_batches_expiry_date on product_batches(expiry_date) where expiry_date is not null;
create index idx_product_batches_received_date on product_batches(received_date);

-- Enable Row Level Security (policies will be added in Phase 13)
alter table products enable row level security;
alter table product_batches enable row level security;
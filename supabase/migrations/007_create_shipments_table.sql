-- Create shipments table for Phase 10: Order Shipment Management
create table shipments (
  id uuid primary key default uuid_generate_v4(),
  order_id uuid not null references orders(id) on delete restrict,
  tracking_number text unique,
  carrier text not null, -- e.g., 'LBC', 'J&T Express', 'Ninja Van'
  shipped_date timestamptz,
  estimated_delivery_date timestamptz,
  actual_delivery_date timestamptz,
  status text not null check (status in ('pending', 'shipped', 'delivered', 'lost', 'returned')) default 'pending',
  shipping_cost numeric(10,2) not null check (shipping_cost >= 0) default 0,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Indexes for performance
create index idx_shipments_order_id on shipments(order_id);
create index idx_shipments_tracking_number on shipments(tracking_number);
create index idx_shipments_status on shipments(status);
create index idx_shipments_shipped_date on shipments(shipped_date);

-- Enable Row Level Security (policies will be added in Phase 13)
alter table shipments enable row level security;
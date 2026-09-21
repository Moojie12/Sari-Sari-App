-- Create inventory_transactions table for Phase 7
create table inventory_transactions (
  id uuid primary key default uuid_generate_v4(),
  product_id uuid not null references products(id) on delete restrict,
  product_batch_id uuid references product_batches(id) on delete set null,
  transaction_type text not null check (transaction_type in ('receipt', 'wastage', 'consumable', 'sale', 'adjustment')),
  quantity numeric(10,2) not null,
  unit_price numeric(10,2) not null check (unit_price >= 0),
  total_amount numeric(10,2) not null check (total_amount >= 0),
  received_from text, -- For receipts: supplier name
  issued_to text, -- For wastage/consumable/sale: customer or employee name
  reference_number text, -- PO number, invoice number, etc.
  notes text,
  transaction_date timestamptz default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Indexes for performance
create index idx_inventory_transactions_product_id on inventory_transactions(product_id);
create index idx_inventory_transactions_product_batch_id on inventory_transactions(product_batch_id);
create index idx_inventory_transactions_transaction_type on inventory_transactions(transaction_type);
create index idx_inventory_transactions_transaction_date on inventory_transactions(transaction_date);

-- Enable Row Level Security (policies will be added in Phase 13)
alter table inventory_transactions enable row level security;
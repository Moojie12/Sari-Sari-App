-- SARISARI HUB - SUPABASE DATABASE SCHEMA BACKUP (V1 PRE-NORMALIZATION)
-- Created as a backup before database normalization enhancements.

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. TABLES

-- Profiles Table (Identity Bridge for Firebase)
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  firebase_uid text NOT NULL UNIQUE,
  first_name text NOT NULL,
  middle_initial text DEFAULT ''::text,
  surname text NOT NULL,
  email text NOT NULL UNIQUE,
  phone text,
  role text NOT NULL CHECK (role = ANY (ARRAY['admin'::text, 'owner'::text, 'employee'::text, 'customer'::text])),
  status text NOT NULL DEFAULT 'Enabled'::text CHECK (status = ANY (ARRAY['Enabled'::text, 'Disabled'::text])),
  avatar_url text,
  is_archived BOOLEAN DEFAULT false,
  archived_at timestamp with time zone,
  archived_by uuid REFERENCES public.profiles(id),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT profiles_pkey PRIMARY KEY (id)
);

-- Categories Table
CREATE TABLE IF NOT EXISTS public.categories (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name text NOT NULL UNIQUE,
  description text,
  is_archived boolean DEFAULT false,
  archived_at timestamp with time zone,
  archived_by uuid REFERENCES public.profiles(id),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT categories_pkey PRIMARY KEY (id)
);

-- Products Table
CREATE TABLE IF NOT EXISTS public.products (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  category text NOT NULL, -- Links to categories.name
  price numeric NOT NULL CHECK (price >= 0::numeric),
  capital numeric NOT NULL CHECK (capital >= 0::numeric),
  barcode text UNIQUE,
  unit text DEFAULT 'pcs'::text CHECK (unit = ANY (ARRAY['pcs'::text, 'piece'::text, 'pack'::text, 'bottle'::text, 'can'::text, 'box'::text, 'sachet'::text, 'kg'::text, 'gram'::text, 'liter'::text])),
  image text,
  description TEXT,
  low_stock_threshold numeric DEFAULT 5.0 CHECK (low_stock_threshold >= 0::numeric),
  is_weight_based boolean DEFAULT false,
  is_archived BOOLEAN DEFAULT false,
  archived_at timestamp with time zone,
  archived_by uuid REFERENCES public.profiles(id),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT products_pkey PRIMARY KEY (id),
  CONSTRAINT products_category_fkey FOREIGN KEY (category) REFERENCES public.categories(name)
);

-- Product Batches (Inventory Management - FEFO Support)
CREATE TABLE IF NOT EXISTS public.product_batches (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  batch_number text,
  quantity numeric NOT NULL CHECK (quantity >= 0::numeric),
  expiry_date timestamp with time zone,
  supplier text,
  notes text,
  received_date timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT product_batches_pkey PRIMARY KEY (id)
);

-- Inventory Transactions (Audit Trail)
CREATE TABLE IF NOT EXISTS public.inventory_transactions (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  product_id uuid NOT NULL REFERENCES public.products(id),
  product_batch_id uuid REFERENCES public.product_batches(id),
  transaction_type text NOT NULL CHECK (transaction_type = ANY (ARRAY['receipt'::text, 'wastage'::text, 'consumable'::text, 'sale'::text, 'adjustment'::text])),
  quantity numeric NOT NULL,
  unit_price numeric NOT NULL CHECK (unit_price >= 0::numeric),
  total_amount numeric NOT NULL CHECK (total_amount >= 0::numeric),
  received_from text,
  issued_to text,
  reference_number text,
  notes text,
  transaction_date timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT inventory_transactions_pkey PRIMARY KEY (id)
);

-- Orders Table (POS Sales & Online Orders)
CREATE TABLE IF NOT EXISTS public.orders (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES public.profiles(id), -- This stores the cashier/user UID
  order_number text NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'completed'::text CHECK (status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'preparing'::text, 'readyForShipment'::text, 'readyForPickup'::text, 'outForDelivery'::text, 'delivered'::text, 'completed'::text, 'cancelled'::text, 'refunded'::text, 'processing'::text, 'voided'::text])),
  total_amount numeric NOT NULL CHECK (total_amount >= 0::numeric),
  subtotal numeric DEFAULT 0 CHECK (subtotal >= 0::numeric),
  delivery_fee numeric DEFAULT 0 CHECK (delivery_fee >= 0::numeric),
  total_items integer NOT NULL CHECK (total_items >= 0),
  cashier_name text DEFAULT 'Unknown'::text,
  discount numeric DEFAULT 0 CHECK (discount >= 0),
  payment_method text DEFAULT 'cash'::text CHECK (payment_method = ANY (ARRAY['cash'::text, 'gcash'::text, 'maya'::text, 'card'::text])),
  payment_status text DEFAULT 'unpaid'::text,
  order_type text DEFAULT 'pickup'::text,
  amount_paid numeric DEFAULT 0 CHECK (amount_paid >= 0),
  customer_name text DEFAULT 'Walk-in'::text,
  customer_contact text,
  delivery_address text,
  order_notes text,
  void_reason text,
  voided_by uuid REFERENCES public.profiles(id),
  voided_at timestamp with time zone,
  placed_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT orders_pkey PRIMARY KEY (id)
);

-- Order Items
CREATE TABLE IF NOT EXISTS public.order_items (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id),
  product_name text NOT NULL,
  unit text NOT NULL DEFAULT 'piece'::text,
  quantity numeric NOT NULL CHECK (quantity > 0::numeric),
  unit_price numeric NOT NULL CHECK (unit_price >= 0::numeric),
  unit_cost numeric NOT NULL DEFAULT 0 CHECK (unit_cost >= 0::numeric),
  total_price numeric NOT NULL CHECK (total_price >= 0::numeric),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT order_items_pkey PRIMARY KEY (id)
);

-- Pre-Orders Table
CREATE TABLE IF NOT EXISTS public.pre_orders (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES public.profiles(id),
  order_number text NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'active'::text CHECK (status = ANY (ARRAY['active'::text, 'completed'::text, 'cancelled'::text])),
  expected_date date NOT NULL,
  total_amount numeric NOT NULL CHECK (total_amount >= 0::numeric),
  total_items integer NOT NULL CHECK (total_items >= 0),
  cashier_name text DEFAULT 'Unknown'::text,
  customer_name text,
  customer_contact text,
  delivery_address text,
  order_notes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT pre_orders_pkey PRIMARY KEY (id)
);

-- Pre-Order Items
CREATE TABLE IF NOT EXISTS public.pre_order_items (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pre_order_id uuid NOT NULL REFERENCES public.pre_orders(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id),
  product_name text NOT NULL,
  unit text NOT NULL DEFAULT 'piece'::text,
  quantity numeric NOT NULL CHECK (quantity > 0::numeric),
  unit_price numeric NOT NULL CHECK (unit_price >= 0::numeric),
  total_price numeric NOT NULL CHECK (total_price >= 0::numeric),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT pre_order_items_pkey PRIMARY KEY (id)
);

-- Shipments Table
CREATE TABLE IF NOT EXISTS public.shipments (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  order_id uuid NOT NULL REFERENCES public.orders(id),
  tracking_number text UNIQUE,
  carrier text NOT NULL,
  shipped_date timestamp with time zone,
  estimated_delivery_date timestamp with time zone,
  actual_delivery_date timestamp with time zone,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'shipped'::text, 'delivered'::text, 'lost'::text, 'returned'::text])),
  shipping_cost numeric NOT NULL DEFAULT 0 CHECK (shipping_cost >= 0::numeric),
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT shipments_pkey PRIMARY KEY (id)
);

-- Shop Settings Table (Singleton)
CREATE TABLE IF NOT EXISTS public.shop_settings (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  store_name text NOT NULL DEFAULT 'Sari-Sari Hub',
  store_address text,
  contact_number text,
  receipt_header text,
  receipt_footer text,
  low_stock_alert_enabled boolean DEFAULT true,
  updated_at timestamp with time zone DEFAULT now()
);

-- Audit Logs (System Activity)
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id text NOT NULL,
  entity_name text NOT NULL,
  performed_by text NOT NULL,
  timestamp timestamp with time zone DEFAULT now(),
  previous_status text,
  new_status text,
  note text,
  CONSTRAINT audit_logs_pkey PRIMARY KEY (id)
);

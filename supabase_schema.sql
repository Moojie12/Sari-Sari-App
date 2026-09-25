-- SARISARI HUB - SUPABASE DATABASE SCHEMA (NORMALIZED 1NF - 5NF)
-- This file contains the complete layout for tables, constraints, security policies, and RPCs.

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
  username text UNIQUE,
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
  created_by text,
  updated_by text,
  CONSTRAINT categories_pkey PRIMARY KEY (id)
);

-- Suppliers Table (3NF Normalization - Standalone Vendor Record)
CREATE TABLE IF NOT EXISTS public.suppliers (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name text NOT NULL UNIQUE,
  contact_number text,
  email text,
  address text,
  notes text,
  is_archived boolean DEFAULT false,
  archived_at timestamp with time zone,
  archived_by uuid REFERENCES public.profiles(id),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT suppliers_pkey PRIMARY KEY (id)
);

-- Units Table (Domain Normalization - Units of Measure)
CREATE TABLE IF NOT EXISTS public.units (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  is_decimal boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT units_pkey PRIMARY KEY (id)
);

-- Products Table
CREATE TABLE IF NOT EXISTS public.products (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  category_id uuid REFERENCES public.categories(id) ON DELETE RESTRICT,
  category text NOT NULL, -- Synchronized name for query compatibility
  price numeric NOT NULL CHECK (price >= 0::numeric),
  capital numeric NOT NULL CHECK (capital >= 0::numeric),
  barcode text UNIQUE,
  unit text DEFAULT 'pcs'::text,
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
  supplier_id uuid REFERENCES public.suppliers(id) ON DELETE SET NULL,
  batch_number text,
  quantity numeric NOT NULL CHECK (quantity >= 0::numeric),
  expiry_date timestamp with time zone,
  supplier text, -- Synchronized string for backwards compatibility
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
  user_id uuid NOT NULL REFERENCES public.profiles(id), -- Cashier or customer profile ID
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

-- Order Items (Point-in-time Snapshot Pattern for Sales Auditability)
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

-- 3. FUNCTIONS & RPCS

-- Atomic Sale Transaction Function
CREATE OR REPLACE FUNCTION public.create_sale_transaction(
  p_firebase_uid text,
  p_order_number text,
  p_total_amount numeric,
  p_total_items integer,
  p_items jsonb, -- Array of {product_id, quantity, unit_price, unit_cost}
  p_customer_name text DEFAULT 'Walk-in',
  p_customer_contact text DEFAULT NULL,
  p_delivery_address text DEFAULT NULL,
  p_order_notes text DEFAULT NULL,
  p_payment_method text DEFAULT 'cash',
  p_discount numeric DEFAULT 0,
  p_amount_paid numeric DEFAULT 0
) RETURNS uuid AS $$
DECLARE
  v_user_id uuid;
  v_order_id uuid;
  v_item record;
  v_batch record;
  v_qty_to_reduce numeric;
  v_reduced numeric;
  v_cashier_name text;
BEGIN
  -- 1. Get user_id and cashier_name from firebase_uid
  SELECT id, (first_name || ' ' || surname) INTO v_user_id, v_cashier_name FROM public.profiles WHERE firebase_uid = p_firebase_uid;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not found for firebase_uid %', p_firebase_uid;
  END IF;

  -- 2. Create Order
  INSERT INTO public.orders (
    user_id, cashier_name, order_number, total_amount, total_items,
    customer_name, customer_contact, delivery_address, order_notes,
    payment_method, discount, amount_paid, status
  ) VALUES (
    v_user_id, v_cashier_name, p_order_number, p_total_amount, p_total_items,
    p_customer_name, p_customer_contact, p_delivery_address, p_order_notes,
    p_payment_method, p_discount, p_amount_paid, 'completed'
  ) RETURNING id INTO v_order_id;

  -- 3. Process Items and Inventory
  FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id uuid, quantity numeric, unit_price numeric, unit_cost numeric)
  LOOP
    -- Get product name and unit for order_items
    DECLARE
      v_prod_name text;
      v_prod_unit text;
    BEGIN
      SELECT name, unit INTO v_prod_name, v_prod_unit FROM public.products WHERE id = v_item.product_id;

      -- Create order item
      INSERT INTO public.order_items (
        order_id, product_id, product_name, unit, quantity, unit_price, unit_cost, total_price
      ) VALUES (
        v_order_id, v_item.product_id, v_prod_name, v_prod_unit, v_item.quantity, v_item.unit_price, v_item.unit_cost, (v_item.unit_price * v_item.quantity)
      );

      -- Reduce inventory using FEFO (First Expiry First Out)
      v_qty_to_reduce := v_item.quantity;

      FOR v_batch IN
        SELECT id, quantity
        FROM public.product_batches
        WHERE product_id = v_item.product_id AND quantity > 0
        ORDER BY expiry_date ASC NULLS LAST, received_date ASC
      LOOP
        EXIT WHEN v_qty_to_reduce <= 0;

        IF v_batch.quantity >= v_qty_to_reduce THEN
          -- Batch has enough stock
          UPDATE public.product_batches SET quantity = quantity - v_qty_to_reduce WHERE id = v_batch.id;

          -- Log transaction
          INSERT INTO public.inventory_transactions (
            product_id, product_batch_id, transaction_type, quantity, unit_price, total_amount,
            reference_number, notes, issued_to
          ) VALUES (
            v_item.product_id, v_batch.id, 'sale', -v_qty_to_reduce, v_item.unit_price, (v_item.unit_price * v_qty_to_reduce),
            p_order_number, 'Sale transaction', p_customer_name
          );

          v_qty_to_reduce := 0;
        ELSE
          -- Batch doesn't have enough, take what's there and move to next batch
          v_reduced := v_batch.quantity;
          UPDATE public.product_batches SET quantity = 0 WHERE id = v_batch.id;

          INSERT INTO public.inventory_transactions (
            product_id, product_batch_id, transaction_type, quantity, unit_price, total_amount,
            reference_number, notes, issued_to
          ) VALUES (
            v_item.product_id, v_batch.id, 'sale', -v_reduced, v_item.unit_price, (v_item.unit_price * v_reduced),
            p_order_number, 'Sale transaction (partial batch)', p_customer_name
          );

          v_qty_to_reduce := v_qty_to_reduce - v_reduced;
        END IF;
      END LOOP;

      -- If we still have quantity to reduce but no more batches, log as adjustment / no batch
      IF v_qty_to_reduce > 0 THEN
         INSERT INTO public.inventory_transactions (
            product_id, transaction_type, quantity, unit_price, total_amount,
            reference_number, notes, issued_to
          ) VALUES (
            v_item.product_id, 'sale', -v_qty_to_reduce, v_item.unit_price, (v_item.unit_price * v_qty_to_reduce),
            p_order_number, 'Sale transaction (excess/no batch)', p_customer_name
          );
      END IF;
    END;
  END LOOP;

  RETURN v_order_id;
END;
$$ LANGUAGE plpgsql;

-- Pre-order Transaction Function
CREATE OR REPLACE FUNCTION public.create_preorder_transaction(
  p_firebase_uid text,
  p_order_number text,
  p_total_amount numeric,
  p_total_items integer,
  p_expected_date timestamp with time zone,
  p_items jsonb,
  p_customer_name text DEFAULT NULL,
  p_customer_contact text DEFAULT NULL,
  p_delivery_address text DEFAULT NULL,
  p_order_notes text DEFAULT NULL
) RETURNS uuid AS $$
DECLARE
  v_user_id uuid;
  v_cashier_name text;
  v_preorder_id uuid;
  v_item record;
BEGIN
  SELECT id, (first_name || ' ' || surname) INTO v_user_id, v_cashier_name FROM public.profiles WHERE firebase_uid = p_firebase_uid;

  INSERT INTO public.pre_orders (
    user_id, cashier_name, order_number, status, expected_date, total_amount, total_items,
    customer_name, customer_contact, delivery_address, order_notes
  ) VALUES (
    v_user_id, v_cashier_name, p_order_number, 'active', p_expected_date::date, p_total_amount, p_total_items,
    p_customer_name, p_customer_contact, p_delivery_address, p_order_notes
  ) RETURNING id INTO v_preorder_id;

  FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id uuid, quantity numeric, unit_price numeric)
  LOOP
    DECLARE
      v_prod_name text;
      v_prod_unit text;
    BEGIN
      SELECT name, unit INTO v_prod_name, v_prod_unit FROM public.products WHERE id = v_item.product_id;

      INSERT INTO public.pre_order_items (
        pre_order_id, product_id, product_name, unit, quantity, unit_price, total_price
      ) VALUES (
        v_preorder_id, v_item.product_id, v_prod_name, v_prod_unit, v_item.quantity, v_item.unit_price, (v_item.unit_price * v_item.quantity)
      );
    END;
  END LOOP;

  RETURN v_preorder_id;
END;
$$ LANGUAGE plpgsql;

-- Convert Pre-order to Order Function
CREATE OR REPLACE FUNCTION public.convert_preorder_to_order(
  p_preorder_id uuid,
  p_order_number text
) RETURNS uuid AS $$
DECLARE
  v_preorder record;
  v_items jsonb;
BEGIN
  SELECT po.*, p.firebase_uid
  INTO v_preorder
  FROM public.pre_orders po
  JOIN public.profiles p ON po.user_id = p.id
  WHERE po.id = p_preorder_id;

  IF v_preorder IS NULL THEN
    RAISE EXCEPTION 'Pre-order not found';
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'product_id', product_id,
    'quantity', quantity,
    'unit_price', unit_price,
    'unit_cost', 0
  )) INTO v_items
  FROM public.pre_order_items
  WHERE pre_order_id = p_preorder_id;

  PERFORM public.create_sale_transaction(
    v_preorder.firebase_uid,
    p_order_number,
    v_preorder.total_amount,
    v_preorder.total_items,
    v_items,
    v_preorder.customer_name,
    v_preorder.customer_contact,
    v_preorder.delivery_address,
    v_preorder.order_notes
  );

  UPDATE public.pre_orders SET status = 'completed', updated_at = now() WHERE id = p_preorder_id;

  RETURN p_preorder_id;
END;
$$ LANGUAGE plpgsql;

-- 4. SECURITY (RLS - Row Level Security)
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.units DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_batches DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_transactions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.pre_orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.pre_order_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipments DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_settings DISABLE ROW LEVEL SECURITY;

-- 5. STORAGE BUCKETS
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

INSERT INTO storage.buckets (id, name, public)
VALUES ('products', 'products', true)
ON CONFLICT (id) DO UPDATE SET public = true;

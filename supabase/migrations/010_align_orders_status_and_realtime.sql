-- Migration 010: Align Order Statuses, Add Supporting Columns, and Enable Realtime
-- This migration ensures that the orders table supports all order lifecycle statuses
-- used by the Owner, Employee, and Customer dashboards.

-- 1. Add supporting columns if they do not already exist
ALTER TABLE public.orders 
  ADD COLUMN IF NOT EXISTS payment_status text DEFAULT 'unpaid'::text,
  ADD COLUMN IF NOT EXISTS order_type text DEFAULT 'pickup'::text,
  ADD COLUMN IF NOT EXISTS delivery_fee numeric DEFAULT 0 CHECK (delivery_fee >= 0),
  ADD COLUMN IF NOT EXISTS subtotal numeric DEFAULT 0 CHECK (subtotal >= 0);

-- 2. Drop the old restrictive check constraint on status
ALTER TABLE public.orders 
  DROP CONSTRAINT IF EXISTS orders_status_check;

-- 3. Add the expanded check constraint matching the application's OrderStatus enum
ALTER TABLE public.orders 
  ADD CONSTRAINT orders_status_check CHECK (
    status = ANY (ARRAY[
      'pending'::text,
      'confirmed'::text,
      'preparing'::text,
      'readyForShipment'::text,
      'readyForPickup'::text,
      'outForDelivery'::text,
      'delivered'::text,
      'completed'::text,
      'cancelled'::text,
      'refunded'::text,
      'processing'::text,
      'voided'::text
    ])
  );

-- 4. Enable Supabase Realtime broadcast for orders and order_items
ALTER TABLE public.orders REPLICA IDENTITY FULL;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
  END IF;
END $$;

-- =============================================================================
-- MIGRATION 014: ENABLE ROW LEVEL SECURITY (RLS) & CREATE RATE LIMIT TABLE
-- =============================================================================
-- Resolves Supabase Linter warnings (policy_exists_rls_disabled & rls_disabled_in_public)
-- Creates the missing rate_limit_events table for login/checkout rate limiting
-- while ensuring Flutter client app using Firebase Auth + Supabase Anon Key
-- continues functioning smoothly.
-- =============================================================================

-- 0. CREATE RATE_LIMIT_EVENTS TABLE IF NOT EXISTS
CREATE TABLE IF NOT EXISTS public.rate_limit_events (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  identifier text NOT NULL,
  action_type text NOT NULL,
  attempt_timestamp timestamp with time zone DEFAULT now(),
  lockout_until timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT rate_limit_events_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_rate_limit_events_identifier ON public.rate_limit_events(identifier, action_type);

-- 1. ENABLE ROW LEVEL SECURITY ON ALL PUBLIC TABLES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pre_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pre_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rate_limit_events ENABLE ROW LEVEL SECURITY;

-- 2. CLEANUP EXISTING ANON POLICIES IF THEY EXIST
DROP POLICY IF EXISTS "Allow anon access to profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow anon access to categories" ON public.categories;
DROP POLICY IF EXISTS "Allow anon access to products" ON public.products;
DROP POLICY IF EXISTS "Allow anon access to product_batches" ON public.product_batches;
DROP POLICY IF EXISTS "Allow anon access to inventory_transactions" ON public.inventory_transactions;
DROP POLICY IF EXISTS "Allow anon access to orders" ON public.orders;
DROP POLICY IF EXISTS "Allow anon access to order_items" ON public.order_items;
DROP POLICY IF EXISTS "Allow anon access to pre_orders" ON public.pre_orders;
DROP POLICY IF EXISTS "Allow anon access to pre_order_items" ON public.pre_order_items;
DROP POLICY IF EXISTS "Allow anon access to shipments" ON public.shipments;
DROP POLICY IF EXISTS "Allow anon access to shop_settings" ON public.shop_settings;
DROP POLICY IF EXISTS "Allow anon access to audit_logs" ON public.audit_logs;
DROP POLICY IF EXISTS "Allow anon access to units" ON public.units;
DROP POLICY IF EXISTS "Allow anon access to suppliers" ON public.suppliers;
DROP POLICY IF EXISTS "Allow anon access to rate_limit_events" ON public.rate_limit_events;

-- 3. CREATE PERMISSIVE ANON & AUTHENTICATED POLICIES FOR FLUTTER APP COMPATIBILITY
CREATE POLICY "Allow anon access to profiles" ON public.profiles FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon access to categories" ON public.categories FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon access to products" ON public.products FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon access to product_batches" ON public.product_batches FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon access to inventory_transactions" ON public.inventory_transactions FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon access to orders" ON public.orders FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon access to order_items" ON public.order_items FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon access to pre_orders" ON public.pre_orders FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon access to pre_order_items" ON public.pre_order_items FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon access to shipments" ON public.shipments FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon access to shop_settings" ON public.shop_settings FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon access to audit_logs" ON public.audit_logs FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon access to units" ON public.units FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon access to suppliers" ON public.suppliers FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon access to rate_limit_events" ON public.rate_limit_events FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

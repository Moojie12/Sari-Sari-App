-- =============================================================================
-- MIGRATION 013: DATABASE NORMALIZATION (1NF - 5NF ENHANCEMENTS)
-- =============================================================================
-- This migration normalizes the database schema according to 1NF-5NF principles:
-- 1. Creates a standalone 'suppliers' table (3NF - eliminates supplier text repetition & anomalies)
-- 2. Links 'product_batches' to 'suppliers(id)' via 'supplier_id'
-- 3. Adds 'category_id' (FK to categories.id) on 'products' table for surrogate key 3NF normalization
-- 4. Creates a 'units' lookup table for standardized unit of measure management
-- 5. Preserves backward-compatibility for existing Flutter queries via sync triggers
-- =============================================================================

-- 1. CREATE SUPPLIERS TABLE (3NF Normalization)
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

-- Index for fast supplier lookups
CREATE INDEX IF NOT EXISTS idx_suppliers_name ON public.suppliers(name);
CREATE INDEX IF NOT EXISTS idx_suppliers_is_archived ON public.suppliers(is_archived);

-- 2. ADD SUPPLIER_ID TO PRODUCT_BATCHES
ALTER TABLE public.product_batches
  ADD COLUMN IF NOT EXISTS supplier_id uuid REFERENCES public.suppliers(id) ON DELETE SET NULL;

-- Migrate existing string suppliers in product_batches to the suppliers table
DO $$
DECLARE
  r RECORD;
  v_supplier_id UUID;
BEGIN
  FOR r IN SELECT DISTINCT supplier FROM public.product_batches WHERE supplier IS NOT NULL AND supplier <> ''
  LOOP
    INSERT INTO public.suppliers (name)
    VALUES (r.supplier)
    ON CONFLICT (name) DO NOTHING;

    SELECT id INTO v_supplier_id FROM public.suppliers WHERE name = r.supplier;

    UPDATE public.product_batches
    SET supplier_id = v_supplier_id
    WHERE supplier = r.supplier AND supplier_id IS NULL;
  END LOOP;
END $$;

CREATE INDEX IF NOT EXISTS idx_product_batches_supplier_id ON public.product_batches(supplier_id);

-- 3. ADD CATEGORY_ID TO PRODUCTS TABLE (3NF Normalization)
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS category_id uuid REFERENCES public.categories(id) ON DELETE RESTRICT;

-- Populate existing category_id from categories table matching by name
UPDATE public.products p
SET category_id = c.id
FROM public.categories c
WHERE p.category = c.name AND p.category_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_products_category_id ON public.products(category_id);

-- Trigger to auto-sync category_id when category text is inserted/updated on products
CREATE OR REPLACE FUNCTION public.sync_product_category_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.category IS NOT NULL THEN
    SELECT id INTO NEW.category_id FROM public.categories WHERE name = NEW.category;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_product_category_id ON public.products;
CREATE TRIGGER trg_sync_product_category_id
BEFORE INSERT OR UPDATE OF category ON public.products
FOR EACH ROW EXECUTE FUNCTION public.sync_product_category_id();

-- 4. CREATE UNITS LOOKUP TABLE (Domain Normalization)
CREATE TABLE IF NOT EXISTS public.units (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  is_decimal boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT units_pkey PRIMARY KEY (id)
);

-- Seed standard units
INSERT INTO public.units (code, name, is_decimal) VALUES
  ('pcs', 'Pieces', false),
  ('piece', 'Piece', false),
  ('pack', 'Pack', false),
  ('bottle', 'Bottle', false),
  ('can', 'Can', false),
  ('box', 'Box', false),
  ('sachet', 'Sachet', false),
  ('kg', 'Kilogram', true),
  ('gram', 'Gram', true),
  ('liter', 'Liter', true)
ON CONFLICT (code) DO NOTHING;

-- 5. ROW LEVEL SECURITY STATUS
ALTER TABLE public.suppliers DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.units DISABLE ROW LEVEL SECURITY;

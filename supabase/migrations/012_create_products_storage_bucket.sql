-- 012_create_products_storage_bucket.sql
-- Create storage bucket for product images and configure RLS policies

-- 1. Create the 'products' bucket if it doesn't already exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('products', 'products', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Allow public access to view product images
CREATE POLICY "Public Access Products"
ON storage.objects FOR SELECT
USING (bucket_id = 'products');

-- 3. Allow authenticated users to upload product images
CREATE POLICY "Authenticated users can upload product images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'products');

-- 4. Allow authenticated users to update their product images
CREATE POLICY "Authenticated users can update product images"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'products');

-- 5. Allow authenticated users to delete product images
CREATE POLICY "Authenticated users can delete product images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'products');

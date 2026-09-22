-- Migration 011: Add avatar_url to profiles and setup avatars storage bucket

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url text;

-- Create avatars storage bucket if it does not exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- RLS Policies for avatars bucket
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Public Access to Avatars'
  ) THEN
    CREATE POLICY "Public Access to Avatars"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Authenticated Users Upload Avatars'
  ) THEN
    CREATE POLICY "Authenticated Users Upload Avatars"
    ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'avatars');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Users Update Own Avatars'
  ) THEN
    CREATE POLICY "Users Update Own Avatars"
    ON storage.objects FOR UPDATE
    USING (bucket_id = 'avatars');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Users Delete Own Avatars'
  ) THEN
    CREATE POLICY "Users Delete Own Avatars"
    ON storage.objects FOR DELETE
    USING (bucket_id = 'avatars');
  END IF;
END $$;

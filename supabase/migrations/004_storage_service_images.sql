-- Creates public storage bucket for service images
INSERT INTO storage.buckets (id, name, public)
VALUES ('service-images', 'service-images', true)
ON CONFLICT (id) DO NOTHING;

-- Public read access (client app can display images without auth)
CREATE POLICY "Public read service images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'service-images');

-- Authenticated users (admins/employees) can upload
CREATE POLICY "Authenticated upload service images"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'service-images');

-- Authenticated users can overwrite existing images
CREATE POLICY "Authenticated update service images"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'service-images');

-- Authenticated users can delete images
CREATE POLICY "Authenticated delete service images"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'service-images');

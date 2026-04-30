-- Adds image URL support to services (displayed in client app)
ALTER TABLE services ADD COLUMN IF NOT EXISTS image_url TEXT;

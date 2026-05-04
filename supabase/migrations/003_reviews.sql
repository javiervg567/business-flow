-- ============================================================
-- Business Flow - Reseñas de citas
-- ============================================================

CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (booking_id)
);

CREATE INDEX idx_reviews_booking ON reviews(booking_id);
CREATE INDEX idx_reviews_client ON reviews(client_id);
CREATE INDEX idx_reviews_business ON reviews(business_id);

ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Clientes pueden ver y crear sus propias reseñas
CREATE POLICY "clients_own_reviews_select" ON reviews
  FOR SELECT USING (client_id = auth.uid());

CREATE POLICY "clients_own_reviews_insert" ON reviews
  FOR INSERT WITH CHECK (client_id = auth.uid());

-- Admin y empleados pueden ver todas las reseñas de su negocio
CREATE POLICY "staff_reviews_select" ON reviews
  FOR SELECT USING (
    business_id IN (
      SELECT business_id FROM profiles WHERE id = auth.uid()
    )
  );

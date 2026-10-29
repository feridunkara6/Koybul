-- =========================================================================
-- 0022 — SEYİR PAYLAŞIMI + "PRUVAN NETA" (SP-3b, kurucu onayı 2026-10-31)
--
-- Kaptan, Defter'deki GERÇEKLEŞEN seyrini toplulukla paylaşabilir. Paylaşım
-- YALNIZ yapısal verilerdir: başlangıç/bitiş adı (katalog adları), mesafe,
-- süre, durak sayısı, sefer günü. Serbest metin TAŞINMAZ — bu yüzden
-- moderasyon kuyruğuna girmez (notlardan farkı budur, bilinçli karar).
--
-- GİZLİLİK (kurucu kuralı): "Konumum" ile başlayan seyirde başlangıç adı
-- İSTEMCİDE düşürülür (start_name NULL gelir); koordinat hiçbir zaman
-- taşınmaz. Konum geçmişi/iz SAKLANMAZ.
--
-- "Pruvan neta" ⚓: tek tür, tek dokunuş tepki — denizci selamı. DM değildir,
-- bildirim zorunluluğu yoktur; sayaç kartta görünür.
-- =========================================================================

CREATE TABLE IF NOT EXISTS shared_trips (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  -- Katalog kaynaklı adlar; serbest metin değil (istemci durak adını yollar).
  start_name  text CHECK (start_name IS NULL OR char_length(start_name) BETWEEN 1 AND 80),
  end_name    text CHECK (end_name   IS NULL OR char_length(end_name)   BETWEEN 1 AND 80),
  -- Plan mesafesi (≈, beyan) — rotalarla aynı aralık ve dürüstlük ilkesi.
  distance_nm numeric(6,1) NOT NULL CHECK (distance_nm >= 0 AND distance_nm <= 500),
  -- Kaptanın elle girdiği süre (dk); yoksa NULL (dürüst boşluk). 10 gün tavan.
  duration_min int CHECK (duration_min >= 1 AND duration_min <= 14400),
  stop_count  int NOT NULL DEFAULT 0 CHECK (stop_count >= 0 AND stop_count <= 50),
  sailed_on   date NOT NULL,
  -- Türetilmiş sayaç (route_saves deseni): kaynak trip_reactions.
  pruva_count int NOT NULL DEFAULT 0 CHECK (pruva_count >= 0),
  created_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz
);

CREATE INDEX IF NOT EXISTS idx_shared_trips_user_created
  ON shared_trips (user_id, created_at DESC);
-- Akış sorgusu (takip edilenlerin en yenileri) için.
CREATE INDEX IF NOT EXISTS idx_shared_trips_created
  ON shared_trips (created_at DESC);

CREATE TABLE IF NOT EXISTS trip_reactions (
  trip_id    uuid NOT NULL REFERENCES shared_trips(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (trip_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_trip_reactions_user ON trip_reactions (user_id);

-- RLS (0017 deseni): okuma herkese açık; yazma yalnız satır sahibi;
-- altyapı yolu (app_current_user_id() IS NULL) serbest.
ALTER TABLE shared_trips ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY shared_trips_read ON shared_trips FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY shared_trips_owner ON shared_trips FOR ALL
    USING (app_current_user_id() IS NULL OR user_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR user_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE trip_reactions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY trip_reactions_read ON trip_reactions FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY trip_reactions_owner ON trip_reactions FOR ALL
    USING (app_current_user_id() IS NULL OR user_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR user_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

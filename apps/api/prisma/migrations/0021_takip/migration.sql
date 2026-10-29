-- =========================================================================
-- 0021 — TAKİP SİSTEMİ (SP-3a, kurucu onayı 2026-10-31)
--
-- "Kaptanı takip et": içerik aboneliği — karşılıklı onay gerektirmez, DM
-- hakkı vermez (sosyalleşme raporu §4A). Takip grafiği SP-3b'deki akışın
-- temelidir; kaptan kartında takipçi sayısı herkese açıktır.
-- =========================================================================

CREATE TABLE IF NOT EXISTS user_follows (
  follower_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  followed_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, followed_id),
  -- Kendini takip etmek anlamsız — şema düzeyinde kapalı.
  CONSTRAINT ck_user_follows_self CHECK (follower_id <> followed_id)
);

-- "Kimler takip ediyor" sayımı ve SP-3b akış sorgusu için.
CREATE INDEX IF NOT EXISTS idx_user_follows_followed ON user_follows (followed_id);

-- RLS (0017 deseniyle aynı): okuma herkese açık (sayı zaten kartta),
-- yazma yalnız satırın sahibi (takip eden); altyapı yolu serbest.
ALTER TABLE user_follows ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY user_follows_read ON user_follows FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY user_follows_owner ON user_follows FOR ALL
    USING (app_current_user_id() IS NULL OR follower_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR follower_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

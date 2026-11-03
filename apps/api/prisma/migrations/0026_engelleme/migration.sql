-- =========================================================================
-- 0026 — KULLANICI ENGELLEME (ENG-1, kurucu onayı 2026-11-03)
--
-- App Store 1.2 gereği: içerik şikâyeti + moderasyonun yanına "kullanıcıyı
-- engelle" gelir. Engelleme SESSİZDİR: karşı tarafa bildirim gitmez,
-- engellendiğini görmez. Liste yalnız engelleyene aittir (RLS okuma dahi
-- sahibe kilitli — takip listesinden farklı: bu sayı/liste kamusal DEĞİL).
-- =========================================================================

CREATE TABLE IF NOT EXISTS user_blocks (
  blocker_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  -- Kendini engellemek anlamsız — şema düzeyinde kapalı.
  CONSTRAINT ck_user_blocks_self CHECK (blocker_id <> blocked_id)
);

-- "Beni engelleyenler" denetimi (takip kapısı) için.
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON user_blocks (blocked_id);

ALTER TABLE user_blocks ENABLE ROW LEVEL SECURITY;

-- Okuma da sahibe kilitli (altyapı yolu serbest): engel listesi kamusal değildir.
DO $$ BEGIN
  CREATE POLICY user_blocks_owner_read ON user_blocks FOR SELECT
    USING (app_current_user_id() IS NULL OR blocker_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY user_blocks_owner_write ON user_blocks FOR ALL
    USING (app_current_user_id() IS NULL OR blocker_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR blocker_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

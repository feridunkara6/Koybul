-- =========================================================================
-- 0025 — TEKNE FAVORİLERİ (TK-5, kurucu onayı 2026-10-30)
--
-- "Favorile": sessiz beğeni — tekne sahibine bildirim gitmez, kimin
-- favorilediği listelenmez; kartta yalnız TOPLAM sayı görünür. Ücretsiz
-- üyelik yeter (misafir yalnız görür). Kardeş tekneler bu dosyada tablo
-- GEREKTİRMEZ: mevcut boats tablosundan rıza süzgeçli sorguyla türetilir.
-- =========================================================================

CREATE TABLE IF NOT EXISTS boat_favorites (
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  boat_id    uuid NOT NULL REFERENCES boats(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, boat_id)
);

-- Kartta "kaç kişi favoriledi" sayımı için.
CREATE INDEX IF NOT EXISTS idx_boat_favorites_boat ON boat_favorites (boat_id);

-- RLS (0017 deseni): okuma herkese açık (sayı zaten kartta), yazma yalnız
-- satırın sahibi (favorileyen); altyapı yolu serbest.
ALTER TABLE boat_favorites ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY boat_favorites_read ON boat_favorites FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY boat_favorites_owner ON boat_favorites FOR ALL
    USING (app_current_user_id() IS NULL OR user_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR user_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================================
-- 0013_premium — Premium temeli (P1, kurucu onayı 2026-09-21, premium v3 raporu)
--
-- 1) users: abonelik yansıma alanları. Gerçek kaynak Apple'dır (P2'de App Store
--    Server Notifications bu alanları yazar); sunucu kararı premium_until > now().
-- 2) exploration_unlocks: KEŞİF HAKKI defteri — ücretsiz üye ayda en fazla 3 koyu
--    "tam aç"ar; (user, location, month) tekildir, aynı koyu aynı ay yeniden
--    açmak hak tüketmez.
--
-- KURAL (boot-migrate): tamamen idempotent DDL — IF NOT EXISTS / duplicate_object
-- yakalama. Aynı SQL hem CI'da `prisma migrate deploy` ile hem canlıda
-- boot-migrate ile koşabilir (bkz. 0012_media_onarim dersi).
-- ============================================================================

ALTER TABLE users ADD COLUMN IF NOT EXISTS premium_until timestamptz;
ALTER TABLE users ADD COLUMN IF NOT EXISTS premium_product_id text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS apple_original_transaction_id text;

-- Bir Apple aboneliği TEK hesaba bağlanır (aile paylaşımı/hesap gezdirme
-- suistimaline karşı). Postgres, NULL'ları eşsizlikten muaf tutar.
CREATE UNIQUE INDEX IF NOT EXISTS ux_users_apple_original_transaction_id
  ON users (apple_original_transaction_id);

CREATE TABLE IF NOT EXISTS exploration_unlocks (
  user_id     uuid NOT NULL REFERENCES users(id)     ON DELETE CASCADE,
  location_id uuid NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
  -- UTC 'YYYY-MM' — sunucu üretir; istemci saatine güvenilmez.
  month_key   text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, location_id, month_key)
);

-- Aylık sayım sorgusu (kaç hak kaldı) bu indeksle çalışır.
CREATE INDEX IF NOT EXISTS ix_exploration_unlocks_user_month
  ON exploration_unlocks (user_id, month_key);

-- RLS — 0002/0003/0008 deseni: sahibi okur/yazar; altyapı yolu (app.user_id
-- NULL) serbesttir. FORCE: tablo sahibi bağlantı da politikaya tabidir.
ALTER TABLE exploration_unlocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE exploration_unlocks FORCE  ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY exploration_unlocks_owner ON exploration_unlocks FOR ALL
    USING (app_current_user_id() IS NULL OR user_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR user_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

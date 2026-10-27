-- ============================================================================
-- 0019_bildirimler — PUSH BİLDİRİM altyapısı (kurucu onayı 2026-10-27).
--
-- device_tokens: her satır BİR telefon. Kullanıcı çıkınca/token tazelenince
-- satır değişir; kategori anahtarları kullanıcının "sıkmama" tercihleridir.
-- notification_log: aynı bildirimin aynı kişiye İKİ KEZ gitmemesi için
-- defter (ör. etkinlik hatırlatması saatlik taramada tekrarlanmasın).
--
-- RLS: 0002 deseni — app.user_id bildirilmişse sahiplik, bildirilmemişse
-- (altyapı yolu: bildirim gönderici) serbest. KURAL (boot-migrate): idempotent.
-- ============================================================================

CREATE TABLE IF NOT EXISTS device_tokens (
  token        text PRIMARY KEY,
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform     text NOT NULL DEFAULT 'ios',
  locale       text NOT NULL DEFAULT 'tr',
  -- Kategoriler: topluluk (cevap + rota kararı), etkinlik (iptal + hatırlatma),
  -- moderasyon (yalnız admin cihazlarına gider).
  community_enabled  boolean NOT NULL DEFAULT true,
  events_enabled     boolean NOT NULL DEFAULT true,
  moderation_enabled boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens(user_id);

DO $$ BEGIN
  CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON device_tokens
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens FORCE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY device_tokens_owner ON device_tokens FOR ALL
    USING (app_current_user_id() IS NULL OR user_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR user_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS notification_log (
  kind      text NOT NULL,
  entity_id uuid NOT NULL,
  user_id   uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sent_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (kind, entity_id, user_id)
);

ALTER TABLE notification_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_log FORCE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY notification_log_infra ON notification_log FOR ALL
    USING (app_current_user_id() IS NULL OR user_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR user_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

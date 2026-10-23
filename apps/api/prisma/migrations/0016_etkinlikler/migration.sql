-- ============================================================================
-- 0016_etkinlikler — Etkinlikler ve Fırsatlar V1 (kurucu onayı 2026-10-23)
--
-- İki bölüm: FIRSATLAR (iş ortağı indirim kodları) + ETKİNLİKLER (kontenjanlı
-- buluşmalar). Kurucu kararları: fırsat başına hedef kitle (herkes/üye/premium,
-- kod kilidi SUNUCUDA); V1'de uygulama içi ödeme YOK (ücret notu serbest metin,
-- "yerinde ödenir" modeli); kontenjan İŞLEMSEL kilitle korunur — 25 kişilik
-- etkinliğe 26. kayıt matematiksel olarak imkânsızdır (keşif hakkı deseni).
--
-- KURAL (boot-migrate): tamamen idempotent DDL (0012-0015 dersi).
-- ============================================================================

CREATE TABLE IF NOT EXISTS deals (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title       text NOT NULL CHECK (char_length(title) BETWEEN 3 AND 120),
  partner     text NOT NULL CHECK (char_length(partner) BETWEEN 2 AND 80),
  -- 'Oran/avantaj' serbest metin: '%15 indirim', '%10 + kargo' gibi.
  benefit     text NOT NULL CHECK (char_length(benefit) BETWEEN 2 AND 80),
  -- Kod NULL olabilir (kodsuz kampanya); kilidi SUNUCU uygular (audience).
  code        text,
  valid_until timestamptz,
  terms       text,
  place       text,
  audience    text NOT NULL DEFAULT 'all' CHECK (audience IN ('all','members','premium')),
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_deals_active ON deals (is_active, valid_until);

CREATE TABLE IF NOT EXISTS events (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title                 text NOT NULL CHECK (char_length(title) BETWEEN 3 AND 120),
  body                  text NOT NULL CHECK (char_length(body) BETWEEN 10 AND 2000),
  starts_at             timestamptz NOT NULL,
  ends_at               timestamptz,
  -- Buluşma yeri serbest metin + istenirse katalog bağlantısı (haritada göster).
  location_text         text NOT NULL CHECK (char_length(location_text) BETWEEN 2 AND 120),
  venue_location_id     uuid REFERENCES locations(id) ON DELETE SET NULL,
  quota                 int NOT NULL CHECK (quota > 0 AND quota <= 10000),
  registration_deadline timestamptz,
  -- V1 ödeme kararı: serbest metin ('Ücretsiz', 'Ücret yerinde ödenir — 500 TL').
  price_note            text,
  conditions            text,
  organizer             text NOT NULL DEFAULT 'Koybul',
  audience              text NOT NULL DEFAULT 'all' CHECK (audience IN ('all','members','premium')),
  status                text NOT NULL DEFAULT 'published' CHECK (status IN ('published','cancelled')),
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_events_feed ON events (status, starts_at);

-- Kayıt defteri: PK mükerrer kaydı KÖKTEN engeller; iptal satırı korunur
-- (yeniden kayıt aynı satırı diriltir — geçmiş izi kalır).
CREATE TABLE IF NOT EXISTS event_registrations (
  event_id   uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status     text NOT NULL DEFAULT 'registered' CHECK (status IN ('registered','cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (event_id, user_id)
);

CREATE INDEX IF NOT EXISTS ix_event_registrations_event
  ON event_registrations (event_id, status);

-- ---------------------------------------------------------------------------
-- RLS (ADR-003): fırsat/etkinlik okunur-herkese, yazma yalnız altyapı yolu
-- (yönetici uçları servis katmanında rol denetiminden geçer). Kayıt defteri
-- sahibine görünür/yazılır; altyapı yolu (sayım, katılımcı listesi) serbest.
-- ---------------------------------------------------------------------------
ALTER TABLE deals               ENABLE ROW LEVEL SECURITY;
ALTER TABLE events              ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_registrations ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY deals_read ON deals FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY deals_infra_write ON deals FOR ALL
    USING (app_current_user_id() IS NULL)
    WITH CHECK (app_current_user_id() IS NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY events_read ON events FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY events_infra_write ON events FOR ALL
    USING (app_current_user_id() IS NULL)
    WITH CHECK (app_current_user_id() IS NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY event_registrations_owner ON event_registrations FOR ALL
    USING (app_current_user_id() IS NULL OR user_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR user_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

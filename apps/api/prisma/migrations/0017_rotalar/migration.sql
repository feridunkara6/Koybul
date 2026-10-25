-- ============================================================================
-- 0017_rotalar — Rota Paylaşımı V1 (Sosyalleşme Hafta 3, kurucu onayı
-- 2026-10-24 sosyalleşme planı §5)
--
-- Kullanıcılar kendi deniz rotalarını (duraklar = katalogdaki lokasyonlar)
-- toplulukla paylaşır; diğerleri keşfeder, kaydeder, "yaptım" der.
--
-- TASARIM KARARLARI:
-- - Rota ÇİZGİSİ saklanmaz: yalnız durak listesi tutulur; çizgiyi istemci
--   kendi rotalayıcısıyla yeniden üretir (depolama + gizlilik kararı §5B).
-- - Mesafe/süre İSTEMCİ hesabından gelir ve sunucu yalnız aralık doğrular;
--   elle yazılamaz (istemci alan göstermez) — yine de beyan niteliğindedir.
-- - Her rota moderasyon ONAYINDAN geçer (yorumlarla aynı: her zaman pending).
-- - Kayıt/yaptım defterleri PK ile tekilleştirilir (qa_likes felsefesi).
--
-- KURAL (boot-migrate): tamamen idempotent DDL — IF NOT EXISTS / duplicate_object
-- yakalama. ALTER TYPE ... ADD VALUE IF NOT EXISTS PG12+'ta transaction içinde
-- güvenlidir; yeni değer aynı transaction'da KULLANILMAZ (0014 dersi).
-- ============================================================================

-- Moderasyon kuyruğu rota içeriğini tanısın (tek kuyruk ilkesi).
ALTER TYPE moderation_entity ADD VALUE IF NOT EXISTS 'route';

CREATE TABLE IF NOT EXISTS routes (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name            text NOT NULL CHECK (char_length(name) BETWEEN 3 AND 80),
  -- Deneyim + uyarılar tek gövdede (S-C gövdesiyle aynı sınırlar).
  body            text NOT NULL CHECK (char_length(body) BETWEEN 30 AND 2000),
  season          text CHECK (season IS NULL OR char_length(season) <= 60),
  boat_suggestion text CHECK (boat_suggestion IS NULL OR char_length(boat_suggestion) <= 120),
  -- İstemcinin rotalayıcısından gelen beyan; aralık sunucuda doğrulanır.
  distance_nm     numeric(6,1) NOT NULL CHECK (distance_nm > 0 AND distance_nm <= 500),
  duration_hours  numeric(5,1) CHECK (duration_hours IS NULL
                    OR (duration_hours > 0 AND duration_hours <= 240)),
  status          moderation_status NOT NULL DEFAULT 'pending',
  -- Denormalize sayaçlar — qa/notes deseniyle aynı: tek UPDATE ile atomik.
  save_count      int NOT NULL DEFAULT 0,
  done_count      int NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  deleted_at      timestamptz
);

CREATE INDEX IF NOT EXISTS ix_routes_feed
  ON routes (status, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS ix_routes_popular
  ON routes (status, save_count DESC, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS ix_routes_user
  ON routes (user_id, created_at DESC);

-- Duraklar: sıra numarasıyla; ilk durak başlangıç, son durak bitiştir.
-- Lokasyon silinmesin diye RESTRICT (katalog zaten soft-delete kullanır).
CREATE TABLE IF NOT EXISTS route_stops (
  route_id    uuid NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
  seq         smallint NOT NULL CHECK (seq BETWEEN 1 AND 12),
  location_id uuid NOT NULL REFERENCES locations(id) ON DELETE RESTRICT,
  PRIMARY KEY (route_id, seq)
);

-- Koy detayındaki "buradan geçen rotalar" sorgusu için.
CREATE INDEX IF NOT EXISTS ix_route_stops_location
  ON route_stops (location_id);

-- Kaydetme/yaptım defterleri: PK mükerrer kaydı KÖKTEN engeller.
CREATE TABLE IF NOT EXISTS route_saves (
  route_id   uuid NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (route_id, user_id)
);

CREATE TABLE IF NOT EXISTS route_dones (
  route_id   uuid NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (route_id, user_id)
);

-- ---------------------------------------------------------------------------
-- RLS (ADR-003, 0014 deseniyle birebir): okuma herkese (yayın kararı
-- UYGULAMA katmanındadır — RLS satır sahipliği içindir), yazma yalnız
-- sahibine; altyapı yolu (app.user_id NULL) serbest kalır.
-- ---------------------------------------------------------------------------
ALTER TABLE routes       ENABLE ROW LEVEL SECURITY;
ALTER TABLE route_stops  ENABLE ROW LEVEL SECURITY;
ALTER TABLE route_saves  ENABLE ROW LEVEL SECURITY;
ALTER TABLE route_dones  ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY routes_read ON routes FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY routes_owner_write ON routes FOR ALL
    USING (app_current_user_id() IS NULL OR user_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR user_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY route_stops_read ON route_stops FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  -- Duraklar rota sahibi üzerinden yazılır; altyapı yolu serbest.
  CREATE POLICY route_stops_owner_write ON route_stops FOR ALL
    USING (app_current_user_id() IS NULL OR EXISTS (
      SELECT 1 FROM routes r
      WHERE r.id = route_id AND r.user_id = app_current_user_id()))
    WITH CHECK (app_current_user_id() IS NULL OR EXISTS (
      SELECT 1 FROM routes r
      WHERE r.id = route_id AND r.user_id = app_current_user_id()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY route_saves_read ON route_saves FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY route_saves_owner ON route_saves FOR ALL
    USING (app_current_user_id() IS NULL OR user_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR user_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY route_dones_read ON route_dones FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY route_dones_owner ON route_dones FOR ALL
    USING (app_current_user_id() IS NULL OR user_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR user_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

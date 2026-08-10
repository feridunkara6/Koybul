-- ============================================================================
-- 0008_community — Kaptan Notları, faydalı/doğrulama oyları, denizci itibarı
--
-- ADDITIVE + GERİYE UYUMLU: yalnız yeni enum değerleri, yeni tip ve yeni tablolar
-- eklenir; mevcut satır/veri hiç etkilenmez, hiçbir sütun düşürülmez.
-- Tümü idempotent (IF NOT EXISTS / duplicate yakalama) — aynı SQL canlı
-- veritabanında elle de güvenle koşturulabilir (0006/0007 deseni).
--
-- Kapsam (docs: topluluk tasarımı §6):
--   · note_kind        — 5 not tipinden 4'ü (yer durumu zaten occupancy_level'da)
--   · location_notes   — konuma bağlı, tarihli, tipli kullanıcı notu
--   · note_reactions   — faydalı / doğrulama / çelişki (kendine oy imkânsız: PK)
--   · user_reputation  — türetilmiş özet (contribution_events'ten yeniden üretilebilir)
--   · user_badges      — rozet sahiplikleri (etiketler istemcide, 4 dilde)
--
-- BİLİNÇLİ OLARAK DOKUNULMAYAN: location_occupancy_reports (doluluk bildirimi
-- bugünkü haliyle korunur — kurucu kararı 2026-08-09).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) Mevcut enum'lara yeni değerler (kullanılmıyor, yalnız ekleniyor)
-- ---------------------------------------------------------------------------
ALTER TYPE moderation_entity ADD VALUE IF NOT EXISTS 'note';

ALTER TYPE contribution_type ADD VALUE IF NOT EXISTS 'occupancy_reported';
ALTER TYPE contribution_type ADD VALUE IF NOT EXISTS 'note_approved';
ALTER TYPE contribution_type ADD VALUE IF NOT EXISTS 'hazard_confirmed';
ALTER TYPE contribution_type ADD VALUE IF NOT EXISTS 'helpful_received';
ALTER TYPE contribution_type ADD VALUE IF NOT EXISTS 'content_rejected';
ALTER TYPE contribution_type ADD VALUE IF NOT EXISTS 'trip_shared';

-- İçerik şikâyeti için ayrı sebep (docs/12 §8.2 backlog kalemi).
ALTER TYPE report_reason ADD VALUE IF NOT EXISTS 'abuse';

ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'helpful_received';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'hazard_disputed';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'level_up';

-- ---------------------------------------------------------------------------
-- 2) Not tipi
--    status     — güncel durum (48 saat öne çıkar), GPS zorunlu
--    hazard     — emniyet uyarısı (kalıcı), GPS zorunlu, insan moderasyonu şart
--    experience — demirleme/marina/restoran deneyimi (kalıcı)
--    passage    — iki nokta arası seyir notu (kalıcı)
-- ---------------------------------------------------------------------------
DO $$ BEGIN
  CREATE TYPE note_kind AS ENUM ('status', 'hazard', 'experience', 'passage');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ---------------------------------------------------------------------------
-- 3) contribution_events sertleştirme
--    · points SMALLINT → INT: tek olayda 32767 tavanı gereksiz bir tuzak.
--    · (user_id, created_at DESC) indeksi: GÜNLÜK PUAN LİMİTİ sorgusunun
--      tam-tarama yapmasını engeller — limit kontrolü her katkıda çalışır.
-- ---------------------------------------------------------------------------
ALTER TABLE contribution_events ALTER COLUMN points TYPE integer;

CREATE INDEX IF NOT EXISTS ix_contribution_events_user_time
  ON contribution_events (user_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- 4) location_notes — Kaptan Notları
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS location_notes (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  location_id      uuid REFERENCES locations(id) ON DELETE CASCADE,
  from_location_id uuid REFERENCES locations(id) ON DELETE SET NULL,
  to_location_id   uuid REFERENCES locations(id) ON DELETE SET NULL,
  user_id          uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  boat_id          uuid REFERENCES boats(id) ON DELETE SET NULL,
  kind             note_kind NOT NULL,
  title            text,
  body             text NOT NULL,
  -- "Ne zaman oradaydın" — created_at DEĞİL. Okuyucu için asıl anlamlı tarih budur.
  observed_on      date NOT NULL,
  -- Bildirim anındaki gerçek konum (yalnız status/hazard için zorunlu).
  reported_from    geography(Point, 4326),
  -- Sunucu, reported_from ile hedef nokta arasındaki mesafeyi doğruladı mı?
  gps_verified     boolean NOT NULL DEFAULT false,
  -- O günkü hava, not yazılırken DONDURULUR ({kn, dirTr}). Sonradan sorgulanmaz.
  wind_summary     jsonb,
  status           moderation_status NOT NULL DEFAULT 'pending',
  helpful_count    integer NOT NULL DEFAULT 0,
  confirm_count    integer NOT NULL DEFAULT 0,
  dispute_count    integer NOT NULL DEFAULT 0,
  -- status tipi için öne çıkma sonu (48 saat). Diğer tiplerde NULL = süresiz.
  expires_at       timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  deleted_at       timestamptz,
  deleted_by       uuid REFERENCES users(id) ON DELETE SET NULL
);

-- Gövde uzunluğu tipe göre (tasarım §1.4): durum 280, uyarı 500, deneyim/seyir 4000.
DO $$ BEGIN
  ALTER TABLE location_notes ADD CONSTRAINT ck_location_notes_body_len CHECK (
    char_length(body) >= 3 AND char_length(body) <= CASE kind
      WHEN 'status' THEN 280
      WHEN 'hazard' THEN 500
      ELSE 4000
    END
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE location_notes ADD CONSTRAINT ck_location_notes_title_len
    CHECK (title IS NULL OR char_length(title) <= 120);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Konumsuz içerik YOKTUR: passage iki uç ister, diğerleri tek nokta ister.
DO $$ BEGIN
  ALTER TABLE location_notes ADD CONSTRAINT ck_location_notes_target CHECK (
    (kind = 'passage'  AND from_location_id IS NOT NULL AND to_location_id IS NOT NULL)
    OR
    (kind <> 'passage' AND location_id IS NOT NULL)
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Taze bilgi tipleri gerçek GPS ister (yanlış bilgi trafiğine karşı).
DO $$ BEGIN
  ALTER TABLE location_notes ADD CONSTRAINT ck_location_notes_gps CHECK (
    kind NOT IN ('status', 'hazard') OR reported_from IS NOT NULL
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Sayaçlar negatif olamaz (uygulama hatasına karşı ikinci fren).
DO $$ BEGIN
  ALTER TABLE location_notes ADD CONSTRAINT ck_location_notes_counts CHECK (
    helpful_count >= 0 AND confirm_count >= 0 AND dispute_count >= 0
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Koy detayı listesi: (nokta, durum, tarih) — en sık sorgu.
CREATE INDEX IF NOT EXISTS ix_location_notes_location_status_observed
  ON location_notes (location_id, status, observed_on DESC)
  WHERE deleted_at IS NULL;

-- "Katkılarım" ekranı.
CREATE INDEX IF NOT EXISTS ix_location_notes_user_created
  ON location_notes (user_id, created_at DESC);

-- Açık uyarılar — harita rozetinin ve emniyet şeridinin kaynağı.
CREATE INDEX IF NOT EXISTS ix_location_notes_hazard_open
  ON location_notes (location_id)
  WHERE kind = 'hazard' AND status = 'approved' AND deleted_at IS NULL;

-- "Yakında paylaşılanlar" — coğrafi arama.
CREATE INDEX IF NOT EXISTS ix_location_notes_geo
  ON location_notes USING GIST (reported_from);

-- Moderasyon kuyruğu.
CREATE INDEX IF NOT EXISTS ix_location_notes_status_created
  ON location_notes (status, created_at)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_location_notes_from_location ON location_notes (from_location_id);
CREATE INDEX IF NOT EXISTS ix_location_notes_to_location   ON location_notes (to_location_id);
CREATE INDEX IF NOT EXISTS ix_location_notes_boat          ON location_notes (boat_id);
CREATE INDEX IF NOT EXISTS ix_location_notes_deleted_by    ON location_notes (deleted_by);

-- ---------------------------------------------------------------------------
-- 5) note_reactions — faydalı / doğrulama / çelişki
--    PK (note_id, user_id, reaction): aynı kullanıcı aynı tepkiyi iki kez veremez.
--    Kendi notuna oy verme uygulama katmanında engellenir (ayrıca CHECK'lenemez:
--    note sahibi bu tabloda değil).
--    weight: oy anındaki güven katsayısı DONDURULUR — geçmiş yeniden hesaplanmaz.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS note_reactions (
  note_id    uuid NOT NULL REFERENCES location_notes(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reaction   text NOT NULL,
  weight     numeric(3,2) NOT NULL DEFAULT 1.00,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (note_id, user_id, reaction),
  CONSTRAINT ck_note_reactions_reaction CHECK (reaction IN ('helpful', 'confirm', 'dispute')),
  CONSTRAINT ck_note_reactions_weight   CHECK (weight >= 0 AND weight <= 1.5)
);

CREATE INDEX IF NOT EXISTS ix_note_reactions_user ON note_reactions (user_id);

-- ---------------------------------------------------------------------------
-- 6) user_reputation — TÜRETİLMİŞ özet (kaynak: contribution_events, append-only)
--    Bu tablo kaybolsa contribution_events'ten yeniden üretilebilir; hız için var.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_reputation (
  user_id                uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  points                 integer NOT NULL DEFAULT 0,
  level_code             text    NOT NULL DEFAULT 'new',
  trust_score            numeric(3,2) NOT NULL DEFAULT 1.00,
  approved_count         integer NOT NULL DEFAULT 0,
  rejected_count         integer NOT NULL DEFAULT 0,
  helpful_received       integer NOT NULL DEFAULT 0,
  reports_against        integer NOT NULL DEFAULT 0,
  -- docs/12 §8.2: 3 doğrulanmış ihlal → 30 gün içerik üretimi kısıtı.
  write_restricted_until timestamptz,
  last_recalc_at         timestamptz NOT NULL DEFAULT now(),
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_user_reputation_level CHECK (
    level_code IN ('new', 'coastal', 'guide', 'master', 'pilot')
  ),
  CONSTRAINT ck_user_reputation_trust CHECK (trust_score >= 0 AND trust_score <= 1.5),
  CONSTRAINT ck_user_reputation_points CHECK (points >= 0)
);

-- ---------------------------------------------------------------------------
-- 7) user_badges — rozet sahiplikleri
--    Etiket/açıklama metinleri İSTEMCİDE yaşar (4 dil, bakım kataloğu deseni);
--    sunucu yalnız kodu ve kapsamı tutar.
--    scope_id NULL olabildiği için PK yerine partial-unique indeks kullanılır.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_badges (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  badge_code text NOT NULL,
  -- Bölgesel rozetler için: 'admin_area' + admin_areas.id
  scope_type text,
  scope_id   uuid,
  awarded_at timestamptz NOT NULL DEFAULT now(),
  -- Suistimal tespitinde rozet geri alınabilir (silinmez — iz kalır).
  revoked_at timestamptz,
  CONSTRAINT ck_user_badges_scope CHECK (
    (scope_type IS NULL AND scope_id IS NULL) OR (scope_type IS NOT NULL AND scope_id IS NOT NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_user_badges_scoped
  ON user_badges (user_id, badge_code, scope_id) WHERE scope_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ux_user_badges_global
  ON user_badges (user_id, badge_code) WHERE scope_id IS NULL;
CREATE INDEX IF NOT EXISTS ix_user_badges_user ON user_badges (user_id) WHERE revoked_at IS NULL;

-- ---------------------------------------------------------------------------
-- 8) RLS (0002/0006 deseniyle birebir aynı)
--    Bağlam bildirilmişse kullanıcı yalnız kendi satırına yazabilir; bağlamsız
--    (anonim okuma, altyapı yolu) serbesttir — ADR-003 "IS NULL kolu".
--    NOT: location_notes okuması herkese açıktır (yayınlanmış içerik); politika
--    yalnız YAZMAYI sahibine kilitler, okuma kısıtı uygulama katmanındadır.
--
--    !! UYGULAMA KURALI (Faz 2'de zorunlu) !!
--    Başkasının satırını değiştiren üç işlem SAHİP BAĞLAMIYLA ÇALIŞTIRILAMAZ,
--    çünkü politika satırı süzer ve UPDATE sessizce 0 satır etkiler:
--      1) helpful/confirm/dispute sayaçlarının artırılması (oyu veren ≠ not sahibi)
--      2) rozet verme ve itibar güncellemesi (sistem yazar, kullanıcı değil)
--      3) moderatörün başkasının notunu onaylaması/soft-delete etmesi
--    Bunlar ADR-003'ün "altyapı yolu"ndan, yani withUserContext SARMALAYICISI
--    OLMADAN yürütülür (app.user_id NULL → politikanın IS NULL kolu izin verir).
--    Aynı desen auth köprüsünde ve public okumalarda zaten kullanılıyor.
-- ---------------------------------------------------------------------------
ALTER TABLE location_notes  ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_reactions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_reputation ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_badges     ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY location_notes_read ON location_notes FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY location_notes_owner_write ON location_notes FOR ALL
    USING (app_current_user_id() IS NULL OR user_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR user_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY note_reactions_owner ON note_reactions FOR ALL
    USING (app_current_user_id() IS NULL OR user_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR user_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY user_reputation_owner ON user_reputation FOR ALL
    USING (app_current_user_id() IS NULL OR user_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR user_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY user_badges_owner ON user_badges FOR ALL
    USING (app_current_user_id() IS NULL OR user_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR user_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- =========================================================================
-- 0023 — KULLANICI ETKİNLİKLERİ (SP-4, kurucu onayı 2026-10-31)
--
-- Kaptanlar kendi buluşmalarını kurabilir. KURUCU KURALLARI:
-- - Oluşturma YALNIZ Premium (kapı SERVİSTE; admin+ muaf, bayrak ilkesi
--   rotalarla aynı). Düğme herkese görünür — teşvik "sıkmadan" tanıtımla.
-- - 3 şablon: koy buluşması / birlikte seyir / marina buluşması.
-- - Her kullanıcı etkinliği MODERASYON onayından geçer (pending doğar);
--   Koybul'un resmi etkinlikleri (created_by NULL) eskisi gibi doğrudan
--   yayınlanır.
-- - Katılımcı listesi RIZALIDIR: kayıt olurken "adım görünsün" diyen
--   (show_name) dışında kimse listede görünmez; e-posta HİÇBİR ZAMAN
--   kamuya çıkmaz (yalnız yönetici paneli, organizasyon amaçlı).
-- =========================================================================

-- Moderasyon kuyruğuna yeni varlık türü (0017 'route' deseniyle aynı).
ALTER TYPE moderation_entity ADD VALUE IF NOT EXISTS 'event';

-- Oluşturan kaptan — NULL = Koybul resmi etkinliği. Kullanıcı silinirse
-- SET NULL: etkinlik ve kayıtlı katılımcılar yaşamaya devam eder (KVKK
-- silmesi zaten profili anonimleştirir).
ALTER TABLE events ADD COLUMN IF NOT EXISTS
  created_by uuid REFERENCES users(id) ON DELETE SET NULL;

-- Şablon — yalnız kullanıcı etkinliklerinde dolu.
ALTER TABLE events ADD COLUMN IF NOT EXISTS
  template text CHECK (template IN ('bay_meetup', 'joint_sail', 'marina_meetup'));

-- Durum sözlüğü genişler: kullanıcı etkinliği 'pending' doğar, reddedilen
-- 'rejected' olur (yalnız sahibine görünür — varlık sızdırılmaz).
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_status_check;
ALTER TABLE events ADD CONSTRAINT events_status_check
  CHECK (status IN ('pending', 'published', 'cancelled', 'rejected'));

-- "Sahibimin bekleyenleri" sorgusu için.
CREATE INDEX IF NOT EXISTS ix_events_created_by
  ON events (created_by, created_at DESC);

-- RIZALI katılımcı listesi: varsayılan GİZLİ (gizlilik önce) — kaydolurken
-- kaptan açıkça "adım görünsün" derse true olur.
ALTER TABLE event_registrations ADD COLUMN IF NOT EXISTS
  show_name boolean NOT NULL DEFAULT false;

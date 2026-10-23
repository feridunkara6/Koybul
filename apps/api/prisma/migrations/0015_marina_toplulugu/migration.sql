-- ============================================================================
-- 0015_marina_toplulugu — Marina Topluluğu V1 (kurucu onayı 2026-10-23)
--
-- Tekneye "bağlı marina" ve görünürlük tercihleri eklenir. GİZLİLİK KARARI
-- (kurucu, konsept onayı): toplam SAYILAR herkese isimsizdir; tekne ADI ancak
-- sahibi 'Marinada görün'ü açarsa listelenir (varsayılan KAPALI); tip/boy/marka
-- ayrıca 'share_specs' anahtarına bağlıdır. Erişim: kendi marinan ücretsiz,
-- başka marinaları gezmek Premium (kilit SUNUCUDA — marina.service).
--
-- KURAL (boot-migrate): tamamen idempotent DDL (0012/0013/0014 dersi).
-- boats RLS zaten açık (0002): sahiplik politikası yazmayı sahibine kısıtlar,
-- altyapı yolu (app.user_id NULL) topluluk okumalarını serbest bırakır —
-- görünürlük süzgeci uygulama SQL'inde uygulanır (visible_in_marina).
-- ============================================================================

ALTER TABLE boats ADD COLUMN IF NOT EXISTS home_marina_location_id uuid
  REFERENCES locations(id) ON DELETE SET NULL;
-- Varsayılan GİZLİ: kullanıcı açıkça 'Marinada görün' demeden ad listelenmez.
ALTER TABLE boats ADD COLUMN IF NOT EXISTS visible_in_marina boolean NOT NULL DEFAULT false;
-- Tip/boy/marka paylaşımı ayrı rızadır (ad görünür olsa bile).
ALTER TABLE boats ADD COLUMN IF NOT EXISTS share_specs boolean NOT NULL DEFAULT false;

-- Marina bazlı sayım/liste sorguları (canlı COUNT — ayrı sayaç tablosu YOK;
-- taşınma/silme anında doğru yansır, tutarsızlaşacak kopya veri olmaz).
CREATE INDEX IF NOT EXISTS ix_boats_home_marina
  ON boats (home_marina_location_id)
  WHERE deleted_at IS NULL AND home_marina_location_id IS NOT NULL;

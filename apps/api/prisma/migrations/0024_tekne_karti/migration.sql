-- =========================================================================
-- 0024 — TEKNE KARTI GENİŞLETMESİ (kurucu onayı 2026-10-30)
--
-- "Teknenin hikâyesi": sahibinin yazdığı kısa tanıtım metni. SERBEST METİN
-- olduğu için MODERASYON onayından geçer (notlarla aynı katılık): her
-- yazım/değişiklik 'pending' olur, onaylanınca kartta görünür. Boşsa bölüm
-- hiç çizilmez. Kart istatistikleri (paylaşılan seyir/rota, Pruvan neta)
-- ve rota listesi TÜRETİLMİŞTİR — zaten herkese açık içerikten sayılır,
-- yeni tablo gerekmez.
-- =========================================================================

ALTER TYPE moderation_entity ADD VALUE IF NOT EXISTS 'boat_story';

ALTER TABLE boats ADD COLUMN IF NOT EXISTS
  story text CHECK (story IS NULL OR char_length(story) BETWEEN 10 AND 600);

-- 'pending' | 'approved' | 'rejected' — hikâye yokken 'approved' (nötr).
ALTER TABLE boats ADD COLUMN IF NOT EXISTS
  story_status text NOT NULL DEFAULT 'approved'
  CHECK (story_status IN ('pending', 'approved', 'rejected'));

-- ============================================================================
-- 0012_media_onarim — CANLI ŞEMA ONARIMI (saha bulgusu 2026-08-12)
--
-- NE OLDU: boot-migrate, canlı veritabanını ilk gördüğünde 0007'ye kadarki
-- göçleri "uygulanmış" saydı (baseline). Oysa canlı şema elle kurulduğu
-- güne aitti ve 0005_media_attribution'ın dört sütunu orada HİÇ yoktu.
-- Defterde 0005 "uygulandı" göründüğü için bir daha denenmedi; içerik
-- seed'i her açılışta `column "external_url" of relation "media" does not
-- exist` (42703) ile düşüp TÜMÜYLE geri alındı — kapak fotoğrafları ve o
-- tarihten sonraki hiçbir veri partisi canlıya inemedi.
--
-- ONARIM: 0005 ile birebir aynı, tamamen idempotent DDL — yeni bir göç adı
-- altında. Defterde bu ad yok → boot-migrate canlıda gerçekten çalıştırır.
-- 0005'i zaten uygulamış veritabanlarında (CI, taze kurulum) IF NOT EXISTS
-- sayesinde hiçbir şey yapmaz.
--
-- DERS: baseline, canlı şemanın baseline sınırıyla AYNI olduğunu varsayar;
-- varsayım yanlışsa düzeltme YENİ bir onarım göçüyle yapılır (defter
-- kurcalanmaz). bkz. boot-migrate.ts / BASELINE_THROUGH notu.
-- ============================================================================

ALTER TABLE media ADD COLUMN IF NOT EXISTS external_url text;
ALTER TABLE media ADD COLUMN IF NOT EXISTS credit text;
ALTER TABLE media ADD COLUMN IF NOT EXISTS license_code text;
ALTER TABLE media ADD COLUMN IF NOT EXISTS source_url text;

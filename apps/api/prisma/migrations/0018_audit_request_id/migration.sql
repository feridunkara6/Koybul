-- ============================================================================
-- 0018_audit_request_id — denetim kaydındaki istek kimliği kolonu METİN olur
-- (saha hatası 2026-10-26: hesap silme 500 veriyordu).
--
-- Kök sebep: audit_logs.request_id UUID tipindeydi; üretimde istek kimliği
-- vekil katmandan gelir ve UUID DEĞİLDİR ('lbrmpcqk…' gibi). CI'da yakalanmadı
-- çünkü test ortamı UUID üretiyordu — users e2e'ye gerçek-dünya kimliğiyle
-- regresyon eklendi.
--
-- KURAL (boot-migrate): idempotent DDL — text→text tekrar çalıştırmak zararsız.
-- ============================================================================

ALTER TABLE audit_logs
  ALTER COLUMN request_id TYPE text USING request_id::text;

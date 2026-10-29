-- =========================================================================
-- 0020 — BİLDİRİM KUTUSU (SP-2 Döngü, kurucu onayı 2026-10-31)
--
-- 0001'deki notifications tablosu bugüne dek hiç yazılmıyordu; SP-2 ile
-- uygulama içi bildirim kutusu olarak devreye giriyor. Push tetikleyen her
-- kullanıcı olayı (cevap, rota kararı, etkinlik, faydalı eşiği, seviye)
-- buraya da satır yazar — telefon bildirimi kaçsa bile kutuda durur.
--
-- Metin SAKLANMAZ: tür + data (kimlik/ad) saklanır, metni istemci kendi
-- dilinde üretir (l10n mobilde yaşar ilkesi — docs/26).
-- =========================================================================

-- Yeni olay türleri (PG16: enum değeri işlem içinde eklenebilir; aynı
-- işlemde KULLANILMADIĞI sürece — bu dosyada kullanılmıyor).
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'qa_answer';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'route_decision';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'event_update';

-- Kutu sorgusu hep "kullanıcının en yenileri" — bileşik dizin.
CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON notifications (user_id, created_at DESC);

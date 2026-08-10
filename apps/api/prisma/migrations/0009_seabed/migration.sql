-- ============================================================================
-- 0009_seabed — deniz dibi tutuş cinsi, LOKASYON TİPİNDEN BAĞIMSIZ
--
-- NEDEN: zemin bilgisi bugüne dek yalnız `anchorage_details.holding_type`
-- kolonunda tutulabiliyordu; o tabloya ise `trg_anchorage_details_check_type`
-- tetikleyicisi YALNIZ mooring_point/buoy/guest_mooring tipli satır yazılmasına
-- izin verir. Oysa kaptan bir balıkçı barınağında ya da belediye limanında da
-- demir atar ve dibin kum mu çamur mu olduğunu bilmek ister. 2026-08 veri
-- turunda kaynaklı açıklamalardan çıkarılan 21 zemin bulgusunun tamamı bu
-- tiplerdeydi ve hiçbir yere yazılamıyordu.
--
-- NEDEN anchorage_details'e YAZMIYORUZ: tetikleyiciyi gevşetmek, o tablonun
-- diğer kolonlarını (is_free NOT NULL DEFAULT true, protection_n/s/e/w) ücretli
-- bir belediye limanı için anlamsız/yanıltıcı biçimde doldururdu — API o satırı
-- görünce "Ücretsiz" rozeti basıyordu. Zemin, demirleme kartının bir parçası
-- değil, YERİN kendi özelliğidir; bu yüzden locations'a taşınır.
--
-- ADDITIVE + GERİYE UYUMLU: tek NULLABLE sütun; mevcut satırlar etkilenmez.
-- Demirleme koylarının zemini `anchorage_details.holding_type`'ta KALIR — API
-- iki kaynağı birleştirir (önce bu sütun, yoksa demirleme detayı). IF NOT
-- EXISTS ile idempotent: CI seed'i iki kez koşar.
--
-- Değer alanı ck_anchorage_details_holding_type ile BİREBİR aynıdır:
-- sand | mud | weed | rock | mixed. Aynı kısıt burada da uygulanır ki iki
-- tarafta farklı sözlük oluşmasın.
-- ============================================================================

ALTER TABLE locations ADD COLUMN IF NOT EXISTS seabed_holding_type text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'ck_locations_seabed_holding_type'
  ) THEN
    ALTER TABLE locations ADD CONSTRAINT ck_locations_seabed_holding_type
      CHECK (seabed_holding_type IS NULL
             OR seabed_holding_type IN ('sand', 'mud', 'weed', 'rock', 'mixed'));
  END IF;
END
$$;

-- ============================================================================
-- 0011_display_name_pii — e-postadan türetilmiş görünen adların temizlenmesi
--
-- SORUN: varsayılan görünen ad, e-posta adresinin yerel kısmından üretiliyordu
-- (ahmet.yilmaz@gmail.com -> "ahmet.yilmaz"). Bu ad, kullanıcıya hiç
-- sorulmadan, yazdığı her notun ve yorumun yanında ANONİM uçlarda herkese
-- görünüyordu; yaygın alan adı tahmin edilerek e-posta adresi geri
-- bulunabiliyordu. KVKK açısından açık bir sorun (denetim bulgusu 2026-08).
--
-- Kod tarafı düzeltildi (prisma-user.repository.ts): yeni hesaplarda ad artık
-- "Kaptan XXXX" biçiminde, kullanıcı kimliğinin ilk dört hane'sinden üretilir.
-- Bu göç, MEVCUT satırları aynı biçime taşır.
--
-- GÜVENLİ SEÇİM: yalnızca görünen adı e-postanın yerel kısmına BİREBİR eşit
-- olan satırlar güncellenir. Kullanıcı adını kendisi değiştirdiyse eşitlik
-- bozulur ve satıra DOKUNULMAZ. Eski kod adı 50 karaktere kırptığı için
-- karşılaştırma da left(...,50) ile yapılır.
--
-- İdempotent: ikinci koşuda hiçbir satır eşleşmez (adlar artık "Kaptan XXXX").
-- ============================================================================

-- SON dört hane alinir, ILK dort degil: kimlikler uuidv7'dir ve ilk 12 hanesi
-- ZAMAN DAMGASIDIR. Bastan dort hane ~50 gunde bir degisir; yani ayni donemde
-- kaydolan herkes "Kaptan 019F" olurdu (inceleme bulgusu 2026-08). Kod tarafi
-- da ayni sekilde son haneleri kullanir; ikisi birlikte degistirilmelidir.
UPDATE user_profiles p
SET display_name = 'Kaptan ' || upper(right(replace(p.user_id::text, '-', ''), 4)),
    updated_at   = now()
FROM users u
WHERE u.id = p.user_id
  AND u.email IS NOT NULL
  -- Eski kod once trim, sonra 50 karaktere kirpma yapiyordu; karsilastirma
  -- birebir ayni sirayla kurulur ki hicbir PII'li ad gozden kacmasin.
  AND p.display_name = left(btrim(split_part(u.email, '@', 1)), 50);

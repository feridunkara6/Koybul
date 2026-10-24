# GERİ DÖNÜŞ NOKTASI — Sosyalleşme öncesi son hâl

**Tarih:** 24 Ekim 2026
**Kayıt noktası:** `7129d05` — commit mesajı **"versiyon 2.12"**
**Karar:** Kurucu onayıyla (24.10.2026) "Denizci Topluluğu & Ana Ekran" planının
uygulanmasına bu noktadan sonra başlandı. Kurucu, istediği an bu noktaya
dönülebilmesini şart koştu.

## Bu noktada uygulamada ne vardı?

Keşfet (harita) + Bugün + Defter + Teknem + Profil sekmeleri; kaptan notları,
koy yorumları, Soru-Cevap, marina topluluğu, etkinlikler/fırsatlar, premium,
moderasyon, itibar/rozet sistemi; 60 modellik + 9 türlük tekne çizim kütüphanesi
("versiyon 2.12" çizim büyütme düzeltmesi dâhil).

## Geriye dönmek istersen (teknik bilgi gerekmez)

1. Claude'a şunu yaz: **"Sosyalleşme değişikliklerini geri al, versiyon 2.12'ye dön."**
2. Claude, `7129d05` sonrasında eklenen değişiklikleri geri alan dosyaları hazırlar
   ve her zamanki yolla teslim eder.
3. Sen GitHub Desktop'ta her zamanki gibi: **Pull origin → commit → Push** yaparsın
   ve üç yeşili beklersin.

Git geçmişi hiçbir zaman silinmediği için bu dönüş her an mümkündür; bu dosya
yalnız "nereye dönüleceğini" kayıt altına alır.

## Sosyalleşme değişikliklerinde veritabanı kuralı

Yeni özellikler veritabanına tablo eklerse, geri dönüşte bu tablolar CANLIDA
durabilir (eski uygulama onları görmez, zarar vermez). Tamamen silinmeleri
istenirse Claude ayrıca temizlik SQL'i hazırlar; bu SQL de her zamanki gibi
Supabase SQL Editöründen elle çalıştırılır (bkz. docs/16 §27).

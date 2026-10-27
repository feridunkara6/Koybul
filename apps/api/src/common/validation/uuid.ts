import { z } from 'zod';

/**
 * YOL/GÖVDE KİMLİĞİ doğrulayıcısı — Postgres'in `uuid` tipiyle AYNI genişlikte.
 *
 * SAHA HATASI (2026-10-27, "rotalar yüklenemedi"): zod'un `.uuid()`'u RFC 4122
 * varyant hanesini (4. grup ilk hane ∈ 8/9/a/b) şart koşar. Örnek içerik
 * kimlikleri ('f0000000-0000-4000-f000-…' gibi) Postgres için GEÇERLİ uuid'dir
 * ama bu süzgeçten geçemiyordu — liste açılıyor, DETAY her seferinde 404'e
 * düşüyordu (rota/soru/etkinlik/tekne kartı detayları). Kural: veritabanının
 * kabul ettiği her kimlik yol doğrulamasından da geçer; süzgecin tek işi
 * `${id}::uuid` cast'inin SQL hatasına dönmesini engellemektir.
 */
export const UuidParam = z
  .string()
  .regex(/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/);

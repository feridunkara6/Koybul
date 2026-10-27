import { UuidParam } from '../src/common/validation/uuid';

/**
 * SAHA HATASI REGRESYONU (2026-10-27, "rotalar yüklenemedi"): zod `.uuid()`
 * RFC varyant hanesini şart koşuyordu; örnek içerik kimlikleri ('f000…-f000-…')
 * Postgres için geçerli olduğu hâlde yol doğrulamasından dönüyor ve rota/soru/
 * etkinlik/tekne kartı DETAYLARI 404'e düşüyordu. Kural: veritabanının kabul
 * ettiği her uuid yol süzgecinden de geçer.
 */
describe('UuidParam (Postgres-genişliğinde kimlik süzgeci)', () => {
  it('örnek içerik kimliklerini kabul eder (varyant hanesi 8/9/a/b DEĞİL)', () => {
    const seeded = [
      'f0000000-0000-4000-f000-000000000001', // rota (supabase_10)
      'c0000000-0000-4000-c000-000000000011', // soru (supabase_7)
      'd0000000-0000-4000-d000-000000000005', // tekne (supabase_5)
      'e0000000-0000-4000-e000-000000000003', // etkinlik (supabase_9)
    ];
    for (const id of seeded) {
      expect(UuidParam.safeParse(id).success).toBe(true);
    }
  });

  it('standart RFC 4122 kimlikleri de geçer (uuidv7 dâhil)', () => {
    expect(UuidParam.safeParse('0192c3a8-7b1e-7cde-8f12-3456789abcde').success).toBe(true);
    expect(UuidParam.safeParse('A0000000-0000-4000-A000-000000000001').success).toBe(true);
  });

  it('uuid OLMAYAN girdi reddedilir (SQL cast hatasına dönüşmesin)', () => {
    const bad = [
      '',
      'abc',
      'f0000000-0000-4000-f000-00000000000', // kısa
      'f0000000-0000-4000-f000-0000000000012', // uzun
      'g0000000-0000-4000-f000-000000000001', // hex dışı
      'f0000000000040000f0000000000000001', // tiresiz
      '1; DROP TABLE routes; --',
    ];
    for (const id of bad) {
      expect(UuidParam.safeParse(id).success).toBe(false);
    }
  });
});

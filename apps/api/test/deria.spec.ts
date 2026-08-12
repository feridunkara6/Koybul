import { DeriaService } from '../src/modules/deria/application/deria.service';
import {
  DERIA_COVE_TO_SLUG,
  deriaTonightWindow,
  transformDeria,
} from '../src/modules/deria/domain/deria.types';
import { EnvService } from '../src/config/env.service';

/**
 * DERİA doluluk testleri. Kaynak: deria.gov.tr (TÜÇA). Kilitlenen sözleşmeler:
 * dönüşümün saçma değerleri elemesi (yanlış "boş" bilgisi denizde tehlikelidir),
 * gece penceresinin TR gününe göre kurulması, önbellek/uçuş birleştirme ve
 * kaynak çökünce SESSİZ geri çekilme (asla 5xx, asla 30 dk'dan bayat veri).
 */

// 2026-08-12 canlı yanıtından kırpılmış GERÇEK 3 koy + 1 UYDURMA eşlenmemiş
// kimlik (9999 — DERİA'nın 20 koyu da artık eşlendiği için gerçek bir
// eşlenmemiş kimlik kalmadı; atlama yolunun sözleşmesi yine de kilitli kalsın).
const LIVE_SAMPLE = {
  items: [
    { id: 13, ad: 'TERSANE ADASI', kapasite: 8, musaitSamandiraSayisi: 2 },
    { id: 4, ad: 'BOYNUZBÜKÜ', kapasite: 84, musaitSamandiraSayisi: 66 },
    { id: 8, ad: 'SARSALA KOYU', kapasite: 98, musaitSamandiraSayisi: 63 },
    { id: 9999, ad: 'HAYALET KOYU', kapasite: 9, musaitSamandiraSayisi: 6 }, // eşlenmemiş
  ],
  totalCount: 4,
};

function makeEnv(enabled: boolean): EnvService {
  return { deriaEnabled: enabled } as unknown as EnvService;
}

describe('transformDeria', () => {
  it('eşlenmiş koyları slug ile döner, eşlenmemişi sessizce atlar', () => {
    const out = transformDeria(LIVE_SAMPLE);
    expect(out).toHaveLength(3);
    const bySlug = new Map(out.map((c) => [c.slug, c]));
    expect(bySlug.get('tersane-adasi-koyu')).toMatchObject({ free: 2, total: 8, coveId: 13 });
    expect(bySlug.get('boynuzbuku-samandira-sahasi')).toMatchObject({ free: 66, total: 84 });
    expect(bySlug.has('hayalet')).toBe(false);
  });

  it("eşleme DERİA'nın 20 koyunun TAMAMINI kapsar (2026-08 ikinci tur)", () => {
    expect(DERIA_COVE_TO_SLUG.size).toBe(20);
    expect(DERIA_COVE_TO_SLUG.get(9)).toBe('binlik-samandira-sahasi');
    expect(DERIA_COVE_TO_SLUG.get(1727)).toBe('yaz-limani-samandira-sahasi');
  });

  it('saçma değerleri ELER: negatif, kapasite üstü, sayı olmayan', () => {
    const out = transformDeria({
      items: [
        { id: 13, ad: 'X', kapasite: 8, musaitSamandiraSayisi: 9 }, // free > total
        { id: 4, ad: 'Y', kapasite: 84, musaitSamandiraSayisi: -1 }, // negatif
        { id: 8, ad: 'Z', kapasite: 0, musaitSamandiraSayisi: 0 }, // kapasite 0
        { id: 5, ad: 'W', kapasite: '55', musaitSamandiraSayisi: 54 }, // string
        { id: 7, ad: 'V', kapasite: 48, musaitSamandiraSayisi: 35 }, // SAĞLAM
      ],
    });
    expect(out).toHaveLength(1);
    expect(out[0].slug).toBe('siralibuk-koyu');
  });

  it('bozuk zarf (items yok / dizi değil) boş liste döner', () => {
    expect(transformDeria({})).toEqual([]);
    expect(transformDeria({ items: 'x' })).toEqual([]);
    expect(transformDeria(null)).toEqual([]);
  });

  it('eşleme tablosundaki her slug benzersizdir', () => {
    const slugs = [...DERIA_COVE_TO_SLUG.values()];
    expect(new Set(slugs).size).toBe(slugs.length);
  });
});

describe('deriaTonightWindow', () => {
  it('TR günü öğle vakti: giriş bu gecenin TR gece yarısı (21:00Z önceki gün)', () => {
    // 2026-08-12 12:00 TR = 09:00Z
    const w = deriaTonightWindow(new Date('2026-08-12T09:00:00.000Z'));
    expect(w.girisIso).toBe('2026-08-11T21:00:00.000Z');
    expect(w.cikisIso).toBe('2026-08-12T21:00:00.000Z');
    expect(w.forDate).toBe('2026-08-12');
  });

  it('TR gece yarısından hemen sonra (00:30 TR) yeni güne geçer', () => {
    // 2026-08-13 00:30 TR = 12 Ağustos 21:30Z
    const w = deriaTonightWindow(new Date('2026-08-12T21:30:00.000Z'));
    expect(w.girisIso).toBe('2026-08-12T21:00:00.000Z');
    expect(w.forDate).toBe('2026-08-13');
  });

  it('TR gece yarısından hemen önce (23:30 TR) hâlâ eski gündedir', () => {
    const w = deriaTonightWindow(new Date('2026-08-12T20:30:00.000Z'));
    expect(w.girisIso).toBe('2026-08-11T21:00:00.000Z');
    expect(w.forDate).toBe('2026-08-12');
  });
});

describe('DeriaService', () => {
  const t0 = new Date('2026-08-12T09:00:00.000Z');

  function makeService(fetchImpl: () => Promise<unknown>, enabled = true) {
    const calls = { n: 0 };
    const provider = {
      fetchRaw: async () => {
        calls.n += 1;
        return fetchImpl();
      },
    };
    return { svc: new DeriaService(provider, makeEnv(enabled)), calls };
  }

  it('ilk çağrı kaynağa gider; 5 dk içinde ikinci çağrı önbellekten döner', async () => {
    const { svc, calls } = makeService(async () => LIVE_SAMPLE);
    const a = await svc.availability(t0);
    expect(a.coves).toHaveLength(3);
    expect(a.forDate).toBe('2026-08-12');
    const b = await svc.availability(new Date(t0.getTime() + 4 * 60 * 1000));
    expect(b).toBe(a); // aynı nesne — önbellek
    expect(calls.n).toBe(1);
  });

  it('5 dk sonra tazelenir', async () => {
    const { svc, calls } = makeService(async () => LIVE_SAMPLE);
    await svc.availability(t0);
    await svc.availability(new Date(t0.getTime() + 6 * 60 * 1000));
    expect(calls.n).toBe(2);
  });

  it('EŞZAMANLI istekler tek kaynak çağrısını paylaşır (uçuş birleştirme)', async () => {
    let release!: (v: unknown) => void;
    const gate = new Promise((r) => {
      release = r;
    });
    const { svc, calls } = makeService(() => gate.then(() => LIVE_SAMPLE));
    const p1 = svc.availability(t0);
    const p2 = svc.availability(t0);
    release(null);
    const [a, b] = await Promise.all([p1, p2]);
    expect(calls.n).toBe(1);
    expect(a.coves).toHaveLength(3);
    expect(b.coves).toHaveLength(3);
  });

  it('kaynak ÇÖKERSE: 30 dk içindeki eski veri sunulur (bayat ama dürüst)', async () => {
    let fail = false;
    const { svc } = makeService(async () => {
      if (fail) throw new Error('kaynak yok');
      return LIVE_SAMPLE;
    });
    const a = await svc.availability(t0);
    fail = true;
    const b = await svc.availability(new Date(t0.getTime() + 20 * 60 * 1000));
    expect(b).toBe(a);
  });

  it("kaynak çökmüş VE veri 30 dk'dan eskiyse: BOŞ liste (asla bayat yalan)", async () => {
    let fail = false;
    const { svc } = makeService(async () => {
      if (fail) throw new Error('kaynak yok');
      return LIVE_SAMPLE;
    });
    await svc.availability(t0);
    fail = true;
    const late = await svc.availability(new Date(t0.getTime() + 31 * 60 * 1000));
    expect(late.coves).toEqual([]);
  });

  it('hiç veri yokken kaynak çökerse: boş liste, istisna YOK (uç 5xx atmaz)', async () => {
    const { svc } = makeService(async () => {
      throw new Error('kaynak yok');
    });
    const a = await svc.availability(t0);
    expect(a.coves).toEqual([]);
    expect(a.attribution).toContain('DERİA');
  });

  it('TR GECE YARISI geçilince önbellek yok sayılır (dünün sayısı "bu gece" olmaz)', async () => {
    // 23:58 TR'de dolu önbellek, 00:02 TR'de (4 dk sonra) kullanılMAMALI:
    // yaş uygun ama pencere değişti — kaynak yeniden sorgulanır.
    const { svc, calls } = makeService(async () => LIVE_SAMPLE);
    const beforeMidnight = new Date('2026-08-12T20:58:00.000Z'); // 23:58 TR
    const a = await svc.availability(beforeMidnight);
    expect(a.forDate).toBe('2026-08-12');
    const afterMidnight = new Date('2026-08-12T21:02:00.000Z'); // 00:02 TR (13 Ağu)
    const b = await svc.availability(afterMidnight);
    expect(b.forDate).toBe('2026-08-13');
    expect(calls.n).toBe(2);
  });

  it('gece değişince BAYAT kurtarma da eski geceyi sunmaz', async () => {
    let fail = false;
    const { svc } = makeService(async () => {
      if (fail) throw new Error('kaynak yok');
      return LIVE_SAMPLE;
    });
    await svc.availability(new Date('2026-08-12T20:58:00.000Z')); // 23:58 TR
    fail = true;
    // 00:10 TR: veri 12 dk yaşında (30 dk sınırının içinde) ama DÜNÜN gecesi.
    const out = await svc.availability(new Date('2026-08-12T21:10:00.000Z'));
    expect(out.coves).toEqual([]);
    expect(out.forDate).toBe('2026-08-13');
  });

  it('gece yarısını KESEN uçuş yeni gecenin isteğine ortak edilmez', async () => {
    // A 23:58 TR'de isteği başlatır (yanıt bekliyor); B 00:02 TR'de gelir.
    // B, A'nın dünkü penceresini PAYLAŞMAMALI — kendi gecesi için ayrı istek.
    let release!: (v: unknown) => void;
    const gate = new Promise((r) => {
      release = r;
    });
    let first = true;
    const { svc, calls } = makeService(() => {
      if (first) {
        first = false;
        return gate.then(() => LIVE_SAMPLE);
      }
      return Promise.resolve(LIVE_SAMPLE);
    });
    const pA = svc.availability(new Date('2026-08-12T20:58:00.000Z')); // 23:58 TR
    const pB = svc.availability(new Date('2026-08-12T21:02:00.000Z')); // 00:02 TR
    release(null);
    const [a, b] = await Promise.all([pA, pB]);
    expect(a.forDate).toBe('2026-08-12');
    expect(b.forDate).toBe('2026-08-13');
    expect(calls.n).toBe(2);
  });

  it('DERIA_ENABLED=false: kaynağa HİÇ gitmez, boş döner', async () => {
    const { svc, calls } = makeService(async () => LIVE_SAMPLE, false);
    const a = await svc.availability(t0);
    expect(a.coves).toEqual([]);
    expect(calls.n).toBe(0);
  });
});

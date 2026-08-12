/**
 * DERİA — Türkiye Çevre Ajansı'nın (TÜÇA) Göcek/Dalaman koyları tonoz-şamandıra
 * rezervasyon sistemi (deria.gov.tr). Biz REZERVASYON YAPMAYIZ; yalnız koy
 * başına doluluk bilgisini okur, kaynak atfıyla gösterir ve kaptanı
 * rezervasyon için deria.gov.tr'ye yönlendiririz (kurucu kararı 2026-08).
 */

/** Tek koyun tonoz doluluğu. */
export interface DeriaCove {
  /** DERİA'nın koy kimliği (cove/paged yanıtındaki `id`). */
  coveId: number;
  /** Bizim lokasyon kaydımızın slug'ı. */
  slug: string;
  /** DERİA'daki koy adı (teşhis/izleme için). */
  deriaName: string;
  /** Toplam tonoz/şamandıra kapasitesi. */
  total: number;
  /** Sorgulanan gece için müsait şamandıra sayısı. */
  free: number;
}

/** Uç noktanın döndürdüğü zarf. */
export interface DeriaAvailability {
  /** Kaynaktan çekildiği an (ISO). İstemci bayatlığı buna göre değerlendirir. */
  fetchedAt: string;
  /** Hangi gece için: giriş günü (YYYY-MM-DD, TR günü). */
  forDate: string;
  attribution: string;
  coves: DeriaCove[];
}

export const DERIA_ATTRIBUTION = 'DERİA — Türkiye Çevre Ajansı (deria.gov.tr)';

/** Ham kaynak satırı (yalnız kullandığımız alanlar). */
export interface DeriaRawCove {
  id: number;
  ad: string;
  kapasite: number;
  musaitSamandiraSayisi: number;
}

export const DERIA_PROVIDER = Symbol('DERIA_PROVIDER');

export interface DeriaProvider {
  /** Verilen TR gecesi için ham koy listesini getirir. */
  fetchRaw(girisIso: string, cikisIso: string): Promise<unknown>;
}

/**
 * DERİA koy kimliği ↔ Koybul slug eşlemesi.
 *
 * EL İLE ve TUTUCU: yalnız iki tarafta da AYNI koy olduğundan emin
 * olduklarımız. Eşleme adla değil KİMLİKLE yapılır (DERİA adları
 * değişebilir); kimliği listede olmayan DERİA koyları sessizce atlanır.
 * Kaynak: deria.gov.tr/api-gateway/api/cove/paged (2026-08-12 canlı yanıtı,
 * koordinatlar bizim kayıtlarla çapraz doğrulandı).
 */
export const DERIA_COVE_TO_SLUG: ReadonlyMap<number, string> = new Map([
  [6, 'bedri-rahmi-samandira-sahasi'], // BEDRİ RAHMİ KOYU (36.6953, 28.8669)
  [4, 'boynuzbuku-samandira-sahasi'], // BOYNUZBÜKÜ (36.7115, 28.8959)
  [8, 'sarsala-samandira-sahasi'], // SARSALA KOYU (36.6613, 28.8579)
  [12, 'gobun-samandira-sahasi'], // GÖBÜN KOYU (36.6443, 28.8938)
  [13, 'tersane-adasi-koyu'], // TERSANE ADASI (36.6755, 28.9152)
  [15, 'yassica-adalari'], // YASSICA ADALARI (36.7104, 28.9331)
  [5, 'kille-buku'], // KİLLE KOYU (36.6988, 28.8794)
  [7, 'siralibuk-koyu'], // SIRALIBÜK KOYU (36.6778, 28.8636)
]);

/**
 * Ham yanıttan eşlenmiş koy listesi üretir. Bilinmeyen/negatif/saçma değer
 * taşıyan satırlar ELENİR (yanlış "boş" bilgisi, hiç bilgi olmamasından
 * tehlikelidir — denizde karar bu sayıya göre verilir).
 */
export function transformDeria(raw: unknown): DeriaCove[] {
  const items = (raw as { items?: unknown })?.items;
  if (!Array.isArray(items)) return [];
  const out: DeriaCove[] = [];
  for (const it of items) {
    const r = it as Partial<DeriaRawCove>;
    if (typeof r.id !== 'number') continue;
    const slug = DERIA_COVE_TO_SLUG.get(r.id);
    if (!slug) continue;
    const total = r.kapasite;
    const free = r.musaitSamandiraSayisi;
    if (
      typeof total !== 'number' ||
      typeof free !== 'number' ||
      !Number.isFinite(total) ||
      !Number.isFinite(free) ||
      total <= 0 ||
      free < 0 ||
      free > total
    ) {
      continue;
    }
    out.push({
      coveId: r.id,
      slug,
      deriaName: typeof r.ad === 'string' ? r.ad : String(r.id),
      total: Math.floor(total),
      free: Math.floor(free),
    });
  }
  return out;
}

/**
 * "Bu gece" penceresi, TÜRKİYE gününe göre (UTC+3, DST yok): giriş = bugünün
 * TR gecesi, çıkış = yarın. DERİA tarihleri TR gece yarısını UTC ile yazar
 * (ör. 12 Ağustos girişi = 11T21:00Z) — canlı sitenin kendi sorgusundan
 * birebir kopya.
 */
export function deriaTonightWindow(now: Date): {
  girisIso: string;
  cikisIso: string;
  forDate: string;
} {
  const trMs = now.getTime() + 3 * 60 * 60 * 1000;
  const tr = new Date(trMs);
  const y = tr.getUTCFullYear();
  const m = tr.getUTCMonth();
  const d = tr.getUTCDate();
  const trMidnightUtc = Date.UTC(y, m, d) - 3 * 60 * 60 * 1000; // bugünün TR 00:00'ı
  const giris = new Date(trMidnightUtc);
  const cikis = new Date(trMidnightUtc + 24 * 60 * 60 * 1000);
  const pad = (n: number) => String(n).padStart(2, '0');
  return {
    girisIso: giris.toISOString(),
    cikisIso: cikis.toISOString(),
    forDate: `${y}-${pad(m + 1)}-${pad(d)}`,
  };
}

import { Inject, Injectable } from '@nestjs/common';
import { EnvService } from '../../../config/env.service';
import {
  DERIA_ATTRIBUTION,
  DERIA_PROVIDER,
  DeriaAvailability,
  DeriaProvider,
  deriaTonightWindow,
  transformDeria,
} from '../domain/deria.types';

/** Tazelik: doluluk dakikalar içinde değişebilir ama kaynağı dövmeyiz.
 * 5 dk, "canlı" hissi ile nazik olmanın dengesi. */
const CACHE_TTL_MS = 5 * 60 * 1000;

/** Bayat sunum tavanı: kaynak çökmüşse en fazla bu yaşa kadar eski veri
 * sunulur; daha eskisi HİÇ sunulmaz. Denizde 30 dakikalık doluluk hâlâ
 * fikir verir; saatlerce eski "boş" bilgisi tehlikeli bir yalandır. */
const STALE_MAX_MS = 30 * 60 * 1000;

interface CacheState {
  data: DeriaAvailability;
  fetchedAtMs: number;
}

/**
 * DERİA doluluk servisi. Tek anahtarlı önbellek ("bu gece"): bin kullanıcı da
 * baksa kaynağa 5 dakikada bir istek gider. Uçuş birleştirme: aynı anda gelen
 * istekler TEK kaynak çağrısını paylaşır (Bugün motoru dersi).
 *
 * Kaynak sorununda dönüş her zaman `coves: []` — istemci bunu "gösterge yok"
 * olarak çizer. Uç nokta 5xx atmaz: doluluk süsleme verisidir, detay
 * sayfasının kendisini asla kırmamalıdır.
 */
@Injectable()
export class DeriaService {
  private cache: CacheState | null = null;

  // Uçuş birleştirme GECE ANAHTARLI (inceleme bulgusu): gece yarısı sırasında
  // uçuşta olan dünün isteğine, yeni gecenin isteği ortak edilmemeli.
  private inFlight: { forDate: string; p: Promise<DeriaAvailability> } | null = null;

  constructor(
    @Inject(DERIA_PROVIDER) private readonly provider: DeriaProvider,
    private readonly env: EnvService,
  ) {}

  async availability(now: Date = new Date()): Promise<DeriaAvailability> {
    const win = deriaTonightWindow(now);
    if (!this.env.deriaEnabled) {
      return this.empty(now, win.forDate);
    }
    const nowMs = now.getTime();
    // Önbellek YALNIZ aynı gece için geçerlidir (inceleme bulgusu): TR gece
    // yarısını geçince dünün sayıları "bu gece" diye sunulamaz — yaş uygun
    // olsa bile pencere değiştiyse önbellek yok sayılır.
    const cached = this.cache;
    const hit = cached && cached.data.forDate === win.forDate ? cached : null;
    if (hit && nowMs - hit.fetchedAtMs < CACHE_TTL_MS) return hit.data;

    if (!this.inFlight || this.inFlight.forDate !== win.forDate) {
      const p = this.refresh(now, win).finally(() => {
        if (this.inFlight?.p === p) this.inFlight = null;
      });
      this.inFlight = { forDate: win.forDate, p };
    }
    try {
      return await this.inFlight.p;
    } catch {
      // Kaynak sorunu: AYNI GECEYE ait ve 30 dakikadan taze veri varsa onu
      // sun; değilse boş.
      if (hit && nowMs - hit.fetchedAtMs < STALE_MAX_MS) return hit.data;
      return this.empty(now, win.forDate);
    }
  }

  private async refresh(
    now: Date,
    win: ReturnType<typeof deriaTonightWindow>,
  ): Promise<DeriaAvailability> {
    const raw = await this.provider.fetchRaw(win.girisIso, win.cikisIso);
    const data: DeriaAvailability = {
      fetchedAt: now.toISOString(),
      forDate: win.forDate,
      attribution: DERIA_ATTRIBUTION,
      coves: transformDeria(raw),
    };
    this.cache = { data, fetchedAtMs: now.getTime() };
    return data;
  }

  private empty(now: Date, forDate: string): DeriaAvailability {
    return {
      fetchedAt: now.toISOString(),
      forDate,
      attribution: DERIA_ATTRIBUTION,
      coves: [],
    };
  }
}

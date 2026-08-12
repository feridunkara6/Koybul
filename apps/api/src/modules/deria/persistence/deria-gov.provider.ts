import { Injectable, Logger } from '@nestjs/common';
import { AppProblem } from '../../../common/problem/problem';
import { DeriaProvider } from '../domain/deria.types';

/**
 * deria.gov.tr sağlayıcısı. Sitenin kendi haritasının kullandığı, girişsiz
 * erişilen koy listesi ucunu okur (cove/paged). Nazik davranış kuralları:
 *  - Sunucu tarafında 5 dk önbellek (DeriaService) — kullanıcı sayısından
 *    bağımsız olarak kaynağa saatte en fazla 12 istek.
 *  - Tanıtıcı User-Agent (kim olduğumuz + iletişim) — soru olursa bize
 *    ulaşabilsinler.
 *  - Kaynak yanıt vermezse SESSİZCE geri çekilme (mobil göstergeyi gizler);
 *    asla uydurma ya da bayat-sınırsız veri sunulmaz.
 */
@Injectable()
export class DeriaGovProvider implements DeriaProvider {
  private readonly logger = new Logger(DeriaGovProvider.name);

  private static readonly BASE = 'https://deria.gov.tr/api-gateway/api/cove/paged';

  // ASCII kalmalı (MET sağlayıcı dersi: Türkçe karakterli başlık isteği kırar).
  static readonly USER_AGENT = 'Koybul/1.0 (maritime discovery app; destek@koybul.com)';

  async fetchRaw(girisIso: string, cikisIso: string): Promise<unknown> {
    const url =
      `${DeriaGovProvider.BASE}?arama=&girisTarihi=${encodeURIComponent(girisIso)}` +
      `&cikisTarihi=${encodeURIComponent(cikisIso)}&page=1&pageNumber=1&pageSize=50&sayfaNo=1&sayfaBoyutu=50`;
    let res: Response;
    try {
      res = await fetch(url, {
        headers: { 'user-agent': DeriaGovProvider.USER_AGENT, accept: 'application/json' },
        signal: AbortSignal.timeout(8000),
      });
    } catch (err) {
      this.logger.warn(`DERIA erişilemedi: ${(err as Error).message}`);
      throw new AppProblem('service-unavailable', 'DERİA kaynağına ulaşılamıyor.');
    }
    if (!res.ok) {
      this.logger.warn(`DERIA yanıtı: HTTP ${res.status}`);
      throw new AppProblem('service-unavailable', 'DERİA kaynağı geçici olarak yanıt vermiyor.');
    }
    try {
      return await res.json();
    } catch (err) {
      // 200 ama gövde JSON değil (WAF/araya giren sayfa) — logsuz kalmasın.
      this.logger.warn(`DERIA yanıtı JSON değil: ${(err as Error).message}`);
      throw new AppProblem('service-unavailable', 'DERİA kaynağı okunamadı.');
    }
  }
}

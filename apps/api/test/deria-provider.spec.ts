import { DeriaGovProvider } from '../src/modules/deria/persistence/deria-gov.provider';
import { DeriaController } from '../src/modules/deria/presentation/deria.controller';
import { DeriaService } from '../src/modules/deria/application/deria.service';
import { AppProblem } from '../src/common/problem/problem';
import { EnvService } from '../src/config/env.service';

/**
 * DERİA sağlayıcı + uç nokta testleri. Sağlayıcının dört yolu (ok / HTTP hata /
 * ağ hatası / 200-ama-JSON-değil) ve ucun zarfı kilitlenir. `fetch` taklit
 * edilir — test ASLA ağa çıkmaz.
 */

const realFetch = global.fetch;

afterEach(() => {
  global.fetch = realFetch;
  jest.restoreAllMocks();
});

function mockFetch(impl: () => Promise<unknown>): jest.Mock {
  const m = jest.fn(impl);
  global.fetch = m as unknown as typeof fetch;
  return m;
}

describe('DeriaGovProvider', () => {
  const GIRIS = '2026-08-11T21:00:00.000Z';
  const CIKIS = '2026-08-12T21:00:00.000Z';

  it('başarılı yanıtta JSON gövdesini döner ve doğru URL ile çağırır', async () => {
    const m = mockFetch(async () => ({
      ok: true,
      status: 200,
      json: async () => ({ items: [] }),
    }));
    const p = new DeriaGovProvider();
    const out = await p.fetchRaw(GIRIS, CIKIS);
    expect(out).toEqual({ items: [] });
    const url = (m.mock.calls[0] as unknown[])[0] as string;
    expect(url).toContain('deria.gov.tr/api-gateway/api/cove/paged');
    expect(url).toContain(encodeURIComponent(GIRIS));
    expect(url).toContain(encodeURIComponent(CIKIS));
    // Baslik ASCII olmali (MET dersi: Turkce karakter istegi kirar).
    const init = (m.mock.calls[0] as unknown[])[1] as { headers: Record<string, string> };
    for (const ch of init.headers['user-agent']) {
      expect(ch.charCodeAt(0)).toBeLessThan(128);
    }
  });

  it('HTTP hata → AppProblem (service-unavailable)', async () => {
    mockFetch(async () => ({ ok: false, status: 503, json: async () => ({}) }));
    await expect(new DeriaGovProvider().fetchRaw(GIRIS, CIKIS)).rejects.toBeInstanceOf(AppProblem);
  });

  it('ağ hatası → AppProblem', async () => {
    mockFetch(async () => {
      throw new Error('ECONNREFUSED');
    });
    await expect(new DeriaGovProvider().fetchRaw(GIRIS, CIKIS)).rejects.toBeInstanceOf(AppProblem);
  });

  it('200 ama gövde JSON değil (WAF sayfası) → AppProblem, ham SyntaxError değil', async () => {
    mockFetch(async () => ({
      ok: true,
      status: 200,
      json: async () => {
        throw new SyntaxError('Unexpected token <');
      },
    }));
    await expect(new DeriaGovProvider().fetchRaw(GIRIS, CIKIS)).rejects.toBeInstanceOf(AppProblem);
  });
});

describe('DeriaController', () => {
  it('servis zarfını olduğu gibi döner (anonim uç)', async () => {
    const svc = new DeriaService({ fetchRaw: async () => ({ items: [] }) }, {
      deriaEnabled: true,
    } as unknown as EnvService);
    const ctrl = new DeriaController(svc);
    const out = await ctrl.availability();
    expect(out.attribution).toContain('DERİA');
    expect(Array.isArray(out.coves)).toBe(true);
  });
});

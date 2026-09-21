import { generateKeyPairSync } from 'crypto';
import { AppleAppStoreGateway } from '../src/modules/premium/infrastructure/apple-appstore.gateway';
import { EnvService } from '../src/config/env.service';

/**
 * Test anahtarı ÇALIŞMA ANINDA üretilir — dosyaya PEM gömülmez (gitleaks,
 * env.schema.spec.ts'teki dersle aynı sebep).
 */
const TEST_P8 = generateKeyPairSync('ec', { namedCurve: 'P-256' }).privateKey.export({
  type: 'pkcs8',
  format: 'pem',
}) as string;

function env(configured: boolean): EnvService {
  return {
    appleIap: configured
      ? {
          issuerId: 'issuer-1',
          keyId: 'KEY123',
          privateKeyP8: TEST_P8,
          bundleId: 'com.koybul.app',
          environment: 'sandbox' as const,
        }
      : null,
  } as unknown as EnvService;
}

function jws(payload: Record<string, unknown>): string {
  const b64 = (o: Record<string, unknown>): string =>
    Buffer.from(JSON.stringify(o)).toString('base64url');
  return `${b64({ alg: 'ES256' })}.${b64(payload)}.imza`;
}

describe('AppleAppStoreGateway (P2)', () => {
  const realFetch = global.fetch;
  afterEach(() => {
    global.fetch = realFetch;
  });

  it('yapılandırma yokken configured=false ve fetchState 503 fırlatır', async () => {
    const gw = new AppleAppStoreGateway(env(false));
    expect(gw.configured).toBe(false);
    await expect(gw.fetchState('t1')).rejects.toMatchObject({
      problemType: 'service-unavailable',
    });
  });

  it('sandbox adresine ES256 Bearer ile gider; 404 → null (Apple tanımıyor)', async () => {
    let seenUrl = '';
    let seenAuth = '';
    global.fetch = ((url: string, init?: { headers?: Record<string, string> }) => {
      seenUrl = url;
      seenAuth = init?.headers?.authorization ?? '';
      return Promise.resolve(new Response('', { status: 404 }));
    }) as unknown as typeof fetch;

    const gw = new AppleAppStoreGateway(env(true));
    expect(await gw.fetchState('t404')).toBeNull();
    expect(seenUrl).toBe(
      'https://api.storekit-sandbox.itunes.apple.com/inApps/v1/subscriptions/t404',
    );
    expect(seenAuth.startsWith('Bearer ')).toBe(true);
    // JWT gövdesi: iss/aud/bid doğru mu? (imzayı Apple doğrular; burada içerik)
    const claims = JSON.parse(
      Buffer.from(seenAuth.slice('Bearer '.length).split('.')[1], 'base64url').toString('utf8'),
    ) as Record<string, unknown>;
    expect(claims.iss).toBe('issuer-1');
    expect(claims.aud).toBe('appstoreconnect-v1');
    expect(claims.bid).toBe('com.koybul.app');
  });

  it('aktif abonelik: durum 1 + expiresDate → entitled, ürün ve bitiş çözülür', async () => {
    const expires = Date.parse('2027-09-21T12:00:00Z');
    const body = {
      data: [
        {
          lastTransactions: [
            {
              originalTransactionId: 't1',
              status: 1,
              signedTransactionInfo: jws({
                originalTransactionId: 't1',
                productId: 'koybul.premium.yillik',
                expiresDate: expires,
              }),
            },
          ],
        },
      ],
    };
    global.fetch = (() =>
      Promise.resolve(
        new Response(JSON.stringify(body), { status: 200 }),
      )) as unknown as typeof fetch;

    const state = await new AppleAppStoreGateway(env(true)).fetchState('t1');
    expect(state).toEqual({
      originalTransactionId: 't1',
      productId: 'koybul.premium.yillik',
      entitled: true,
      appleStatus: 1,
      expiresAt: new Date(expires),
    });
  });

  it('bitmiş abonelik (durum 2) entitled=false; bitiş tarihi ÇÖZÜLEMEZSE hak verilmez', async () => {
    const mk = (status: number, info: Record<string, unknown>): string =>
      JSON.stringify({
        data: [
          {
            lastTransactions: [
              { originalTransactionId: 't1', status, signedTransactionInfo: jws(info) },
            ],
          },
        ],
      });

    global.fetch = (() =>
      Promise.resolve(
        new Response(mk(2, { originalTransactionId: 't1', expiresDate: 5 }), { status: 200 }),
      )) as unknown as typeof fetch;
    const gw = new AppleAppStoreGateway(env(true));
    expect((await gw.fetchState('t1'))?.entitled).toBe(false);

    // Durum 1 ama expiresDate yok → uydurma tarih YAZILMAZ, hak da verilmez.
    global.fetch = (() =>
      Promise.resolve(
        new Response(mk(1, { originalTransactionId: 't1' }), { status: 200 }),
      )) as unknown as typeof fetch;
    const s2 = await gw.fetchState('t1');
    expect(s2?.entitled).toBe(false);
    expect(s2?.expiresAt).toBeNull();
  });

  it('Apple 401/5xx → 503 service-unavailable (kullanıcıya dürüst hata)', async () => {
    global.fetch = (() =>
      Promise.resolve(new Response('', { status: 401 }))) as unknown as typeof fetch;
    await expect(new AppleAppStoreGateway(env(true)).fetchState('t1')).rejects.toMatchObject({
      problemType: 'service-unavailable',
    });
  });
});

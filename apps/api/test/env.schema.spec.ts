import { validateEnv } from '../src/config/env.schema';

/**
 * Şemanın ZORUNLU alanlarının tamamı. Eksik bırakılırsa "geçerli ortam" testi
 * kendi kurgusundan düşer (2026-08'de tam olarak bu oluyordu: FIREBASE_PROJECT_ID
 * ve JWT anahtarları fixture'da yoktu, test kırmızıydı).
 */
const VALID: NodeJS.ProcessEnv = {
  NODE_ENV: 'test',
  DATABASE_URL: 'postgresql://user:pass@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  FIREBASE_PROJECT_ID: 'dockly-test',
  // Şema yalnız metinde 'BEGIN' geçmesini şart koşar (env.schema.ts:18-19).
  // GERÇEK PEM BAŞLIK KALIBI BİLEREK KULLANILMIYOR: sahte bile olsa o kalıp
  // gitleaks'in private-key kuralını tetikler ve güvenlik taramasını kırmızıya
  // düşürür (10 Ağu 2026'da tam olarak bu oldu). Yorumda bile yazılmamalı.
  JWT_PRIVATE_KEY_PEM: 'BEGIN sahte ozel anahtar (test fixture)',
  JWT_PUBLIC_KEY_PEM: 'BEGIN sahte acik anahtar (test fixture)',
};

describe('validateEnv (fail-fast, docs/24 §16)', () => {
  it('geçerli ortamı tipli döndürür ve varsayılanları uygular', () => {
    const env = validateEnv(VALID);
    expect(env.PORT).toBe(3000);
    expect(env.LOG_LEVEL).toBe('info');
    expect(env.SHUTDOWN_TIMEOUT_MS).toBe(10_000);
  });

  it('DATABASE_URL eksikse anlaşılır hatayla düşer', () => {
    const { DATABASE_URL: _omitted, ...rest } = VALID;
    expect(() => validateEnv(rest)).toThrow(/DATABASE_URL/);
  });

  it('postgresql:// olmayan DATABASE_URL reddedilir', () => {
    expect(() => validateEnv({ ...VALID, DATABASE_URL: 'mysql://x:y@h/db' })).toThrow(
      /DATABASE_URL/,
    );
  });

  it('geçersiz PORT reddedilir (edge: 0 ve 65536)', () => {
    expect(() => validateEnv({ ...VALID, PORT: '0' })).toThrow(/PORT/);
    expect(() => validateEnv({ ...VALID, PORT: '65536' })).toThrow(/PORT/);
  });

  it('bilinmeyen NODE_ENV reddedilir', () => {
    expect(() => validateEnv({ ...VALID, NODE_ENV: 'qa' })).toThrow(/NODE_ENV/);
  });

  it('FIREBASE_PROJECT_ID ve JWT anahtarları ZORUNLUDUR (fail-fast)', () => {
    const { FIREBASE_PROJECT_ID: _a, ...noProject } = VALID;
    expect(() => validateEnv(noProject)).toThrow(/FIREBASE_PROJECT_ID/);
    const { JWT_PRIVATE_KEY_PEM: _b, ...noKey } = VALID;
    expect(() => validateEnv(noKey)).toThrow(/JWT_PRIVATE_KEY_PEM/);
  });

  it('genel hız sınırı varsayılanları uygulanır (0008 topluluk paketi)', () => {
    const env = validateEnv(VALID);
    expect(env.READ_RATE_LIMIT_PER_MIN).toBe(300);
    expect(env.WRITE_RATE_LIMIT_PER_MIN).toBe(60);
    expect(env.AUTH_RATE_LIMIT_PER_MIN).toBe(10);
  });

  it('hız sınırı 0 veya negatif olamaz', () => {
    expect(() => validateEnv({ ...VALID, READ_RATE_LIMIT_PER_MIN: '0' })).toThrow(/READ_RATE/);
    expect(() => validateEnv({ ...VALID, WRITE_RATE_LIMIT_PER_MIN: '-5' })).toThrow(/WRITE_RATE/);
  });

  it('PREMIUM_ENFORCE: varsayılan KAPALI; true/false kabul; yanlış yazım düşürür (P1)', () => {
    // Varsayılan false — bayrak, mobil paywall yayında olana dek kapalı durur.
    expect(validateEnv(VALID).PREMIUM_ENFORCE).toBe(false);
    expect(validateEnv({ ...VALID, PREMIUM_ENFORCE: 'true' }).PREMIUM_ENFORCE).toBe(true);
    expect(validateEnv({ ...VALID, PREMIUM_ENFORCE: ' TRUE ' }).PREMIUM_ENFORCE).toBe(true);
    expect(validateEnv({ ...VALID, PREMIUM_ENFORCE: 'false' }).PREMIUM_ENFORCE).toBe(false);
    // '1'/'on' gibi yazımlar SESSİZCE kapalı kalmasın: önyükleme hatayla durur.
    expect(() => validateEnv({ ...VALID, PREMIUM_ENFORCE: '1' })).toThrow(/PREMIUM_ENFORCE/);
  });

  it('APPLE_IAP_*: ya dördü birden ya hiçbiri; ortam varsayılanı sandbox (P2)', () => {
    // Hiçbiri yok → geçerli, uçlar 503 döner (Sentry deseni).
    expect(validateEnv(VALID).APPLE_IAP_ISSUER_ID).toBeUndefined();
    expect(validateEnv(VALID).APPLE_IAP_ENVIRONMENT).toBe('sandbox');

    const full = {
      ...VALID,
      APPLE_IAP_ISSUER_ID: 'issuer-1',
      APPLE_IAP_KEY_ID: 'KEY123',
      // PEM kalıbı BİLEREK kullanılmıyor (bu dosyanın başındaki gitleaks dersi).
      APPLE_IAP_PRIVATE_KEY_P8: 'BEGIN sahte p8 anahtari (test fixture)',
      APPLE_IAP_BUNDLE_ID: 'com.koybul.app',
    };
    expect(validateEnv(full).APPLE_IAP_BUNDLE_ID).toBe('com.koybul.app');
    expect(
      validateEnv({ ...full, APPLE_IAP_ENVIRONMENT: 'production' }).APPLE_IAP_ENVIRONMENT,
    ).toBe('production');

    // Kısmi yapılandırma en sinsi hata sınıfıdır — önyükleme durmalı.
    const { APPLE_IAP_BUNDLE_ID: _omitted, ...partial } = full;
    expect(() => validateEnv(partial)).toThrow(/APPLE_IAP_BUNDLE_ID/);
    expect(() => validateEnv({ ...VALID, APPLE_IAP_KEY_ID: 'KEY123' })).toThrow(/APPLE_IAP/);
  });
});

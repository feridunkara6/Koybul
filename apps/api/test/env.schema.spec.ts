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
  JWT_PRIVATE_KEY_PEM: '-----BEGIN PRIVATE KEY-----\nxx\n-----END PRIVATE KEY-----',
  JWT_PUBLIC_KEY_PEM: '-----BEGIN PUBLIC KEY-----\nxx\n-----END PUBLIC KEY-----',
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
});

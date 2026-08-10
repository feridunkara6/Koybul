import { Request, Response } from 'express';
import {
  RateLimitMiddleware,
  bucketFor,
  isExemptPath,
} from '../src/common/rate-limit/rate-limit.middleware';
import { EnvService } from '../src/config/env.service';
import { RateLimiterService, RateDecision } from '../src/infrastructure/redis/rate-limiter.service';

function fakeEnv(nodeEnv: string): EnvService {
  const values: Record<string, unknown> = {
    NODE_ENV: nodeEnv,
    READ_RATE_LIMIT_PER_MIN: 300,
    WRITE_RATE_LIMIT_PER_MIN: 60,
  };
  return { get: (k: string) => values[k] } as unknown as EnvService;
}

function fakeLimiter(decision: RateDecision, calls: unknown[][] = []): RateLimiterService {
  return {
    consume: (...args: unknown[]) => {
      calls.push(args);
      return Promise.resolve(decision);
    },
  } as unknown as RateLimiterService;
}

function fakeRes(): Response & {
  statusCode?: number;
  body?: unknown;
  headers: Record<string, string>;
  capturedType?: string;
} {
  const res = {
    headers: {} as Record<string, string>,
    setHeader(name: string, value: string) {
      res.headers[name] = value;
      return res;
    },
    status(code: number) {
      res.statusCode = code;
      return res;
    },
    type(t: string) {
      res.capturedType = t;
      return res;
    },
    json(b: unknown) {
      res.body = b;
      return res;
    },
  } as unknown as Response & {
    statusCode?: number;
    body?: unknown;
    headers: Record<string, string>;
    capturedType?: string;
  };
  return res;
}

const req = (over: Partial<Request> = {}): Request =>
  ({ method: 'GET', originalUrl: '/v1/locations', ip: '1.2.3.4', socket: {}, ...over }) as Request;

describe('isExemptPath', () => {
  it('sağlık uçları muaftır', () => {
    expect(isExemptPath('/healthz')).toBe(true);
    expect(isExemptPath('/readyz')).toBe(true);
  });

  it('/auth muaftır (kendi, daha sıkı sınırı var)', () => {
    expect(isExemptPath('/v1/auth/sessions')).toBe(true);
    expect(isExemptPath('/v1/auth/sessions/refresh')).toBe(true);
  });

  it('benzer görünen ama farklı yol muaf DEĞİLDİR (önek tuzağı)', () => {
    expect(isExemptPath('/v1/authors')).toBe(false);
    expect(isExemptPath('/v1/locations')).toBe(false);
    expect(isExemptPath('/v1/weather')).toBe(false);
  });
});

describe('bucketFor', () => {
  it('güvenli metotlar okuma sayılır', () => {
    expect(bucketFor('GET')).toBe('read');
    expect(bucketFor('head')).toBe('read');
    expect(bucketFor('OPTIONS')).toBe('read');
  });

  it('değiştiren metotlar yazma sayılır', () => {
    for (const m of ['POST', 'PATCH', 'PUT', 'DELETE']) {
      expect(bucketFor(m)).toBe('write');
    }
  });
});

describe('RateLimitMiddleware', () => {
  const allow: RateDecision = { allowed: true, retryAfterSec: 0 };
  const deny: RateDecision = { allowed: false, retryAfterSec: 42 };

  it('izin verilen istekte next() çağrılır ve yanıt yazılmaz', async () => {
    const res = fakeRes();
    const next = jest.fn();
    const mw = new RateLimitMiddleware(fakeLimiter(allow), fakeEnv('production'));
    await mw.use(req(), res, next);
    expect(next).toHaveBeenCalledTimes(1);
    expect(res.statusCode).toBeUndefined();
  });

  it('sınır aşılınca 429 + Retry-After + problem+json; next() ÇAĞRILMAZ', async () => {
    const res = fakeRes();
    const next = jest.fn();
    const mw = new RateLimitMiddleware(fakeLimiter(deny), fakeEnv('production'));
    const r = req({ method: 'POST', originalUrl: '/v1/locations/x/notes' });
    await mw.use(r, res, next);
    expect(next).not.toHaveBeenCalled();
    expect(res.statusCode).toBe(429);
    expect(res.headers['Retry-After']).toBe('42');
    expect(res.capturedType).toBe('application/problem+json');
    expect(res.body).toMatchObject({
      status: 429,
      type: expect.stringContaining('rate-limited'),
    });
  });

  it('429 gövdesinde sorgu dizesi SIZMAZ (konum verisi log/gövde hijyeni)', async () => {
    const res = fakeRes();
    const mw = new RateLimitMiddleware(fakeLimiter(deny), fakeEnv('production'));
    await mw.use(req({ originalUrl: '/v1/weather?lat=36.62&lon=29.12' }), res, jest.fn());
    expect(JSON.stringify(res.body)).not.toContain('36.62');
    expect(res.body).toMatchObject({ instance: '/v1/weather' });
  });

  it('okuma ve yazma FARKLI bütçe kullanır', async () => {
    const calls: unknown[][] = [];
    const mw = new RateLimitMiddleware(fakeLimiter(allow, calls), fakeEnv('production'));
    await mw.use(req(), fakeRes(), jest.fn());
    await mw.use(req({ method: 'POST' }), fakeRes(), jest.fn());
    expect(calls[0][0]).toBe('read');
    expect(calls[0][2]).toBe(300);
    expect(calls[1][0]).toBe('write');
    expect(calls[1][2]).toBe(60);
  });

  it('muaf yolda sayaç HİÇ tüketilmez', async () => {
    const calls: unknown[][] = [];
    const mw = new RateLimitMiddleware(fakeLimiter(deny, calls), fakeEnv('production'));
    const next = jest.fn();
    await mw.use(req({ originalUrl: '/healthz' }), fakeRes(), next);
    expect(calls).toHaveLength(0);
    expect(next).toHaveBeenCalledTimes(1);
  });

  it('test ortamında devre dışıdır (e2e paketleri sınıra takılmasın)', async () => {
    const calls: unknown[][] = [];
    const mw = new RateLimitMiddleware(fakeLimiter(deny, calls), fakeEnv('test'));
    const next = jest.fn();
    await mw.use(req({ method: 'POST' }), fakeRes(), next);
    expect(calls).toHaveLength(0);
    expect(next).toHaveBeenCalledTimes(1);
  });

  it('IP yoksa soketten okunur, o da yoksa "unknown" kullanılır', async () => {
    const calls: unknown[][] = [];
    const mw = new RateLimitMiddleware(fakeLimiter(allow, calls), fakeEnv('production'));
    await mw.use(
      { method: 'GET', originalUrl: '/v1/locations', socket: {} } as Request,
      fakeRes(),
      jest.fn(),
    );
    expect(calls[0][1]).toBe('unknown');
  });
});

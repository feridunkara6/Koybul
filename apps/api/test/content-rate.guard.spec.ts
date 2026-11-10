import { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import {
  CONTENT_RATE_KEY,
  CONTENT_RATE_WINDOW_SEC,
  ContentRateGuard,
  ContentRateSpec,
} from '../src/common/guards/content-rate.guard';
import { AppProblem } from '../src/common/problem/problem';
import { Principal } from '../src/core/auth/principal';
import { RateDecision, RateLimiterService } from '../src/infrastructure/redis/rate-limiter.service';
import { EnvService } from '../src/config/env.service';

/** Sahte sayaç: çağrıları kaydeder, kararları kuyruktan verir. */
class FakeLimiter {
  calls: Array<{ bucket: string; id: string; max: number; windowSec: number }> = [];
  next: RateDecision = { allowed: true, retryAfterSec: 0 };

  consume(bucket: string, id: string, max: number, windowSec: number): Promise<RateDecision> {
    this.calls.push({ bucket, id, max, windowSec });
    return Promise.resolve(this.next);
  }
}

function fakeEnv(nodeEnv: string): EnvService {
  return { get: () => nodeEnv } as unknown as EnvService;
}

function contextWith(principal: Principal | undefined, spec?: ContentRateSpec): ExecutionContext {
  const handler = (): void => undefined;
  if (spec) {
    Reflect.defineMetadata(CONTENT_RATE_KEY, spec, handler);
  }
  return {
    getHandler: () => handler,
    getClass: () => class {},
    switchToHttp: () => ({ getRequest: () => ({ principal }) }),
  } as unknown as ExecutionContext;
}

function principalWith(userId: string): Principal {
  return { userId, role: 'user', isGuest: false, familyId: 'f', jti: 'j' };
}

describe('ContentRateGuard — içerik spam freni (yayın hazırlığı 2026-11)', () => {
  function guardWith(limiter: FakeLimiter, nodeEnv = 'production'): ContentRateGuard {
    return new ContentRateGuard(
      new Reflector(),
      limiter as unknown as RateLimiterService,
      fakeEnv(nodeEnv),
    );
  }

  it('metadata yoksa sayaç HİÇ çalışmaz ve istek geçer', async () => {
    const limiter = new FakeLimiter();
    const guard = guardWith(limiter);
    await expect(guard.canActivate(contextWith(principalWith('u1')))).resolves.toBe(true);
    expect(limiter.calls).toHaveLength(0);
  });

  it('test ortamında devre dışıdır (e2e paketleri sınıra takılmasın)', async () => {
    const limiter = new FakeLimiter();
    const guard = guardWith(limiter, 'test');
    const ctx = contextWith(principalWith('u1'), { kind: 'note', maxPerHour: 10 });
    await expect(guard.canActivate(ctx)).resolves.toBe(true);
    expect(limiter.calls).toHaveLength(0);
  });

  it('limit altında geçer — kova, kimlik ve pencere doğru bağlanır', async () => {
    const limiter = new FakeLimiter();
    const guard = guardWith(limiter);
    const ctx = contextWith(principalWith('kullanici-1'), { kind: 'note', maxPerHour: 10 });
    await expect(guard.canActivate(ctx)).resolves.toBe(true);
    expect(limiter.calls).toEqual([
      {
        bucket: 'content:note',
        id: 'kullanici-1',
        max: 10,
        windowSec: CONTENT_RATE_WINDOW_SEC,
      },
    ]);
  });

  it('limit aşılınca 429 rate-limited + Retry-After başlığı fırlatır', async () => {
    const limiter = new FakeLimiter();
    limiter.next = { allowed: false, retryAfterSec: 1800 };
    const guard = guardWith(limiter);
    const ctx = contextWith(principalWith('u1'), { kind: 'review', maxPerHour: 10 });
    let thrown: unknown;
    try {
      await guard.canActivate(ctx);
    } catch (e) {
      thrown = e;
    }
    expect(thrown).toBeInstanceOf(AppProblem);
    const problem = thrown as AppProblem;
    expect(problem.problemType).toBe('rate-limited');
    expect(problem.status).toBe(429);
    expect(problem.headers).toEqual({ 'Retry-After': '1800' });
  });

  it('principal yoksa (guard sırası hatası) fail-closed invalid-token fırlatır', async () => {
    const limiter = new FakeLimiter();
    const guard = guardWith(limiter);
    const ctx = contextWith(undefined, { kind: 'note', maxPerHour: 10 });
    let thrown: unknown;
    try {
      await guard.canActivate(ctx);
    } catch (e) {
      thrown = e;
    }
    expect(thrown).toBeInstanceOf(AppProblem);
    expect((thrown as AppProblem).problemType).toBe('invalid-token');
    expect(limiter.calls).toHaveLength(0);
  });
});

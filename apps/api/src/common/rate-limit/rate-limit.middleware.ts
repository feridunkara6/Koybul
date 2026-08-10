import { Injectable, Logger, NestMiddleware } from '@nestjs/common';
import { NextFunction, Request, Response } from 'express';
import { EnvService } from '../../config/env.service';
import { RateLimiterService } from '../../infrastructure/redis/rate-limiter.service';
import { currentRequestId } from '../context/request-context';
import { AppProblem } from '../problem/problem';

const PROBLEM_CONTENT_TYPE = 'application/problem+json';
const WINDOW_SEC = 60;

/**
 * Muaf yollar. Yalnızca sağlık uçları ve AuthController'ın KENDİ (daha sıkı)
 * sınırını uyguladığı iki uç muaftır. `/v1/auth` alt ağacının tamamını muaf
 * tutmak, logout uçlarını sınırsız bırakırdı — denetim bulgusunun tam kalbi.
 */
const AUTH_SELF_LIMITED = new Set(['/v1/auth/sessions', '/v1/auth/sessions/refresh']);

export function isExemptPath(path: string, method = 'POST'): boolean {
  if (path === '/healthz' || path === '/readyz') return true;
  // /auth/sessions yalnız POST'ta kendi bütçesine sahip; DELETE (logout) değil.
  return method.toUpperCase() === 'POST' && AUTH_SELF_LIMITED.has(path);
}

/** Okuma mu yazma mı — güvenli metotlar okuma sayılır. */
export function bucketFor(method: string): 'read' | 'write' {
  const m = method.toUpperCase();
  return m === 'GET' || m === 'HEAD' || m === 'OPTIONS' ? 'read' : 'write';
}

/**
 * Genel hız sınırı (denetim bulgusu 2026-08: 26 uçtan yalnız 2'si sınırlıydı).
 *
 * Neden ORTA KATMAN (middleware), guard değil: guard'lar yalnız korumalı
 * controller'larda çalışır; asıl açık olan uçlar (arama, hava vekili) anonim.
 * Neden yanıtı KENDİ yazıyor: middleware'den fırlatılan istisnalar Nest'in
 * global exception filter'ına güvenilir biçimde ULAŞMAZ — 429 gövdesini burada
 * RFC 9457 biçiminde üretmek tek doğru davranıştır.
 *
 * Test ortamında (NODE_ENV=test) devre dışıdır: e2e paketleri onlarca istek
 * atar ve sınır, testin doğruladığı davranışı gölgelemez.
 */
@Injectable()
export class RateLimitMiddleware implements NestMiddleware {
  private readonly logger = new Logger(RateLimitMiddleware.name);

  constructor(
    private readonly limiter: RateLimiterService,
    private readonly env: EnvService,
  ) {}

  async use(req: Request, res: Response, next: NextFunction): Promise<void> {
    const path = (req.originalUrl ?? req.url).split('?')[0];
    if (this.env.get('NODE_ENV') === 'test' || isExemptPath(path, req.method)) {
      next();
      return;
    }

    const bucket = bucketFor(req.method);
    const max =
      bucket === 'read'
        ? this.env.get('READ_RATE_LIMIT_PER_MIN')
        : this.env.get('WRITE_RATE_LIMIT_PER_MIN');

    // Kimlik: IP. Vekil arkasında doğru IP için main.ts'te `trust proxy` açıktır.
    const id = req.ip ?? req.socket.remoteAddress ?? 'unknown';
    const decision = await this.limiter.consume(bucket, id, max, WINDOW_SEC);

    if (decision.allowed) {
      next();
      return;
    }

    // Yanıtı burada yazdığımız için pino-http erişim logu ÇALIŞMAZ; kısıtlama
    // olayı görünmez kalmasın diye açıkça loglanır (alarm/ölçüm bunun üstüne kurulur).
    this.logger.warn(
      { event: 'rate_limited', bucket, path, requestId: currentRequestId() },
      'İstek hız sınırına takıldı',
    );

    const problem = new AppProblem(
      'rate-limited',
      'Çok fazla istek gönderildi — kısa bir süre sonra tekrar dene.',
    );
    res.setHeader('Retry-After', String(decision.retryAfterSec));
    res
      .status(problem.status)
      .type(PROBLEM_CONTENT_TYPE)
      .json(problem.toBody(path, currentRequestId()));
  }
}

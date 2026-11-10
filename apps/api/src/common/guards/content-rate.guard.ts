import { CanActivate, ExecutionContext, Injectable, SetMetadata } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { EnvService } from '../../config/env.service';
import { RateLimiterService } from '../../infrastructure/redis/rate-limiter.service';
import { AppProblem } from '../problem/problem';
import { AuthedRequest } from './jwt-auth.guard';

export const CONTENT_RATE_KEY = 'dockly:contentRate';

/** Pencere: 1 saat. İçerik üretimi dakikalık değil saatlik bütçeyle frenlenir. */
export const CONTENT_RATE_WINDOW_SEC = 3600;

export interface ContentRateSpec {
  /** Sayaç türü (ör. 'note', 'review') — Redis anahtarı `rl:content:<kind>:<userId>`. */
  kind: string;
  /** Kullanıcı başına saatlik üst sınır. */
  maxPerHour: number;
}

/**
 * İçerik üretme ucuna KULLANICI BAŞI saatlik tavan koyar (spam freni,
 * yayın hazırlığı 2026-11). Genel orta katman sınırı (rate-limit.middleware)
 * IP başına ve DAKİKALIK çalışır; NAT arkasında onlarca kullanıcı aynı IP'yi
 * paylaşır ve sabırlı bir spamci dakikalık bütçeye hiç takılmadan saatte
 * yüzlerce içerik üretebilirdi. Bu guard o açığı kimliğe (userId) bağlı
 * saatlik sayaçla kapatır.
 *
 * KULLANIM: @UseGuards listesinde JwtAuthGuard'dan SONRA gelmeli
 * (principal'a ihtiyaç duyar); principal yoksa fail-closed invalid-token
 * fırlatır — sıra hatası sessizce sınırsızlığa dönüşmesin.
 *
 * Test ortamında (NODE_ENV=test) devre dışıdır — orta katmanla aynı gerekçe:
 * e2e paketleri onlarca istek atar ve sınır, testin doğruladığı davranışı
 * gölgelemez. Guard'ın kendi davranışı content-rate.guard.spec.ts'te
 * üretim-benzeri sahte ortamla test edilir.
 */
export const ContentRate = (kind: string, maxPerHour: number): MethodDecorator =>
  SetMetadata(CONTENT_RATE_KEY, { kind, maxPerHour } satisfies ContentRateSpec);

@Injectable()
export class ContentRateGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly limiter: RateLimiterService,
    private readonly env: EnvService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const spec = this.reflector.getAllAndOverride<ContentRateSpec | undefined>(CONTENT_RATE_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!spec) return true;
    if (this.env.get('NODE_ENV') === 'test') return true;

    const { principal } = context.switchToHttp().getRequest<AuthedRequest>();
    if (!principal) throw new AppProblem('invalid-token');

    const decision = await this.limiter.consume(
      `content:${spec.kind}`,
      principal.userId,
      spec.maxPerHour,
      CONTENT_RATE_WINDOW_SEC,
    );
    if (!decision.allowed) {
      throw new AppProblem(
        'rate-limited',
        'Kısa sürede çok fazla paylaşım yapıldı — bir süre sonra tekrar dene.',
        undefined,
        { 'Retry-After': String(decision.retryAfterSec) },
      );
    }
    return true;
  }
}

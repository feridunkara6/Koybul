import { Global, Module } from '@nestjs/common';
import { RedisService } from './redis.service';
import { RateLimiterService } from './rate-limiter.service';

/**
 * Global altyapı modülü. RateLimiterService burada da sağlanır çünkü genel hız
 * sınırı ORTA KATMAN'dan (AppModule.configure) çözülür; AuthModule kendi yerel
 * örneğini korur (mevcut testler ve /auth'un ayrı, daha sıkı bütçesi bozulmasın).
 * İki örnek aynı Redis sayaçlarını paylaşır — yalnız bellek-içi yedek ayrıdır.
 */
@Global()
@Module({
  providers: [RedisService, RateLimiterService],
  exports: [RedisService, RateLimiterService],
})
export class RedisModule {}

import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PremiumAccessService } from './application/premium-access.service';
import { PremiumSubscriptionService } from './application/premium-subscription.service';
import { APPLE_SUBSCRIPTION_GATEWAY } from './domain/apple.types';
import { PREMIUM_REPOSITORY } from './domain/premium.repository';
import { AppleAppStoreGateway } from './infrastructure/apple-appstore.gateway';
import { PrismaPremiumRepository } from './persistence/prisma-premium.repository';
import { PremiumController } from './presentation/premium.controller';

/**
 * Premium modülü (P1 karar katmanı + P2 Apple abonelik doğrulaması,
 * kurucu onayı 2026-09-21). AuthModule: /premium/me ve /premium/apple/link
 * JwtAuthGuard/AccountGuard kullanır. Apple yapılandırması yokken uçlar 503
 * döner (panelde anahtar tanımlanınca yeniden dağıtım GEREKMEDEN çalışır
 * denemez — env değişikliği Render'da yeni dağıtım başlatır, bu yeterlidir).
 */
@Module({
  imports: [AuthModule],
  controllers: [PremiumController],
  providers: [
    PremiumAccessService,
    PremiumSubscriptionService,
    { provide: PREMIUM_REPOSITORY, useClass: PrismaPremiumRepository },
    { provide: APPLE_SUBSCRIPTION_GATEWAY, useClass: AppleAppStoreGateway },
  ],
  exports: [PremiumAccessService],
})
export class PremiumModule {}

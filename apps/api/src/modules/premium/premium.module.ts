import { Module } from '@nestjs/common';
import { PremiumAccessService } from './application/premium-access.service';
import { PREMIUM_REPOSITORY } from './domain/premium.repository';
import { PrismaPremiumRepository } from './persistence/prisma-premium.repository';

/**
 * Premium erişim kararları (P1, kurucu onayı 2026-09-21). Satın alma/Apple
 * doğrulaması P2'de bu modüle eklenir; P1 yalnız KARAR katmanıdır (detay kilidi
 * + keşif hakkı). LocationsModule bu modülü içe alır.
 */
@Module({
  providers: [
    PremiumAccessService,
    { provide: PREMIUM_REPOSITORY, useClass: PrismaPremiumRepository },
  ],
  exports: [PremiumAccessService],
})
export class PremiumModule {}

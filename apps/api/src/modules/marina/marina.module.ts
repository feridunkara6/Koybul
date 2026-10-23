import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PremiumModule } from '../premium/premium.module';
import { MarinaService } from './application/marina.service';
import { MARINA_REPOSITORY } from './domain/marina.types';
import { PrismaMarinaRepository } from './persistence/prisma-marina.repository';
import { MarinaController } from './presentation/marina.controller';

/**
 * Marina Topluluğu modülü (V1 — kurucu onayı 2026-10-23).
 * PremiumModule: "başka marinayı gez" kilidi erişim kararını
 * PremiumAccessService'e sorar (vitrin/soru-cevap ile aynı tek kaynak).
 */
@Module({
  imports: [AuthModule, PremiumModule],
  controllers: [MarinaController],
  providers: [MarinaService, { provide: MARINA_REPOSITORY, useClass: PrismaMarinaRepository }],
})
export class MarinaModule {}

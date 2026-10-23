import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PremiumModule } from '../premium/premium.module';
import { QaService } from './application/qa.service';
import { QA_REPOSITORY } from './domain/qa.types';
import { PrismaQaRepository } from './persistence/prisma-qa.repository';
import { QaController } from './presentation/qa.controller';

/**
 * Soru-cevap modülü (Blog V1 — kurucu onayı 2026-10-23).
 * PremiumModule: detay/yazma kilidi erişim kararını PremiumAccessService'e
 * sorar (koy vitrin kilidiyle aynı tek-kaynak ilkesi).
 */
@Module({
  imports: [AuthModule, PremiumModule],
  controllers: [QaController],
  providers: [QaService, { provide: QA_REPOSITORY, useClass: PrismaQaRepository }],
})
export class QaModule {}

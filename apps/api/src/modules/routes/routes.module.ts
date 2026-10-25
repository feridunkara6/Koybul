import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PremiumModule } from '../premium/premium.module';
import { RoutesController } from './presentation/routes.controller';
import { RoutesService } from './application/routes.service';
import { ROUTES_REPOSITORY } from './domain/route.types';
import { PrismaRoutesRepository } from './persistence/prisma-routes.repository';

/** ROTA PAYLAŞIMI modülü (Sosyalleşme Hafta 3, kurucu onayı 2026-10-24). */
@Module({
  imports: [AuthModule, PremiumModule],
  controllers: [RoutesController],
  providers: [RoutesService, { provide: ROUTES_REPOSITORY, useClass: PrismaRoutesRepository }],
})
export class RoutesModule {}

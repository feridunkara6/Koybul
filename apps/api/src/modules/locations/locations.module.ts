import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PremiumModule } from '../premium/premium.module';
import { LocationsController } from './presentation/locations.controller';
import { LocationsService } from './application/locations.service';
import { LOCATIONS_REPOSITORY } from './domain/locations.repository';
import { PrismaLocationsRepository } from './persistence/prisma-locations.repository';

@Module({
  // AuthModule: doluluk bildirimi ucu JwtAuthGuard/AccountGuard kullanır (2026-07 ①).
  // PremiumModule: detay kilidi + keşif hakkı kararları (P1, 2026-09).
  imports: [AuthModule, PremiumModule],
  controllers: [LocationsController],
  providers: [
    LocationsService,
    { provide: LOCATIONS_REPOSITORY, useClass: PrismaLocationsRepository },
  ],
})
export class LocationsModule {}

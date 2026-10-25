import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { BoatsController, BoatsPublicController } from './presentation/boats.controller';
import { BoatsService } from './application/boats.service';
import { BOAT_REPOSITORY } from './domain/boat.repository';
import { PrismaBoatRepository } from './persistence/prisma-boat.repository';

@Module({
  imports: [AuthModule],
  // Tekne Kartı (Hafta 2): zırhlı CRUD + kimliksiz kart aynı modülde.
  controllers: [BoatsController, BoatsPublicController],
  providers: [BoatsService, { provide: BOAT_REPOSITORY, useClass: PrismaBoatRepository }],
})
export class BoatsModule {}

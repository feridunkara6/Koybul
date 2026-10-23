import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PremiumModule } from '../premium/premium.module';
import { EventsService } from './application/events.service';
import { EVENTS_REPOSITORY } from './domain/events.types';
import { PrismaEventsRepository } from './persistence/prisma-events.repository';
import { EventsAdminController, EventsController } from './presentation/events.controller';

/**
 * Etkinlikler & Fırsatlar modülü (V1 — kurucu onayı 2026-10-23).
 * PremiumModule: 'premium' kitle kilidi erişim kararını tek kaynaktan sorar.
 */
@Module({
  imports: [AuthModule, PremiumModule],
  controllers: [EventsController, EventsAdminController],
  providers: [EventsService, { provide: EVENTS_REPOSITORY, useClass: PrismaEventsRepository }],
})
export class EventsModule {}

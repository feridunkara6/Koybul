import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { TripsController } from './presentation/trips.controller';
import { FeedController } from './presentation/feed.controller';
import { TripsService } from './application/trips.service';
import { FeedService } from './application/feed.service';
import { TRIPS_REPOSITORY } from './domain/trip.types';
import { FEED_REPOSITORY } from './domain/feed.types';
import { PrismaTripsRepository } from './persistence/prisma-trips.repository';
import { PrismaFeedRepository } from './persistence/prisma-feed.repository';

/**
 * SEYİR PAYLAŞIMI + TAKİP AKIŞI modülü (SP-3b, kurucu onayı 2026-10-31).
 * Akış burada yaşar çünkü tek yeni veri kaynağı paylaşılan seyirlerdir;
 * not/rota zaten kendi modüllerinde doğar, akış onları yalnız OKUR.
 */
@Module({
  imports: [AuthModule],
  controllers: [TripsController, FeedController],
  providers: [
    TripsService,
    FeedService,
    { provide: TRIPS_REPOSITORY, useClass: PrismaTripsRepository },
    { provide: FEED_REPOSITORY, useClass: PrismaFeedRepository },
  ],
})
export class TripsModule {}

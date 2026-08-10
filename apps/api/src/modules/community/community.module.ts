import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { NotesService } from './application/notes.service';
import { ReviewsService } from './application/reviews.service';
import { ReportsService } from './application/reports.service';
import { ModerationService } from './application/moderation.service';
import { ReputationService } from './application/reputation.service';
import { NOTES_REPOSITORY } from './domain/notes.repository';
import { REPUTATION_REPOSITORY } from './domain/reputation.repository';
import { MODERATION_REPOSITORY } from './domain/moderation.types';
import { REVIEWS_WRITE_REPOSITORY } from './domain/reviews.repository';
import { REPORTS_REPOSITORY } from './domain/reports.repository';
import { PrismaNotesRepository } from './persistence/prisma-notes.repository';
import { PrismaReputationRepository } from './persistence/prisma-reputation.repository';
import { PrismaModerationRepository } from './persistence/prisma-moderation.repository';
import { PrismaReviewsWriteRepository } from './persistence/prisma-reviews-write.repository';
import { PrismaReportsRepository } from './persistence/prisma-reports.repository';
import { NotesController } from './presentation/notes.controller';
import { ReviewsController } from './presentation/reviews.controller';
import { ReportsController } from './presentation/reports.controller';
import { ModerationController } from './presentation/moderation.controller';
import { ReputationController } from './presentation/reputation.controller';

/** Topluluk modülü — Kaptan Notları, yorum yazma, şikâyet, moderasyon, itibar. */
@Module({
  imports: [AuthModule],
  controllers: [
    NotesController,
    ReviewsController,
    ReportsController,
    ModerationController,
    ReputationController,
  ],
  providers: [
    NotesService,
    ReviewsService,
    ReportsService,
    ModerationService,
    ReputationService,
    { provide: NOTES_REPOSITORY, useClass: PrismaNotesRepository },
    { provide: REPUTATION_REPOSITORY, useClass: PrismaReputationRepository },
    { provide: MODERATION_REPOSITORY, useClass: PrismaModerationRepository },
    { provide: REVIEWS_WRITE_REPOSITORY, useClass: PrismaReviewsWriteRepository },
    { provide: REPORTS_REPOSITORY, useClass: PrismaReportsRepository },
  ],
})
export class CommunityModule {}

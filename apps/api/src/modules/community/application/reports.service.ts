import { Inject, Injectable, Logger } from '@nestjs/common';
import { AppProblem } from '../../../common/problem/problem';
import { Principal } from '../../../core/auth/principal';
import { AUTO_HIDE_REPORT_THRESHOLD } from '../domain/note.types';
import {
  CreateReportInput,
  REPORTS_REPOSITORY,
  ReportsRepository,
} from '../domain/reports.repository';
import { ReputationService } from './reputation.service';

@Injectable()
export class ReportsService {
  private readonly logger = new Logger(ReportsService.name);

  constructor(
    @Inject(REPORTS_REPOSITORY) private readonly reports: ReportsRepository,
    private readonly reputation: ReputationService,
  ) {}

  async create(
    principal: Principal,
    idOrSlug: string,
    input: CreateReportInput,
  ): Promise<{ id: string; autoHidden: boolean }> {
    const state = await this.reputation.authorState(principal.userId);
    this.reputation.assertCanWrite(state);

    const locationId = await this.reports.publishedLocationId(idOrSlug);
    if (!locationId) throw new AppProblem('not-found');

    // 24 saat içinde aynı sebeple mükerrer bildirim (07 S-23 anti-abuse kuralı).
    if (await this.reports.hasRecentDuplicate(principal.userId, locationId, input.reason)) {
      throw new AppProblem('duplicate-request', 'Bildirimin zaten incelemede.');
    }

    const created = await this.reports.create(principal.userId, locationId, input);

    // İçerik şikâyeti eşiği: 3 farklı kullanıcı → içerik yayından kalkar ve
    // kuyruğa döner (docs/12 §8.2). Tek kişi içerik kaldıramaz.
    let autoHidden = false;
    if (input.targetType && input.targetId) {
      autoHidden = await this.reports.autoHideIfFlooded(
        input.targetType,
        input.targetId,
        AUTO_HIDE_REPORT_THRESHOLD,
      );
      if (autoHidden) {
        this.logger.warn(
          { event: 'content_auto_hidden', targetType: input.targetType, targetId: input.targetId },
          'İçerik şikâyet eşiğiyle yeniden incelemeye alındı',
        );
      }
    }
    return { id: created.id, autoHidden };
  }
}

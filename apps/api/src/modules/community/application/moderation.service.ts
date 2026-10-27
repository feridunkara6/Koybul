import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { AppProblem } from '../../../common/problem/problem';
import { Principal } from '../../../core/auth/principal';
import { NotificationsService } from '../../notifications/application/notifications.service';
import {
  MODERATION_REPOSITORY,
  ModerationDecision,
  ModerationItem,
  ModerationRepository,
} from '../domain/moderation.types';
import { NoteKind, notePoints, reviewPoints } from '../domain/scoring';
import { ReputationService } from './reputation.service';

@Injectable()
export class ModerationService {
  private readonly logger = new Logger(ModerationService.name);

  constructor(
    @Inject(MODERATION_REPOSITORY) private readonly repo: ModerationRepository,
    private readonly reputation: ReputationService,
    /** Push tetikleri (ateşle-unut) — birim testleri vermez, yol atlanır. */
    @Optional() private readonly notifications?: NotificationsService,
  ) {}

  queue(entityType: string | undefined, limit: number): Promise<ModerationItem[]> {
    return this.repo.queue(entityType, limit);
  }

  counts(): Promise<Record<string, number>> {
    return this.repo.counts();
  }

  /**
   * Karar ver. Sıra: (1) içerik durumu + görev + denetim kaydı tek transaction,
   * (2) puan/ceza, (3) güven katsayısı tazeleme. 2 ve 3 patlarsa karar geçerli
   * kalır — moderasyon iş akışı puanlamaya bağımlı olamaz.
   */
  async decide(
    principal: Principal,
    taskId: string,
    decision: ModerationDecision,
    reason: string | null,
  ): Promise<{ entityId: string; decision: ModerationDecision; pointsAwarded: number }> {
    const res = await this.repo.decide(taskId, principal.userId, decision, reason);
    if (!res) throw new AppProblem('not-found');

    this.logger.log(
      { event: 'moderation_decision', taskId, decision, entityType: res.entityType },
      'Moderasyon kararı',
    );

    // Push paketi ②/①: rota kararı sahibine her iki yönde bildirilir; kuyruktan
    // ONAYLANAN cevap soru sahibine ancak şimdi gider (yazarken gitmemişti).
    if (res.entityType === 'route') {
      this.notifications?.routeDecision(res.entityId, decision === 'approve');
    } else if (res.entityType === 'qa_answer' && decision === 'approve') {
      this.notifications?.qaAnswerModerated(res.entityId);
    }

    // Sahip çözülemediyse (henüz bağlanmamış varlık tipi) puan/ceza yazılmaz.
    if (!res.ownerUserId) {
      return { entityId: res.entityId, decision, pointsAwarded: 0 };
    }

    let pointsAwarded = 0;
    if (decision === 'approve') {
      const base = this.basePointsFor(res.entityType, res.noteKind, res.bodyLength);
      const action = res.entityType === 'review' ? 'review_created' : 'note_approved';
      pointsAwarded = await this.reputation.award(res.ownerUserId, action, base, {
        type: res.entityType,
        id: res.entityId,
      });
    } else {
      // Ceza güven katsayısıyla çarpılmaz: kötü davranış düşük güvenli
      // kullanıcıda ucuzlamamalı (scoring.awardablePoints negatif tabanı geçirir).
      pointsAwarded = await this.reputation.award(res.ownerUserId, 'content_rejected', -10, {
        type: res.entityType,
        id: res.entityId,
      });
    }

    await this.reputation.refreshTrust(res.ownerUserId);
    return { entityId: res.entityId, decision, pointsAwarded };
  }

  private basePointsFor(entityType: string, noteKind: string | null, bodyLength: number): number {
    if (entityType === 'review') return reviewPoints(bodyLength);
    if (entityType === 'media') return 10;
    if (entityType === 'suggested_location') return 40;
    if (entityType === 'note' && noteKind) return notePoints(noteKind as NoteKind);
    return 0;
  }
}

import { Inject, Injectable, Logger } from '@nestjs/common';
import { AppProblem } from '../../../common/problem/problem';
import {
  AuthorState,
  ContributionItem,
  REPUTATION_REPOSITORY,
  ReputationRepository,
  ReputationSummary,
} from '../domain/reputation.repository';
import {
  ContributionAction,
  HELPFUL_POINTS_PER_CONTENT_CAP,
  awardablePoints,
  isWriteRestricted,
} from '../domain/scoring';

/**
 * Puan yazımının tek kapısı. Hiçbir controller doğrudan puan yazamaz; her yol
 * buradan geçer ki tavanlar ve güven katsayısı tek yerde uygulansın.
 *
 * Puan yazımı ASLA ana işlemi düşürmez: katkı kaydedildiyse kullanıcı için iş
 * bitmiştir. Puan hesabı patlarsa loglanır ve akış devam eder (0 puanla).
 */
@Injectable()
export class ReputationService {
  private readonly logger = new Logger(ReputationService.name);

  constructor(@Inject(REPUTATION_REPOSITORY) private readonly repo: ReputationRepository) {}

  async authorState(userId: string): Promise<AuthorState> {
    return this.repo.authorState(userId);
  }

  /** Yazma kısıtı altındaki kullanıcı içerik üretemez (docs/12 §8.2). */
  assertCanWrite(state: AuthorState, now: Date = new Date()): void {
    if (isWriteRestricted(state.writeRestrictedUntil, now)) {
      throw new AppProblem(
        'forbidden',
        'İçerik üretimi geçici olarak kısıtlı. Kısıt kalkınca tekrar paylaşabilirsin.',
      );
    }
  }

  /**
   * Katkıyı puanlar. `base` çağıran tarafından hesaplanır (nota/yoruma göre
   * değişir); tavanlar ve güven çarpanı burada uygulanır.
   * Dönen değer GERÇEKTEN yazılan puandır (0 olabilir).
   */
  async award(
    userId: string,
    action: ContributionAction,
    base: number,
    entity: { type: string; id: string } | null,
    opts: { freshness?: number } = {},
  ): Promise<number> {
    try {
      // "Faydalı" oyu: tek içeriğin ömür boyu tavanı ayrıca kontrol edilir.
      if (action === 'helpful_received' && entity) {
        const earned = await this.repo.helpfulPointsForEntity(entity.id);
        if (earned >= HELPFUL_POINTS_PER_CONTENT_CAP) return 0;
      }

      // YAYIN ÖDÜLÜ İÇERİK BAŞINA TEK KEZ. Düzenlenen içerik yeniden incelemeye
      // düşüyor; ikinci onay aynı içerik için tekrar puan yazmamalı — yoksa
      // "düzenle → onaylat" döngüsü puan çiftliğine dönerdi (bulgu 2026-08).
      if (entity && (action === 'note_approved' || action === 'review_created')) {
        if (await this.repo.hasAwardedFor(entity.id, action)) return 0;
      }

      const w = await this.repo.awardWindow(userId, action);
      const points = awardablePoints(action, {
        base,
        trust: w.trustScore,
        todayEventsOfAction: w.todayEventsOfAction,
        todayPoints: w.todayPoints,
        weekPoints: w.weekPoints,
        freshness: opts.freshness,
      });
      if (points === 0) return 0;

      const res = await this.repo.award(userId, action, points, entity);
      if (res.leveledUp) {
        this.logger.log({ event: 'level_up', userId, level: res.levelCode }, 'Denizci seviyesi');
      }
      return points;
    } catch (err) {
      // Puan, katkının kendisinden daha az önemlidir — akışı düşürmez.
      // Ama SESSİZ KALMAZ: bozuk SQL burada gizlenirse aylarca fark edilmez.
      this.logger.error(
        { event: 'server_error', scope: 'reputation_award', userId, action, err: String(err) },
        'Puan yazılamadı',
      );
      return 0;
    }
  }

  /** Moderasyon kararından sonra güven katsayısını tazeler. */
  async refreshTrust(userId: string): Promise<void> {
    try {
      await this.repo.recomputeTrust(userId);
    } catch (err) {
      this.logger.warn({ err: String(err), userId }, 'Güven katsayısı güncellenemedi');
    }
  }

  summary(userId: string): Promise<ReputationSummary> {
    return this.repo.summary(userId);
  }

  contributions(userId: string, limit: number): Promise<ContributionItem[]> {
    return this.repo.contributions(userId, limit);
  }
}

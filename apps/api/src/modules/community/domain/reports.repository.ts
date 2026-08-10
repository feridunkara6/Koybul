export type ReportReason =
  | 'wrong_info'
  | 'closed_permanently'
  | 'wrong_photo'
  | 'wrong_position'
  | 'duplicate'
  | 'abuse'
  | 'other';

export interface CreateReportInput {
  reason: ReportReason;
  message?: string | null;
  /** İçerik şikâyeti ise hedef: not/yorum kimliği. */
  targetType?: 'note' | 'review' | null;
  targetId?: string | null;
}

export interface ReportsRepository {
  publishedLocationId(idOrSlug: string): Promise<string | null>;
  /** 24 saat içinde aynı kullanıcıdan aynı hedefe mükerrer bildirim var mı. */
  hasRecentDuplicate(userId: string, locationId: string, reason: string): Promise<boolean>;
  create(userId: string, locationId: string, input: CreateReportInput): Promise<{ id: string }>;
  /**
   * Bir içeriğe gelen farklı kullanıcı sayısı eşiği aşarsa içeriği yeniden
   * incelemeye çeker (docs/12 §8.2). Çekildiyse true döner.
   */
  autoHideIfFlooded(
    targetType: 'note' | 'review',
    targetId: string,
    threshold: number,
  ): Promise<boolean>;
}

export const REPORTS_REPOSITORY = Symbol('REPORTS_REPOSITORY');

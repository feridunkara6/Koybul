import { BadgeProgress, BadgeStats, EarnedBadge } from './badges';
import { ContributionAction, LevelCode } from './scoring';

/** Puan yazımı için gereken sayaçlar — tek sorguda toplanır. */
export interface AwardWindow {
  todayPoints: number;
  weekPoints: number;
  todayEventsOfAction: number;
  trustScore: number;
}

export interface ReputationSummary {
  points: number;
  levelCode: LevelCode;
  pointsToNext: number | null;
  trustScore: number;
  approvedCount: number;
  pendingCount: number;
  rejectedCount: number;
  helpfulReceived: number;
  writeRestrictedUntil: string | null;
  badges: { code: string; scopeId: string | null; awardedAt: string }[];
  /** Bölgesel uzmanlık: en çok katkı verilen ilk 3 idari bölge. */
  areas: { adminAreaId: string; name: string; count: number }[];
  /** Rozet ekranının tamamı: kazanılanlar + kazanılmayanların ilerlemesi. */
  badgeProgress: BadgeProgress[];
}

/** Yazma öncesi bakılan asgari yazar durumu. */
export interface AuthorState {
  trustScore: number;
  approvedCount: number;
  writeRestrictedUntil: Date | null;
}

export interface ContributionItem {
  id: string;
  type: string;
  entityType: string | null;
  entityId: string | null;
  points: number;
  createdAt: string;
}

export interface ReputationRepository {
  /** Puan yazımı öncesi pencere sayaçları + güven katsayısı. */
  awardWindow(userId: string, action: ContributionAction): Promise<AwardWindow>;
  /**
   * Katkı olayını yazar ve özeti günceller — TEK transaction.
   * `contribution_events` append-only; `user_reputation` türetilmiş özettir.
   */
  award(
    userId: string,
    action: ContributionAction,
    points: number,
    entity: { type: string; id: string } | null,
  ): Promise<{ points: number; levelCode: LevelCode; leveledUp: boolean }>;
  /** Bir içeriğin ömrü boyunca "faydalı"dan kazandırdığı toplam puan. */
  helpfulPointsForEntity(entityId: string): Promise<number>;
  /** Bu içerik için bu tipte POZİTİF puan daha önce yazıldı mı (tekrar ödülü engeller). */
  hasAwardedFor(entityId: string, action: ContributionAction): Promise<boolean>;
  summary(userId: string): Promise<ReputationSummary>;
  contributions(userId: string, limit: number): Promise<ContributionItem[]>;
  /** Güven katsayısını yeniden hesaplar ve yazar (moderasyon kararından sonra). */
  recomputeTrust(userId: string): Promise<number>;
  /** Rozet sayaçları (saf değerlendirme `badges.ts`'te yapılır). */
  badgeStats(userId: string): Promise<BadgeStats>;
  /**
   * Hak edilen rozetleri yazar; zaten varsa hiçbir şey yapmaz.
   * ALTYAPI YOLU: rozeti SİSTEM verir, kullanıcı değil (0008 RLS notu).
   * Dönen liste YENİ verilenlerdir (bildirim/kutlama için).
   */
  grantBadges(userId: string, badges: EarnedBadge[]): Promise<EarnedBadge[]>;
  /**
   * Yazma ucunun ilk adımı: kısıt + otomatik yayın kararı için gereken
   * asgari durum. Tam özet (summary) yerine bu kullanılır — daha ucuz.
   */
  authorState(userId: string): Promise<AuthorState>;
}

export const REPUTATION_REPOSITORY = Symbol('REPUTATION_REPOSITORY');

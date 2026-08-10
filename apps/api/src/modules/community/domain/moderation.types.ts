/** Moderasyon kuyruğunda görünen tek öğe. */
export interface ModerationItem {
  taskId: string;
  entityType: 'note' | 'review' | 'media' | 'suggested_location' | 'location_report';
  entityId: string;
  createdAt: string;
  /** Karar verirken gereken bağlam — moderatör içeriği görmeden karar veremez. */
  preview: {
    kind: string | null;
    title: string | null;
    body: string | null;
    locationName: string | null;
    observedOn: string | null;
    gpsVerified: boolean | null;
  };
  author: {
    userId: string;
    displayName: string;
    levelCode: string;
    approvedCount: number;
    rejectedCount: number;
  };
}

export type ModerationDecision = 'approve' | 'reject';

/** Reddetme sebepleri — kullanıcıya kibar bir metin olarak gösterilir. */
export const REJECT_REASONS = [
  'off_topic',
  'not_verifiable',
  'duplicate',
  'personal_data',
  'offensive',
  'wrong_location',
  'other',
] as const;
export type RejectReason = (typeof REJECT_REASONS)[number];

export interface DecisionResult {
  entityType: string;
  entityId: string;
  /** null = sahip çözülemedi (henüz bağlanmamış varlık tipi) → puan yazılmaz. */
  ownerUserId: string | null;
  decision: ModerationDecision;
  /** Onaylanan içeriğin türü/uzunluğu — puan hesabı buna göre yapılır. */
  noteKind: string | null;
  bodyLength: number;
}

export interface ModerationRepository {
  queue(entityType: string | undefined, limit: number): Promise<ModerationItem[]>;
  counts(): Promise<Record<string, number>>;
  /**
   * Kararı TEK transaction'da uygular: moderation_tasks + içeriğin status'ü +
   * audit_logs. Puan yazımı servis katmanında, karardan SONRA yapılır.
   * ALTYAPI YOLU: withUserContext KULLANILMAZ — moderatör başkasının satırını
   * günceller ve RLS sahiplik politikası onu süzerdi (0008 migration notu).
   */
  decide(
    taskId: string,
    moderatorUserId: string,
    decision: ModerationDecision,
    reason: string | null,
  ): Promise<DecisionResult | null>;
}

export const MODERATION_REPOSITORY = Symbol('MODERATION_REPOSITORY');

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import {
  AuthorState,
  AwardWindow,
  ContributionItem,
  ReputationRepository,
  ReputationSummary,
} from '../domain/reputation.repository';
import { BadgeStats, EarnedBadge, WINTER_MONTHS, badgeProgress } from '../domain/badges';
import {
  ContributionAction,
  LevelCode,
  RESTRICTION_DAYS,
  VIOLATIONS_FOR_RESTRICTION,
  computeTrustScore,
  levelForPoints,
  pointsToNextLevel,
} from '../domain/scoring';

/** ALTYAPI YOLU: itibar satırını SİSTEM yazar, kullanıcı değil (RLS notu, 0008). */
@Injectable()
export class PrismaReputationRepository implements ReputationRepository {
  constructor(private readonly prisma: PrismaService) {}

  async authorState(userId: string): Promise<AuthorState> {
    const rows = await this.prisma.$queryRaw<
      { trustScore: string | null; approvedCount: number | null; restrictedUntil: Date | null }[]
    >(Prisma.sql`
      SELECT r.trust_score AS "trustScore", r.approved_count AS "approvedCount",
             r.write_restricted_until AS "restrictedUntil"
      FROM users u LEFT JOIN user_reputation r ON r.user_id = u.id
      WHERE u.id = ${userId}::uuid
    `);
    const row = rows[0];
    return {
      trustScore: row?.trustScore != null ? Number(row.trustScore) : 1,
      approvedCount: Number(row?.approvedCount ?? 0),
      writeRestrictedUntil: row?.restrictedUntil ?? null,
    };
  }

  async awardWindow(userId: string, action: ContributionAction): Promise<AwardWindow> {
    const rows = await this.prisma.$queryRaw<
      { todayPoints: number; weekPoints: number; todayEvents: number; trustScore: string | null }[]
    >(Prisma.sql`
      SELECT
        COALESCE(SUM(c.points) FILTER (WHERE c.created_at >= now() - interval '1 day'), 0)::int
          AS "todayPoints",
        COALESCE(SUM(c.points) FILTER (WHERE c.created_at >= now() - interval '7 days'), 0)::int
          AS "weekPoints",
        COUNT(*) FILTER (
          WHERE c.created_at >= now() - interval '1 day'
            AND c.type = ${action}::contribution_type AND c.points > 0
        )::int AS "todayEvents",
        (SELECT trust_score FROM user_reputation WHERE user_id = ${userId}::uuid) AS "trustScore"
      FROM contribution_events c
      WHERE c.user_id = ${userId}::uuid AND c.created_at >= now() - interval '7 days'
    `);
    const r = rows[0];
    return {
      todayPoints: Number(r?.todayPoints ?? 0),
      weekPoints: Number(r?.weekPoints ?? 0),
      todayEventsOfAction: Number(r?.todayEvents ?? 0),
      trustScore: r?.trustScore != null ? Number(r.trustScore) : 1,
    };
  }

  async award(
    userId: string,
    action: ContributionAction,
    points: number,
    entity: { type: string; id: string } | null,
  ): Promise<{ points: number; levelCode: LevelCode; leveledUp: boolean }> {
    return this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw(Prisma.sql`
        INSERT INTO contribution_events (user_id, type, entity_type, entity_id, points)
        VALUES (${userId}::uuid, ${action}::contribution_type,
                ${entity?.type ?? null}, ${entity?.id ?? null}::uuid, ${points})
      `);
      const before = await tx.$queryRaw<{ points: number }[]>(Prisma.sql`
        SELECT COALESCE(points, 0)::int AS points FROM user_reputation
        WHERE user_id = ${userId}::uuid
      `);
      const oldPoints = Number(before[0]?.points ?? 0);
      // Toplama VERİTABANINDA yapılır (GREATEST(0, points + delta)): iki eşzamanlı
      // ödül JS'te hesaplanıp mutlak değer yazılsaydı biri kaybolurdu.
      const rows = await tx.$queryRaw<{ points: number }[]>(Prisma.sql`
        INSERT INTO user_reputation (user_id, points, level_code, last_recalc_at)
        VALUES (${userId}::uuid, GREATEST(0, ${points}), 'new', now())
        ON CONFLICT (user_id) DO UPDATE
          SET points = GREATEST(0, user_reputation.points + ${points}),
              last_recalc_at = now(), updated_at = now()
        RETURNING points
      `);
      const newPoints = Number(rows[0]?.points ?? Math.max(0, oldPoints + points));
      const level = levelForPoints(newPoints);
      await tx.$executeRaw(Prisma.sql`
        UPDATE user_reputation SET level_code = ${level}, updated_at = now()
        WHERE user_id = ${userId}::uuid AND level_code <> ${level}
      `);
      return {
        points: newPoints,
        levelCode: level,
        leveledUp: level !== levelForPoints(oldPoints),
      };
    });
  }

  async hasAwardedFor(entityId: string, action: ContributionAction): Promise<boolean> {
    const rows = await this.prisma.$queryRaw<{ n: number }[]>(Prisma.sql`
      SELECT count(*)::int AS n FROM contribution_events
      WHERE entity_id = ${entityId}::uuid
        AND type = ${action}::contribution_type AND points > 0
    `);
    return Number(rows[0]?.n ?? 0) > 0;
  }

  async helpfulPointsForEntity(entityId: string): Promise<number> {
    const rows = await this.prisma.$queryRaw<{ total: number }[]>(Prisma.sql`
      SELECT COALESCE(SUM(points), 0)::int AS total FROM contribution_events
      WHERE entity_id = ${entityId}::uuid AND type = 'helpful_received'::contribution_type
    `);
    return Number(rows[0]?.total ?? 0);
  }

  async summary(userId: string): Promise<ReputationSummary> {
    const [rep] = await this.prisma.$queryRaw<
      {
        points: number;
        levelCode: string;
        trustScore: string;
        approvedCount: number;
        rejectedCount: number;
        helpfulReceived: number;
        restrictedUntil: Date | null;
      }[]
    >(Prisma.sql`
      SELECT COALESCE(points,0)::int AS points, COALESCE(level_code,'new') AS "levelCode",
             COALESCE(trust_score,1.00) AS "trustScore",
             COALESCE(approved_count,0)::int AS "approvedCount",
             COALESCE(rejected_count,0)::int AS "rejectedCount",
             COALESCE(helpful_received,0)::int AS "helpfulReceived",
             write_restricted_until AS "restrictedUntil"
      FROM user_reputation WHERE user_id = ${userId}::uuid
    `);

    // Ad, not kartlarındaki yazar adıyla AYNI kaynaktan gelir (user_profiles).
    // BURADA VARSAYILAN AD KOYULMAZ: profil satırı henüz yoksa boş döner ve
    // istemci kendi dilindeki başlığa düşer. Sunucu Türkçe bir yer tutucu
    // gönderseydi İngilizce uygulamada da o metin görünür, avatar da olmayan
    // bir addan baş harf uydururdu (inceleme bulgusu 2026-08).
    const [profile] = await this.prisma.$queryRaw<{ displayName: string | null }[]>(Prisma.sql`
      SELECT display_name AS "displayName" FROM user_profiles WHERE user_id = ${userId}::uuid
    `);

    const [pending] = await this.prisma.$queryRaw<{ n: number }[]>(Prisma.sql`
      SELECT (
        (SELECT count(*) FROM location_notes
          WHERE user_id = ${userId}::uuid AND status = 'pending' AND deleted_at IS NULL)
        + (SELECT count(*) FROM reviews
            WHERE user_id = ${userId}::uuid AND status = 'pending' AND deleted_at IS NULL)
      )::int AS n
    `);

    const badges = await this.prisma.$queryRaw<
      { code: string; scopeId: string | null; awardedAt: Date }[]
    >(Prisma.sql`
      SELECT badge_code AS code, scope_id AS "scopeId", awarded_at AS "awardedAt"
      FROM user_badges WHERE user_id = ${userId}::uuid AND revoked_at IS NULL
      ORDER BY awarded_at DESC
    `);

    // Bölgesel uzmanlık: onaylı NOTLARIN bağlı olduğu ilçe/il bazında sayım.
    // Rozet ilerlemesi de aynı sayımı kullanır — iki yerde iki farklı sayı
    // görünmesin diye TEK sorgudan beslenir.
    const stats = await this.badgeStats(userId);
    const areas = stats.areaApproved.slice(0, 3);

    const held = badges.map((b) => ({
      code: b.code,
      scopeId: b.scopeId,
      awardedAt: b.awardedAt.toISOString(),
    }));

    const points = Number(rep?.points ?? 0);
    return {
      displayName: profile?.displayName ?? '',
      points,
      levelCode: (rep?.levelCode ?? 'new') as LevelCode,
      pointsToNext: pointsToNextLevel(points),
      trustScore: rep?.trustScore != null ? Number(rep.trustScore) : 1,
      approvedCount: Number(rep?.approvedCount ?? 0),
      pendingCount: Number(pending?.n ?? 0),
      rejectedCount: Number(rep?.rejectedCount ?? 0),
      helpfulReceived: Number(rep?.helpfulReceived ?? 0),
      writeRestrictedUntil: rep?.restrictedUntil ? rep.restrictedUntil.toISOString() : null,
      badges: held,
      areas,
      badgeProgress: badgeProgress(stats, held),
    };
  }

  /**
   * Rozet sayaçları — üç bağımsız sorgu, PARALEL koşar. Karar `badges.ts`'te
   * verilir; burada yalnız ham sayı toplanır (SQL'de iş kuralı tutulmaz).
   */
  async badgeStats(userId: string): Promise<BadgeStats> {
    const [areas, one, winter, regions] = await Promise.all([
      this.approvedByArea(userId),

      // "Fener": TEK bir içeriğin aldığı en yüksek "faydalı" oyu.
      // status = 'approved' ŞART: reddedilen içerik rozet kazandırmamalı —
      // aksi halde bir moderasyon REDDİ, kararın hemen ardından koşan
      // syncBadges yüzünden rozetin sebebi olurdu (inceleme bulgusu).
      this.prisma.$queryRaw<{ maxHelpful: number; hazards: number }[]>(
        Prisma.sql`
        SELECT
          GREATEST(
            COALESCE((SELECT MAX(helpful_count) FROM location_notes
                       WHERE user_id = ${userId}::uuid
                         AND status = 'approved' AND deleted_at IS NULL), 0),
            COALESCE((SELECT MAX(helpful_count) FROM reviews
                       WHERE user_id = ${userId}::uuid
                         AND status = 'approved' AND deleted_at IS NULL), 0)
          )::int AS "maxHelpful",
          (SELECT count(*) FROM location_notes
            WHERE user_id = ${userId}::uuid AND kind = 'hazard'::note_kind
              AND status = 'approved' AND deleted_at IS NULL AND confirm_count > 0)::int
            AS hazards
      `,
      ),

      // "Kış Denizcisi": Kasım–Mart arasında ÜRETİLEN katkı.
      // - Ay, Türkiye saatine göre hesaplanır: timestamptz'ın UTC ayı 1 Kasım
      //   00:30'da hâlâ Ekim'dir (sınırda kayma).
      // - `helpful_received` SAYILMAZ: o satırı BAŞKASININ oyu doğurur;
      //   kışın oy alan yaz katkısı "kış denizciliği" değildir.
      // - Her ay parametresi AÇIKÇA int'e çevrilir: çıplak parametrenin tipini
      //   PostgreSQL bazı bağlamlarda çözemiyor ("could not determine data type").
      this.prisma.$queryRaw<{ n: number }[]>(Prisma.sql`
        SELECT count(*)::int AS n FROM contribution_events
        WHERE user_id = ${userId}::uuid AND points > 0
          AND type IN ('note_approved'::contribution_type,
                       'occupancy_reported'::contribution_type,
                       'hazard_confirmed'::contribution_type,
                       'review_created'::contribution_type,
                       'photo_approved'::contribution_type,
                       'suggestion_approved'::contribution_type,
                       'trip_shared'::contribution_type)
          AND EXTRACT(MONTH FROM created_at AT TIME ZONE 'Europe/Istanbul')::int
              IN (${Prisma.join(WINTER_MONTHS.map((m) => Prisma.sql`${m}::int`))})
      `),

      // "Gezgin": kaç FARKLI bölgede katkı var. `approvedByArea`'nın uzunluğu
      // KULLANILAMAZ — o sorgu LIMIT'lidir ve seyir notlarını (location_id
      // NULL, yalnız from/to dolu) dışarıda bırakırdı.
      this.prisma.$queryRaw<{ n: number }[]>(Prisma.sql`
        SELECT count(DISTINCT l.admin_area_id)::int AS n
        FROM location_notes n
        JOIN locations l ON l.id = COALESCE(n.location_id, n.from_location_id)
        WHERE n.user_id = ${userId}::uuid AND n.status = 'approved'
          AND n.deleted_at IS NULL AND l.admin_area_id IS NOT NULL
      `),
    ]);

    return {
      areaApproved: areas,
      maxHelpfulOnOneNote: Number(one[0]?.maxHelpful ?? 0),
      confirmedHazards: Number(one[0]?.hazards ?? 0),
      winterContributions: Number(winter[0]?.n ?? 0),
      distinctRegions: Number(regions[0]?.n ?? 0),
    };
  }

  async grantBadges(userId: string, badges: EarnedBadge[]): Promise<EarnedBadge[]> {
    const granted: EarnedBadge[] = [];
    for (const b of badges) {
      // Kapsamlı/kapsamsız iki AYRI kısmi tekil indeks var; ON CONFLICT bir
      // indeks (ya da eşleşen kısmi koşul) ister. "Yoksa ekle" bu yüzden
      // NOT EXISTS ile yazılır.
      //
      // DİKKAT: kontrol `revoked_at`'e BAKMAZ. İndeksler de bakmıyor — geri
      // alınmış satır indeks yerini tutmaya devam eder. Kontrole
      // `revoked_at IS NULL` eklenirse geri alınan her rozet, bir sonraki
      // eşitlemede 23505 (duplicate key) üretir ve o kullanıcının SONRAKİ
      // bütün rozetleri sessizce yazılamaz olurdu (inceleme bulgusu).
      // Yani: geri alınan rozet geri alınmış KALIR — zaten istenen budur.
      const n = await this.prisma.$executeRaw(Prisma.sql`
        INSERT INTO user_badges (user_id, badge_code, scope_type, scope_id)
        SELECT ${userId}::uuid, ${b.code}::text, ${b.scopeType}::text, ${b.scopeId}::uuid
        WHERE NOT EXISTS (
          SELECT 1 FROM user_badges
          WHERE user_id = ${userId}::uuid AND badge_code = ${b.code}::text
            AND scope_id IS NOT DISTINCT FROM ${b.scopeId}::uuid
        )
      `);
      if (Number(n) > 0) granted.push(b);
    }
    return granted;
  }

  /**
   * Bölge bazında onaylı katkı sayısı — hem özet hem rozet bunu kullanır.
   * Seyir notunda `location_id` NULL'dur (0008 ck_location_notes_target):
   * bu yüzden başlangıç noktası üzerinden bağlanır, yoksa çok gezen kaptan
   * hiçbir bölgede görünmezdi.
   */
  private approvedByArea(
    userId: string,
    limit = 50,
  ): Promise<{ adminAreaId: string; name: string; count: number }[]> {
    return this.prisma
      .$queryRaw<{ adminAreaId: string; name: string; count: number }[]>(
        Prisma.sql`
        SELECT a.id AS "adminAreaId",
               COALESCE(i.name, a.name, a.slug) AS name,
               count(*)::int AS count
        FROM location_notes n
        JOIN locations l ON l.id = COALESCE(n.location_id, n.from_location_id)
        JOIN admin_areas a ON a.id = l.admin_area_id
        LEFT JOIN admin_area_i18n i ON i.admin_area_id = a.id AND i.locale = 'tr'
        WHERE n.user_id = ${userId}::uuid AND n.status = 'approved' AND n.deleted_at IS NULL
        GROUP BY a.id, i.name, a.name, a.slug
        ORDER BY count DESC
        LIMIT ${limit}
      `,
      )
      .then((rows) => rows.map((a) => ({ ...a, count: Number(a.count) })));
  }

  async contributions(userId: string, limit: number): Promise<ContributionItem[]> {
    const rows = await this.prisma.$queryRaw<
      {
        id: bigint;
        type: string;
        entityType: string | null;
        entityId: string | null;
        points: number;
        createdAt: Date;
      }[]
    >(Prisma.sql`
      SELECT id, type::text AS type, entity_type AS "entityType", entity_id AS "entityId",
             points, created_at AS "createdAt"
      FROM contribution_events WHERE user_id = ${userId}::uuid
      ORDER BY created_at DESC LIMIT ${limit}
    `);
    return rows.map((r) => ({
      id: String(r.id),
      type: r.type,
      entityType: r.entityType,
      entityId: r.entityId,
      points: Number(r.points),
      createdAt: r.createdAt.toISOString(),
    }));
  }

  async recomputeTrust(userId: string): Promise<number> {
    const [s] = await this.prisma.$queryRaw<
      {
        ageDays: number;
        approved: number;
        rejected: number;
        helpful: number;
        reports: number;
      }[]
    >(Prisma.sql`
      SELECT
        EXTRACT(EPOCH FROM (now() - u.created_at)) / 86400 AS "ageDays",
        (SELECT count(*) FROM location_notes WHERE user_id = u.id AND status = 'approved' AND deleted_at IS NULL)
        + (SELECT count(*) FROM reviews WHERE user_id = u.id AND status = 'approved' AND deleted_at IS NULL)
          AS approved,
        (SELECT count(*) FROM location_notes WHERE user_id = u.id AND status = 'rejected')
        + (SELECT count(*) FROM reviews WHERE user_id = u.id AND status = 'rejected')
          AS rejected,
        COALESCE((SELECT SUM(helpful_count) FROM location_notes WHERE user_id = u.id AND deleted_at IS NULL), 0)
          AS helpful,
        -- İhlal = kullanıcının içeriğinin AĞIR sebeple reddedilmesi. Eskiden
        -- location_reports.message içinde kullanıcı kimliği aranıyordu; oraya
        -- HEDEF içerik kimliği yazıldığı için sayaç hep 0 kalıyordu (bulgu 2026-08).
        (SELECT count(*) FROM moderation_tasks mt
          WHERE mt.status = 'rejected'
            AND mt.decision_note IN ('offensive', 'personal_data')
            AND (
              mt.entity_id IN (SELECT id FROM location_notes WHERE user_id = u.id)
              OR mt.entity_id IN (SELECT id FROM reviews WHERE user_id = u.id)
            )) AS reports
      FROM users u WHERE u.id = ${userId}::uuid
    `);
    if (!s) return 1;

    const stats = {
      accountAgeDays: Number(s.ageDays),
      approvedCount: Number(s.approved),
      rejectedCount: Number(s.rejected),
      helpfulReceived: Number(s.helpful),
      confirmedReports: Number(s.reports),
    };
    const trust = computeTrustScore(stats);
    const restricted = stats.confirmedReports >= VIOLATIONS_FOR_RESTRICTION;

    await this.prisma.$executeRaw(Prisma.sql`
      INSERT INTO user_reputation (user_id, trust_score, approved_count, rejected_count,
                                   helpful_received, reports_against, write_restricted_until, last_recalc_at)
      VALUES (${userId}::uuid, ${trust}::numeric, ${stats.approvedCount}, ${stats.rejectedCount},
              ${stats.helpfulReceived}, ${stats.confirmedReports},
              ${restricted ? Prisma.sql`now() + make_interval(days => ${RESTRICTION_DAYS})` : Prisma.sql`NULL`},
              now())
      ON CONFLICT (user_id) DO UPDATE SET
        trust_score = ${trust}::numeric,
        approved_count = ${stats.approvedCount},
        rejected_count = ${stats.rejectedCount},
        helpful_received = ${stats.helpfulReceived},
        reports_against = ${stats.confirmedReports},
        write_restricted_until = ${restricted ? Prisma.sql`now() + make_interval(days => ${RESTRICTION_DAYS})` : Prisma.sql`user_reputation.write_restricted_until`},
        last_recalc_at = now(),
        updated_at = now()
    `);
    return trust;
  }
}

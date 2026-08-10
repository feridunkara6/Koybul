import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import {
  DecisionResult,
  ModerationDecision,
  ModerationItem,
  ModerationRepository,
} from '../domain/moderation.types';

/** ALTYAPI YOLU: moderatör BAŞKASININ satırını günceller — withUserContext kullanılmaz. */
@Injectable()
export class PrismaModerationRepository implements ModerationRepository {
  constructor(private readonly prisma: PrismaService) {}

  async queue(entityType: string | undefined, limit: number): Promise<ModerationItem[]> {
    const typeFilter = entityType
      ? Prisma.sql`AND t.entity_type = ${entityType}::moderation_entity`
      : Prisma.empty;
    const rows = await this.prisma.$queryRaw<
      {
        taskId: string;
        entityType: string;
        entityId: string;
        createdAt: Date;
        kind: string | null;
        title: string | null;
        body: string | null;
        locationName: string | null;
        observedOn: Date | null;
        gpsVerified: boolean | null;
        authorId: string | null;
        displayName: string | null;
        levelCode: string | null;
        approvedCount: number | null;
        rejectedCount: number | null;
      }[]
    >(Prisma.sql`
      SELECT t.id AS "taskId", t.entity_type::text AS "entityType", t.entity_id AS "entityId",
             t.created_at AS "createdAt",
             n.kind::text AS kind,
             COALESCE(n.title, r.title) AS title,
             COALESCE(n.body, r.body) AS body,
             COALESCE(ln.name, lr.name) AS "locationName",
             n.observed_on AS "observedOn",
             n.gps_verified AS "gpsVerified",
             COALESCE(n.user_id, r.user_id) AS "authorId",
             p.display_name AS "displayName",
             COALESCE(rep.level_code, 'new') AS "levelCode",
             COALESCE(rep.approved_count, 0)::int AS "approvedCount",
             COALESCE(rep.rejected_count, 0)::int AS "rejectedCount"
      FROM moderation_tasks t
      LEFT JOIN location_notes n
        ON t.entity_type = 'note' AND n.id = t.entity_id AND n.deleted_at IS NULL
      LEFT JOIN reviews r
        ON t.entity_type = 'review' AND r.id = t.entity_id AND r.deleted_at IS NULL
      LEFT JOIN locations ln ON ln.id = n.location_id
      LEFT JOIN locations lr ON lr.id = r.location_id
      LEFT JOIN user_profiles p ON p.user_id = COALESCE(n.user_id, r.user_id)
      LEFT JOIN user_reputation rep ON rep.user_id = COALESCE(n.user_id, r.user_id)
      WHERE t.status = 'pending' ${typeFilter}
      ORDER BY (t.entity_type = 'note' AND n.kind = 'hazard') DESC, t.created_at ASC
      LIMIT ${limit}
    `);

    return rows.map((r) => ({
      taskId: r.taskId,
      entityType: r.entityType as ModerationItem['entityType'],
      entityId: r.entityId,
      createdAt: r.createdAt.toISOString(),
      preview: {
        kind: r.kind,
        title: r.title,
        body: r.body,
        locationName: r.locationName,
        observedOn: r.observedOn ? r.observedOn.toISOString().slice(0, 10) : null,
        gpsVerified: r.gpsVerified,
      },
      author: {
        userId: r.authorId ?? '',
        displayName: r.displayName ?? 'Koybul Kullanıcısı',
        levelCode: r.levelCode ?? 'new',
        approvedCount: Number(r.approvedCount ?? 0),
        rejectedCount: Number(r.rejectedCount ?? 0),
      },
    }));
  }

  async counts(): Promise<Record<string, number>> {
    const rows = await this.prisma.$queryRaw<{ entityType: string; n: number }[]>(Prisma.sql`
      SELECT entity_type::text AS "entityType", count(*)::int AS n
      FROM moderation_tasks WHERE status = 'pending' GROUP BY entity_type
    `);
    const out: Record<string, number> = {};
    for (const r of rows) out[r.entityType] = Number(r.n);
    return out;
  }

  async decide(
    taskId: string,
    moderatorUserId: string,
    decision: ModerationDecision,
    reason: string | null,
  ): Promise<DecisionResult | null> {
    const status = decision === 'approve' ? 'approved' : 'rejected';
    return this.prisma.$transaction(async (tx) => {
      const claimed = await tx.$queryRaw<{ entityType: string; entityId: string }[]>(Prisma.sql`
        UPDATE moderation_tasks SET
          status = ${status}::moderation_status,
          decided_by_user_id = ${moderatorUserId}::uuid,
          decided_at = now(),
          decision_note = ${reason},
          updated_at = now()
        WHERE id = ${taskId}::uuid AND status = 'pending'::moderation_status
        RETURNING entity_type::text AS "entityType", entity_id AS "entityId"
      `);
      // Yarış koşulu: iki moderatör aynı görevi açtıysa ikincisi 404 alır.
      if (claimed.length === 0) return null;
      const { entityType, entityId } = claimed[0];

      if (entityType === 'note') {
        const rows = await tx.$queryRaw<{ ownerUserId: string; kind: string; len: number }[]>(
          Prisma.sql`
            UPDATE location_notes SET status = ${status}::moderation_status, updated_at = now()
            WHERE id = ${entityId}::uuid AND deleted_at IS NULL
            RETURNING user_id AS "ownerUserId", kind::text AS kind, char_length(body)::int AS len
          `,
        );
        if (rows.length === 0) return null;
        return {
          entityType,
          entityId,
          ownerUserId: rows[0].ownerUserId,
          decision,
          noteKind: rows[0].kind,
          bodyLength: Number(rows[0].len),
        };
      }

      if (entityType === 'review') {
        const rows = await tx.$queryRaw<{ ownerUserId: string; len: number }[]>(Prisma.sql`
          UPDATE reviews SET status = ${status}::moderation_status, updated_at = now()
          WHERE id = ${entityId}::uuid AND deleted_at IS NULL
          RETURNING user_id AS "ownerUserId", COALESCE(char_length(body), 0)::int AS len
        `);
        if (rows.length === 0) return null;
        return {
          entityType,
          entityId,
          ownerUserId: rows[0].ownerUserId,
          decision,
          noteKind: null,
          bodyLength: Number(rows[0].len),
        };
      }

      // Diğer varlık tipleri (media, suggestion) Faz 5'te bağlanır. Sahip
      // çözülemediği için puan yazılmaz (boş uuid ile sorgu denenmez).
      return { entityType, entityId, ownerUserId: null, decision, noteKind: null, bodyLength: 0 };
    });
  }
}

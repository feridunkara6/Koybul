import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import { CreateReportInput, ReportsRepository } from '../domain/reports.repository';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

@Injectable()
export class PrismaReportsRepository implements ReportsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async publishedLocationId(idOrSlug: string): Promise<string | null> {
    const cond = UUID_RE.test(idOrSlug)
      ? Prisma.sql`l.id = ${idOrSlug}::uuid`
      : Prisma.sql`l.slug = ${idOrSlug}`;
    const rows = await this.prisma.$queryRaw<{ id: string }[]>(Prisma.sql`
      SELECT l.id FROM locations l
      WHERE ${cond} AND l.status = 'published' AND l.deleted_at IS NULL
    `);
    return rows[0]?.id ?? null;
  }

  async hasRecentDuplicate(userId: string, locationId: string, reason: string): Promise<boolean> {
    const rows = await this.prisma.$queryRaw<{ n: number }[]>(Prisma.sql`
      SELECT count(*)::int AS n FROM location_reports
      WHERE user_id = ${userId}::uuid AND location_id = ${locationId}::uuid
        AND reason = ${reason}::report_reason
        AND created_at >= now() - interval '24 hours'
    `);
    return Number(rows[0]?.n ?? 0) > 0;
  }

  async create(
    userId: string,
    locationId: string,
    input: CreateReportInput,
  ): Promise<{ id: string }> {
    // Hedef referansı mesaja işlenir: şemada ayrı hedef sütunu yok (docs/12 §8.2
    // "aynı uç + hedef referansı"). Ayrı sütun Faz 5'te değerlendirilecek.
    const message =
      input.targetType && input.targetId
        ? `[${input.targetType}:${input.targetId}] ${input.message ?? ''}`.trim()
        : (input.message ?? null);
    const rows = await this.prisma.$queryRaw<{ id: string }[]>(Prisma.sql`
      INSERT INTO location_reports (user_id, location_id, reason, message)
      VALUES (${userId}::uuid, ${locationId}::uuid, ${input.reason}::report_reason, ${message})
      RETURNING id
    `);
    return { id: rows[0].id };
  }

  async autoHideIfFlooded(
    targetType: 'note' | 'review',
    targetId: string,
    threshold: number,
  ): Promise<boolean> {
    const marker = `[${targetType}:${targetId}]`;
    const rows = await this.prisma.$queryRaw<{ n: number }[]>(Prisma.sql`
      SELECT count(DISTINCT user_id)::int AS n FROM location_reports
      WHERE message LIKE ${marker + '%'} AND status IN ('open', 'in_review')
    `);
    if (Number(rows[0]?.n ?? 0) < threshold) return false;

    const table = targetType === 'note' ? Prisma.sql`location_notes` : Prisma.sql`reviews`;
    const moved = await this.prisma.$executeRaw(Prisma.sql`
      UPDATE ${table} SET status = 'pending'::moderation_status, updated_at = now()
      WHERE id = ${targetId}::uuid AND status = 'approved'::moderation_status
    `);
    if (moved > 0) {
      await this.prisma.$executeRaw(Prisma.sql`
        INSERT INTO moderation_tasks (entity_type, entity_id, status)
        VALUES (${targetType}::moderation_entity, ${targetId}::uuid, 'pending'::moderation_status)
        ON CONFLICT (entity_type, entity_id)
        DO UPDATE SET status = 'pending'::moderation_status, decided_at = NULL, updated_at = now()
      `);
    }
    return moved > 0;
  }
}

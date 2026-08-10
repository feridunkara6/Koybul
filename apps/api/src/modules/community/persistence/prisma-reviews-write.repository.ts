import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import {
  CreateReviewInput,
  ReviewWriteResult,
  ReviewsWriteRepository,
  UpdateReviewInput,
} from '../domain/reviews.repository';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

@Injectable()
export class PrismaReviewsWriteRepository implements ReviewsWriteRepository {
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

  async existingReviewId(locationId: string, userId: string): Promise<string | null> {
    const rows = await this.prisma.$queryRaw<{ id: string }[]>(Prisma.sql`
      SELECT id FROM reviews
      WHERE location_id = ${locationId}::uuid AND user_id = ${userId}::uuid AND deleted_at IS NULL
    `);
    return rows[0]?.id ?? null;
  }

  async create(
    id: string,
    locationId: string,
    userId: string,
    input: CreateReviewInput,
  ): Promise<ReviewWriteResult> {
    return this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw(Prisma.sql`
        INSERT INTO reviews (id, location_id, user_id, boat_id, overall_rating, title, body, visited_on, status)
        VALUES (${id}::uuid, ${locationId}::uuid, ${userId}::uuid, ${input.boatId ?? null}::uuid,
                ${input.overallRating}, ${input.title ?? null}, ${input.body ?? null},
                ${input.visitedOn ?? null}::date, 'pending'::moderation_status)
      `);
      await this.writeDimensions(tx, id, input.dimensions);
      await tx.$executeRaw(Prisma.sql`
        INSERT INTO moderation_tasks (entity_type, entity_id, status)
        VALUES ('review'::moderation_entity, ${id}::uuid, 'pending'::moderation_status)
        ON CONFLICT (entity_type, entity_id) DO NOTHING
      `);
      return { id, status: 'pending' as const, bodyLength: (input.body ?? '').length };
    });
  }

  async update(
    reviewId: string,
    userId: string,
    patch: UpdateReviewInput,
  ): Promise<ReviewWriteResult | null> {
    return this.prisma.$transaction(async (tx) => {
      const rows = await tx.$queryRaw<{ id: string; len: number }[]>(Prisma.sql`
        UPDATE reviews SET
          overall_rating = COALESCE(${patch.overallRating ?? null}, overall_rating),
          title = COALESCE(${patch.title === undefined ? null : patch.title}, title),
          body = COALESCE(${patch.body === undefined ? null : patch.body}, body),
          visited_on = COALESCE(${patch.visitedOn ?? null}::date, visited_on),
          -- Düzenlenen yorum yeniden incelenir.
          status = 'pending'::moderation_status,
          updated_at = now()
        WHERE id = ${reviewId}::uuid AND user_id = ${userId}::uuid AND deleted_at IS NULL
        RETURNING id, COALESCE(char_length(body), 0)::int AS len
      `);
      if (rows.length === 0) return null;
      await this.writeDimensions(tx, reviewId, patch.dimensions);
      await tx.$executeRaw(Prisma.sql`
        INSERT INTO moderation_tasks (entity_type, entity_id, status)
        VALUES ('review'::moderation_entity, ${reviewId}::uuid, 'pending'::moderation_status)
        ON CONFLICT (entity_type, entity_id)
        DO UPDATE SET status = 'pending'::moderation_status, decided_at = NULL, updated_at = now()
      `);
      return { id: reviewId, status: 'pending' as const, bodyLength: Number(rows[0].len) };
    });
  }

  async softDelete(reviewId: string, userId: string): Promise<boolean> {
    const n = await this.prisma.$executeRaw(Prisma.sql`
      UPDATE reviews SET deleted_at = now(), deleted_by = ${userId}::uuid, updated_at = now()
      WHERE id = ${reviewId}::uuid AND user_id = ${userId}::uuid AND deleted_at IS NULL
    `);
    return n > 0;
  }

  async findOwner(reviewId: string): Promise<string | null> {
    const rows = await this.prisma.$queryRaw<{ userId: string }[]>(Prisma.sql`
      SELECT user_id AS "userId" FROM reviews
      WHERE id = ${reviewId}::uuid AND deleted_at IS NULL AND status = 'approved'
    `);
    return rows[0]?.userId ?? null;
  }

  async react(
    reviewId: string,
    userId: string,
  ): Promise<{ helpfulCount: number; ownerUserId: string; created: boolean } | null> {
    return this.prisma.$transaction(async (tx) => {
      const inserted = await tx.$executeRaw(Prisma.sql`
        INSERT INTO review_reactions (review_id, user_id, reaction)
        VALUES (${reviewId}::uuid, ${userId}::uuid, 'helpful')
        ON CONFLICT (review_id, user_id, reaction) DO NOTHING
      `);
      const created = inserted > 0;
      // helpful_count ELLE ARTIRILMAZ: 0001_init'teki
      // trg_review_reactions_helpful_count tetikleyicisi sayacı baştan hesaplar.
      // Elle artırmak sayacı ikiye katlıyordu (inceleme bulgusu 2026-08).
      const rows = await tx.$queryRaw<{ helpfulCount: number; ownerUserId: string }[]>(Prisma.sql`
        SELECT helpful_count AS "helpfulCount", user_id AS "ownerUserId"
        FROM reviews WHERE id = ${reviewId}::uuid AND deleted_at IS NULL
      `);
      if (rows.length === 0) return null;
      return {
        helpfulCount: Number(rows[0].helpfulCount),
        ownerUserId: rows[0].ownerUserId,
        created,
      };
    });
  }

  async invalidDimensionCodes(codes: string[]): Promise<string[]> {
    if (codes.length === 0) return [];
    const rows = await this.prisma.$queryRaw<{ code: string }[]>(Prisma.sql`
      SELECT code FROM rating_dimensions WHERE code IN (${Prisma.join(codes)}) AND is_active
    `);
    const known = new Set(rows.map((r) => r.code));
    return codes.filter((c) => !known.has(c));
  }

  private async writeDimensions(
    tx: Prisma.TransactionClient,
    reviewId: string,
    dims: Record<string, number> | undefined,
  ): Promise<void> {
    if (!dims) return;
    for (const [code, score] of Object.entries(dims)) {
      await tx.$executeRaw(Prisma.sql`
        INSERT INTO review_ratings (review_id, dimension_id, score)
        -- ::smallint ZORUNLU: INSERT..SELECT'te hedef sütun tipi parametreye
        -- yayılmaz, çıplak parametre "could not determine data type" verir.
        SELECT ${reviewId}::uuid, d.id, ${score}::smallint
        FROM rating_dimensions d WHERE d.code = ${code}
        ON CONFLICT (review_id, dimension_id)
        DO UPDATE SET score = ${score}::smallint, updated_at = now()
      `);
    }
  }
}

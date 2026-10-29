import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import { ShareTripInput, TripsRepository } from '../domain/trip.types';

/**
 * Seyir paylaşımı deposu — ham SQL (routes deposuyla aynı ALTYAPI YOLU,
 * ADR-003). Yazmalar sahiplik bağlamıyla (withUserContext) koşar; RLS
 * sahiplik politikası ikinci kilittir.
 */
@Injectable()
export class PrismaTripsRepository implements TripsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async sharedToday(userId: string, now: Date): Promise<number> {
    const rows = await this.prisma.$queryRaw<{ n: number }[]>(Prisma.sql`
      SELECT count(*)::int AS n FROM shared_trips
      WHERE user_id = ${userId}::uuid AND deleted_at IS NULL
        AND created_at >= date_trunc('day', ${now}::timestamptz)
    `);
    return Number(rows[0]?.n ?? 0);
  }

  async share(id: string, userId: string, input: ShareTripInput): Promise<void> {
    await this.prisma.withUserContext(userId, (tx) =>
      tx.$executeRaw(Prisma.sql`
        INSERT INTO shared_trips
          (id, user_id, start_name, end_name, distance_nm, duration_min,
           stop_count, sailed_on)
        VALUES
          (${id}::uuid, ${userId}::uuid, ${input.startName}, ${input.endName},
           ${input.distanceNm}, ${input.durationMin}, ${input.stopCount},
           ${input.sailedOn}::date)
      `),
    );
  }

  async remove(tripId: string, userId: string): Promise<boolean> {
    const rows = await this.prisma.withUserContext(userId, (tx) =>
      tx.$queryRaw<{ id: string }[]>(Prisma.sql`
        UPDATE shared_trips SET deleted_at = now()
        WHERE id = ${tripId}::uuid AND user_id = ${userId}::uuid
          AND deleted_at IS NULL
        RETURNING id
      `),
    );
    return rows.length > 0;
  }

  async exists(tripId: string): Promise<boolean> {
    const rows = await this.prisma.$queryRaw<{ ok: boolean }[]>(Prisma.sql`
      SELECT EXISTS (SELECT 1 FROM shared_trips
        WHERE id = ${tripId}::uuid AND deleted_at IS NULL) AS ok
    `);
    return Boolean(rows[0]?.ok);
  }

  async togglePruva(
    tripId: string,
    userId: string,
  ): Promise<{ reacted: boolean; pruvaCount: number }> {
    // route_saves toggle deseni: sil → yoksa ekle → sayacı tek UPDATE.
    const rows = await this.prisma.withUserContext(userId, (tx) =>
      tx.$queryRaw<{ reacted: boolean; pruvaCount: number }[]>(Prisma.sql`
        WITH del AS (
          DELETE FROM trip_reactions
          WHERE trip_id = ${tripId}::uuid AND user_id = ${userId}::uuid
          RETURNING 1
        ), ins AS (
          INSERT INTO trip_reactions (trip_id, user_id)
          SELECT ${tripId}::uuid, ${userId}::uuid
          WHERE NOT EXISTS (SELECT 1 FROM del)
          RETURNING 1
        ), upd AS (
          UPDATE shared_trips
          SET pruva_count = GREATEST(0, pruva_count
                + CASE WHEN EXISTS (SELECT 1 FROM del) THEN -1 ELSE 1 END)
          WHERE id = ${tripId}::uuid
          RETURNING pruva_count
        )
        SELECT EXISTS (SELECT 1 FROM ins) AS reacted,
               COALESCE((SELECT pruva_count::int FROM upd), 0) AS "pruvaCount"
      `),
    );
    return rows[0];
  }
}

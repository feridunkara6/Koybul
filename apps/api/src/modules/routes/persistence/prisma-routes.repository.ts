import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import {
  CreateRouteInput,
  RouteRow,
  RouteSort,
  RouteStopView,
  RoutesRepository,
} from '../domain/route.types';

/**
 * Rota deposu — ham SQL (qa/notes depolarıyla aynı ALTYAPI YOLU, ADR-003):
 * yayın kararı uygulama katmanındadır; okumalar altyapı yolundan geçer.
 * Durak adları her sorguda katalogdan taze gelir (kopya ad saklanmaz).
 */

/** Liste/detay ortak kolonları: yazar adı + ilk/son durak adı + durak sayısı. */
const ROUTE_COLS = Prisma.sql`
  r.id, r.user_id AS "userId", r.name, r.body, r.season,
  r.boat_suggestion AS "boatSuggestion", r.distance_nm AS "distanceNm",
  r.duration_hours AS "durationHours", r.status, r.save_count AS "saveCount",
  r.done_count AS "doneCount", r.created_at AS "createdAt",
  p.display_name AS "authorName",
  (SELECT l.name FROM route_stops s JOIN locations l ON l.id = s.location_id
    WHERE s.route_id = r.id ORDER BY s.seq ASC LIMIT 1) AS "startName",
  (SELECT l.name FROM route_stops s JOIN locations l ON l.id = s.location_id
    WHERE s.route_id = r.id ORDER BY s.seq DESC LIMIT 1) AS "endName",
  (SELECT count(*)::int FROM route_stops s WHERE s.route_id = r.id) AS "stopCount"
`;

const AUTHOR_JOIN = Prisma.sql`
  LEFT JOIN user_profiles p ON p.user_id = r.user_id
`;

@Injectable()
export class PrismaRoutesRepository implements RoutesRepository {
  constructor(private readonly prisma: PrismaService) {}

  async list(sort: RouteSort, locationId: string | null, limit: number): Promise<RouteRow[]> {
    const order =
      sort === 'popular'
        ? Prisma.sql`r.save_count DESC, r.created_at DESC`
        : Prisma.sql`r.created_at DESC`;
    const locationFilter =
      locationId === null
        ? Prisma.empty
        : Prisma.sql`AND EXISTS (SELECT 1 FROM route_stops fs
            WHERE fs.route_id = r.id AND fs.location_id = ${locationId}::uuid)`;
    return this.prisma.$queryRaw<RouteRow[]>(Prisma.sql`
      SELECT ${ROUTE_COLS}
      FROM routes r ${AUTHOR_JOIN}
      WHERE r.status = 'approved'::moderation_status AND r.deleted_at IS NULL
      ${locationFilter}
      ORDER BY ${order}
      LIMIT ${limit}
    `);
  }

  async findRoute(routeId: string): Promise<RouteRow | null> {
    const rows = await this.prisma.$queryRaw<RouteRow[]>(Prisma.sql`
      SELECT ${ROUTE_COLS}
      FROM routes r ${AUTHOR_JOIN}
      WHERE r.id = ${routeId}::uuid AND r.deleted_at IS NULL
    `);
    return rows.length > 0 ? rows[0] : null;
  }

  async stopsFor(routeId: string): Promise<RouteStopView[]> {
    return this.prisma.$queryRaw<RouteStopView[]>(Prisma.sql`
      SELECT s.seq::int AS seq, s.location_id AS "locationId",
             l.name, lt.code AS "typeCode"
      FROM route_stops s
      JOIN locations l ON l.id = s.location_id
      JOIN location_types lt ON lt.id = l.location_type_id
      WHERE s.route_id = ${routeId}::uuid
      ORDER BY s.seq ASC
    `);
  }

  async publishedLocationCount(locationIds: string[]): Promise<number> {
    if (locationIds.length === 0) return 0;
    const rows = await this.prisma.$queryRaw<{ n: number }[]>(Prisma.sql`
      SELECT count(DISTINCT l.id)::int AS n
      FROM locations l
      WHERE l.id = ANY(${locationIds}::uuid[])
        AND l.status = 'published'::location_status AND l.deleted_at IS NULL
    `);
    return Number(rows[0]?.n ?? 0);
  }

  async monthlyCount(userId: string, now: Date): Promise<number> {
    const rows = await this.prisma.$queryRaw<{ n: number }[]>(Prisma.sql`
      SELECT count(*)::int AS n FROM routes
      WHERE user_id = ${userId}::uuid AND deleted_at IS NULL
        AND date_trunc('month', created_at) = date_trunc('month', ${now}::timestamptz)
    `);
    return Number(rows[0]?.n ?? 0);
  }

  async create(id: string, userId: string, input: CreateRouteInput): Promise<RouteRow> {
    // Rota + duraklar + moderasyon görevi TEK transaction (qa deseni).
    // Duraklar unnest ile sıra numarası alır; yazma sahiplik bağlamıyla koşar.
    const seqs = input.stopLocationIds.map((_, i) => i + 1);
    const rows = await this.prisma.withUserContext(userId, (tx) =>
      tx.$queryRaw<RouteRow[]>(Prisma.sql`
        WITH ins AS (
          INSERT INTO routes (id, user_id, name, body, season, boat_suggestion,
                              distance_nm, duration_hours, status)
          VALUES (${id}::uuid, ${userId}::uuid, ${input.name}, ${input.body},
                  ${input.season ?? null}, ${input.boatSuggestion ?? null},
                  ${input.distanceNm}, ${input.durationHours ?? null},
                  'pending'::moderation_status)
          RETURNING *
        ), stops AS (
          INSERT INTO route_stops (route_id, seq, location_id)
          SELECT ins.id, x.seq, x.loc
          FROM ins, unnest(${seqs}::smallint[], ${input.stopLocationIds}::uuid[])
            AS x(seq, loc)
          RETURNING 1
        ), task AS (
          INSERT INTO moderation_tasks (entity_type, entity_id, status)
          SELECT 'route'::moderation_entity, ins.id, 'pending'::moderation_status
          FROM ins
          ON CONFLICT (entity_type, entity_id) DO NOTHING
        )
        SELECT r.id, r.user_id AS "userId", r.name, r.body, r.season,
               r.boat_suggestion AS "boatSuggestion", r.distance_nm AS "distanceNm",
               r.duration_hours AS "durationHours", r.status,
               r.save_count AS "saveCount", r.done_count AS "doneCount",
               r.created_at AS "createdAt",
               p.display_name AS "authorName",
               NULL::text AS "startName", NULL::text AS "endName",
               (SELECT count(*)::int FROM stops) AS "stopCount"
        FROM ins r
        LEFT JOIN user_profiles p ON p.user_id = r.user_id
      `),
    );
    return rows[0];
  }

  async savedBy(routeId: string, userId: string): Promise<boolean> {
    const rows = await this.prisma.$queryRaw<{ ok: boolean }[]>(Prisma.sql`
      SELECT EXISTS (SELECT 1 FROM route_saves
        WHERE route_id = ${routeId}::uuid AND user_id = ${userId}::uuid) AS ok
    `);
    return Boolean(rows[0]?.ok);
  }

  async doneBy(routeId: string, userId: string): Promise<boolean> {
    const rows = await this.prisma.$queryRaw<{ ok: boolean }[]>(Prisma.sql`
      SELECT EXISTS (SELECT 1 FROM route_dones
        WHERE route_id = ${routeId}::uuid AND user_id = ${userId}::uuid) AS ok
    `);
    return Boolean(rows[0]?.ok);
  }

  async toggleSave(
    routeId: string,
    userId: string,
  ): Promise<{ saved: boolean; saveCount: number }> {
    // qa_question_likes toggle deseni: sil → yoksa ekle → sayacı tek UPDATE.
    const rows = await this.prisma.$queryRaw<{ saved: boolean; saveCount: number }[]>(Prisma.sql`
      WITH del AS (
        DELETE FROM route_saves
        WHERE route_id = ${routeId}::uuid AND user_id = ${userId}::uuid
        RETURNING 1
      ), ins AS (
        INSERT INTO route_saves (route_id, user_id)
        SELECT ${routeId}::uuid, ${userId}::uuid
        WHERE NOT EXISTS (SELECT 1 FROM del)
        RETURNING 1
      ), upd AS (
        UPDATE routes
        SET save_count = GREATEST(0, save_count
              + CASE WHEN EXISTS (SELECT 1 FROM del) THEN -1 ELSE 1 END),
            updated_at = now()
        WHERE id = ${routeId}::uuid
        RETURNING save_count
      )
      SELECT EXISTS (SELECT 1 FROM ins) AS saved,
             COALESCE((SELECT save_count::int FROM upd), 0) AS "saveCount"
    `);
    return rows[0];
  }

  async toggleDone(routeId: string, userId: string): Promise<{ done: boolean; doneCount: number }> {
    const rows = await this.prisma.$queryRaw<{ done: boolean; doneCount: number }[]>(Prisma.sql`
      WITH del AS (
        DELETE FROM route_dones
        WHERE route_id = ${routeId}::uuid AND user_id = ${userId}::uuid
        RETURNING 1
      ), ins AS (
        INSERT INTO route_dones (route_id, user_id)
        SELECT ${routeId}::uuid, ${userId}::uuid
        WHERE NOT EXISTS (SELECT 1 FROM del)
        RETURNING 1
      ), upd AS (
        UPDATE routes
        SET done_count = GREATEST(0, done_count
              + CASE WHEN EXISTS (SELECT 1 FROM del) THEN -1 ELSE 1 END),
            updated_at = now()
        WHERE id = ${routeId}::uuid
        RETURNING done_count
      )
      SELECT EXISTS (SELECT 1 FROM ins) AS done,
             COALESCE((SELECT done_count::int FROM upd), 0) AS "doneCount"
    `);
    return rows[0];
  }

  async softDelete(routeId: string, userId: string): Promise<boolean> {
    // Sahiplik SQL'de; bekleyen moderasyon görevi kapatılır (notes deseni).
    const rows = await this.prisma.withUserContext(userId, (tx) =>
      tx.$queryRaw<{ id: string }[]>(Prisma.sql`
        WITH del AS (
          UPDATE routes SET deleted_at = now(), updated_at = now()
          WHERE id = ${routeId}::uuid AND user_id = ${userId}::uuid
            AND deleted_at IS NULL
          RETURNING id
        ), task AS (
          UPDATE moderation_tasks SET status = 'rejected'::moderation_status,
                 decision_note = 'author_deleted', decided_at = now(), updated_at = now()
          WHERE entity_type = 'route'::moderation_entity
            AND entity_id IN (SELECT id FROM del)
            AND status = 'pending'::moderation_status
        )
        SELECT id FROM del
      `),
    );
    return rows.length > 0;
  }
}

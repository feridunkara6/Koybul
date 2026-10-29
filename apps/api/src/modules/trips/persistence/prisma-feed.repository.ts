import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import { FEED_NOTE_BODY_MAX, FeedRepository, FeedRow } from '../domain/feed.types';

/**
 * Akış deposu — TEK sorgu, üç kaynak UNION ALL (SP-3b). Her dal kendi
 * indeksiyle (created_at DESC) LIMIT'li süzülür; birleşik sıralama dışta.
 * Yazar adı/seviye her satıra tek JOIN turuyla eklenir — kopya ad saklanmaz
 * (rota deposuyla aynı tazelik ilkesi).
 */
@Injectable()
export class PrismaFeedRepository implements FeedRepository {
  constructor(private readonly prisma: PrismaService) {}

  async followingFeed(userId: string, limit: number): Promise<FeedRow[]> {
    return this.prisma.$queryRaw<FeedRow[]>(Prisma.sql`
      WITH f AS (
        SELECT followed_id FROM user_follows WHERE follower_id = ${userId}::uuid
      ), src AS (
        (
          SELECT 'trip'::text AS kind, t.id, t.user_id AS author_id,
                 t.created_at,
                 t.start_name, t.end_name, t.distance_nm, t.duration_min,
                 t.stop_count, t.sailed_on, t.pruva_count,
                 EXISTS (SELECT 1 FROM trip_reactions x
                   WHERE x.trip_id = t.id AND x.user_id = ${userId}::uuid) AS my_pruva,
                 NULL::uuid AS location_id, NULL::text AS location_name,
                 NULL::text AS note_kind, NULL::text AS body,
                 NULL::text AS route_name, NULL::int AS save_count
          FROM shared_trips t JOIN f ON f.followed_id = t.user_id
          WHERE t.deleted_at IS NULL
          ORDER BY t.created_at DESC LIMIT ${limit}
        )
        UNION ALL
        (
          SELECT 'note'::text, n.id, n.user_id, n.created_at,
                 NULL, NULL, NULL::numeric, NULL::int, NULL::int, NULL::date,
                 NULL::int, NULL::boolean,
                 n.location_id, l.name,
                 n.kind::text, left(n.body, ${FEED_NOTE_BODY_MAX}),
                 NULL, NULL::int
          FROM location_notes n
          JOIN f ON f.followed_id = n.user_id
          LEFT JOIN locations l ON l.id = n.location_id
          WHERE n.status = 'approved'::moderation_status AND n.deleted_at IS NULL
          ORDER BY n.created_at DESC LIMIT ${limit}
        )
        UNION ALL
        (
          SELECT 'route'::text, r.id, r.user_id, r.created_at,
                 NULL, NULL, NULL::numeric, NULL::int,
                 (SELECT count(*)::int FROM route_stops s WHERE s.route_id = r.id),
                 NULL::date, NULL::int, NULL::boolean,
                 NULL::uuid, NULL::text, NULL::text, NULL::text,
                 r.name, r.save_count
          FROM routes r JOIN f ON f.followed_id = r.user_id
          WHERE r.status = 'approved'::moderation_status AND r.deleted_at IS NULL
          ORDER BY r.created_at DESC LIMIT ${limit}
        )
      )
      SELECT src.kind, src.id,
             src.author_id   AS "authorId",
             p.display_name  AS "authorName",
             rep.level_code  AS "levelCode",
             src.created_at  AS "createdAt",
             src.start_name  AS "startName",
             src.end_name    AS "endName",
             src.distance_nm AS "distanceNm",
             src.duration_min AS "durationMin",
             src.stop_count  AS "stopCount",
             src.sailed_on   AS "sailedOn",
             src.pruva_count AS "pruvaCount",
             src.my_pruva    AS "myPruva",
             src.location_id AS "locationId",
             src.location_name AS "locationName",
             src.note_kind   AS "noteKind",
             src.body,
             src.route_name  AS "routeName",
             src.save_count  AS "saveCount"
      FROM src
      JOIN users u ON u.id = src.author_id
        AND u.deleted_at IS NULL AND u.status = 'active'
      LEFT JOIN user_profiles p ON p.user_id = src.author_id
      LEFT JOIN user_reputation rep ON rep.user_id = src.author_id
      ORDER BY src.created_at DESC
      LIMIT ${limit}
    `);
  }
}

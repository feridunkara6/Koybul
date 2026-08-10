import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import { CreateNoteInput, Note, NoteReaction, UpdateNoteInput } from '../domain/note.types';
import {
  NearbyNote,
  NearbyNoteQuery,
  NoteListFilters,
  NoteOwnership,
  NotesRepository,
  ReactionResult,
} from '../domain/notes.repository';

/**
 * ALTYAPI YOLU (ADR-003 + 0008 migration notu): bu depo `withUserContext`
 * KULLANMAZ. Sayaç artırma, moderasyon durumu değiştirme gibi işlemler
 * BAŞKASININ satırına dokunur; sahiplik bağlamı kurulursa RLS satırı süzer ve
 * UPDATE sessizce 0 satır etkiler. Sahiplik kontrolü SQL'in WHERE'inde açıkça
 * yapılır (`user_id = $userId`) — uygulama katmanı birincil yetki katmanıdır.
 */
const NM_TO_M = 1852;

/** Tepki yazılırken not silinmişse işlemi geri almak için (rollback tetikler). */
class NoteVanishedError extends Error {}

interface NoteRow {
  id: string;
  kind: string;
  locationId: string | null;
  fromLocationId: string | null;
  toLocationId: string | null;
  title: string | null;
  body: string;
  observedOn: Date;
  gpsVerified: boolean;
  windSummary: unknown;
  helpfulCount: number;
  confirmCount: number;
  disputeCount: number;
  status: string;
  createdAt: Date;
  authorId: string;
  displayName: string;
  levelCode: string;
}

function toWind(v: unknown): { kn: number; dirTr: string } | null {
  if (!v || typeof v !== 'object') return null;
  const o = v as { kn?: unknown; dirTr?: unknown };
  if (typeof o.kn !== 'number' || typeof o.dirTr !== 'string') return null;
  return { kn: o.kn, dirTr: o.dirTr };
}

function ymd(d: Date): string {
  return d.toISOString().slice(0, 10);
}

function toNote(r: NoteRow, includeStatus: boolean): Note {
  return {
    id: r.id,
    kind: r.kind as Note['kind'],
    locationId: r.locationId,
    fromLocationId: r.fromLocationId,
    toLocationId: r.toLocationId,
    title: r.title,
    body: r.body,
    observedOn: ymd(r.observedOn),
    gpsVerified: r.gpsVerified,
    wind: toWind(r.windSummary),
    helpfulCount: Number(r.helpfulCount),
    confirmCount: Number(r.confirmCount),
    disputeCount: Number(r.disputeCount),
    createdAt: r.createdAt.toISOString(),
    author: {
      userId: r.authorId,
      displayName: r.displayName,
      levelCode: r.levelCode,
      // Bölgesel uzmanlık sayacı Faz 4'te (materyalize görünüm) gelir.
      areaContributions: null,
    },
    ...(includeStatus ? { status: r.status as Note['status'] } : {}),
  };
}

/** Ortak SELECT gövdesi — yazar bilgisi PII taşımaz (takma ad + seviye). */
const NOTE_SELECT = Prisma.sql`
  n.id, n.kind::text AS "kind", n.location_id AS "locationId",
  n.from_location_id AS "fromLocationId", n.to_location_id AS "toLocationId",
  n.title, n.body, n.observed_on AS "observedOn", n.gps_verified AS "gpsVerified",
  n.wind_summary AS "windSummary", n.helpful_count AS "helpfulCount",
  n.confirm_count AS "confirmCount", n.dispute_count AS "disputeCount",
  n.status::text AS "status", n.created_at AS "createdAt",
  n.user_id AS "authorId",
  COALESCE(p.display_name, 'Koybul Kullanıcısı') AS "displayName",
  COALESCE(rep.level_code, 'new') AS "levelCode"
`;

const NOTE_JOINS = Prisma.sql`
  LEFT JOIN user_profiles p ON p.user_id = n.user_id
  LEFT JOIN user_reputation rep ON rep.user_id = n.user_id
`;

@Injectable()
export class PrismaNotesRepository implements NotesRepository {
  constructor(private readonly prisma: PrismaService) {}

  async listForLocation(locationId: string, f: NoteListFilters): Promise<Note[]> {
    const kindFilter = f.kind ? Prisma.sql`AND n.kind = ${f.kind}::note_kind` : Prisma.empty;
    const rows = await this.prisma.$queryRaw<NoteRow[]>(Prisma.sql`
      SELECT ${NOTE_SELECT}
      FROM location_notes n ${NOTE_JOINS}
      WHERE n.location_id = ${locationId}::uuid
        AND n.status = 'approved' AND n.deleted_at IS NULL
        -- Süresi dolan "güncel durum" notu öne çıkmaz (48 saatlik tazelik).
        AND (n.expires_at IS NULL OR n.expires_at > now())
        ${kindFilter}
      ORDER BY (n.kind = 'hazard') DESC, n.observed_on DESC, n.created_at DESC
      LIMIT ${f.limit}
    `);
    return rows.map((r) => toNote(r, false));
  }

  async nearby(q: NearbyNoteQuery): Promise<NearbyNote[]> {
    const rows = await this.prisma.$queryRaw<
      (NoteRow & { distanceNm: number; locationName: string | null })[]
    >(
      Prisma.sql`
        SELECT ${NOTE_SELECT},
          ST_Distance(n.reported_from, ST_SetSRID(ST_MakePoint(${q.lon}, ${q.lat}), 4326)::geography)
            / ${NM_TO_M} AS "distanceNm",
          l.name AS "locationName"
        FROM location_notes n ${NOTE_JOINS}
        LEFT JOIN locations l ON l.id = n.location_id
        WHERE n.status = 'approved' AND n.deleted_at IS NULL
          AND (n.expires_at IS NULL OR n.expires_at > now())
          AND n.reported_from IS NOT NULL
          AND n.created_at >= now() - make_interval(hours => ${q.sinceHours})
          AND ST_DWithin(
                n.reported_from,
                ST_SetSRID(ST_MakePoint(${q.lon}, ${q.lat}), 4326)::geography,
                ${q.radiusNm * NM_TO_M}
              )
        ORDER BY (n.kind = 'hazard') DESC, n.created_at DESC
        LIMIT ${q.limit}
      `,
    );
    return rows.map((r) => ({
      ...toNote(r, false),
      distanceNm: Number(Number(r.distanceNm).toFixed(1)),
      locationName: r.locationName,
    }));
  }

  async listForUser(userId: string, status: string | undefined, limit: number): Promise<Note[]> {
    const statusFilter = status
      ? Prisma.sql`AND n.status = ${status}::moderation_status`
      : Prisma.empty;
    const rows = await this.prisma.$queryRaw<NoteRow[]>(Prisma.sql`
      SELECT ${NOTE_SELECT}
      FROM location_notes n ${NOTE_JOINS}
      WHERE n.user_id = ${userId}::uuid AND n.deleted_at IS NULL ${statusFilter}
      ORDER BY n.created_at DESC
      LIMIT ${limit}
    `);
    return rows.map((r) => toNote(r, true));
  }

  async findOwnership(noteId: string): Promise<NoteOwnership | null> {
    const rows = await this.prisma.$queryRaw<{ userId: string; kind: string; status: string }[]>(
      Prisma.sql`
        SELECT user_id AS "userId", kind::text AS "kind", status::text AS "status"
        FROM location_notes WHERE id = ${noteId}::uuid AND deleted_at IS NULL
      `,
    );
    if (rows.length === 0) return null;
    return {
      userId: rows[0].userId,
      kind: rows[0].kind as NoteOwnership['kind'],
      status: rows[0].status as NoteOwnership['status'],
    };
  }

  async checkTarget(
    locationId: string,
    position: { lat: number; lon: number } | undefined,
    maxDistanceM: number,
  ): Promise<'ok' | 'too-far' | 'not-found'> {
    const rows = await this.prisma.$queryRaw<{ dist: number | null }[]>(Prisma.sql`
      SELECT CASE WHEN ${position ? Prisma.sql`TRUE` : Prisma.sql`FALSE`}
        THEN ST_Distance(
          l.position,
          ST_SetSRID(ST_MakePoint(${position?.lon ?? 0}, ${position?.lat ?? 0}), 4326)::geography
        ) ELSE NULL END AS dist
      FROM locations l
      WHERE l.id = ${locationId}::uuid AND l.status = 'published' AND l.deleted_at IS NULL
    `);
    if (rows.length === 0) return 'not-found';
    const d = rows[0].dist;
    if (d !== null && Number(d) > maxDistanceM) return 'too-far';
    return 'ok';
  }

  /**
   * Tek ifadede: notu yaz + gerekiyorsa moderasyon görevini aç.
   * CTE kullanılır ki iki yazma aynı işlemde olsun (yarım kalmış kayıt olmasın).
   */
  async create(
    id: string,
    userId: string,
    input: CreateNoteInput,
    expiresAt: Date | null,
    status: 'pending' | 'approved',
  ): Promise<Note> {
    const pos = input.position;
    const geo = pos
      ? Prisma.sql`ST_SetSRID(ST_MakePoint(${pos.lon}, ${pos.lat}), 4326)::geography`
      : Prisma.sql`NULL`;
    const wind = input.wind ? JSON.stringify(input.wind) : null;

    const rows = await this.prisma.$queryRaw<NoteRow[]>(Prisma.sql`
      WITH ins AS (
        INSERT INTO location_notes (
          id, location_id, from_location_id, to_location_id, user_id, boat_id,
          kind, title, body, observed_on, reported_from, gps_verified,
          wind_summary, status, expires_at
        ) VALUES (
          ${id}::uuid,
          ${input.locationId ?? null}::uuid,
          ${input.fromLocationId ?? null}::uuid,
          ${input.toLocationId ?? null}::uuid,
          ${userId}::uuid,
          ${input.boatId ?? null}::uuid,
          ${input.kind}::note_kind,
          ${input.title ?? null},
          ${input.body},
          ${input.observedOn}::date,
          ${geo},
          ${pos !== undefined},
          ${wind}::jsonb,
          ${status}::moderation_status,
          ${expiresAt}::timestamptz
        )
        RETURNING *
      ), task AS (
        INSERT INTO moderation_tasks (entity_type, entity_id, status)
        SELECT 'note'::moderation_entity, ins.id, 'pending'::moderation_status
        FROM ins WHERE ins.status = 'pending'::moderation_status
        ON CONFLICT (entity_type, entity_id) DO NOTHING
      )
      SELECT ${NOTE_SELECT}
      FROM ins n ${NOTE_JOINS}
    `);
    return toNote(rows[0], true);
  }

  async update(noteId: string, userId: string, patch: UpdateNoteInput): Promise<Note | null> {
    const rows = await this.prisma.$queryRaw<NoteRow[]>(Prisma.sql`
      WITH upd AS (
        UPDATE location_notes n SET
          title = COALESCE(${patch.title === undefined ? null : patch.title}, n.title),
          body  = COALESCE(${patch.body ?? null}, n.body),
          -- Düzenlenen içerik yeniden incelenir: onaylı metin sessizce değişmez.
          status = 'pending'::moderation_status,
          updated_at = now()
        WHERE n.id = ${noteId}::uuid AND n.user_id = ${userId}::uuid AND n.deleted_at IS NULL
        RETURNING *
      ), task AS (
        INSERT INTO moderation_tasks (entity_type, entity_id, status)
        SELECT 'note'::moderation_entity, upd.id, 'pending'::moderation_status FROM upd
        ON CONFLICT (entity_type, entity_id)
        DO UPDATE SET status = 'pending'::moderation_status, decided_at = NULL, updated_at = now()
      )
      SELECT ${NOTE_SELECT} FROM upd n ${NOTE_JOINS}
    `);
    return rows.length > 0 ? toNote(rows[0], true) : null;
  }

  async softDelete(noteId: string, userId: string): Promise<boolean> {
    return this.prisma.$transaction(async (tx) => {
      const n = await tx.$executeRaw(Prisma.sql`
        UPDATE location_notes
        SET deleted_at = now(), deleted_by = ${userId}::uuid, updated_at = now()
        WHERE id = ${noteId}::uuid AND user_id = ${userId}::uuid AND deleted_at IS NULL
      `);
      if (n === 0) return false;
      // Silinen içerik moderatörün kuyruğunda ASILI KALMAZ.
      await tx.$executeRaw(Prisma.sql`
        UPDATE moderation_tasks SET status = 'rejected'::moderation_status,
               decision_note = 'author_deleted', decided_at = now(), updated_at = now()
        WHERE entity_type = 'note' AND entity_id = ${noteId}::uuid AND status = 'pending'
      `);
      return true;
    });
  }

  async refsValid(
    toLocationId: string | null | undefined,
    boatId: string | null | undefined,
    userId: string,
  ): Promise<boolean> {
    if (!toLocationId && !boatId) return true;
    const rows = await this.prisma.$queryRaw<{ ok: boolean }[]>(Prisma.sql`
      SELECT
        (${toLocationId ?? null}::uuid IS NULL OR EXISTS (
          SELECT 1 FROM locations
          WHERE id = ${toLocationId ?? null}::uuid AND status = 'published' AND deleted_at IS NULL
        ))
        AND
        (${boatId ?? null}::uuid IS NULL OR EXISTS (
          SELECT 1 FROM boats
          WHERE id = ${boatId ?? null}::uuid AND owner_user_id = ${userId}::uuid
            AND deleted_at IS NULL
        )) AS ok
    `);
    return rows[0]?.ok === true;
  }

  async react(
    noteId: string,
    userId: string,
    reaction: NoteReaction,
    weight: number,
    disputeThreshold: number,
  ): Promise<ReactionResult | null> {
    try {
      return await this.reactInTransaction(noteId, userId, reaction, weight, disputeThreshold);
    } catch (err) {
      if (err instanceof NoteVanishedError) return null;
      throw err;
    }
  }

  private async reactInTransaction(
    noteId: string,
    userId: string,
    reaction: NoteReaction,
    weight: number,
    disputeThreshold: number,
  ): Promise<ReactionResult> {
    return this.prisma.$transaction(async (tx) => {
      const inserted = await tx.$executeRaw(Prisma.sql`
        INSERT INTO note_reactions (note_id, user_id, reaction, weight)
        VALUES (${noteId}::uuid, ${userId}::uuid, ${reaction}, ${weight}::numeric)
        ON CONFLICT (note_id, user_id, reaction) DO NOTHING
      `);
      const created = inserted > 0;

      const rows = await tx.$queryRaw<
        { helpfulCount: number; confirmCount: number; disputeCount: number; ownerUserId: string }[]
      >(Prisma.sql`
        UPDATE location_notes n SET
          helpful_count = helpful_count + ${created && reaction === 'helpful' ? 1 : 0},
          confirm_count = confirm_count + ${created && reaction === 'confirm' ? 1 : 0},
          dispute_count = dispute_count + ${created && reaction === 'dispute' ? 1 : 0},
          updated_at = now()
        WHERE n.id = ${noteId}::uuid AND n.deleted_at IS NULL
        RETURNING helpful_count AS "helpfulCount", confirm_count AS "confirmCount",
                  dispute_count AS "disputeCount", user_id AS "ownerUserId"
      `);
      // Not bu arada silindiyse tepki satırı da GERİ ALINIR: işlemden `null`
      // dönmek satırı geri almaz, hata fırlatmak alır (inceleme bulgusu 2026-08).
      if (rows.length === 0) throw new NoteVanishedError();
      const r = rows[0];

      // İki bağımsız çelişki → uyarı yeniden incelemeye döner. Tek kişi
      // emniyet bilgisini yayından kaldıramaz.
      let movedToReview = false;
      if (created && reaction === 'dispute' && Number(r.disputeCount) >= disputeThreshold) {
        const moved = await tx.$executeRaw(Prisma.sql`
          UPDATE location_notes SET status = 'pending'::moderation_status, updated_at = now()
          WHERE id = ${noteId}::uuid AND status = 'approved'::moderation_status
        `);
        if (moved > 0) {
          movedToReview = true;
          await tx.$executeRaw(Prisma.sql`
            INSERT INTO moderation_tasks (entity_type, entity_id, status)
            VALUES ('note'::moderation_entity, ${noteId}::uuid, 'pending'::moderation_status)
            ON CONFLICT (entity_type, entity_id)
            DO UPDATE SET status = 'pending'::moderation_status, decided_at = NULL, updated_at = now()
          `);
        }
      }

      return {
        created,
        helpfulCount: Number(r.helpfulCount),
        confirmCount: Number(r.confirmCount),
        disputeCount: Number(r.disputeCount),
        movedToReview,
        ownerUserId: r.ownerUserId,
      };
    });
  }
}

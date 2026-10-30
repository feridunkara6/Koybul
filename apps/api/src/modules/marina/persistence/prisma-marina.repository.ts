import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import {
  MarinaBoat,
  MarinaRepository,
  MyMarinaBoat,
  UpsertMyBoatInput,
} from '../domain/marina.types';

/**
 * Marina topluluğu deposu — ham SQL (notes/qa depolarıyla aynı ALTYAPI YOLU).
 * Tekne YAZMA işlemleri withUserContext ile koşar (boats RLS sahiplik
 * politikası — 0002); topluluk OKUMALARI altyapı yolundan geçer ve görünürlük
 * süzgeci SQL'de uygulanır: visible=false tekne listede ASLA yer almaz,
 * shareSpecs=false teknenin boy/marka alanları istemciye hiç inmez.
 */

/** Marina sayılan katalog tipleri (kurucu konsept: gerçek marinalar). */
const MARINA_TYPES = Prisma.sql`('private_marina', 'municipal_marina')`;

interface MyBoatRow {
  boatId: string;
  name: string;
  boatTypeCode: string;
  lengthM: unknown;
  brand: string | null;
  model: string | null;
  buildYear: number | null;
  marinaId: string | null;
  marinaName: string | null;
  visible: boolean;
  shareSpecs: boolean;
  story: string | null;
  storyStatus: string;
}

function toMyBoat(r: MyBoatRow): MyMarinaBoat {
  return {
    boatId: r.boatId,
    name: r.name,
    boatTypeCode: r.boatTypeCode,
    lengthM: Number(r.lengthM),
    brand: r.brand,
    model: r.model,
    buildYear: r.buildYear,
    marina:
      r.marinaId !== null && r.marinaName !== null ? { id: r.marinaId, name: r.marinaName } : null,
    visible: r.visible,
    shareSpecs: r.shareSpecs,
    story: r.story,
    storyStatus: r.storyStatus,
  };
}

const MY_BOAT_SELECT = Prisma.sql`
  b.id AS "boatId", b.name, bt.code AS "boatTypeCode", b.length_m AS "lengthM",
  b.brand, b.model, b.build_year AS "buildYear",
  l.id AS "marinaId", l.name AS "marinaName",
  b.visible_in_marina AS visible, b.share_specs AS "shareSpecs",
  b.story, b.story_status AS "storyStatus"
`;

@Injectable()
export class PrismaMarinaRepository implements MarinaRepository {
  constructor(private readonly prisma: PrismaService) {}

  async marinaInfo(locationId: string): Promise<{ id: string; name: string } | null> {
    const rows = await this.prisma.$queryRaw<{ id: string; name: string }[]>(Prisma.sql`
      SELECT l.id, l.name
      FROM locations l
      JOIN location_types lt ON lt.id = l.location_type_id
      WHERE l.id = ${locationId}::uuid
        AND l.status = 'published'::location_status
        AND l.deleted_at IS NULL
        AND lt.code IN ${MARINA_TYPES}
    `);
    return rows.length > 0 ? rows[0] : null;
  }

  async findMyBoat(userId: string): Promise<MyMarinaBoat | null> {
    const rows = await this.prisma.$queryRaw<MyBoatRow[]>(Prisma.sql`
      SELECT ${MY_BOAT_SELECT}
      FROM boats b
      JOIN boat_types bt ON bt.id = b.boat_type_id
      LEFT JOIN locations l ON l.id = b.home_marina_location_id
      WHERE b.owner_user_id = ${userId}::uuid AND b.deleted_at IS NULL
      ORDER BY b.is_primary DESC, b.created_at ASC
      LIMIT 1
    `);
    return rows.length > 0 ? toMyBoat(rows[0]) : null;
  }

  async upsertMyBoat(userId: string, input: UpsertMyBoatInput): Promise<MyMarinaBoat> {
    // Yazma SAHİPLİK bağlamıyla koşar (RLS ikinci fren). Birincil tekne varsa
    // güncellenir; yoksa birincil olarak oluşturulur (mobil V1 = tek tekne).
    const rows = await this.prisma.withUserContext(userId, (tx) =>
      tx.$queryRaw<MyBoatRow[]>(Prisma.sql`
        WITH mevcut AS (
          SELECT id FROM boats
          WHERE owner_user_id = ${userId}::uuid AND deleted_at IS NULL
          ORDER BY is_primary DESC, created_at ASC
          LIMIT 1
        ), guncel AS (
          UPDATE boats b SET
            name = ${input.name},
            boat_type_id = (SELECT id FROM boat_types WHERE code = ${input.boatTypeCode}),
            length_m = ${input.lengthM},
            brand = ${input.brand ?? null},
            model = ${input.model ?? null},
            build_year = ${input.buildYear ?? null},
            home_marina_location_id = ${input.marinaLocationId}::uuid,
            visible_in_marina = ${input.visible},
            share_specs = ${input.shareSpecs},
            -- TEKNENİN HİKÂYESİ (0024): alan GÖNDERİLMEDİYSE dokunulmaz
            -- (anahtar değişikliği hikâyeyi silmesin!); yalnız metin
            -- DEĞİŞİNCE 'pending' olur; silinen hikâye nötr 'approved'.
            story = CASE WHEN ${input.story !== undefined}
              THEN ${input.story ?? null} ELSE b.story END,
            story_status = CASE
              WHEN NOT ${input.story !== undefined} THEN b.story_status
              WHEN ${input.story ?? null}::text IS NULL THEN 'approved'
              WHEN b.story IS DISTINCT FROM ${input.story ?? null}::text THEN 'pending'
              ELSE b.story_status END,
            updated_at = now()
          FROM mevcut WHERE b.id = mevcut.id
          RETURNING b.*
        ), yeni AS (
          INSERT INTO boats (owner_user_id, name, boat_type_id, length_m, brand,
                             model, build_year,
                             home_marina_location_id, visible_in_marina, share_specs,
                             is_primary, story, story_status)
          SELECT ${userId}::uuid, ${input.name},
                 (SELECT id FROM boat_types WHERE code = ${input.boatTypeCode}),
                 ${input.lengthM}, ${input.brand ?? null},
                 ${input.model ?? null}, ${input.buildYear ?? null},
                 ${input.marinaLocationId}::uuid, ${input.visible}, ${input.shareSpecs},
                 true, ${input.story ?? null},
                 CASE WHEN ${input.story ?? null}::text IS NULL
                      THEN 'approved' ELSE 'pending' END
          WHERE NOT EXISTS (SELECT 1 FROM mevcut)
          RETURNING *
        ), tekne AS (
          SELECT * FROM guncel UNION ALL SELECT * FROM yeni
        ), hikaye_gorevi AS (
          -- Bekleyen hikâye moderasyon kuyruğuna düşer; aynı tekne için
          -- görev TEK satırdır — yeni metin eski kararı sıfırlayıp yeniden
          -- 'pending' yapar (rota/not desenin tekne hâli).
          INSERT INTO moderation_tasks (entity_type, entity_id, status)
          SELECT 'boat_story'::moderation_entity, tekne.id,
                 'pending'::moderation_status
          FROM tekne WHERE tekne.story_status = 'pending'
          ON CONFLICT (entity_type, entity_id) DO UPDATE SET
            status = 'pending'::moderation_status,
            decided_by_user_id = NULL, decided_at = NULL,
            decision_note = NULL, updated_at = now()
        )
        SELECT b.id AS "boatId", b.name, bt.code AS "boatTypeCode",
               b.length_m AS "lengthM", b.brand, b.model, b.build_year AS "buildYear",
               l.id AS "marinaId", l.name AS "marinaName",
               b.visible_in_marina AS visible, b.share_specs AS "shareSpecs",
               b.story, b.story_status AS "storyStatus"
        FROM tekne b
        JOIN boat_types bt ON bt.id = b.boat_type_id
        LEFT JOIN locations l ON l.id = b.home_marina_location_id
      `),
    );
    return toMyBoat(rows[0]);
  }

  async boatTypeValid(code: string): Promise<boolean> {
    const row = await this.prisma.boatType.findUnique({ where: { code } });
    return row !== null && row.isActive;
  }

  async isMemberOf(userId: string, locationId: string): Promise<boolean> {
    const rows = await this.prisma.$queryRaw<{ ok: boolean }[]>(Prisma.sql`
      SELECT EXISTS (
        SELECT 1 FROM boats
        WHERE owner_user_id = ${userId}::uuid
          AND home_marina_location_id = ${locationId}::uuid
          AND deleted_at IS NULL
      ) AS ok
    `);
    return Boolean(rows[0]?.ok);
  }

  async counts(locationId: string): Promise<{ total: number; visibleCount: number }> {
    const rows = await this.prisma.$queryRaw<{ total: number; visibleCount: number }[]>(
      Prisma.sql`
        SELECT count(*)::int AS total,
               count(*) FILTER (WHERE visible_in_marina)::int AS "visibleCount"
        FROM boats
        WHERE home_marina_location_id = ${locationId}::uuid AND deleted_at IS NULL
      `,
    );
    return {
      total: Number(rows[0]?.total ?? 0),
      visibleCount: Number(rows[0]?.visibleCount ?? 0),
    };
  }

  async visibleBoats(locationId: string): Promise<MarinaBoat[]> {
    // GİZLİLİK SQL'DE: visible=false satır hiç seçilmez; shareSpecs=false ise
    // boy/marka NULL'lanır — istemciye inmeyen veri "gizlenmiş" değil YOKTUR.
    const rows = await this.prisma.$queryRaw<
      {
        boatId: string;
        name: string;
        boatTypeCode: string;
        lengthM: unknown;
        brand: string | null;
        captainName: string | null;
      }[]
    >(Prisma.sql`
      SELECT b.id AS "boatId", b.name, bt.code AS "boatTypeCode",
             CASE WHEN b.share_specs THEN b.length_m END AS "lengthM",
             CASE WHEN b.share_specs THEN b.brand END AS brand,
             p.display_name AS "captainName"
      FROM boats b
      JOIN boat_types bt ON bt.id = b.boat_type_id
      LEFT JOIN user_profiles p ON p.user_id = b.owner_user_id
      WHERE b.home_marina_location_id = ${locationId}::uuid
        AND b.deleted_at IS NULL AND b.visible_in_marina
      ORDER BY b.name ASC
    `);
    return rows.map((r) => ({
      boatId: r.boatId,
      name: r.name,
      boatTypeCode: r.boatTypeCode,
      lengthM: r.lengthM === null || r.lengthM === undefined ? null : Number(r.lengthM),
      brand: r.brand,
      captainName: r.captainName ?? 'Koybul Kaptanı',
    }));
  }
}

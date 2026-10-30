import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import { BoatRepository, LookupIds, LookupResolution } from '../domain/boat.repository';
import {
  Boat,
  CreateBoatInput,
  FavoriteBoatRef,
  PublicBoatCard,
  UpdateBoatInput,
} from '../domain/boat.types';

type BoatRow = Prisma.BoatGetPayload<{ include: { boatType: true; engineType: true } }>;

@Injectable()
export class PrismaBoatRepository implements BoatRepository {
  constructor(private readonly prisma: PrismaService) {}

  async listByOwner(ownerUserId: string): Promise<Boat[]> {
    const rows = await this.prisma.withUserContext(ownerUserId, (tx) =>
      tx.boat.findMany({
        where: { ownerUserId, deletedAt: null },
        include: { boatType: true, engineType: true },
        orderBy: [{ isPrimary: 'desc' }, { createdAt: 'desc' }],
      }),
    );
    return rows.map((r) => this.toBoat(r));
  }

  async findOwned(ownerUserId: string, boatId: string): Promise<Boat | null> {
    const row = await this.prisma.withUserContext(ownerUserId, (tx) =>
      tx.boat.findFirst({
        where: { id: boatId, ownerUserId, deletedAt: null },
        include: { boatType: true, engineType: true },
      }),
    );
    return row ? this.toBoat(row) : null;
  }

  async countActiveByOwner(ownerUserId: string): Promise<number> {
    return this.prisma.withUserContext(ownerUserId, (tx) =>
      tx.boat.count({ where: { ownerUserId, deletedAt: null } }),
    );
  }

  async resolveLookups(input: {
    boatTypeCode?: string;
    engineTypeCode?: string | null;
    flagCountryCode?: string | null;
  }): Promise<LookupResolution> {
    const [boatType, engineType, country] = await Promise.all([
      input.boatTypeCode
        ? this.prisma.boatType.findUnique({ where: { code: input.boatTypeCode } })
        : Promise.resolve(null),
      input.engineTypeCode
        ? this.prisma.engineType.findUnique({ where: { code: input.engineTypeCode } })
        : Promise.resolve(null),
      input.flagCountryCode
        ? this.prisma.country.findUnique({ where: { code: input.flagCountryCode } })
        : Promise.resolve(null),
    ]);
    return {
      boatTypeId: boatType?.id ?? null,
      engineTypeId: engineType?.id ?? null,
      countryValid: input.flagCountryCode ? country !== null : true,
    };
  }

  async create(
    id: string,
    ownerUserId: string,
    input: CreateBoatInput,
    ids: LookupIds,
  ): Promise<Boat> {
    const row = await this.prisma.withUserContext(ownerUserId, async (tx) => {
      const activeCount = await tx.boat.count({ where: { ownerUserId, deletedAt: null } });
      // İlk tekne veya açık isPrimary=true → birincil olacak; önce mevcut birincil devredilir.
      const makePrimary = activeCount === 0 || input.isPrimary === true;
      if (makePrimary) {
        await tx.boat.updateMany({
          where: { ownerUserId, isPrimary: true, deletedAt: null },
          data: { isPrimary: false },
        });
      }
      return tx.boat.create({
        data: {
          id,
          ownerUserId,
          name: input.name,
          boatTypeId: ids.boatTypeId!,
          lengthM: new Prisma.Decimal(input.lengthM),
          brand: input.brand ?? null,
          model: input.model ?? null,
          buildYear: input.buildYear ?? null,
          beamM: input.beamM != null ? new Prisma.Decimal(input.beamM) : null,
          draftM: input.draftM != null ? new Prisma.Decimal(input.draftM) : null,
          engineTypeId: ids.engineTypeId ?? null,
          flagCountryCode: input.flagCountryCode ?? null,
          registrationNo: input.registrationNo ?? null,
          isPrimary: makePrimary,
        },
        include: { boatType: true, engineType: true },
      });
    });
    return this.toBoat(row);
  }

  async update(
    ownerUserId: string,
    boatId: string,
    patch: UpdateBoatInput,
    ids: LookupIds,
  ): Promise<Boat> {
    const row = await this.prisma.withUserContext(ownerUserId, async (tx) => {
      if (patch.isPrimary === true) {
        await tx.boat.updateMany({
          where: { ownerUserId, isPrimary: true, deletedAt: null, id: { not: boatId } },
          data: { isPrimary: false },
        });
      }
      return tx.boat.update({
        where: { id: boatId },
        data: {
          ...(patch.name !== undefined ? { name: patch.name } : {}),
          ...(ids.boatTypeId !== undefined ? { boatTypeId: ids.boatTypeId } : {}),
          ...(patch.brand !== undefined ? { brand: patch.brand } : {}),
          ...(patch.model !== undefined ? { model: patch.model } : {}),
          ...(patch.buildYear !== undefined ? { buildYear: patch.buildYear } : {}),
          ...(patch.lengthM !== undefined ? { lengthM: new Prisma.Decimal(patch.lengthM) } : {}),
          ...(patch.beamM !== undefined
            ? { beamM: patch.beamM != null ? new Prisma.Decimal(patch.beamM) : null }
            : {}),
          ...(patch.draftM !== undefined
            ? { draftM: patch.draftM != null ? new Prisma.Decimal(patch.draftM) : null }
            : {}),
          ...(ids.engineTypeId !== undefined ? { engineTypeId: ids.engineTypeId } : {}),
          ...(patch.flagCountryCode !== undefined
            ? { flagCountryCode: patch.flagCountryCode }
            : {}),
          ...(patch.registrationNo !== undefined ? { registrationNo: patch.registrationNo } : {}),
          ...(patch.isPrimary === true ? { isPrimary: true } : {}),
        },
        include: { boatType: true, engineType: true },
      });
    });
    return this.toBoat(row);
  }

  async softDelete(ownerUserId: string, boatId: string, actorUserId: string): Promise<void> {
    await this.prisma.withUserContext(ownerUserId, (tx) =>
      tx.boat.updateMany({
        where: { id: boatId, ownerUserId, deletedAt: null },
        data: { deletedAt: new Date(), deletedBy: actorUserId, isPrimary: false },
      }),
    );
  }

  async promoteNewPrimaryIfNeeded(ownerUserId: string): Promise<void> {
    await this.prisma.withUserContext(ownerUserId, async (tx) => {
      const hasPrimary = await tx.boat.findFirst({
        where: { ownerUserId, isPrimary: true, deletedAt: null },
        select: { id: true },
      });
      if (hasPrimary) return;
      const newest = await tx.boat.findFirst({
        where: { ownerUserId, deletedAt: null },
        orderBy: { createdAt: 'desc' },
        select: { id: true },
      });
      if (newest) {
        await tx.boat.update({ where: { id: newest.id }, data: { isPrimary: true } });
      }
    });
  }

  /**
   * TEKNE KARTI (Hafta 2, kurucu onayı 2026-10-24). Kullanıcı bağlamı YOK:
   * okuma kamuya açıktır (kaptan kartı deposuyla aynı ilke). Görünürlük
   * süzgeci SORGUDA: visible_in_marina kapalı tekne bulunamaz; shareSpecs
   * kapalıysa teknik alanlar istemciye hiç inmez.
   */
  async publicCard(boatId: string): Promise<PublicBoatCard | null> {
    const row = await this.prisma.boat.findFirst({
      where: {
        id: boatId,
        deletedAt: null,
        visibleInMarina: true,
        owner: { deletedAt: null, status: 'active' },
      },
      select: {
        id: true,
        name: true,
        brand: true,
        model: true,
        buildYear: true,
        lengthM: true,
        shareSpecs: true,
        ownerUserId: true,
        story: true,
        storyStatus: true,
        boatType: { select: { code: true } },
        homeMarinaLocation: { select: { id: true, name: true } },
        owner: {
          select: {
            profile: { select: { displayName: true } },
            reputation: { select: { levelCode: true } },
          },
        },
      },
    });
    if (!row) return null;
    // Kart istatistikleri + rota listesi (0024): kaptanın ZATEN herkese
    // açık içeriğinden türetilir — tek tur ham SQL, kopya veri saklanmaz.
    const owner = row.ownerUserId;
    const [statRows, routeRows, socialRows, sisterRows] = await Promise.all([
      this.prisma.$queryRaw<{ trips: number; pruva: number; routes: number }[]>(Prisma.sql`
        SELECT
          (SELECT count(*)::int FROM shared_trips t
            WHERE t.user_id = ${owner}::uuid AND t.deleted_at IS NULL) AS trips,
          (SELECT COALESCE(sum(t.pruva_count), 0)::int FROM shared_trips t
            WHERE t.user_id = ${owner}::uuid AND t.deleted_at IS NULL) AS pruva,
          (SELECT count(*)::int FROM routes r
            WHERE r.user_id = ${owner}::uuid
              AND r.status = 'approved'::moderation_status
              AND r.deleted_at IS NULL) AS routes
      `),
      this.prisma.$queryRaw<
        { id: string; name: string; distanceNm: unknown; saveCount: number }[]
      >(Prisma.sql`
        SELECT r.id, r.name, r.distance_nm AS "distanceNm",
               r.save_count AS "saveCount"
        FROM routes r
        WHERE r.user_id = ${owner}::uuid
          AND r.status = 'approved'::moderation_status AND r.deleted_at IS NULL
        ORDER BY r.created_at DESC
        LIMIT 5
      `),
      // FAVORİLE + TAKİPÇİ (TK-5): iki herkese açık sayı tek turda.
      this.prisma.$queryRaw<{ favs: number; followers: number }[]>(Prisma.sql`
        SELECT
          (SELECT count(*)::int FROM boat_favorites f
            WHERE f.boat_id = ${row.id}::uuid) AS favs,
          (SELECT count(*)::int FROM user_follows uf
            WHERE uf.followed_id = ${owner}::uuid) AS followers
      `),
      // KARDEŞ TEKNELER (TK-5): aynı marka+model (büyük/küçük harf dengeli),
      // yalnız ÇİFTE RIZALI (görünür + teknik paylaşımlı) tekneler. Bu kartın
      // kendisi de teknik paylaşmıyorsa eşleşme aranmaz (boş liste).
      row.shareSpecs && row.brand && row.model
        ? this.prisma.$queryRaw<
            { id: string; name: string; typeCode: string; marinaName: string | null }[]
          >(Prisma.sql`
            SELECT b.id, b.name, bt.code AS "typeCode", l.name AS "marinaName"
            FROM boats b
            JOIN boat_types bt ON bt.id = b.boat_type_id
            LEFT JOIN locations l ON l.id = b.home_marina_location_id
            JOIN users u ON u.id = b.owner_user_id
            WHERE b.id <> ${row.id}::uuid
              AND b.deleted_at IS NULL
              AND b.visible_in_marina = true
              AND b.share_specs = true
              AND u.deleted_at IS NULL AND u.status = 'active'
              AND lower(trim(b.brand)) = lower(trim(${row.brand}))
              AND lower(trim(b.model)) = lower(trim(${row.model}))
            ORDER BY b.created_at DESC
            LIMIT 5
          `)
        : Promise.resolve([]),
    ]);
    const specs = row.shareSpecs;
    return {
      id: row.id,
      name: row.name,
      boatTypeCode: row.boatType.code,
      brand: specs ? row.brand : null,
      model: specs ? row.model : null,
      lengthM: specs ? row.lengthM.toNumber() : null,
      buildYear: specs ? row.buildYear : null,
      marina: row.homeMarinaLocation
        ? { id: row.homeMarinaLocation.id, name: row.homeMarinaLocation.name }
        : null,
      captain: {
        userId: row.ownerUserId,
        displayName: row.owner.profile?.displayName ?? 'Koybul Kaptanı',
        levelCode: row.owner.reputation?.levelCode ?? 'new',
      },
      // Yalnız ONAYLI hikâye iner (bekleyen/reddedilen kartta yoktur).
      story: row.storyStatus === 'approved' ? row.story : null,
      stats: {
        sharedTrips: Number(statRows[0]?.trips ?? 0),
        sharedRoutes: Number(statRows[0]?.routes ?? 0),
        pruvaTotal: Number(statRows[0]?.pruva ?? 0),
      },
      routes: routeRows.map((r) => ({
        id: r.id,
        name: r.name,
        distanceNm: Number(r.distanceNm),
        saveCount: r.saveCount,
      })),
      favoriteCount: Number(socialRows[0]?.favs ?? 0),
      captainFollowers: Number(socialRows[0]?.followers ?? 0),
      sisters: sisterRows.map((s) => ({
        id: s.id,
        name: s.name,
        boatTypeCode: s.typeCode,
        marinaName: s.marinaName,
      })),
    };
  }

  /**
   * FAVORİLE (TK-5, 0025). Tek sorgu: tekne hâlâ görünür + sahibi aktifse
   * ekler (ON CONFLICT sessiz) — görünmez tekneye kalp atılamaz (kartla
   * aynı 404 ilkesi). RLS owner politikası kullanıcı bağlamıyla sağlanır.
   */
  async addFavorite(userId: string, boatId: string): Promise<boolean> {
    const rows = await this.prisma.withUserContext(userId, (tx) =>
      tx.$queryRaw<{ id: string }[]>(Prisma.sql`
        INSERT INTO boat_favorites (user_id, boat_id)
        SELECT ${userId}::uuid, b.id
        FROM boats b
        JOIN users u ON u.id = b.owner_user_id
        WHERE b.id = ${boatId}::uuid
          AND b.deleted_at IS NULL
          AND b.visible_in_marina = true
          AND b.owner_user_id <> ${userId}::uuid
          AND u.deleted_at IS NULL AND u.status = 'active'
        ON CONFLICT (user_id, boat_id) DO UPDATE SET user_id = EXCLUDED.user_id
        RETURNING boat_id AS id
      `),
    );
    return rows.length > 0;
  }

  async removeFavorite(userId: string, boatId: string): Promise<void> {
    await this.prisma.withUserContext(userId, (tx) =>
      tx.boatFavorite.deleteMany({ where: { userId, boatId } }),
    );
  }

  async countFavoritesByUser(userId: string): Promise<number> {
    return this.prisma.withUserContext(userId, (tx) =>
      tx.boatFavorite.count({ where: { userId } }),
    );
  }

  /** Favori listesi: yalnız HÂLÂ görünür tekneler; teknik alanlar rızaya bağlı. */
  async listFavorites(userId: string): Promise<FavoriteBoatRef[]> {
    const rows = await this.prisma.withUserContext(userId, (tx) =>
      tx.$queryRaw<
        {
          id: string;
          name: string;
          typeCode: string;
          brand: string | null;
          model: string | null;
          shareSpecs: boolean;
          marinaName: string | null;
        }[]
      >(Prisma.sql`
        SELECT b.id, b.name, bt.code AS "typeCode", b.brand, b.model,
               b.share_specs AS "shareSpecs", l.name AS "marinaName"
        FROM boat_favorites f
        JOIN boats b ON b.id = f.boat_id
        JOIN boat_types bt ON bt.id = b.boat_type_id
        LEFT JOIN locations l ON l.id = b.home_marina_location_id
        JOIN users u ON u.id = b.owner_user_id
        WHERE f.user_id = ${userId}::uuid
          AND b.deleted_at IS NULL
          AND b.visible_in_marina = true
          AND u.deleted_at IS NULL AND u.status = 'active'
        ORDER BY f.created_at DESC
        LIMIT 200
      `),
    );
    return rows.map((r) => ({
      id: r.id,
      name: r.name,
      boatTypeCode: r.typeCode,
      brand: r.shareSpecs ? r.brand : null,
      model: r.shareSpecs ? r.model : null,
      marinaName: r.marinaName,
    }));
  }

  private toBoat(row: BoatRow): Boat {
    return {
      id: row.id,
      name: row.name,
      boatTypeCode: row.boatType.code,
      brand: row.brand,
      model: row.model,
      buildYear: row.buildYear,
      lengthM: row.lengthM.toNumber(),
      beamM: row.beamM ? row.beamM.toNumber() : null,
      draftM: row.draftM ? row.draftM.toNumber() : null,
      engineTypeCode: row.engineType?.code ?? null,
      flagCountryCode: row.flagCountryCode,
      registrationNo: row.registrationNo,
      isPrimary: row.isPrimary,
      createdAt: row.createdAt.toISOString(),
    };
  }
}

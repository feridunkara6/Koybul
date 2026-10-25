import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import { BoatRepository, LookupIds, LookupResolution } from '../domain/boat.repository';
import { Boat, CreateBoatInput, UpdateBoatInput } from '../domain/boat.types';

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

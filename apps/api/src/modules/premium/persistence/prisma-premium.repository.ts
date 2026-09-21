import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import { PremiumRepository } from '../domain/premium.repository';

/**
 * Premium yansıması + keşif-hakkı defteri (P1). Yazma yolu withUserContext ile
 * koşar (RLS sahibi politikası: exploration_unlocks yalnız sahibine yazılır).
 */
@Injectable()
export class PrismaPremiumRepository implements PremiumRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findPremiumUntil(userId: string): Promise<Date | null> {
    const row = await this.prisma.user.findFirst({
      where: { id: userId, deletedAt: null },
      select: { premiumUntil: true },
    });
    return row?.premiumUntil ?? null;
  }

  async findSubscription(
    userId: string,
  ): Promise<{ premiumUntil: Date | null; productId: string | null }> {
    const row = await this.prisma.user.findFirst({
      where: { id: userId, deletedAt: null },
      select: { premiumUntil: true, premiumProductId: true },
    });
    return { premiumUntil: row?.premiumUntil ?? null, productId: row?.premiumProductId ?? null };
  }

  async countUnlocks(userId: string, monthKey: string): Promise<number> {
    return this.prisma.explorationUnlock.count({ where: { userId, monthKey } });
  }

  async hasUnlock(userId: string, locationId: string, monthKey: string): Promise<boolean> {
    const row = await this.prisma.explorationUnlock.findUnique({
      where: { userId_locationId_monthKey: { userId, locationId, monthKey } },
      select: { userId: true },
    });
    return row !== null;
  }

  async createUnlock(
    userId: string,
    locationId: string,
    monthKey: string,
    monthlyLimit: number,
  ): Promise<'created' | 'existing' | 'quota'> {
    // Tek transaksiyon: say → sınır altındaysa yaz. PK (user, location, month)
    // aynı koyun tekrar açılmasını veritabanında da tekilleştirir; yarış anında
    // çifte tüketim PK'ye takılır ve 'existing' sayılır.
    return this.prisma.withUserContext(userId, async (tx) => {
      const existing = await tx.explorationUnlock.findUnique({
        where: { userId_locationId_monthKey: { userId, locationId, monthKey } },
        select: { userId: true },
      });
      if (existing) return 'existing';

      const used = await tx.explorationUnlock.count({ where: { userId, monthKey } });
      if (used >= monthlyLimit) return 'quota';

      await tx.explorationUnlock.create({ data: { userId, locationId, monthKey } });
      return 'created';
    });
  }

  async findUserIdByOriginalTransactionId(originalTransactionId: string): Promise<string | null> {
    const row = await this.prisma.user.findUnique({
      where: { appleOriginalTransactionId: originalTransactionId },
      select: { id: true },
    });
    return row?.id ?? null;
  }

  async saveSubscription(
    userId: string,
    state: { premiumUntil: Date | null; productId: string | null; originalTransactionId: string },
  ): Promise<void> {
    // Altyapı yolu (bildirim işleyici kullanıcı bağlamı DIŞINDA da çağırır);
    // users tablosunda RLS'in IS NULL kolu bu yazmaya izin verir.
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        premiumUntil: state.premiumUntil,
        premiumProductId: state.productId,
        appleOriginalTransactionId: state.originalTransactionId,
      },
    });
  }
}

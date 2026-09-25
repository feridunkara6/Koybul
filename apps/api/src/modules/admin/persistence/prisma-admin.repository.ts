import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import { AdminRepository, AdminStats } from '../domain/admin.repository';

@Injectable()
export class PrismaAdminRepository implements AdminRepository {
  constructor(private readonly prisma: PrismaService) {}

  async stats(now: Date): Promise<AdminStats> {
    const weekAgo = new Date(now.getTime() - 7 * 24 * 3600 * 1000);
    const [totalUsers, guestUsers, newUsers7d, premiumActive, pendingModeration, totalReviews, totalNotes] =
      await Promise.all([
        this.prisma.user.count({ where: { isGuest: false, deletedAt: null } }),
        this.prisma.user.count({ where: { isGuest: true, deletedAt: null } }),
        this.prisma.user.count({
          where: { isGuest: false, deletedAt: null, createdAt: { gte: weekAgo } },
        }),
        this.prisma.user.count({ where: { deletedAt: null, premiumUntil: { gt: now } } }),
        this.prisma.moderationTask.count({ where: { status: 'pending' } }),
        this.prisma.review.count(),
        this.prisma.locationNote.count(),
      ]);
    return { totalUsers, guestUsers, newUsers7d, premiumActive, pendingModeration, totalReviews, totalNotes };
  }

  async findUserByEmail(
    email: string,
  ): Promise<{ id: string; email: string; premiumUntil: Date | null } | null> {
    // email kolonu citext'tir — eşitlik veritabanında zaten harf duyarsızdır.
    const u = await this.prisma.user.findFirst({
      where: { email, isGuest: false, deletedAt: null },
      select: { id: true, email: true, premiumUntil: true },
    });
    return u?.email ? { id: u.id, email: u.email, premiumUntil: u.premiumUntil } : null;
  }

  async setPremium(userId: string, until: Date, productId: string): Promise<void> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { premiumUntil: until, premiumProductId: productId },
    });
  }
}

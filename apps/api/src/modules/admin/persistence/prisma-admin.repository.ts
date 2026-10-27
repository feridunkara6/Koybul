import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import {
  AdminContentRow,
  AdminContentType,
  AdminRepository,
  AdminStats,
} from '../domain/admin.repository';

@Injectable()
export class PrismaAdminRepository implements AdminRepository {
  constructor(private readonly prisma: PrismaService) {}

  async stats(now: Date): Promise<AdminStats> {
    const weekAgo = new Date(now.getTime() - 7 * 24 * 3600 * 1000);
    const [
      totalUsers,
      guestUsers,
      newUsers7d,
      premiumActive,
      pendingModeration,
      totalReviews,
      totalNotes,
    ] = await Promise.all([
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
    return {
      totalUsers,
      guestUsers,
      newUsers7d,
      premiumActive,
      pendingModeration,
      totalReviews,
      totalNotes,
    };
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

  // ==========================================================================
  // İÇERİK YÖNETİMİ (kurucu talebi 2026-10-27) — tür başına liste + silme.
  // Liste yalnız SİLİNMEMİŞLERİ gösterir; silme YUMUŞAKTIR (deleted_at) ve
  // modüllerin sahip-silme SQL'leriyle aynı dili konuşur.
  // ==========================================================================

  async listContent(type: AdminContentType, limit: number): Promise<AdminContentRow[]> {
    const q = (sql: Prisma.Sql): Promise<AdminContentRow[]> =>
      this.prisma.$queryRaw<AdminContentRow[]>(sql);
    switch (type) {
      case 'routes':
        return q(Prisma.sql`
          SELECT r.id, r.name AS title, p.display_name AS "authorName",
                 r.status::text AS status, r.created_at AS "createdAt"
          FROM routes r LEFT JOIN user_profiles p ON p.user_id = r.user_id
          WHERE r.deleted_at IS NULL
          ORDER BY r.created_at DESC LIMIT ${limit}`);
      case 'questions':
        return q(Prisma.sql`
          SELECT x.id, x.title, p.display_name AS "authorName",
                 x.status::text AS status, x.created_at AS "createdAt"
          FROM qa_questions x LEFT JOIN user_profiles p ON p.user_id = x.user_id
          WHERE x.deleted_at IS NULL
          ORDER BY x.created_at DESC LIMIT ${limit}`);
      case 'answers':
        return q(Prisma.sql`
          SELECT a.id, left(a.body, 120) AS title, p.display_name AS "authorName",
                 a.status::text AS status, a.created_at AS "createdAt"
          FROM qa_answers a LEFT JOIN user_profiles p ON p.user_id = a.user_id
          WHERE a.deleted_at IS NULL
          ORDER BY a.created_at DESC LIMIT ${limit}`);
      case 'notes':
        return q(Prisma.sql`
          SELECT n.id, COALESCE(n.title, left(n.body, 120)) AS title,
                 p.display_name AS "authorName",
                 n.status::text AS status, n.created_at AS "createdAt"
          FROM location_notes n LEFT JOIN user_profiles p ON p.user_id = n.user_id
          WHERE n.deleted_at IS NULL
          ORDER BY n.created_at DESC LIMIT ${limit}`);
      case 'reviews':
        return q(Prisma.sql`
          SELECT v.id, COALESCE(v.title, left(v.body, 120)) AS title,
                 p.display_name AS "authorName",
                 v.status::text AS status, v.created_at AS "createdAt"
          FROM reviews v LEFT JOIN user_profiles p ON p.user_id = v.user_id
          WHERE v.deleted_at IS NULL
          ORDER BY v.created_at DESC LIMIT ${limit}`);
      case 'boats':
        return q(Prisma.sql`
          SELECT b.id,
                 b.name || COALESCE(' · ' || b.brand, '') AS title,
                 p.display_name AS "authorName",
                 CASE WHEN b.visible_in_marina THEN 'visible' ELSE 'hidden' END AS status,
                 b.created_at AS "createdAt"
          FROM boats b LEFT JOIN user_profiles p ON p.user_id = b.owner_user_id
          WHERE b.deleted_at IS NULL
          ORDER BY b.created_at DESC LIMIT ${limit}`);
    }
  }

  /** Tür → tablo + moderasyon varlık adı (bekleyen görev kapatılır). */
  private static readonly CONTENT_TABLE: Record<
    AdminContentType,
    { table: string; entity: string | null; fixup: 'answers' | null }
  > = {
    routes: { table: 'routes', entity: 'route', fixup: null },
    questions: { table: 'qa_questions', entity: 'qa_question', fixup: null },
    answers: { table: 'qa_answers', entity: 'qa_answer', fixup: 'answers' },
    notes: { table: 'location_notes', entity: 'note', fixup: null },
    reviews: { table: 'reviews', entity: 'review', fixup: null },
    boats: { table: 'boats', entity: null, fixup: null },
  };

  async deleteContent(type: AdminContentType, id: string): Promise<boolean> {
    const meta = PrismaAdminRepository.CONTENT_TABLE[type];
    return this.prisma.$transaction(async (tx) => {
      const n = await tx.$executeRaw(Prisma.sql`
        UPDATE ${Prisma.raw(meta.table)}
        SET deleted_at = now(), updated_at = now()
        WHERE id = ${id}::uuid AND deleted_at IS NULL
      `);
      if (n === 0) return false;
      if (meta.entity !== null) {
        await tx.$executeRaw(Prisma.sql`
          UPDATE moderation_tasks
          SET status = 'rejected'::moderation_status, decision_note = 'admin_deleted',
              decided_at = now(), updated_at = now()
          WHERE entity_type = ${meta.entity}::moderation_entity
            AND entity_id = ${id}::uuid
            AND status = 'pending'::moderation_status
        `);
      }
      // DÜRÜST SAYAÇ: cevap silinince sorunun cevabı sayısı yeniden SAYILIR
      // (elle azaltma değil — ledger kuralıyla aynı ilke).
      if (meta.fixup === 'answers') {
        await tx.$executeRaw(Prisma.sql`
          UPDATE qa_questions q
          SET answers_count = (
            SELECT count(*) FROM qa_answers a
            WHERE a.question_id = q.id AND a.deleted_at IS NULL
          ), updated_at = now()
          WHERE q.id = (SELECT question_id FROM qa_answers WHERE id = ${id}::uuid)
        `);
      }
      return true;
    });
  }
}

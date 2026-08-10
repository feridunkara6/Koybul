import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import { FirebaseIdentity } from '../../../infrastructure/firebase/firebase-token.verifier';
import { UserAccountRepository } from '../domain/user-account.repository';
import { UserAccount } from '../domain/auth.types';
import { RoleCode } from '../../../core/auth/principal';
import { AppProblem } from '../../../common/problem/problem';

@Injectable()
export class PrismaUserAccountRepository implements UserAccountRepository {
  constructor(private readonly prisma: PrismaService) {}

  async upsertFromIdentity(id: string, identity: FirebaseIdentity): Promise<UserAccount> {
    const now = new Date();
    const isGuestLogin = identity.provider === 'anonymous';

    const existing = await this.prisma.user.findUnique({
      where: { firebaseUid: identity.uid },
      include: { role: true },
    });

    if (existing) {
      if (existing.status === 'suspended' || existing.deletedAt !== null) {
        throw new AppProblem('forbidden', 'Hesap kullanıma kapalı.');
      }
      const updated = await this.prisma.user.update({
        where: { id: existing.id },
        data: {
          lastSignInAt: now,
          // Misafir → kayıtlı yükseltme: firebase_uid sabit, satır aynı (docs/23 §3.3).
          isGuest: existing.isGuest && !isGuestLogin ? false : existing.isGuest,
          email: identity.email ?? existing.email,
          emailVerifiedAt:
            identity.emailVerified && existing.emailVerifiedAt === null
              ? now
              : existing.emailVerifiedAt,
          phone: identity.phone ?? existing.phone,
          // Firebase phone sağlayıcısı numarayı doğrulamış demektir (docs/29 SEC-17 temeli).
          phoneVerifiedAt:
            identity.phone && existing.phoneVerifiedAt === null ? now : existing.phoneVerifiedAt,
        },
        include: { role: true },
      });
      return this.toAccount(updated.id, updated.firebaseUid, updated.role.code, updated);
    }

    const created = await this.prisma.user.create({
      data: {
        id,
        firebaseUid: identity.uid,
        email: identity.email,
        emailVerifiedAt: identity.emailVerified ? now : null,
        phone: identity.phone,
        phoneVerifiedAt: identity.phone ? now : null,
        isGuest: isGuestLogin,
        lastSignInAt: now,
      },
      include: { role: true },
    });
    return this.toAccount(created.id, created.firebaseUid, created.role.code, created);
  }

  async promoteToModerator(userId: string): Promise<RoleCode> {
    // Tek sorguda: yalnız `user` rolündeki satır güncellenir, sonuç okunur.
    // KOŞUL SQL'DE (JS'te değil): iki eşzamanlı giriş yarışırsa ikisi de
    // aynı sonucu yazar, hiçbiri daha yüksek bir rolü ezmez.
    const rows = await this.prisma.$queryRaw<{ code: RoleCode }[]>(Prisma.sql`
      WITH target AS (SELECT id FROM roles WHERE code = 'moderator'),
      upd AS (
        UPDATE users u
           SET role_id = (SELECT id FROM target), updated_at = now()
         WHERE u.id = ${userId}::uuid
           AND u.role_id = (SELECT id FROM roles WHERE code = 'user')
           AND u.is_guest = false
           AND u.status = 'active'
           AND u.deleted_at IS NULL
           -- 'moderator' satırı yoksa (seed uygulanmamış) role_id NULL olurdu
           -- ve NOT NULL kısıtı HER GİRİŞTE patlardı. Sessizce hiçbir şey yapma.
           AND EXISTS (SELECT 1 FROM target)
        RETURNING u.role_id
      )
      SELECT r.code AS code
        FROM roles r
       WHERE r.id = COALESCE(
               (SELECT role_id FROM upd),
               -- CTE gorunurlugu: bu alt sorgu UPDATE ONCESI anlik goruntuyu
               -- okur. Sorun degil: yalniz upd bosken, yani hicbir sey
               -- degismemisken degerlendirilir; o durumda dogru cevap zaten
               -- eski roldur.
               (SELECT role_id FROM users WHERE id = ${userId}::uuid)
             )
    `);
    const role = rows[0]?.code ?? 'user';

    // YETKİ ARTIŞI KALICI İZ BIRAKMALIDIR. stdout log'u dönerli (rotate edilir)
    // ve olay incelemesinde kaybolur; `audit_logs` kalıcıdır. Yazımı ana akışı
    // düşürmez — yetki zaten verildi, iz atılamadıysa uyarı yeter.
    if (role === 'moderator') {
      try {
        await this.prisma.auditLog.create({
          data: {
            occurredAt: new Date(),
            actorType: 'system',
            actorUserId: userId,
            action: 'user.role_promoted',
            entityType: 'user',
            entityId: userId,
            oldValues: { role: 'user' },
            newValues: { role: 'moderator', source: 'MODERATOR_EMAILS' },
          },
        });
      } catch {
        // Denetim kaydı yazılamadı: yükseltmeyi geri almak daha kötü olurdu.
      }
    }
    return role;
  }

  async findActiveById(id: string): Promise<UserAccount | null> {
    const row = await this.prisma.user.findFirst({
      where: { id, status: 'active', deletedAt: null },
      include: { role: true },
    });
    if (!row) return null;
    return this.toAccount(row.id, row.firebaseUid, row.role.code, row);
  }

  private toAccount(
    id: string,
    firebaseUid: string,
    roleCode: string,
    row: { isGuest: boolean; locale: string; status: string },
  ): UserAccount {
    return {
      id,
      firebaseUid,
      role: roleCode as RoleCode,
      isGuest: row.isGuest,
      locale: row.locale,
      status: row.status as UserAccount['status'],
    };
  }
}

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { uuidv7 } from 'uuidv7';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import { DeletionAudit, UserRepository } from '../domain/user.repository';
import { UpdateMeInput, UserMe } from '../domain/user.types';
import { RoleCode } from '../../../core/auth/principal';

const ANONYMIZED_DISPLAY_NAME = 'Silinmiş Kullanıcı';
const DEFAULT_DISPLAY_NAME = 'Kaptan';

type UserWithRelations = Prisma.UserGetPayload<{
  include: { role: true; profile: true; settings: true };
}>;

@Injectable()
export class PrismaUserRepository implements UserRepository {
  constructor(private readonly prisma: PrismaService) {}

  async getMe(userId: string): Promise<UserMe | null> {
    return this.prisma.withUserContext(userId, async (tx) => {
      const user = await tx.user.findFirst({
        where: { id: userId, deletedAt: null },
        include: { role: true, profile: true, settings: true },
      });
      if (!user) return null;

      // Lazy init: ilk erişimde varsayılan profil/ayar satırları oluşturulur.
      // Rıza zamanları kayıt anındaki kabule dayanır (S-03 KVKK metni — docs/21).
      if (!user.profile) {
        await tx.userProfile.create({
          data: { userId, displayName: this.defaultDisplayName(userId) },
        });
      }
      if (!user.settings) {
        const now = new Date();
        await tx.userSetting.create({
          data: { userId, termsAcceptedAt: now, privacyAcceptedAt: now },
        });
      }
      if (!user.profile || !user.settings) {
        const fresh = await tx.user.findUniqueOrThrow({
          where: { id: userId },
          include: { role: true, profile: true, settings: true },
        });
        return this.toMe(fresh);
      }
      return this.toMe(user);
    });
  }

  async updateMe(userId: string, patch: UpdateMeInput): Promise<UserMe> {
    await this.prisma.withUserContext(userId, async (tx) => {
      if (patch.locale !== undefined) {
        await tx.user.update({ where: { id: userId }, data: { locale: patch.locale } });
      }
      if (patch.profile) {
        const p = patch.profile;
        await tx.userProfile.update({
          where: { userId },
          data: {
            ...(p.displayName !== undefined ? { displayName: p.displayName } : {}),
            ...(p.fullName !== undefined ? { fullName: p.fullName } : {}),
            ...(p.bio !== undefined ? { bio: p.bio } : {}),
            ...(p.experienceYears !== undefined ? { experienceYears: p.experienceYears } : {}),
          },
        });
      }
      if (patch.settings) {
        const s = patch.settings;
        await tx.userSetting.update({
          where: { userId },
          data: {
            ...(s.theme !== undefined ? { theme: s.theme === 'system' ? null : s.theme } : {}),
            ...(s.units !== undefined ? { units: s.units } : {}),
            ...(s.marketingConsent !== undefined
              ? { marketingConsentAt: s.marketingConsent ? new Date() : null }
              : {}),
          },
        });
      }
    });
    const me = await this.getMe(userId);
    if (!me) {
      // updateMe yalnız guard'lı akıştan çağrılır; satır silinmişse tutarsızlıktır.
      throw new Error('Kullanıcı güncelleme sonrası okunamadı');
    }
    return me;
  }

  async softDeleteAndAnonymize(userId: string, audit: DeletionAudit): Promise<void> {
    const now = new Date();
    await this.prisma.withUserContext(userId, async (tx) => {
      await tx.userProfile.upsert({
        where: { userId },
        create: { userId, displayName: ANONYMIZED_DISPLAY_NAME },
        update: {
          displayName: ANONYMIZED_DISPLAY_NAME,
          fullName: null,
          bio: null,
          avatarMediaId: null,
          homePortLocationId: null,
          experienceYears: null,
        },
      });
      await tx.userSetting.updateMany({
        where: { userId },
        data: { marketingConsentAt: null },
      });
      await tx.userDevice.deleteMany({ where: { userId } });
      await tx.user.update({
        where: { id: userId },
        data: {
          status: 'deleted',
          deletedAt: now,
          deletedBy: userId,
          email: null,
          emailVerifiedAt: null,
          phone: null,
          phoneVerifiedAt: null,
          // Tombstone: unique alan serbest kalır — aynı kişi dönerse YENİ hesap açılır
          // (gizlilik: silinen hesapla ilişki kurulamaz; docs/22 §1.5).
          firebaseUid: `del_${uuidv7()}`,
        },
      });
      await tx.auditLog.create({
        data: {
          occurredAt: now,
          actorType: 'user',
          actorUserId: userId,
          action: 'user.delete',
          entityType: 'user',
          entityId: userId,
          ip: audit.ip,
          requestId: audit.requestId,
        },
      });
    });
  }

  private toMe(user: UserWithRelations): UserMe {
    return {
      id: user.id,
      email: user.email,
      phone: user.phone,
      role: user.role.code as RoleCode,
      isGuest: user.isGuest,
      locale: user.locale,
      countryCode: user.countryCode,
      createdAt: user.createdAt.toISOString(),
      profile: {
        displayName: user.profile?.displayName ?? DEFAULT_DISPLAY_NAME,
        fullName: user.profile?.fullName ?? null,
        bio: user.profile?.bio ?? null,
        experienceYears: user.profile?.experienceYears ?? null,
      },
      settings: {
        theme: (user.settings?.theme ?? 'system') as UserMe['settings']['theme'],
        units: (user.settings?.units ?? 'metric') as UserMe['settings']['units'],
        marketingConsent: user.settings?.marketingConsentAt != null,
      },
    };
  }

  /**
   * Varsayılan görünen ad — E-POSTADAN TÜRETİLMEZ.
   *
   * Eskiden e-postanın yerel kısmı kullanılıyordu: `ahmet.yilmaz@gmail.com`
   * ile giren kaptanın adı her notunun ve yorumunun yanında "ahmet.yilmaz"
   * olarak HERKESE görünüyordu — kullanıcı hiç sorulmadan, üstelik yaygın
   * alan adı tahmin edilerek adresi geri bulunabilecek şekilde. KVKK
   * açısından açık bir sorun (denetim bulgusu 2026-08, Faz 0).
   *
   * Yerine: "Kaptan" + kullanıcı kimliğinden türeyen kısa, kararlı bir sonek.
   * Sonek kişisel veri DEĞİLDİR (kimliğin rastgele parçası) ve `authorId`
   * olarak yanıtlarda zaten görünür; ama iki kaptanı birbirinden ayırmaya
   * yetiyor, yani topluluk ve moderasyon kullanılabilir kalıyor.
   *
   * SON dört hane alınır, İLK dört değil: kimlikler uuidv7'dir ve onun ilk
   * 12 hanesi ZAMAN DAMGASIDIR — baştan dört hane yaklaşık 50 günde bir
   * değişir, yani aynı dönemde kaydolan herkes "Kaptan 019F" olurdu
   * (inceleme bulgusu 2026-08). Son haneler rastgele bölümden gelir.
   */
  private defaultDisplayName(userId: string): string {
    const suffix = userId.replace(/-/g, '').slice(-4).toUpperCase();
    return suffix.length === 4 ? `${DEFAULT_DISPLAY_NAME} ${suffix}` : DEFAULT_DISPLAY_NAME;
  }
}

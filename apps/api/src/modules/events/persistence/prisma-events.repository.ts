import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import {
  CreateUserEventInput,
  DealRow,
  EventParticipant,
  EventRow,
  EventsRepository,
  PublicAttendee,
  RegisterOutcome,
  UpsertDealInput,
  UpsertEventInput,
} from '../domain/events.types';

/**
 * Etkinlik/fırsat deposu. OKUMA ve KAYIT işlemleri ALTYAPI YOLUNDAN koşar
 * (kullanıcı bağlamı YOK — bilinçli): kontenjan sayımı HERKESİN kaydını
 * saymak zorundadır; RLS sahiplik politikası kullanıcı bağlamında başkasının
 * satırını gizlerdi. Sahiplik güvenliği burada kod sözleşmesiyle sağlanır —
 * userId her zaman doğrulanmış Principal'dan gelir, istemci beyanından asla.
 *
 * KONTENJAN KİLİDİ: kayıt tek transaction'da "etkinlik satırını kilitle →
 * say → yaz" yapar; iki kişi son koltuğa aynı anda bassa da Postgres satır
 * kilidi ikinciyi bekletir ve ikinci sayım doluluğu görür.
 */
@Injectable()
export class PrismaEventsRepository implements EventsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async activeDeals(): Promise<DealRow[]> {
    const rows = await this.prisma.deal.findMany({
      where: { isActive: true },
      orderBy: [{ createdAt: 'desc' }],
    });
    return rows.map((r) => ({
      id: r.id,
      title: r.title,
      partner: r.partner,
      benefit: r.benefit,
      code: r.code,
      validUntil: r.validUntil,
      terms: r.terms,
      place: r.place,
      audience: r.audience,
      isActive: r.isActive,
    }));
  }

  private eventSelect(viewerUserId: string | null): Prisma.Sql {
    return Prisma.sql`
      e.id, e.title, e.body, e.starts_at AS "startsAt", e.ends_at AS "endsAt",
      e.location_text AS "locationText", e.venue_location_id AS "venueLocationId",
      e.quota::int AS quota,
      e.registration_deadline AS "registrationDeadline",
      e.price_note AS "priceNote", e.conditions, e.organizer, e.audience, e.status,
      e.created_by AS "createdBy", e.template,
      (SELECT count(*)::int FROM event_registrations r
        WHERE r.event_id = e.id AND r.status = 'registered') AS "registeredCount",
      (${viewerUserId}::uuid IS NOT NULL AND EXISTS (
        SELECT 1 FROM event_registrations r
        WHERE r.event_id = e.id AND r.user_id = ${viewerUserId}::uuid
          AND r.status = 'registered')) AS "registeredByViewer"
    `;
  }

  async upcomingEvents(viewerUserId: string | null, now: Date): Promise<EventRow[]> {
    // GEÇMİŞ PENCERESİ (kurucu onayı 2026-10-25): son 6 ayın bitmiş
    // etkinlikleri de akışa girer — mobil, listeyi "yaklaşan / geçmiş"
    // diye ikiye böler (geçmiş bölümünde kayıt kapalıdır; register()
    // zaten son tarihi geçen etkinliği 'not-open' ile reddeder).
    // İPTAL edilen gelecek etkinlik dürüstçe 'iptal' rozetiyle görünür.
    // SP-4: bekleyen/reddedilen kullanıcı etkinliği YALNIZ sahibine görünür
    // ("paylaştım ama görünmüyor" dersi, rotalarla aynı dürüstlük) — başkasının
    // bekleyeni asla sızmaz.
    return this.prisma.$queryRaw<EventRow[]>(Prisma.sql`
      SELECT ${this.eventSelect(viewerUserId)}
      FROM events e
      WHERE COALESCE(e.ends_at, e.starts_at) >= ${now}::timestamptz - interval '6 months'
        AND (e.status IN ('published', 'cancelled')
             OR (${viewerUserId}::uuid IS NOT NULL AND e.created_by = ${viewerUserId}::uuid))
      ORDER BY e.starts_at ASC
      LIMIT 100
    `);
  }

  async findEvent(eventId: string, viewerUserId: string | null): Promise<EventRow | null> {
    const rows = await this.prisma.$queryRaw<EventRow[]>(Prisma.sql`
      SELECT ${this.eventSelect(viewerUserId)} FROM events e WHERE e.id = ${eventId}::uuid
    `);
    return rows.length > 0 ? rows[0] : null;
  }

  async register(
    eventId: string,
    userId: string,
    now: Date,
    showName: boolean,
  ): Promise<RegisterOutcome> {
    return this.prisma.$transaction(async (tx) => {
      // 1) Etkinlik satırı KİLİTLENİR — eşzamanlı kayıtlar burada sıralanır.
      const events = await tx.$queryRaw<
        { quota: number; status: string; deadline: Date | null; startsAt: Date }[]
      >(Prisma.sql`
        SELECT quota::int AS quota, status, registration_deadline AS deadline,
               starts_at AS "startsAt"
        FROM events WHERE id = ${eventId}::uuid FOR UPDATE
      `);
      if (events.length === 0) return { result: 'not-open' };
      const ev = events[0];
      const deadline = ev.deadline ?? ev.startsAt;
      if (ev.status !== 'published' || deadline.getTime() <= now.getTime()) {
        return { result: 'not-open' };
      }

      // 2) Mevcut kayıt? (registered ise idempotent dönüş)
      const mine = await tx.$queryRaw<{ status: string }[]>(Prisma.sql`
        SELECT status FROM event_registrations
        WHERE event_id = ${eventId}::uuid AND user_id = ${userId}::uuid
      `);
      const counted = await tx.$queryRaw<{ n: number }[]>(Prisma.sql`
        SELECT count(*)::int AS n FROM event_registrations
        WHERE event_id = ${eventId}::uuid AND status = 'registered'
      `);
      const n = Number(counted[0]?.n ?? 0);

      if (mine.length > 0 && mine[0].status === 'registered') {
        return { result: 'already', remaining: Math.max(0, ev.quota - n) };
      }
      if (n >= ev.quota) return { result: 'quota' };

      // 3) Yaz (iptal satırı dirilir — PK sayesinde mükerrer imkânsız).
      await tx.$executeRaw(Prisma.sql`
        INSERT INTO event_registrations (event_id, user_id, status, show_name)
        VALUES (${eventId}::uuid, ${userId}::uuid, 'registered', ${showName})
        ON CONFLICT (event_id, user_id)
        DO UPDATE SET status = 'registered', show_name = ${showName},
                      updated_at = now()
      `);
      return { result: 'registered', remaining: Math.max(0, ev.quota - n - 1) };
    });
  }

  async cancelRegistration(eventId: string, userId: string): Promise<boolean> {
    const changed = await this.prisma.$executeRaw(Prisma.sql`
      UPDATE event_registrations SET status = 'cancelled', updated_at = now()
      WHERE event_id = ${eventId}::uuid AND user_id = ${userId}::uuid
        AND status = 'registered'
    `);
    return changed > 0;
  }

  async createDeal(input: UpsertDealInput): Promise<string> {
    const row = await this.prisma.deal.create({
      data: {
        title: input.title,
        partner: input.partner,
        benefit: input.benefit,
        code: input.code ?? null,
        validUntil:
          input.validUntil !== null && input.validUntil !== undefined
            ? new Date(input.validUntil)
            : null,
        terms: input.terms ?? null,
        place: input.place ?? null,
        audience: input.audience,
        isActive: input.isActive ?? true,
      },
    });
    return row.id;
  }

  async updateDeal(dealId: string, patch: Partial<UpsertDealInput>): Promise<boolean> {
    const changed = await this.prisma.deal.updateMany({
      where: { id: dealId },
      data: {
        ...(patch.title !== undefined ? { title: patch.title } : {}),
        ...(patch.partner !== undefined ? { partner: patch.partner } : {}),
        ...(patch.benefit !== undefined ? { benefit: patch.benefit } : {}),
        ...(patch.code !== undefined ? { code: patch.code } : {}),
        ...(patch.validUntil !== undefined
          ? { validUntil: patch.validUntil === null ? null : new Date(patch.validUntil) }
          : {}),
        ...(patch.terms !== undefined ? { terms: patch.terms } : {}),
        ...(patch.place !== undefined ? { place: patch.place } : {}),
        ...(patch.audience !== undefined ? { audience: patch.audience } : {}),
        ...(patch.isActive !== undefined ? { isActive: patch.isActive } : {}),
        updatedAt: new Date(),
      },
    });
    return changed.count > 0;
  }

  async createEvent(input: UpsertEventInput): Promise<string> {
    const row = await this.prisma.event.create({
      data: {
        title: input.title,
        body: input.body,
        startsAt: new Date(input.startsAt),
        endsAt: input.endsAt ? new Date(input.endsAt) : null,
        locationText: input.locationText,
        venueLocationId: input.venueLocationId ?? null,
        quota: input.quota,
        registrationDeadline: input.registrationDeadline
          ? new Date(input.registrationDeadline)
          : null,
        priceNote: input.priceNote ?? null,
        conditions: input.conditions ?? null,
        organizer: input.organizer ?? 'Koybul',
        audience: input.audience,
      },
    });
    return row.id;
  }

  async updateEvent(
    eventId: string,
    patch: Partial<UpsertEventInput> & { status?: 'published' | 'cancelled' },
  ): Promise<boolean> {
    const changed = await this.prisma.event.updateMany({
      where: { id: eventId },
      data: {
        ...(patch.title !== undefined ? { title: patch.title } : {}),
        ...(patch.body !== undefined ? { body: patch.body } : {}),
        ...(patch.startsAt !== undefined ? { startsAt: new Date(patch.startsAt) } : {}),
        ...(patch.endsAt !== undefined
          ? { endsAt: patch.endsAt === null ? null : new Date(patch.endsAt) }
          : {}),
        ...(patch.locationText !== undefined ? { locationText: patch.locationText } : {}),
        ...(patch.venueLocationId !== undefined ? { venueLocationId: patch.venueLocationId } : {}),
        ...(patch.quota !== undefined ? { quota: patch.quota } : {}),
        ...(patch.registrationDeadline !== undefined
          ? {
              registrationDeadline:
                patch.registrationDeadline === null ? null : new Date(patch.registrationDeadline),
            }
          : {}),
        ...(patch.priceNote !== undefined ? { priceNote: patch.priceNote } : {}),
        ...(patch.conditions !== undefined ? { conditions: patch.conditions } : {}),
        ...(patch.organizer !== undefined ? { organizer: patch.organizer } : {}),
        ...(patch.audience !== undefined ? { audience: patch.audience } : {}),
        ...(patch.status !== undefined ? { status: patch.status } : {}),
        updatedAt: new Date(),
      },
    });
    return changed.count > 0;
  }

  async participants(eventId: string): Promise<EventParticipant[]> {
    const rows = await this.prisma.$queryRaw<
      { userId: string; displayName: string | null; email: string; registeredAt: Date }[]
    >(Prisma.sql`
      SELECT r.user_id AS "userId", p.display_name AS "displayName",
             u.email, r.created_at AS "registeredAt"
      FROM event_registrations r
      JOIN users u ON u.id = r.user_id
      LEFT JOIN user_profiles p ON p.user_id = r.user_id
      WHERE r.event_id = ${eventId}::uuid AND r.status = 'registered'
      ORDER BY r.created_at ASC
    `);
    return rows.map((r) => ({
      userId: r.userId,
      displayName: r.displayName ?? 'Koybul Kaptanı',
      email: r.email,
      registeredAt: r.registeredAt.toISOString(),
    }));
  }

  // --- KULLANICI ETKİNLİKLERİ (SP-4, kurucu onayı 2026-10-31) ---

  async createUserEvent(id: string, userId: string, input: CreateUserEventInput): Promise<void> {
    // Etkinlik + moderasyon görevi TEK transaction (rota deseni, 0017).
    // organizer = kaptanın görünen adı (katalog tazeliği değil — etkinlik
    // afişindeki imzadır; profil satırı yoksa varsayılan ad).
    await this.prisma.$executeRaw(Prisma.sql`
      WITH ins AS (
        INSERT INTO events
          (id, title, body, starts_at, ends_at, location_text,
           venue_location_id, quota, organizer, audience, status,
           created_by, template)
        SELECT ${id}::uuid, ${input.title}, ${input.body},
               ${input.startsAt}::timestamptz,
               ${input.endsAt ?? null}::timestamptz,
               ${input.locationText}, ${input.venueLocationId ?? null}::uuid,
               ${input.quota}, COALESCE(p.display_name, 'Koybul Kaptanı'),
               'members', 'pending', ${userId}::uuid, ${input.template}
        FROM (SELECT 1) one
        LEFT JOIN user_profiles p ON p.user_id = ${userId}::uuid
        RETURNING id
      )
      INSERT INTO moderation_tasks (entity_type, entity_id, status)
      SELECT 'event'::moderation_entity, ins.id, 'pending'::moderation_status
      FROM ins
      ON CONFLICT (entity_type, entity_id) DO NOTHING
    `);
  }

  async cancelOwnEvent(eventId: string, userId: string): Promise<boolean> {
    // Yalnız kurucu, yalnız yaşayan durumlar; bekleyen moderasyon görevi
    // kapatılır (rota silme deseni).
    const rows = await this.prisma.$queryRaw<{ id: string }[]>(Prisma.sql`
      WITH upd AS (
        UPDATE events SET status = 'cancelled', updated_at = now()
        WHERE id = ${eventId}::uuid AND created_by = ${userId}::uuid
          AND status IN ('pending', 'published')
        RETURNING id
      ), task AS (
        UPDATE moderation_tasks SET status = 'rejected'::moderation_status,
               decision_note = 'author_cancelled', decided_at = now(), updated_at = now()
        WHERE entity_type = 'event'::moderation_entity
          AND entity_id IN (SELECT id FROM upd)
          AND status = 'pending'::moderation_status
      )
      SELECT id FROM upd
    `);
    return rows.length > 0;
  }

  async attendees(eventId: string): Promise<PublicAttendee[]> {
    // YALNIZ rıza verenler (show_name) — e-posta/kimlik asla çıkmaz.
    const rows = await this.prisma.$queryRaw<
      { displayName: string | null; levelCode: string | null }[]
    >(Prisma.sql`
      SELECT p.display_name AS "displayName",
             COALESCE(rep.level_code, 'new') AS "levelCode"
      FROM event_registrations r
      LEFT JOIN user_profiles p ON p.user_id = r.user_id
      LEFT JOIN user_reputation rep ON rep.user_id = r.user_id
      WHERE r.event_id = ${eventId}::uuid AND r.status = 'registered'
        AND r.show_name = true
      ORDER BY r.created_at ASC
      LIMIT 100
    `);
    return rows.map((r) => ({
      displayName: r.displayName ?? 'Koybul Kaptanı',
      levelCode: r.levelCode ?? 'new',
    }));
  }
}

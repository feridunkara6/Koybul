import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import {
  DevicePrefs,
  DeviceRegistration,
  DeviceRow,
  EventReminderCandidate,
  InboxRow,
  InboxType,
  NotificationCategory,
  NotificationsRepository,
} from '../domain/notifications.types';

/** Kategori → kolon (kullanıcı tercihi süzgeci). */
const CATEGORY_COL: Record<NotificationCategory, Prisma.Sql> = {
  community: Prisma.sql`community_enabled`,
  events: Prisma.sql`events_enabled`,
  moderation: Prisma.sql`moderation_enabled`,
};

/**
 * Bildirim deposu — ham SQL (altyapı yolu). Cihaz yazmaları kullanıcı
 * bağlamıyla (RLS sahibi), gönderim okumaları bağlamsız (0002 IS NULL kolu).
 */
@Injectable()
export class PrismaNotificationsRepository implements NotificationsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async upsertDevice(userId: string, reg: DeviceRegistration): Promise<void> {
    await this.prisma.withUserContext(userId, (tx) =>
      tx.$executeRaw(Prisma.sql`
        INSERT INTO device_tokens (token, user_id, platform, locale, last_seen_at)
        VALUES (${reg.token}, ${userId}::uuid, ${reg.platform}, ${reg.locale}, now())
        ON CONFLICT (token) DO UPDATE SET
          user_id = EXCLUDED.user_id,
          platform = EXCLUDED.platform,
          locale = EXCLUDED.locale,
          last_seen_at = now(),
          updated_at = now()
      `),
    );
  }

  async removeDevice(userId: string, token: string): Promise<void> {
    await this.prisma.withUserContext(userId, (tx) =>
      tx.$executeRaw(Prisma.sql`
        DELETE FROM device_tokens
        WHERE token = ${token} AND user_id = ${userId}::uuid
      `),
    );
  }

  async setPrefs(userId: string, token: string, prefs: DevicePrefs): Promise<boolean> {
    const n = await this.prisma.withUserContext(userId, (tx) =>
      tx.$executeRaw(Prisma.sql`
        UPDATE device_tokens SET
          community_enabled = COALESCE(${prefs.community ?? null}, community_enabled),
          events_enabled = COALESCE(${prefs.events ?? null}, events_enabled),
          moderation_enabled = COALESCE(${prefs.moderation ?? null}, moderation_enabled),
          updated_at = now()
        WHERE token = ${token} AND user_id = ${userId}::uuid
      `),
    );
    return n > 0;
  }

  async getPrefs(
    userId: string,
    token: string,
  ): Promise<{ community: boolean; events: boolean; moderation: boolean } | null> {
    const rows = await this.prisma.$queryRaw<
      { community: boolean; events: boolean; moderation: boolean }[]
    >(Prisma.sql`
      SELECT community_enabled AS community, events_enabled AS events,
             moderation_enabled AS moderation
      FROM device_tokens WHERE token = ${token} AND user_id = ${userId}::uuid
    `);
    return rows[0] ?? null;
  }

  devicesForUser(userId: string, category: NotificationCategory): Promise<DeviceRow[]> {
    return this.prisma.$queryRaw<DeviceRow[]>(Prisma.sql`
      SELECT token, locale FROM device_tokens
      WHERE user_id = ${userId}::uuid AND ${CATEGORY_COL[category]} = true
    `);
  }

  async devicesForUsers(userIds: string[], category: NotificationCategory): Promise<DeviceRow[]> {
    if (userIds.length === 0) return [];
    return this.prisma.$queryRaw<DeviceRow[]>(Prisma.sql`
      SELECT token, locale FROM device_tokens
      WHERE user_id = ANY(${userIds}::uuid[]) AND ${CATEGORY_COL[category]} = true
    `);
  }

  devicesForAdmins(): Promise<DeviceRow[]> {
    return this.prisma.$queryRaw<DeviceRow[]>(Prisma.sql`
      SELECT d.token, d.locale FROM device_tokens d
      JOIN users u ON u.id = d.user_id
      JOIN roles r ON r.id = u.role_id
      WHERE r.code IN ('admin', 'super_admin')
        AND u.deleted_at IS NULL AND d.moderation_enabled = true
    `);
  }

  async deleteToken(token: string): Promise<void> {
    await this.prisma.$executeRaw(Prisma.sql`
      DELETE FROM device_tokens WHERE token = ${token}
    `);
  }

  async questionOwnerAndTitle(
    questionId: string,
  ): Promise<{ ownerId: string; title: string } | null> {
    const rows = await this.prisma.$queryRaw<{ ownerId: string; title: string }[]>(Prisma.sql`
      SELECT user_id AS "ownerId", title FROM qa_questions
      WHERE id = ${questionId}::uuid AND deleted_at IS NULL
    `);
    return rows[0] ?? null;
  }

  async answerQuestion(answerId: string): Promise<{ questionId: string; authorId: string } | null> {
    const rows = await this.prisma.$queryRaw<{ questionId: string; authorId: string }[]>(
      Prisma.sql`
        SELECT question_id AS "questionId", user_id AS "authorId" FROM qa_answers
        WHERE id = ${answerId}::uuid AND deleted_at IS NULL
      `,
    );
    return rows[0] ?? null;
  }

  async routeOwnerAndName(routeId: string): Promise<{ ownerId: string; name: string } | null> {
    const rows = await this.prisma.$queryRaw<{ ownerId: string; name: string }[]>(Prisma.sql`
      SELECT user_id AS "ownerId", name FROM routes
      WHERE id = ${routeId}::uuid AND deleted_at IS NULL
    `);
    return rows[0] ?? null;
  }

  async eventTitleAndRegistrants(
    eventId: string,
  ): Promise<{ title: string; userIds: string[] } | null> {
    const rows = await this.prisma.$queryRaw<{ title: string; userIds: string[] }[]>(Prisma.sql`
      SELECT e.title,
             COALESCE(array_agg(r.user_id) FILTER (WHERE r.user_id IS NOT NULL),
                      '{}') AS "userIds"
      FROM events e
      LEFT JOIN event_registrations r
        ON r.event_id = e.id AND r.status = 'registered'
      WHERE e.id = ${eventId}::uuid
      GROUP BY e.id
    `);
    return rows[0] ?? null;
  }

  eventReminderCandidates(now: Date): Promise<EventReminderCandidate[]> {
    return this.prisma.$queryRaw<EventReminderCandidate[]>(Prisma.sql`
      SELECT e.id AS "eventId", r.user_id AS "userId", e.title,
             e.starts_at AS "startsAt"
      FROM events e
      JOIN event_registrations r
        ON r.event_id = e.id AND r.status = 'registered'
      WHERE e.status = 'published'
        AND e.starts_at > ${now}::timestamptz
        AND e.starts_at <= ${now}::timestamptz + interval '24 hours'
    `);
  }

  async logOnce(kind: string, entityId: string, userId: string): Promise<boolean> {
    const n = await this.prisma.$executeRaw(Prisma.sql`
      INSERT INTO notification_log (kind, entity_id, user_id)
      VALUES (${kind}, ${entityId}::uuid, ${userId}::uuid)
      ON CONFLICT (kind, entity_id, user_id) DO NOTHING
    `);
    return n > 0;
  }

  // --- BİLDİRİM KUTUSU (SP-2 Döngü, 2026-10-31) ---

  async noteOwnerAndTitle(noteId: string): Promise<{ ownerId: string; title: string } | null> {
    // Görünen başlık: notun başlığı, yoksa koy adı — kutu satırı insanca okunur.
    const rows = await this.prisma.$queryRaw<{ ownerId: string; title: string | null }[]>(
      Prisma.sql`
        SELECT n.user_id AS "ownerId", COALESCE(n.title, l.name) AS "title"
        FROM location_notes n
        LEFT JOIN locations l ON l.id = n.location_id
        WHERE n.id = ${noteId}::uuid AND n.deleted_at IS NULL
      `,
    );
    const r = rows[0];
    return r ? { ownerId: r.ownerId, title: r.title ?? '' } : null;
  }

  async insertInbox(userId: string, type: InboxType, data: Record<string, string>): Promise<void> {
    await this.prisma.$executeRaw(Prisma.sql`
      INSERT INTO notifications (user_id, type, data, pushed_at)
      VALUES (${userId}::uuid, ${type}::notification_type, ${JSON.stringify(data)}::jsonb, now())
    `);
  }

  async listInbox(userId: string, limit: number): Promise<InboxRow[]> {
    const rows = await this.prisma.$queryRaw<
      { id: string; type: InboxType; data: unknown; readAt: Date | null; createdAt: Date }[]
    >(Prisma.sql`
      SELECT id::text AS id, type::text AS type, data, read_at AS "readAt",
             created_at AS "createdAt"
      FROM notifications
      WHERE user_id = ${userId}::uuid
      ORDER BY created_at DESC
      LIMIT ${limit}
    `);
    return rows.map((r) => ({
      id: r.id,
      type: r.type,
      data: (r.data ?? {}) as Record<string, string>,
      readAt: r.readAt ? r.readAt.toISOString() : null,
      createdAt: r.createdAt.toISOString(),
    }));
  }

  async markAllRead(userId: string): Promise<number> {
    return this.prisma.$executeRaw(Prisma.sql`
      UPDATE notifications SET read_at = now(), updated_at = now()
      WHERE user_id = ${userId}::uuid AND read_at IS NULL
    `);
  }
}

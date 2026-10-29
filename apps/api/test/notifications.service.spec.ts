import { NotificationsService } from '../src/modules/notifications/application/notifications.service';
import {
  DevicePrefs,
  DeviceRegistration,
  DeviceRow,
  EventReminderCandidate,
  InboxRow,
  InboxType,
  NotificationCategory,
  NotificationsRepository,
  PushMessage,
  PushSender,
} from '../src/modules/notifications/domain/notifications.types';

/**
 * PUSH BİLDİRİM SERVİSİ birim testleri (kurucu onayı 2026-10-27).
 * Ağ YOK: sahte gönderici her çağrıyı kaydeder; depo bellek içidir.
 * Tetikleyiciler ateşle-unut olduğundan testler mikro-görev kuyruğunun
 * boşalmasını bekler (flush).
 */

class FakeSender implements PushSender {
  configured = true;
  sent: { token: string; message: PushMessage }[] = [];
  /** Belirli tokenlara verilecek sonuçlar (varsayılan 'ok'). */
  results = new Map<string, 'ok' | 'gone' | 'error'>();

  async send(token: string, message: PushMessage): Promise<'ok' | 'gone' | 'error'> {
    this.sent.push({ token, message });
    return this.results.get(token) ?? 'ok';
  }
}

class FakeRepo implements NotificationsRepository {
  devices = new Map<string, DeviceRow[]>(); // userId → cihazlar
  adminDevices: DeviceRow[] = [];
  logged = new Set<string>();
  deletedTokens: string[] = [];

  question: { ownerId: string; title: string } | null = null;
  answer: { questionId: string; authorId: string } | null = null;
  route: { ownerId: string; name: string } | null = null;
  event: { title: string; userIds: string[] } | null = null;
  reminders: EventReminderCandidate[] = [];

  async upsertDevice(_userId: string, _reg: DeviceRegistration): Promise<void> {}
  async removeDevice(_userId: string, _token: string): Promise<void> {}
  async setPrefs(_u: string, _t: string, _p: DevicePrefs): Promise<boolean> {
    return true;
  }
  async getPrefs(): Promise<{ community: boolean; events: boolean; moderation: boolean } | null> {
    return { community: true, events: true, moderation: true };
  }
  async devicesForUser(userId: string, _c: NotificationCategory): Promise<DeviceRow[]> {
    return this.devices.get(userId) ?? [];
  }
  async devicesForUsers(userIds: string[], _c: NotificationCategory): Promise<DeviceRow[]> {
    return userIds.flatMap((u) => this.devices.get(u) ?? []);
  }
  async devicesForAdmins(): Promise<DeviceRow[]> {
    return this.adminDevices;
  }
  async deleteToken(token: string): Promise<void> {
    this.deletedTokens.push(token);
  }
  async questionOwnerAndTitle(): Promise<{ ownerId: string; title: string } | null> {
    return this.question;
  }
  async answerQuestion(): Promise<{ questionId: string; authorId: string } | null> {
    return this.answer;
  }
  async routeOwnerAndName(): Promise<{ ownerId: string; name: string } | null> {
    return this.route;
  }
  async eventTitleAndRegistrants(): Promise<{ title: string; userIds: string[] } | null> {
    return this.event;
  }
  async eventReminderCandidates(): Promise<EventReminderCandidate[]> {
    return this.reminders;
  }
  async logOnce(kind: string, entityId: string, userId: string): Promise<boolean> {
    const key = `${kind}|${entityId}|${userId}`;
    if (this.logged.has(key)) return false;
    this.logged.add(key);
    return true;
  }

  // --- BİLDİRİM KUTUSU (SP-2, 2026-10-31) ---
  note: { ownerId: string; title: string } | null = null;
  inboxRows: { userId: string; type: InboxType; data: Record<string, string> }[] = [];

  async noteOwnerAndTitle(): Promise<{ ownerId: string; title: string } | null> {
    return this.note;
  }
  async insertInbox(userId: string, type: InboxType, data: Record<string, string>): Promise<void> {
    this.inboxRows.push({ userId, type, data });
  }
  async listInbox(userId: string, limit: number): Promise<InboxRow[]> {
    return this.inboxRows
      .filter((r) => r.userId === userId)
      .slice(0, limit)
      .map((r, i) => ({
        id: `in-${i}`,
        type: r.type,
        data: r.data,
        readAt: null,
        createdAt: '2026-10-31T10:00:00.000Z',
      }));
  }
  async markAllRead(userId: string): Promise<number> {
    return this.inboxRows.filter((r) => r.userId === userId).length;
  }
}

/** Ateşle-unut zincirlerinin bitmesini bekle (iç içe birkaç await var). */
const flush = () => new Promise<void>((resolve) => setTimeout(resolve, 0));

function setup(): { service: NotificationsService; repo: FakeRepo; sender: FakeSender } {
  const repo = new FakeRepo();
  const sender = new FakeSender();
  const service = new NotificationsService(repo, sender);
  return { service, repo, sender };
}

describe('NotificationsService', () => {
  it('soruya cevap: soru sahibinin cihazlarına, kendi dilinde gider', async () => {
    const { service, repo, sender } = setup();
    repo.question = { ownerId: 'u-owner', title: 'Göcek demirleme?' };
    repo.devices.set('u-owner', [
      { token: 't-tr', locale: 'tr' },
      { token: 't-en', locale: 'en-US' },
    ]);

    service.qaAnswer('q1', 'a1', 'u-author');
    await flush();

    expect(sender.sent).toHaveLength(2);
    expect(sender.sent[0].message.title).toBe('Soruna cevap geldi');
    expect(sender.sent[1].message.title).toBe('Your question got an answer');
    expect(sender.sent[0].message.body).toBe('Göcek demirleme?');
    expect(sender.sent[0].message.data).toEqual({ kind: 'qa_answer', id: 'q1' });
  });

  it('kendi sorusuna verdiği cevap bildirim ÜRETMEZ', async () => {
    const { service, repo, sender } = setup();
    repo.question = { ownerId: 'u-same', title: 'Soru' };
    repo.devices.set('u-same', [{ token: 't1', locale: 'tr' }]);

    service.qaAnswer('q1', 'a1', 'u-same');
    await flush();

    expect(sender.sent).toHaveLength(0);
  });

  it('aynı cevap iki kez tetiklense bildirim BİR kez gider (logOnce)', async () => {
    const { service, repo, sender } = setup();
    repo.question = { ownerId: 'u-owner', title: 'Soru' };
    repo.devices.set('u-owner', [{ token: 't1', locale: 'tr' }]);

    service.qaAnswer('q1', 'a1', 'u-author');
    service.qaAnswer('q1', 'a1', 'u-author');
    await flush();

    expect(sender.sent).toHaveLength(1);
  });

  it('rota kararı: onay ve ret ayrı metinlerle sahibine gider', async () => {
    const { service, repo, sender } = setup();
    repo.route = { ownerId: 'u-r', name: 'Göcek Turu' };
    repo.devices.set('u-r', [{ token: 't1', locale: 'tr' }]);

    service.routeDecision('r1', true);
    await flush();
    service.routeDecision('r2', false);
    await flush();

    expect(sender.sent).toHaveLength(2);
    expect(sender.sent[0].message.title).toBe('Rotan yayında');
    expect(sender.sent[0].message.body).toContain('Göcek Turu');
    expect(sender.sent[1].message.title).toBe('Rotan yayınlanmadı');
    expect(sender.sent[1].message.data.kind).toBe('route_rejected');
  });

  it('etkinlik iptali: kayıtlı HERKESE gider, tekrar güncelleme tekrar göndermez', async () => {
    const { service, repo, sender } = setup();
    repo.event = { title: 'Koybul Buluşması', userIds: ['u1', 'u2'] };
    repo.devices.set('u1', [{ token: 't1', locale: 'tr' }]);
    repo.devices.set('u2', [{ token: 't2', locale: 'es' }]);

    service.eventCancelled('e1');
    await flush();
    service.eventCancelled('e1'); // panel ikinci kez kaydetti
    await flush();

    expect(sender.sent).toHaveLength(2);
    expect(sender.sent[1].message.title).toBe('Evento cancelado');
  });

  it('hatırlatma taraması: adaylara bir kez, saat başı tekrar taramada sessiz', async () => {
    const { service, repo, sender } = setup();
    repo.reminders = [
      { eventId: 'e1', userId: 'u1', title: 'Yarınki Etkinlik', startsAt: new Date() },
    ];
    repo.devices.set('u1', [{ token: 't1', locale: 'tr' }]);

    await service.scanEventReminders();
    await service.scanEventReminders(); // bir saat sonraki tarama

    expect(sender.sent).toHaveLength(1);
    expect(sender.sent[0].message.title).toBe('Etkinlik yarın');
    expect(sender.sent[0].message.body).toContain('Yarınki Etkinlik');
  });

  it('moderasyon kuyruğu: admin cihazlarına tür adıyla gider', async () => {
    const { service, repo, sender } = setup();
    repo.adminDevices = [{ token: 't-adm', locale: 'tr' }];

    service.moderationNew('route');
    await flush();

    expect(sender.sent).toHaveLength(1);
    expect(sender.sent[0].message.title).toBe('Moderasyon kuyruğu');
    expect(sender.sent[0].message.body).toContain('rota');
  });

  it('ölü token (gone) anında veritabanından silinir', async () => {
    const { service, repo, sender } = setup();
    repo.adminDevices = [
      { token: 't-dead', locale: 'tr' },
      { token: 't-alive', locale: 'tr' },
    ];
    sender.results.set('t-dead', 'gone');

    service.moderationNew('note');
    await flush();

    expect(repo.deletedTokens).toEqual(['t-dead']);
    expect(sender.sent).toHaveLength(2); // ikinciye gönderim sürer
  });

  it('gönderici yapılandırılmamışsa tetik HİÇ koşmaz (logOnce bile yazılmaz)', async () => {
    const { service, repo, sender } = setup();
    sender.configured = false;
    repo.question = { ownerId: 'u-owner', title: 'Soru' };
    repo.devices.set('u-owner', [{ token: 't1', locale: 'tr' }]);

    service.qaAnswer('q1', 'a1', 'u-author');
    await flush();

    expect(sender.sent).toHaveLength(0);
    expect(repo.logged.size).toBe(0); // push açıldığında olay "gönderildi" sayılmasın
  });

  it('moderasyondan onaylanan cevap soru sahibine ANCAK O ZAMAN gider', async () => {
    const { service, repo, sender } = setup();
    repo.answer = { questionId: 'q1', authorId: 'u-author' };
    repo.question = { ownerId: 'u-owner', title: 'Soru' };
    repo.devices.set('u-owner', [{ token: 't1', locale: 'tr' }]);

    service.qaAnswerModerated('a1');
    await flush();
    await flush(); // zincir: answerQuestion → qaAnswer

    expect(sender.sent).toHaveLength(1);
    expect(sender.sent[0].message.data).toEqual({ kind: 'qa_answer', id: 'q1' });
  });

  it('bilinmeyen dil Türkçeye düşer', async () => {
    const { service, repo, sender } = setup();
    repo.adminDevices = [{ token: 't1', locale: 'fr-FR' }];

    service.moderationNew('review');
    await flush();

    expect(sender.sent[0].message.title).toBe('Moderasyon kuyruğu');
  });
});

import { Inject, Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import {
  DevicePrefs,
  DeviceRegistration,
  DeviceRow,
  InboxRow,
  InboxType,
  NOTIFICATIONS_REPOSITORY,
  NotificationsRepository,
  PUSH_SENDER,
  PushMessage,
  PushSender,
} from '../domain/notifications.types';

/** Moderasyon kuyruğuna düşebilen içerik türleri (admin bildirimi gövdesi). */
export type ModerationKind = 'route' | 'question' | 'answer' | 'note' | 'review' | 'report';

/**
 * Dil başına bildirim metinleri — l10n dosyaları MOBİLDE yaşar, sunucunun
 * elindeki tek dil bilgisi cihaz kaydındaki locale'dir; metin burada üretilir.
 * Bilinmeyen dil Türkçeye düşer (kitlenin ana dili).
 */
interface LocaleStrings {
  qaAnswerTitle: string;
  routeApprovedTitle: string;
  routeApprovedBody: (name: string) => string;
  routeRejectedTitle: string;
  routeRejectedBody: (name: string) => string;
  eventCancelledTitle: string;
  eventCancelledBody: (title: string) => string;
  eventReminderTitle: string;
  eventReminderBody: (title: string) => string;
  moderationNewTitle: string;
  moderationNewBody: (kind: string) => string;
  kinds: Record<ModerationKind, string>;
  // SP-2 Döngü (2026-10-31): faydalı eşiği + seviye atlama.
  helpfulTitle: string;
  helpfulBody: (title: string, count: number) => string;
  levelUpTitle: string;
  levelUpBody: (levelName: string) => string;
  levels: Record<string, string>;
}

const STRINGS: Record<'tr' | 'en' | 'es' | 'ru', LocaleStrings> = {
  tr: {
    qaAnswerTitle: 'Soruna cevap geldi',
    routeApprovedTitle: 'Rotan yayında',
    routeApprovedBody: (name: string) => `"${name}" onaylandı — artık Rota Keşfi'nde.`,
    routeRejectedTitle: 'Rotan yayınlanmadı',
    routeRejectedBody: (name: string) =>
      `"${name}" moderasyonda onaylanmadı. Detay için Defter'e bakabilirsin.`,
    eventCancelledTitle: 'Etkinlik iptal edildi',
    eventCancelledBody: (title: string) => `"${title}" iptal edildi.`,
    eventReminderTitle: 'Etkinlik yarın',
    eventReminderBody: (title: string) => `"${title}" yarın başlıyor — unutma!`,
    moderationNewTitle: 'Moderasyon kuyruğu',
    moderationNewBody: (kind: string) => `Onay bekleyen yeni içerik: ${kind}.`,
    kinds: {
      route: 'rota',
      question: 'soru',
      answer: 'cevap',
      note: 'not',
      review: 'yorum',
      report: 'şikâyet',
    },
    helpfulTitle: 'Notun işe yarıyor',
    helpfulBody: (title: string, count: number) =>
      `"${title}" notun ${count} faydalı oyuna ulaştı. Pruvan neta!`,
    levelUpTitle: 'Seviye atladın',
    levelUpBody: (levelName: string) => `Yeni denizci seviyen: ${levelName}. Tebrikler!`,
    levels: {
      new: 'Yeni Denizci',
      coastal: 'Kıyı Kaşifi',
      guide: 'Yol Gösteren',
      master: 'Usta Kaptan',
      pilot: 'Deniz Rehberi',
    },
  },
  en: {
    qaAnswerTitle: 'Your question got an answer',
    routeApprovedTitle: 'Your route is live',
    routeApprovedBody: (name: string) => `"${name}" was approved — it's now in Route Discovery.`,
    routeRejectedTitle: 'Your route was not published',
    routeRejectedBody: (name: string) => `"${name}" was not approved in moderation.`,
    eventCancelledTitle: 'Event cancelled',
    eventCancelledBody: (title: string) => `"${title}" has been cancelled.`,
    eventReminderTitle: 'Event tomorrow',
    eventReminderBody: (title: string) => `"${title}" starts tomorrow — don't forget!`,
    moderationNewTitle: 'Moderation queue',
    moderationNewBody: (kind: string) => `New content awaiting review: ${kind}.`,
    kinds: {
      route: 'route',
      question: 'question',
      answer: 'answer',
      note: 'note',
      review: 'review',
      report: 'report',
    },
    helpfulTitle: 'Your note is helping',
    helpfulBody: (title: string, count: number) =>
      `"${title}" reached ${count} helpful votes. Well done!`,
    levelUpTitle: 'Level up',
    levelUpBody: (levelName: string) => `Your new sailor level: ${levelName}. Congrats!`,
    levels: {
      new: 'New Sailor',
      coastal: 'Coastal Explorer',
      guide: 'Wayfinder',
      master: 'Master Skipper',
      pilot: 'Sea Guide',
    },
  },
  es: {
    qaAnswerTitle: 'Tu pregunta recibió una respuesta',
    routeApprovedTitle: 'Tu ruta está publicada',
    routeApprovedBody: (name: string) => `"${name}" fue aprobada — ya está en Descubrir Rutas.`,
    routeRejectedTitle: 'Tu ruta no se publicó',
    routeRejectedBody: (name: string) => `"${name}" no fue aprobada en moderación.`,
    eventCancelledTitle: 'Evento cancelado',
    eventCancelledBody: (title: string) => `"${title}" ha sido cancelado.`,
    eventReminderTitle: 'Evento mañana',
    eventReminderBody: (title: string) => `"${title}" empieza mañana — ¡no lo olvides!`,
    moderationNewTitle: 'Cola de moderación',
    moderationNewBody: (kind: string) => `Nuevo contenido pendiente de revisión: ${kind}.`,
    kinds: {
      route: 'ruta',
      question: 'pregunta',
      answer: 'respuesta',
      note: 'nota',
      review: 'reseña',
      report: 'denuncia',
    },
    helpfulTitle: 'Tu nota está ayudando',
    helpfulBody: (title: string, count: number) =>
      `"${title}" alcanzó ${count} votos útiles. ¡Bien hecho!`,
    levelUpTitle: 'Subiste de nivel',
    levelUpBody: (levelName: string) => `Tu nuevo nivel: ${levelName}. ¡Felicidades!`,
    levels: {
      new: 'Marinero nuevo',
      coastal: 'Explorador costero',
      guide: 'Guía',
      master: 'Patrón experto',
      pilot: 'Guía del mar',
    },
  },
  ru: {
    qaAnswerTitle: 'На ваш вопрос ответили',
    routeApprovedTitle: 'Ваш маршрут опубликован',
    routeApprovedBody: (name: string) => `«${name}» одобрен — теперь в разделе маршрутов.`,
    routeRejectedTitle: 'Маршрут не опубликован',
    routeRejectedBody: (name: string) => `«${name}» не прошёл модерацию.`,
    eventCancelledTitle: 'Мероприятие отменено',
    eventCancelledBody: (title: string) => `«${title}» отменено.`,
    eventReminderTitle: 'Мероприятие завтра',
    eventReminderBody: (title: string) => `«${title}» начинается завтра — не забудьте!`,
    moderationNewTitle: 'Очередь модерации',
    moderationNewBody: (kind: string) => `Новый контент ждёт проверки: ${kind}.`,
    kinds: {
      route: 'маршрут',
      question: 'вопрос',
      answer: 'ответ',
      note: 'заметка',
      review: 'отзыв',
      report: 'жалоба',
    },
    helpfulTitle: 'Ваша заметка помогает',
    helpfulBody: (title: string, count: number) =>
      `«${title}» набрала ${count} отметок «полезно». Отлично!`,
    levelUpTitle: 'Новый уровень',
    levelUpBody: (levelName: string) => `Ваш новый уровень моряка: ${levelName}. Поздравляем!`,
    levels: {
      new: 'Новый моряк',
      coastal: 'Исследователь побережья',
      guide: 'Проводник',
      master: 'Опытный капитан',
      pilot: 'Морской лоцман',
    },
  },
};

function stringsFor(locale: string): LocaleStrings {
  const lang = locale.toLowerCase().split(/[-_]/)[0];
  return (STRINGS as Partial<Record<string, LocaleStrings>>)[lang] ?? STRINGS.tr;
}

/** Saatlik etkinlik hatırlatma taraması aralığı. */
const REMINDER_SCAN_MS = 60 * 60 * 1000;

/**
 * Bildirim servisi (kurucu onayı 2026-10-27). İki yüzü var:
 *
 *  1. Cihaz kaydı/tercihleri — controller'dan çağrılır (bekletilir).
 *  2. notify* tetikleyicileri — içerik servislerinden ATEŞLE-UNUT çağrılır:
 *     hiçbiri Promise döndürmez, hata yutulup loglanır. Bildirim gönderimi
 *     HİÇBİR ana işi (cevap yazma, moderasyon kararı…) geciktiremez/bozamaz.
 *
 * Tekrar koruması notification_log tablosuyladır (logOnce): aynı olay aynı
 * kullanıcıya iki kez gidemez — saatlik tarama ve çifte tetik güvenlidir.
 */
@Injectable()
export class NotificationsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(NotificationsService.name);
  private reminderTimer: NodeJS.Timeout | null = null;

  constructor(
    @Inject(NOTIFICATIONS_REPOSITORY) private readonly repo: NotificationsRepository,
    @Inject(PUSH_SENDER) private readonly sender: PushSender,
  ) {}

  // --- Yaşam döngüsü: saatlik etkinlik hatırlatma taraması -----------------

  onModuleInit(): void {
    if (!this.sender.configured) return; // yapılandırma yoksa tarama da yok
    this.reminderTimer = setInterval(() => {
      this.scanEventReminders().catch((err) =>
        this.logger.warn({ event: 'push_reminder_scan_failed', err: String(err) }),
      );
    }, REMINDER_SCAN_MS);
    this.reminderTimer.unref(); // test/kapanışta süreci asılı tutmasın
  }

  onModuleDestroy(): void {
    if (this.reminderTimer) clearInterval(this.reminderTimer);
  }

  // --- Cihaz kaydı ve tercihler (controller yüzü) --------------------------

  async registerDevice(
    userId: string,
    reg: DeviceRegistration,
  ): Promise<{ community: boolean; events: boolean; moderation: boolean }> {
    await this.repo.upsertDevice(userId, reg);
    // Upsert tercih kolonlarına DOKUNMAZ — mevcut tercihler okunup döndürülür
    // ki ayarlar ekranı tek istekle doğru durumu çizsin.
    const prefs = await this.repo.getPrefs(userId, reg.token);
    return prefs ?? { community: true, events: true, moderation: true };
  }

  unregisterDevice(userId: string, token: string): Promise<void> {
    return this.repo.removeDevice(userId, token);
  }

  async updatePrefs(
    userId: string,
    token: string,
    prefs: DevicePrefs,
  ): Promise<{ community: boolean; events: boolean; moderation: boolean } | null> {
    const ok = await this.repo.setPrefs(userId, token, prefs);
    if (!ok) return null;
    return this.repo.getPrefs(userId, token);
  }

  // --- Tetikleyiciler (ateşle-unut; içerik servislerinden çağrılır) --------

  /** ① Soruya cevap geldi → soru sahibine (kendi cevabına bildirim YOK). */
  qaAnswer(questionId: string, answerId: string, answerAuthorId: string): void {
    this.fireAndForget('qa_answer', async () => {
      const q = await this.repo.questionOwnerAndTitle(questionId);
      if (!q || q.ownerId === answerAuthorId) return;
      if (!(await this.repo.logOnce('qa_answer', answerId, q.ownerId))) return;
      // KUTU (SP-2): push kaçsa bile olay uygulama içinde durur.
      await this.inbox(q.ownerId, 'qa_answer', {
        kind: 'qa_answer',
        id: questionId,
        title: q.title,
      });
      await this.sendTo(await this.repo.devicesForUser(q.ownerId, 'community'), (s) => ({
        title: s.qaAnswerTitle,
        body: q.title,
        data: { kind: 'qa_answer', id: questionId },
      }));
    });
  }

  /** ① (moderasyon yolu) Kuyruktaki cevap onaylanınca soru sahibine. */
  qaAnswerModerated(answerId: string): void {
    this.fireAndForget('qa_answer_moderated', async () => {
      const a = await this.repo.answerQuestion(answerId);
      if (!a) return;
      this.qaAnswer(a.questionId, answerId, a.authorId);
    });
  }

  /** ② Paylaşılan rotanın moderasyon kararı → rota sahibine. */
  routeDecision(routeId: string, approved: boolean): void {
    this.fireAndForget('route_decision', async () => {
      const r = await this.repo.routeOwnerAndName(routeId);
      if (!r) return;
      const kind = approved ? 'route_approved' : 'route_rejected';
      if (!(await this.repo.logOnce(kind, routeId, r.ownerId))) return;
      await this.inbox(r.ownerId, 'route_decision', { kind, id: routeId, name: r.name });
      await this.sendTo(await this.repo.devicesForUser(r.ownerId, 'community'), (s) => ({
        title: approved ? s.routeApprovedTitle : s.routeRejectedTitle,
        body: approved ? s.routeApprovedBody(r.name) : s.routeRejectedBody(r.name),
        data: { kind, id: routeId },
      }));
    });
  }

  /** ③ Etkinlik iptal edildi → kayıtlı HERKESE. */
  eventCancelled(eventId: string): void {
    this.fireAndForget('event_cancelled', async () => {
      const ev = await this.repo.eventTitleAndRegistrants(eventId);
      if (!ev || ev.userIds.length === 0) return;
      for (const userId of ev.userIds) {
        if (!(await this.repo.logOnce('event_cancelled', eventId, userId))) continue;
        await this.inbox(userId, 'event_update', {
          kind: 'event_cancelled',
          id: eventId,
          title: ev.title,
        });
        await this.sendTo(await this.repo.devicesForUser(userId, 'events'), (s) => ({
          title: s.eventCancelledTitle,
          body: s.eventCancelledBody(ev.title),
          data: { kind: 'event_cancelled', id: eventId },
        }));
      }
    });
  }

  /** ⑥ "Faydalı" EŞİĞİ (SP-2, 2026-10-31): notun 1., 5. ve 25. faydalı
   *  oyunda sahibine bir kez — her oyda push atmak taciz olurdu. */
  helpfulMilestone(noteId: string, count: number): void {
    this.fireAndForget('helpful_milestone', async () => {
      const n = await this.repo.noteOwnerAndTitle(noteId);
      if (!n) return;
      // entity_id uuid'dir — eşik, tür adına işlenir (helpful_5 gibi).
      if (!(await this.repo.logOnce(`helpful_${count}`, noteId, n.ownerId))) return;
      await this.inbox(n.ownerId, 'helpful_received', {
        kind: 'helpful_received',
        id: noteId,
        title: n.title,
        count: String(count),
      });
      await this.sendTo(await this.repo.devicesForUser(n.ownerId, 'community'), (s) => ({
        title: s.helpfulTitle,
        body: s.helpfulBody(n.title, count),
        data: { kind: 'helpful_received', id: noteId },
      }));
    });
  }

  /** ⑦ SEVİYE ATLAMA (SP-2): her seviye koduna bir kez (logOnce: level_<kod>). */
  levelUp(userId: string, levelCode: string): void {
    this.fireAndForget('level_up', async () => {
      if (!(await this.repo.logOnce(`level_${levelCode}`, userId, userId))) return;
      await this.inbox(userId, 'level_up', { kind: 'level_up', level: levelCode });
      await this.sendTo(await this.repo.devicesForUser(userId, 'community'), (s) => ({
        title: s.levelUpTitle,
        body: s.levelUpBody(s.levels[levelCode] ?? levelCode),
        data: { kind: 'level_up', id: levelCode },
      }));
    });
  }

  // --- BİLDİRİM KUTUSU (SP-2): uygulama içi liste -------------------------

  /** Kullanıcının kutusu (en yeni 50). */
  listInbox(userId: string): Promise<InboxRow[]> {
    return this.repo.listInbox(userId, 50);
  }

  /** Tümünü okundu say (kutu ekranı açılınca). */
  markAllRead(userId: string): Promise<number> {
    return this.repo.markAllRead(userId);
  }

  /** Kutu yazımı en-iyi-çaba: kutu hatası push'u asla engellemez. */
  private async inbox(
    userId: string,
    type: InboxType,
    data: Record<string, string>,
  ): Promise<void> {
    try {
      await this.repo.insertInbox(userId, type, data);
    } catch (err) {
      this.logger.warn({ event: 'inbox_write_failed', type, err: String(err) });
    }
  }

  /** ⑤ Moderasyon kuyruğuna yeni içerik → admin cihazlarına. */
  moderationNew(kind: ModerationKind): void {
    this.fireAndForget('moderation_new', async () => {
      await this.sendTo(await this.repo.devicesForAdmins(), (s) => ({
        title: s.moderationNewTitle,
        body: s.moderationNewBody(s.kinds[kind]),
        data: { kind: 'moderation_new', id: kind },
      }));
    });
  }

  /** ④ Saatlik tarama: 24 saat içinde başlayan etkinliklerin kayıtlıları. */
  async scanEventReminders(now: Date = new Date()): Promise<void> {
    const candidates = await this.repo.eventReminderCandidates(now);
    for (const c of candidates) {
      // logOnce = tekrar kalkanı: tarama her saat koşar, bildirim BİR kez gider.
      if (!(await this.repo.logOnce('event_reminder', c.eventId, c.userId))) continue;
      await this.inbox(c.userId, 'event_update', {
        kind: 'event_reminder',
        id: c.eventId,
        title: c.title,
      });
      await this.sendTo(await this.repo.devicesForUser(c.userId, 'events'), (s) => ({
        title: s.eventReminderTitle,
        body: s.eventReminderBody(c.title),
        data: { kind: 'event_reminder', id: c.eventId },
      }));
    }
  }

  // --- İç işleyiş ----------------------------------------------------------

  /** Cihaz listesine dil-duyarlı gönderim; ölü token anında temizlenir. */
  private async sendTo(
    devices: DeviceRow[],
    build: (s: LocaleStrings) => PushMessage,
  ): Promise<void> {
    if (!this.sender.configured || devices.length === 0) return;
    for (const device of devices) {
      const result = await this.sender.send(device.token, build(stringsFor(device.locale)));
      if (result === 'gone') {
        await this.repo.deleteToken(device.token).catch(() => undefined);
      }
    }
  }

  /**
   * Tetikleyici sarmalayıcı: asla fırlatmaz, asla bekletmez. Gönderici
   * yapılandırılmamışsa HİÇ koşmaz — logOnce satırları da yazılmaz ki push
   * panelden açıldığında eski olaylar "zaten gönderildi" sayılmasın.
   */
  private fireAndForget(label: string, work: () => Promise<void>): void {
    if (!this.sender.configured) return;
    work().catch((err) =>
      this.logger.warn({ event: 'push_trigger_failed', trigger: label, err: String(err) }),
    );
  }
}

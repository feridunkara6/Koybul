import { Inject, Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import {
  DevicePrefs,
  DeviceRegistration,
  DeviceRow,
  NOTIFICATIONS_REPOSITORY,
  NotificationCategory,
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
        await this.sendTo(await this.repo.devicesForUser(userId, 'events'), (s) => ({
          title: s.eventCancelledTitle,
          body: s.eventCancelledBody(ev.title),
          data: { kind: 'event_cancelled', id: eventId },
        }));
      }
    });
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

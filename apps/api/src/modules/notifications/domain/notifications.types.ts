/**
 * PUSH BİLDİRİMLERİ sözleşmeleri (kurucu onayı 2026-10-27).
 *
 * Kapsam (v1, sıkmama sözleşmesi — az ama değerli):
 *  - qa_answer          → soruna cevap geldi (soru sahibine)
 *  - route_approved/route_rejected → paylaştığın rotanın moderasyon kararı
 *  - event_cancelled    → kayıtlı olduğun etkinlik iptal edildi
 *  - event_reminder     → kayıtlı olduğun etkinlik yarın (saatlik tarama + defter)
 *  - moderation_new     → (yalnız admin cihazları) kuyruğa yeni içerik düştü
 *
 * Bakım hatırlatması BİLEREK burada YOK: bakım verisi cihazda yaşar; o
 * bildirim telefonun YEREL bildirimi olarak mobilde üretilir (gizlilik).
 */

export interface DeviceRegistration {
  token: string;
  platform: 'ios' | 'android' | 'web';
  locale: string;
}

export interface DevicePrefs {
  community?: boolean;
  events?: boolean;
  moderation?: boolean;
}

/** Gönderilecek tek bildirim — data, uygulamada derin bağlantı için. */
export interface PushMessage {
  title: string;
  body: string;
  data: Record<string, string>;
}

export interface DeviceRow {
  token: string;
  locale: string;
}

/** Gönderici soyutlaması — testte sahte; gerçek impl FCM HTTP v1. */
export interface PushSender {
  /** Servis hesabı yapılandırılmadıysa false — tüm gönderimler sessiz geçer. */
  readonly configured: boolean;

  /** 'ok' | 'gone' (token ölü — silinmeli) | 'error' (loglanır, geçilir). */
  send(token: string, message: PushMessage): Promise<'ok' | 'gone' | 'error'>;
}

export const PUSH_SENDER = Symbol('PUSH_SENDER');

export type NotificationCategory = 'community' | 'events' | 'moderation';

export interface EventReminderCandidate {
  eventId: string;
  userId: string;
  title: string;
  startsAt: Date;
}

export interface NotificationsRepository {
  upsertDevice(userId: string, reg: DeviceRegistration): Promise<void>;
  removeDevice(userId: string, token: string): Promise<void>;
  setPrefs(userId: string, token: string, prefs: DevicePrefs): Promise<boolean>;
  getPrefs(
    userId: string,
    token: string,
  ): Promise<{ community: boolean; events: boolean; moderation: boolean } | null>;

  /** Kullanıcının o kategorisi AÇIK cihazları. */
  devicesForUser(userId: string, category: NotificationCategory): Promise<DeviceRow[]>;
  devicesForUsers(userIds: string[], category: NotificationCategory): Promise<DeviceRow[]>;
  /** admin+ rollü hesapların moderation açık cihazları. */
  devicesForAdmins(): Promise<DeviceRow[]>;

  /** Ölü (UNREGISTERED) token temizliği. */
  deleteToken(token: string): Promise<void>;

  // --- Tetikleyici bakışları (bildirim servisinin kendi sorguları) ---
  questionOwnerAndTitle(questionId: string): Promise<{ ownerId: string; title: string } | null>;
  /** Moderasyondan onaylanan cevabın sorusu + yazarı (cevap kuyruktan çıkınca). */
  answerQuestion(answerId: string): Promise<{ questionId: string; authorId: string } | null>;
  routeOwnerAndName(routeId: string): Promise<{ ownerId: string; name: string } | null>;
  eventTitleAndRegistrants(eventId: string): Promise<{ title: string; userIds: string[] } | null>;
  /** Önümüzdeki 24 saatte başlayan, iptal edilmemiş etkinliklerin kayıtlıları. */
  eventReminderCandidates(now: Date): Promise<EventReminderCandidate[]>;

  /** Defter satırı atar; İLK kez eklendiyse true (tekrar koruması). */
  logOnce(kind: string, entityId: string, userId: string): Promise<boolean>;

  // --- BİLDİRİM KUTUSU (SP-2 Döngü, kurucu onayı 2026-10-31) ---

  /** "Faydalı" eşiği bildirimi için not sahibi + görünen başlık (koy adı). */
  noteOwnerAndTitle(noteId: string): Promise<{ ownerId: string; title: string } | null>;

  /** Kutuya satır yazar — metin değil, tür + data (metin istemcide üretilir). */
  insertInbox(userId: string, type: InboxType, data: Record<string, string>): Promise<void>;

  /** Kullanıcının en yeni kutu satırları (en yeni önce). */
  listInbox(userId: string, limit: number): Promise<InboxRow[]>;

  /** Tümünü okundu işaretler; işaretlenen satır sayısını döner. */
  markAllRead(userId: string): Promise<number>;
}

/** Kutuya yazılan olay türleri — prisma notification_type alt kümesi. */
export type InboxType =
  'qa_answer' | 'route_decision' | 'event_update' | 'helpful_received' | 'level_up';

/** Kutu satırı (API yanıtı ile birebir). */
export interface InboxRow {
  id: string;
  type: InboxType;
  data: Record<string, string>;
  readAt: string | null;
  createdAt: string;
}

export const NOTIFICATIONS_REPOSITORY = Symbol('NOTIFICATIONS_REPOSITORY');

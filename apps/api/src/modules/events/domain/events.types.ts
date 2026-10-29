/**
 * ETKİNLİKLER & FIRSATLAR (V1 — kurucu onayı 2026-10-23).
 *
 * KİTLE KİLİDİ (kurucu kararı A): her fırsat/etkinlik hedef kitle taşır —
 * 'all' herkese, 'members' hesaplı üyelere, 'premium' Premium üyelere.
 * Fırsat KODU kilitliyse istemciye HİÇ İNMEZ (locked=true, code=null).
 * PREMIUM_ENFORCE kapalıyken premium kilidi açılır; üye kilidi her zaman
 * geçerlidir (hesap teşviki premium bayrağından bağımsızdır).
 *
 * KONTENJAN SÖZÜ: kayıt tek işlemde "kilitle → say → yaz" yapılır; kontenjan
 * üstü kayıt matematiksel olarak imkânsızdır. İptal sayacı anında düşürür.
 * V1'de uygulama içi ödeme YOK — ücret notu serbest metindir.
 */

export type EventAudience = 'all' | 'members' | 'premium';

// --- KULLANICI ETKİNLİKLERİ (SP-4, kurucu onayı 2026-10-31) ---

/** 3 şablon (kurucu kararı): koy buluşması / birlikte seyir / marina. */
export type UserEventTemplate = 'bay_meetup' | 'joint_sail' | 'marina_meetup';

export const USER_EVENT_TEMPLATES: readonly UserEventTemplate[] = [
  'bay_meetup',
  'joint_sail',
  'marina_meetup',
];

/** Kullanıcı etkinliği girdisi — kitle her zaman 'members' (misafir
 *  etkileşemez), durum 'pending' doğar; fiyat/koşul alanı YOKTUR (ticari
 *  organizasyon değil, buluşmadır — kurucu şablon kararı). */
export interface CreateUserEventInput {
  template: UserEventTemplate;
  title: string;
  body: string;
  startsAt: string;
  endsAt?: string | null;
  locationText: string;
  venueLocationId?: string | null;
  quota: number;
}

/** RIZALI katılımcı satırı — yalnız show_name=true diyenler; PII YOK. */
export interface PublicAttendee {
  displayName: string;
  levelCode: string;
}

/** Fırsat — kod, kitle kilidine göre null'lanmış hâlde taşınır. */
export interface DealView {
  id: string;
  title: string;
  partner: string;
  benefit: string;
  /** Kilitliyse null — sunucudan hiç çıkmaz. */
  code: string | null;
  /** Kod var ama bakanın kitlesi yetmiyor → true (istemci kilit rozeti çizer). */
  locked: boolean;
  audience: EventAudience;
  validUntil: string | null;
  terms: string | null;
  place: string | null;
  /** Son kullanım geçti mi? (geçmiş fırsat soluk çizilir, kod kopyalanmaz) */
  expired: boolean;
}

export interface EventView {
  id: string;
  title: string;
  body: string;
  startsAt: string;
  endsAt: string | null;
  locationText: string;
  venueLocationId: string | null;
  quota: number;
  registeredCount: number;
  remaining: number;
  registrationDeadline: string | null;
  priceNote: string | null;
  conditions: string | null;
  organizer: string;
  audience: EventAudience;
  status: 'pending' | 'published' | 'cancelled' | 'rejected';
  /** Bakan bu etkinliğe kayıtlı mı? (anonimde false) */
  registered: boolean;
  full: boolean;
  /** SP-4: şablon kodu — Koybul resmi etkinliğinde null. */
  template: UserEventTemplate | null;
  /** SP-4: etkinliği bakan mı kurdu? (kendi bekleyenini görür + iptal eder) */
  mine: boolean;
  /** SP-4: kullanıcı etkinliği mi? (istemci "topluluk" rozeti çizer) */
  community: boolean;
}

export interface UpsertDealInput {
  title: string;
  partner: string;
  benefit: string;
  code?: string | null;
  validUntil?: string | null;
  terms?: string | null;
  place?: string | null;
  audience: EventAudience;
  isActive?: boolean;
}

export interface UpsertEventInput {
  title: string;
  body: string;
  startsAt: string;
  endsAt?: string | null;
  locationText: string;
  venueLocationId?: string | null;
  quota: number;
  registrationDeadline?: string | null;
  priceNote?: string | null;
  conditions?: string | null;
  organizer?: string;
  audience: EventAudience;
}

export interface EventParticipant {
  userId: string;
  displayName: string;
  email: string;
  registeredAt: string;
}

/** Depo satırları (iç kullanım). */
export interface DealRow {
  id: string;
  title: string;
  partner: string;
  benefit: string;
  code: string | null;
  validUntil: Date | null;
  terms: string | null;
  place: string | null;
  audience: string;
  isActive: boolean;
}

export interface EventRow {
  id: string;
  title: string;
  body: string;
  startsAt: Date;
  endsAt: Date | null;
  locationText: string;
  venueLocationId: string | null;
  quota: number;
  registeredCount: number;
  registrationDeadline: Date | null;
  priceNote: string | null;
  conditions: string | null;
  organizer: string;
  audience: string;
  status: string;
  registeredByViewer: boolean;
  /** SP-4 (0023): oluşturan kaptan; NULL = Koybul resmi etkinliği. */
  createdBy: string | null;
  template: string | null;
}

export type RegisterOutcome =
  | { result: 'registered'; remaining: number }
  | { result: 'already'; remaining: number }
  | { result: 'quota' }
  | { result: 'not-open' };

export const EVENTS_REPOSITORY = Symbol('EVENTS_REPOSITORY');

export interface EventsRepository {
  activeDeals(): Promise<DealRow[]>;
  /** Yayındaki etkinlikler + İPTAL edilmiş gelecek etkinlikler (dürüst durum). */
  upcomingEvents(viewerUserId: string | null, now: Date): Promise<EventRow[]>;
  findEvent(eventId: string, viewerUserId: string | null): Promise<EventRow | null>;
  /**
   * İşlemsel kayıt: etkinlik satırı kilitlenir → sayılır → yazılır.
   * Mükerrer kayıt 'already'; dolu 'quota'; süre/iptal 'not-open'.
   */
  /** [showName]: rızalı liste tercihi — kayıtla birlikte yazılır (SP-4). */
  register(eventId: string, userId: string, now: Date, showName: boolean): Promise<RegisterOutcome>;
  /** Kayıt iptali — satır silinmez, durumu 'cancelled' olur (iz kalır). */
  cancelRegistration(eventId: string, userId: string): Promise<boolean>;
  createDeal(input: UpsertDealInput): Promise<string>;
  updateDeal(dealId: string, patch: Partial<UpsertDealInput>): Promise<boolean>;
  createEvent(input: UpsertEventInput): Promise<string>;
  updateEvent(
    eventId: string,
    patch: Partial<UpsertEventInput> & { status?: 'published' | 'cancelled' },
  ): Promise<boolean>;
  participants(eventId: string): Promise<EventParticipant[]>;

  // --- KULLANICI ETKİNLİKLERİ (SP-4, kurucu onayı 2026-10-31) ---

  /** Kullanıcı etkinliği: 'pending' doğar + moderasyon görevi (tek işlem). */
  createUserEvent(id: string, userId: string, input: CreateUserEventInput): Promise<void>;
  /** Kurucunun kendi etkinliğini iptali; satır yoksa/başkasınınsa false. */
  cancelOwnEvent(eventId: string, userId: string): Promise<boolean>;
  /** RIZALI katılımcılar — yalnız show_name=true; ad + seviye, PII yok. */
  attendees(eventId: string): Promise<PublicAttendee[]>;
}

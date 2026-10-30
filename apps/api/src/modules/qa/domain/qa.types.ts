/**
 * SORU-CEVAP (Blog V1 — kurucu onayı 2026-10-23).
 *
 * Erişim sözleşmesi (KURUCU REVİZYONU 2026-10-30, saha kararı):
 * - Liste + başlık + kısa önizleme HERKESE açık (misafir dâhil).
 * - Detay, cevaplar, soru sorma, cevap yazma, beğeni → ÜCRETSİZ HESAP
 *   yeterli (Premium ŞARTI KALDIRILDI — topluluk bilgisi herkese akar;
 *   misafir yalnız önizleme görür, hesap teşviki korunur).
 * - ARAMA + SAYFALAMA (saha isteği 2026-10-30): başlık/gövdede anahtar
 *   kelime araması; akış sayfa sayfa döner (sonsuz kaydırma yerine).
 *
 * Moderasyon KARMA model (kurucu onayı): kullanıcının İLK soru-cevap içeriği
 * kuyruktan geçer; onaylı bir içeriği olan kullanıcının sonraki içerikleri
 * ön-süzgeç (community/prefilter) temizse anında yayınlanır. ⚑ Bildir her
 * içerikte açıktır ve içeriği mevcut moderasyon kuyruğuna düşürür.
 */

export const QA_CATEGORIES = [
  'demirleme',
  'seyir',
  'ekipman',
  'marina',
  'uygulama',
  'genel',
] as const;
export type QaCategory = (typeof QA_CATEGORIES)[number];

export const QA_TITLE_MIN = 10;
export const QA_TITLE_MAX = 140;
export const QA_BODY_MIN = 30;
export const QA_BODY_MAX = 2000;
export const QA_ANSWER_MIN = 10;
export const QA_ANSWER_MAX = 2000;

/** Ücretsiz üyenin gördüğü önizleme uzunluğu — gövde istemciye HİÇ inmez. */
export const QA_PREVIEW_CHARS = 160;
/** Premium görünürlük avantajı: onaydan sonra bu kadar saat "Öne çıkan". */
export const QA_FEATURED_HOURS = 24;
/** Şeritte aynı anda en çok bu kadar soru döner (adalet kararı A). */
export const QA_FEATURED_MAX = 3;
export const QA_LIST_DEFAULT_LIMIT = 20;
export const QA_LIST_MAX_LIMIT = 50;
/** Sayfalı düzen (2026-10-30): bir sayfada bu kadar soru — kaydırma kısalır. */
export const QA_PAGE_SIZE = 10;
/** Arama metni sınırları (zod + istemci aynı). */
export const QA_SEARCH_MIN = 2;
export const QA_SEARCH_MAX = 60;

export type QaModerationStatus = 'pending' | 'approved' | 'rejected';

/** Liste satırı — herkese açık alanlar (gövde YOK, yalnız önizleme). */
export interface QaQuestionSummary {
  id: string;
  category: QaCategory;
  title: string;
  /** Gövdenin ilk QA_PREVIEW_CHARS karakteri — sunucuda kesilir. */
  preview: string;
  /** Yazarın kimliği — herkese açık kaptan kartına köprü (Hafta 1B).
   *  Notlardaki `NoteAuthor.userId` ile aynı ilke: id PII değildir. */
  authorId: string;
  authorName: string;
  /** Yazar ŞU AN Premium mu? (rozet — admin ve üstü de Premium sayılır). */
  authorPremium: boolean;
  /** "Öne çıkan" şeridinde mi? (featured_until > now) */
  featured: boolean;
  likeCount: number;
  answersCount: number;
  createdAt: string;
}

/** Detaydaki soru — tam gövdeyle (yalnız access='full' iken döner). */
export interface QaQuestionFull extends QaQuestionSummary {
  body: string;
  status: QaModerationStatus;
  mine: boolean;
  likedByMe: boolean;
}

export interface QaAnswerView {
  id: string;
  body: string;
  status: QaModerationStatus;
  /** Yazar kimliği — kaptan kartı köprüsü (Hafta 1B). */
  authorId: string;
  authorName: string;
  authorPremium: boolean;
  helpfulCount: number;
  mine: boolean;
  helpedByMe: boolean;
  createdAt: string;
}

/** Liste yanıtı: "Öne çıkan" şeridi + kronolojik akış (adalet kararı A). */
export interface QaFeed {
  featured: QaQuestionSummary[];
  items: QaQuestionSummary[];
  /** Süzgece uyan TOPLAM soru (sayfalama için, 2026-10-30). */
  total: number;
  /** Toplam sayfa sayısı — istemci sayfa seçiciyi bununla çizer. */
  pageCount: number;
  /** Dönen sayfa (1 tabanlı). */
  page: number;
}

/** Detay yanıtı — koy vitrin kilidiyle aynı erişim-kararı deseni. */
export type QaDetail =
  | { access: 'full'; question: QaQuestionFull; answers: QaAnswerView[] }
  | { access: 'teaser'; question: QaQuestionSummary; answersCount: number };

export interface CreateQuestionInput {
  category: QaCategory;
  title: string;
  body: string;
}

/** Depo satırı — SQL'den dönen ham soru (iç kullanım). */
export interface QaQuestionRow {
  id: string;
  userId: string;
  category: string;
  title: string;
  body: string;
  status: QaModerationStatus;
  featuredUntil: Date | null;
  likeCount: number;
  answersCount: number;
  createdAt: Date;
  authorName: string | null;
  authorPremium: boolean;
}

export interface QaAnswerRow {
  id: string;
  questionId: string;
  userId: string;
  body: string;
  status: QaModerationStatus;
  helpfulCount: number;
  createdAt: Date;
  authorName: string | null;
  authorPremium: boolean;
  helpedByMe: boolean;
}

export const QA_REPOSITORY = Symbol('QA_REPOSITORY');

export interface QaRepository {
  /** Onaylı sorular, yeniden eskiye; kategori + arama süzgeçli, sayfalı. */
  list(
    category: QaCategory | null,
    search: string | null,
    offset: number,
    limit: number,
  ): Promise<QaQuestionRow[]>;
  /** Süzgece uyan toplam onaylı soru — sayfa sayısı bundan türer. */
  count(category: QaCategory | null, search: string | null): Promise<number>;
  /** "Öne çıkan" şeridi: featured_until > now, en yeni QA_FEATURED_MAX adet. */
  featured(limit: number): Promise<QaQuestionRow[]>;
  /** Soru + yazar bilgisi; silinmişse null (durum süzgeci YOK — karar serviste). */
  findQuestion(id: string): Promise<QaQuestionRow | null>;
  /** Onaylı cevaplar + bakanın kendi bekleyen cevapları, eskiden yeniye. */
  answersFor(questionId: string, viewerUserId: string | null): Promise<QaAnswerRow[]>;
  /** Bakan bu soruyu beğenmiş mi? (viewer yoksa false) */
  likedBy(questionId: string, viewerUserId: string): Promise<boolean>;
  /** Kullanıcının onaylı bir soru-cevap içeriği var mı? (karma moderasyon) */
  hasApprovedContent(userId: string): Promise<boolean>;
  /** Kullanıcının bu soruda ONAYLI cevabı var mı? (süresi biten premium kuralı) */
  hasApprovedAnswerIn(questionId: string, userId: string): Promise<boolean>;
  createQuestion(
    id: string,
    userId: string,
    input: CreateQuestionInput,
    status: QaModerationStatus,
    featuredUntil: Date | null,
  ): Promise<QaQuestionRow>;
  createAnswer(
    id: string,
    questionId: string,
    userId: string,
    body: string,
    status: QaModerationStatus,
  ): Promise<QaAnswerRow>;
  /** Beğeni aç/kapa — kendi sorusuna izin verilmez (serviste denetlenir). */
  toggleLike(questionId: string, userId: string): Promise<{ liked: boolean; likeCount: number }>;
  toggleHelpful(
    answerId: string,
    userId: string,
  ): Promise<{ helped: boolean; helpfulCount: number }>;
  /** Cevap sahibi + durumu (faydalı/şikâyet denetimleri için). */
  findAnswerMeta(
    answerId: string,
  ): Promise<{ userId: string; status: QaModerationStatus; questionId: string } | null>;
  /**
   * ⚑ Bildir: içerik YAYINDA KALIR, moderasyon görevi 'pending'e çekilir
   * (önce-yayın ilkesi; karar moderatörün). Var olmayan içerikte false.
   */
  report(entity: 'qa_question' | 'qa_answer', entityId: string): Promise<boolean>;
}

/**
 * Otomatik ön filtre — moderasyon kuyruğuna gelmeden önceki YAPISAL tarama.
 *
 * Kapsam bilinçli olarak dar: link/iletişim bilgisi, bağırma, tekrar, çok kısa
 * içerik. Küfür/argo sözlüğü BURADA YOK — kelime listeleri yanlış pozitif üretir
 * (denizcilik terimleri, yer adları) ve bakımı sürekli iş çıkarır. Bu iş insan
 * moderasyonuna bırakılır; ön filtre yalnız KUYRUK ÖNCELİĞİ ve otomatik yayın
 * kararı için sinyal üretir, tek başına içerik REDDETMEZ.
 */

export type PrefilterFlag = 'too_short' | 'many_links' | 'contact_info' | 'shouting' | 'repetition';

export interface PrefilterResult {
  flags: PrefilterFlag[];
  /** Hiç bayrak yoksa temiz. */
  clean: boolean;
}

const URL_RE = /https?:\/\/|www\./gi;
/** E.164 benzeri veya 10+ haneli yerel numara. */
const PHONE_RE = /(\+\d[\d\s().-]{8,})|(\b0?5\d{2}[\s.-]?\d{3}[\s.-]?\d{2}[\s.-]?\d{2}\b)/;
const EMAIL_RE = /[\w.+-]+@[\w-]+\.[\w.]{2,}/;

export const MIN_MEANINGFUL_CHARS = 15;
export const MAX_LINKS = 1;
export const SHOUT_MIN_CHARS = 20;
export const SHOUT_RATIO = 0.6;
export const REPEAT_RUN = 8;

/** Türkçe büyük harfleri de sayan oran (İ/I/Ş/Ğ/Ü/Ö/Ç dahil). */
function upperRatio(text: string): number {
  const letters = [...text].filter((c) => c.toLocaleLowerCase('tr') !== c.toLocaleUpperCase('tr'));
  if (letters.length === 0) return 0;
  const upper = letters.filter((c) => c === c.toLocaleUpperCase('tr'));
  return upper.length / letters.length;
}

export function screenText(body: string): PrefilterResult {
  const flags: PrefilterFlag[] = [];
  const text = body.trim();

  if (text.length < MIN_MEANINGFUL_CHARS) flags.push('too_short');
  if ((text.match(URL_RE) ?? []).length > MAX_LINKS) flags.push('many_links');
  // Kişisel veri hijyeni (KVKK): telefon/e-posta serbest metinde yayınlanmaz.
  if (PHONE_RE.test(text) || EMAIL_RE.test(text)) flags.push('contact_info');
  if (text.length >= SHOUT_MIN_CHARS && upperRatio(text) >= SHOUT_RATIO) flags.push('shouting');
  if (new RegExp(`(.)\\1{${REPEAT_RUN - 1},}`).test(text)) flags.push('repetition');

  return { flags, clean: flags.length === 0 };
}

/**
 * Otomatik yayın kararı.
 *
 * YALNIZ "güncel durum" notu otomatik yayınlanabilir: 48 saat ömürlü, 280
 * karakter, GPS doğrulamalı ve tek değeri TAZELİK olan tip. 24 saat sonra
 * onaylanan bir "ücret 450 TL oldu" bilgisi değersizdir.
 *
 * Şartlar birlikte sağlanmalı: ön filtre temiz + kullanıcı güveni tam +
 * en az bir onaylı katkı geçmişi. Yeni ya da lekeli hesap kuyruğa gider.
 * Uyarı (hazard) tipi ASLA otomatik yayınlanmaz — yanlış emniyet bilgisi
 * tehlikelidir (tasarım §9.4).
 */
export function shouldAutoPublish(params: {
  kind: string;
  prefilter: PrefilterResult;
  trustScore: number;
  approvedCount: number;
}): boolean {
  return (
    params.kind === 'status' &&
    params.prefilter.clean &&
    params.trustScore >= 1 &&
    params.approvedCount >= 1
  );
}

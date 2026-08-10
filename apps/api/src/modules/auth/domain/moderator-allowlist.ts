import { RoleCode } from '../../../core/auth/principal';

/**
 * MODERATÖR LİSTESİ — saf ayrıştırma ve karar (docs/23 §4.1).
 *
 * Ortam değişkeninden gelen ham metni güvenli bir listeye çevirir ve "bu
 * hesap yükseltilmeli mi?" sorusunu yanıtlar. Veritabanına, saate, ağa
 * dokunmaz: yetki kararı ürünün en hassas parçasıdır, tamamı birim testiyle
 * kilitlenebilmelidir.
 */

/** Adresler virgül, noktalı virgül, boşluk ya da satır sonuyla ayrılabilir. */
const SEPARATORS = /[,;\s]+/;

/**
 * Ham `MODERATOR_EMAILS` değerini normalize edilmiş listeye çevirir.
 * Küçük harfe indirir, boşlukları kırpar, tekrarları eler ve '@' içermeyen
 * girdileri ATAR — yapılandırma hatası sessizce yanlış hesabı yükseltmesin.
 */
export function parseModeratorEmails(raw: string | undefined | null): string[] {
  if (!raw) return [];
  const seen = new Set<string>();
  for (const part of raw.split(SEPARATORS)) {
    const email = part.trim().toLowerCase();
    // '@' hem başta hem sonda karakter istemeli: "a@" ya da "@b" adres değildir.
    const at = email.indexOf('@');
    if (at <= 0 || at === email.length - 1) continue;
    seen.add(email);
  }
  return [...seen];
}

/** Rol sıralaması — `roleAtLeast` ile aynı hiyerarşi, burada yalnız eşik için. */
const PROMOTABLE_FROM: ReadonlySet<RoleCode> = new Set<RoleCode>(['user']);

/**
 * E-postası SAHİPLİĞİ KANITLANMIŞ sayılan giriş yöntemleri.
 *
 * Firebase'de `email_verified` iddiası sağlayıcıya göre farklı ağırlık taşır:
 * Google ve Apple adresi kendileri doğrular; `password` ile kayıtta ise adres
 * hiç doğrulanmaz. Bu yüzden yalnız `email_verified` yetmez, SAĞLAYICI da
 * beyaz listede olmalıdır (güvenlik incelemesi 2026-08).
 */
const TRUSTED_EMAIL_PROVIDERS: ReadonlySet<string> = new Set<string>(['google.com', 'apple.com']);

export interface PromotionCheck {
  /** Firebase kimliğinden gelen e-posta (null olabilir: telefon/anonim giriş). */
  email: string | null | undefined;
  /** Adres sahipliği kanıtlandı mı (`email_verified`). */
  emailVerified: boolean;
  /** Firebase `sign_in_provider` — 'google.com' | 'apple.com' | 'password' | … */
  provider: string;
  /** Misafir hesap ASLA yükseltilmez. */
  isGuest: boolean;
  /** Hesabın şu anki rolü. */
  role: RoleCode;
  list: readonly string[];
}

/**
 * Bu giriş, hesabı moderatöre yükseltmeli mi?
 *
 * KURALLAR:
 *  · Liste boşsa hiçbir şey yapılmaz (varsayılan güvenli).
 *  · E-posta yoksa (telefonla ya da anonim giriş) yükseltme YOK.
 *  · ADRES DOĞRULANMAMIŞSA YÜKSELTME YOK. Bu kural KRİTİKTİR: Firebase'in
 *    web API anahtarı uygulama paketinden çıkarılabilir ve e-posta+parola
 *    kaydı adres sahipliğini HİÇ denetlemez. Bu kural olmadan, saldırgan
 *    listedeki adresle kayıt olup geçerli bir Firebase token'ı alır ve
 *    moderatör olurdu (güvenlik incelemesi 2026-08).
 *  · Sağlayıcı da güvenilir olmalı: `email_verified` iddiasını Google/Apple
 *    kendi doğrular, `password` sağlayıcısında bu iddia kullanıcı eylemiyle
 *    (doğrulama e-postası) doğru olabilse de zinciri Google garanti etmez.
 *  · Misafir hesap yükseltilmez — önce gerçek hesaba dönmesi gerekir.
 *  · Yalnız `user` rolü yükseltilir. `admin`/`super_admin` DOKUNULMAZ:
 *    aksi halde bu liste bir yükseltme aracı değil, sessiz bir DÜŞÜRME
 *    aracı olurdu.
 *  · Zaten moderatörse tekrar yazılmaz (gereksiz UPDATE yok).
 */
export function shouldPromoteToModerator(c: PromotionCheck): boolean {
  if (c.list.length === 0) return false;
  if (c.isGuest) return false;
  if (!c.emailVerified) return false;
  if (!TRUSTED_EMAIL_PROVIDERS.has(c.provider)) return false;
  if (!PROMOTABLE_FROM.has(c.role)) return false;
  const email = c.email?.trim().toLowerCase();
  if (!email) return false;
  return c.list.includes(email);
}

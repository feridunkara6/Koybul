import { z } from 'zod';

/**
 * Ortam değişkeni şeması (docs/24 §16 — fail-fast).
 * Eksik/yanlış değişkende uygulama HİÇ ayağa kalkmaz.
 */
export const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'staging', 'production', 'test']),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  DATABASE_URL: z.string().url().startsWith('postgresql://'),
  REDIS_URL: z.string().url().startsWith('redis://'),
  LOG_LEVEL: z.enum(['trace', 'debug', 'info', 'warn', 'error']).default('info'),
  /** Graceful shutdown süresi (ms) — ALB deregistration delay ile hizalı. */
  SHUTDOWN_TIMEOUT_MS: z.coerce.number().int().positive().default(10_000),
  /** Firebase ID token doğrulaması (docs/23 §3.1): aud/iss pinning için proje kimliği. */
  FIREBASE_PROJECT_ID: z.string().min(1),
  /** RS256 imzalama anahtarları (PEM, PKCS8/SPKI). Kaynak: SSM (docs/28 §5). */
  JWT_PRIVATE_KEY_PEM: z.string().includes('BEGIN'),
  JWT_PUBLIC_KEY_PEM: z.string().includes('BEGIN'),
  /** Anahtar rotasyonu için key id (docs/23 §3.2). */
  JWT_KID: z.string().min(1).default('dockly-k1'),
  ACCESS_TOKEN_TTL_SEC: z.coerce.number().int().min(60).max(3600).default(900),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().min(1).max(365).default(60),
  /** /auth uçları IP başına dakikalık tavan (docs/30 §1). */
  AUTH_RATE_LIMIT_PER_MIN: z.coerce.number().int().min(1).default(10),
  /**
   * Genel hız sınırları — IP başına dakikalık tavan (bulgu 2026-08: 26 uçtan
   * yalnız 2'si sınırlıydı; /weather açık bir vekildi). Okuma cömert, yazma
   * dar: harita gezinmesi çok istek üretir, içerik gönderimi üretmez.
   */
  READ_RATE_LIMIT_PER_MIN: z.coerce.number().int().min(1).default(300),
  WRITE_RATE_LIMIT_PER_MIN: z.coerce.number().int().min(1).default(60),
  /**
   * İzleme (monitoring) — OPSİYONEL (Faz A.6 iskeleti, docs/implementation/monitoring-kurulum-rehberi.md).
   * DSN verilmezse Sentry devre dışı; hata izleme ara çözümü log tabanlı alarmdır
   * (5xx logları `event: 'server_error'` etiketiyle akar). SDK bağlanınca burası okunur.
   */
  SENTRY_DSN: z.string().url().optional(),
  SENTRY_ENVIRONMENT: z.enum(['development', 'staging', 'production', 'test']).optional(),
  /**
   * MODERATÖR LİSTESİ — virgülle ayrılmış e-posta adresleri.
   *
   * NEDEN VAR: `roles` tablosunda moderatör rolü baştan beri tanımlı ama onu
   * kimseye VEREN bir yol yoktu; herkes `user` olarak kaydoluyordu. Sonuç:
   * incelemeye düşen not sonsuza kadar orada kalıyor ve Moderasyon ekranı
   * hiç kimseye açılmıyordu (bulgu 2026-08, topluluk adım 4 sonrası).
   *
   * Buradaki adresle GİRİŞ YAPILDIĞI AN hesap moderatöre yükseltilir; rol
   * veritabanına yazılır, yani listeden sonradan çıkarılsa bile geri
   * düşmez (yetki alma işi bilinçli olarak elle yapılır).
   *
   * Boş bırakılabilir: o zaman kimse otomatik yükseltilmez.
   */
  MODERATOR_EMAILS: z.string().optional(),
});

export type Env = z.infer<typeof envSchema>;

export function validateEnv(raw: NodeJS.ProcessEnv): Env {
  const parsed = envSchema.safeParse(raw);
  if (!parsed.success) {
    const details = parsed.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ');
    throw new Error(`Ortam yapılandırması geçersiz — ${details}`);
  }
  return parsed.data;
}

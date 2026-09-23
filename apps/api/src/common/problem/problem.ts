import { HttpStatus } from '@nestjs/common';

/**
 * RFC 9457 Problem Details sözleşmesi (docs/23 §5).
 * `type` URI'si ve `errors[].code` makine sözleşmesidir; mesajlar sunum detayıdır.
 */
export const PROBLEM_BASE = 'https://api.dockly.app/problems/';

export interface FieldError {
  field: string;
  code: string;
  message: string;
}

export interface ProblemBody {
  type: string;
  title: string;
  status: number;
  detail?: string;
  instance?: string;
  requestId?: string;
  errors?: FieldError[];
}

/** docs/23 §5 çekirdek problem type kataloğu. */
export type ProblemType =
  | 'invalid-token'
  | 'token-expired'
  | 'guest-not-allowed'
  | 'forbidden'
  | 'not-found'
  | 'conflict-state'
  | 'duplicate-review'
  | 'duplicate-request'
  | 'validation-error'
  | 'quota-exceeded'
  | 'premium-required'
  | 'rate-limited'
  | 'payload-too-large'
  | 'service-unavailable'
  | 'internal';

const CATALOG: Record<ProblemType, { status: HttpStatus; title: string }> = {
  'invalid-token': { status: HttpStatus.UNAUTHORIZED, title: 'Geçersiz kimlik' },
  'token-expired': { status: HttpStatus.UNAUTHORIZED, title: 'Oturum süresi doldu' },
  'guest-not-allowed': { status: HttpStatus.FORBIDDEN, title: 'Bu işlem için hesap gerekli' },
  forbidden: { status: HttpStatus.FORBIDDEN, title: 'Yetkiniz yok' },
  'not-found': { status: HttpStatus.NOT_FOUND, title: 'Bulunamadı' },
  'conflict-state': { status: HttpStatus.CONFLICT, title: 'Geçersiz durum geçişi' },
  'duplicate-review': { status: HttpStatus.CONFLICT, title: 'Bu noktaya zaten yorumunuz var' },
  'duplicate-request': { status: HttpStatus.CONFLICT, title: 'Bu tarihlere aktif talebiniz var' },
  'validation-error': { status: HttpStatus.UNPROCESSABLE_ENTITY, title: 'Doğrulama hatası' },
  // Keşif hakkı tavanı (P1, premium v3 raporu K2) — mobil bu tipe paywall açar.
  'quota-exceeded': { status: HttpStatus.FORBIDDEN, title: 'Aylık keşif hakkı doldu' },
  // Kilitli içerik ucu (P5, premium v3 §9): vitrin gören kullanıcıya yorum
  // listesi gibi kilitli veriler İNMEZ — boş liste yalanı yerine dürüst 403.
  'premium-required': { status: HttpStatus.FORBIDDEN, title: 'Bu içerik Premium ile açılır' },
  'rate-limited': { status: HttpStatus.TOO_MANY_REQUESTS, title: 'Çok fazla istek' },
  'payload-too-large': { status: HttpStatus.PAYLOAD_TOO_LARGE, title: 'İçerik çok büyük' },
  'service-unavailable': {
    status: HttpStatus.SERVICE_UNAVAILABLE,
    title: 'Servis geçici olarak kullanılamıyor',
  },
  internal: { status: HttpStatus.INTERNAL_SERVER_ERROR, title: 'Beklenmeyen hata' },
};

/**
 * Domain/uygulama katmanının fırlattığı tek istisna ailesi (docs/24 §6, §14).
 * HTTP bilgisi taşımaz görünür ama katalog eşlemesi burada merkezidir.
 */
export class AppProblem extends Error {
  readonly problemType: ProblemType;
  readonly detail?: string;
  readonly errors?: FieldError[];
  /** Yanıta eklenecek header'lar (ör. rate-limited → Retry-After, docs/23 §6). */
  readonly headers?: Record<string, string>;

  constructor(
    problemType: ProblemType,
    detail?: string,
    errors?: FieldError[],
    headers?: Record<string, string>,
  ) {
    super(detail ?? CATALOG[problemType].title);
    this.name = 'AppProblem';
    this.problemType = problemType;
    this.detail = detail;
    this.errors = errors;
    this.headers = headers;
  }

  get status(): number {
    return CATALOG[this.problemType].status;
  }

  toBody(instance?: string, requestId?: string): ProblemBody {
    const { status, title } = CATALOG[this.problemType];
    return {
      type: `${PROBLEM_BASE}${this.problemType}`,
      title,
      status,
      ...(this.detail ? { detail: this.detail } : {}),
      ...(instance ? { instance } : {}),
      ...(requestId ? { requestId } : {}),
      ...(this.errors?.length ? { errors: this.errors } : {}),
    };
  }
}

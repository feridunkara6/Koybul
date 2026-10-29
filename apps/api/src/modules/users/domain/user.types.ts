import { RoleCode } from '../../../core/auth/principal';

/** GET /v1/users/me yanıt modeli (docs/23 §10 #4). */
export interface UserMe {
  id: string;
  email: string | null;
  phone: string | null;
  role: RoleCode;
  isGuest: boolean;
  locale: string;
  countryCode: string;
  createdAt: string;
  profile: {
    displayName: string;
    fullName: string | null;
    bio: string | null;
    experienceYears: number | null;
  };
  settings: {
    theme: 'system' | 'light' | 'dark';
    units: 'metric' | 'imperial';
    marketingConsent: boolean;
  };
}

/**
 * GET /v1/users/:id/public yanıtı (Sosyalleşme Hafta 1B, kurucu onayı
 * 2026-10-24): kaptanın HERKESE AÇIK kartviziti.
 *
 * PII İÇERMEZ: e-posta, telefon, gerçek ad (fullName), rol, premium durumu,
 * konum ve marina bilgisi bu modelde YOKTUR ve eklenmez. Yalnız kullanıcının
 * toplulukta zaten imzaladığı kimlik (görünen ad) + kendi beyan ettiği
 * tanıtım alanları + sunucunun hesapladığı itibar taşınır.
 */
export interface PublicCaptain {
  id: string;
  displayName: string;
  bio: string | null;
  experienceYears: number | null;
  /** Üyelik başlangıcı (yalnız yıl hassasiyetinde gösterilmesi önerilir). */
  memberSince: string;
  points: number;
  levelCode: string;
  approvedCount: number;
  helpfulReceived: number;
  /** Geri alınmamış rozet kodları — etiket metinleri istemcide (4 dil). */
  badges: string[];
  /** SON KATKILAR vitrini (SP-1 Kimlik, kurucu onayı 2026-10-29): yalnız
   *  ONAYLI içerik — en yeni birkaç not (koy adıyla) + paylaşılan rota.
   *  PII taşımaz; içerik zaten herkese açık yüzeylerde yayındadır. */
  recentContributions: CaptainContribution[];
}

/** Kaptan kartındaki tek vitrin satırı. */
export interface CaptainContribution {
  kind: 'note' | 'route';
  /** Not için koy adı; rota için rota adı. Koy adı silinmişse null. */
  title: string | null;
  /** Not türü kodu ('hazard'|'status'|'experience'|'passage') — etiket istemcide. */
  noteKind: string | null;
  /** Rota için kaydedilme sayısı; not için null. */
  savedCount: number | null;
  /** ISO 8601 oluşturulma zamanı. */
  createdAt: string;
}

/** PATCH /v1/users/me girişi — JSON Merge Patch alt kümesi; alan beyaz listesi (SEC). */
export interface UpdateMeInput {
  locale?: 'tr' | 'en';
  profile?: {
    displayName?: string;
    fullName?: string | null;
    bio?: string | null;
    experienceYears?: number | null;
  };
  settings?: {
    theme?: 'system' | 'light' | 'dark';
    units?: 'metric' | 'imperial';
    marketingConsent?: boolean;
  };
}

import type { NoteKind } from './scoring';

export type { NoteKind };

/** Yayına çıkmış bir Kaptan Notu (istemciye dönen biçim). */
export interface Note {
  id: string;
  kind: NoteKind;
  locationId: string | null;
  fromLocationId: string | null;
  toLocationId: string | null;
  title: string | null;
  body: string;
  observedOn: string; // YYYY-MM-DD
  gpsVerified: boolean;
  /** Not yazılırken dondurulan hava özeti — sonradan sorgulanmaz. */
  wind: { kn: number; dirTr: string } | null;
  helpfulCount: number;
  confirmCount: number;
  disputeCount: number;
  createdAt: string;
  author: NoteAuthor;
  /** Yalnız sahibine dolu döner (kendi bekleyen/reddedilen içeriğini görür). */
  status?: 'pending' | 'approved' | 'rejected';
}

/** Not yazarının PII taşımayan kamuya açık kimliği. */
export interface NoteAuthor {
  userId: string;
  displayName: string;
  levelCode: string;
  /** Bu notun bölgesinde kaç onaylı katkısı var (bölgesel uzmanlık sinyali). */
  areaContributions: number | null;
}

export interface CreateNoteInput {
  kind: NoteKind;
  locationId?: string;
  fromLocationId?: string;
  toLocationId?: string;
  title?: string | null;
  body: string;
  observedOn: string;
  boatId?: string | null;
  position?: { lat: number; lon: number };
  wind?: { kn: number; dirTr: string } | null;
}

export type UpdateNoteInput = { title?: string | null; body?: string };

export type NoteReaction = 'helpful' | 'confirm' | 'dispute';

/** Gövde uzunluğu tipe göre sınırlıdır (DB CHECK ile birebir aynı). */
export const NOTE_BODY_MAX: Record<NoteKind, number> = {
  status: 280,
  hazard: 500,
  experience: 4000,
  passage: 4000,
};
export const NOTE_BODY_MIN = 3;
export const NOTE_TITLE_MAX = 120;

/** Taze bilgi tipleri gerçek GPS ister. */
export const GPS_REQUIRED_KINDS: NoteKind[] = ['status', 'hazard'];

/** İstemci eşiği 5 NM; sunucu GPS sapması payıyla biraz gevşektir (occupancy deseni). */
export const NOTE_MAX_REPORT_DISTANCE_M = 11_112; // 6 NM

/** "Güncel durum" notunun öne çıkma süresi. */
export const STATUS_NOTE_TTL_HOURS = 48;

/** "Yakında paylaşılanlar" akışının varsayılan penceresi. */
export const NEARBY_DEFAULT_HOURS = 48;
export const NEARBY_MAX_HOURS = 168;
export const NEARBY_DEFAULT_RADIUS_NM = 50;
export const NEARBY_MAX_RADIUS_NM = 200;

/**
 * İki bağımsız çelişki bildirimi bir uyarıyı yeniden incelemeye düşürür.
 * Tek kişi bir uyarıyı yayından kaldıramaz — emniyet bilgisi bu kadar ucuz olmamalı.
 */
export const HAZARD_DISPUTE_THRESHOLD = 2;

/** Aynı hedefe 3 şikâyet → içerik otomatik yeniden incelemeye alınır (docs/12 §8.2). */
export const AUTO_HIDE_REPORT_THRESHOLD = 3;

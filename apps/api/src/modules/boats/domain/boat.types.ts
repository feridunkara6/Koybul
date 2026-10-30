/** Tekne DTO'su (docs/23 §10 #7). Ölçüler metrik + birim son eki (docs/22 §1.8). */
export interface Boat {
  id: string;
  name: string;
  boatTypeCode: string;
  brand: string | null;
  model: string | null;
  buildYear: number | null;
  lengthM: number;
  beamM: number | null;
  draftM: number | null;
  engineTypeCode: string | null;
  flagCountryCode: string | null;
  registrationNo: string | null;
  isPrimary: boolean;
  createdAt: string;
}

/**
 * GET /v1/boats/:id/public yanıtı — TEKNE KARTI (Sosyalleşme Hafta 2,
 * kurucu onayı 2026-10-24).
 *
 * GİZLİLİK SÖZLEŞMESİ marina listesinin devamıdır: kart YALNIZ sahibi
 * "Marinada görün"ü (visibleInMarina) açtıysa vardır; teknik alanlar
 * (marka/model/boy/yıl) shareSpecs rızasına bağlıdır — kapalıysa null bile
 * değil, istemciye HİÇ inmez. Konum, bağlama yeri, sicil no ve iletişim
 * bu modelde YOKTUR. Çizim istemcide üretilir (marka+model → çizim
 * kütüphanesi); sunucu görsel taşımaz.
 */
export interface PublicBoatCard {
  id: string;
  name: string;
  boatTypeCode: string;
  /** shareSpecs kapalıysa dördü birden null. */
  brand: string | null;
  model: string | null;
  lengthM: number | null;
  buildYear: number | null;
  marina: { id: string; name: string } | null;
  captain: { userId: string; displayName: string; levelCode: string };
  /** TEKNENİN HİKÂYESİ (0024): yalnız moderasyon ONAYLI metin iner. */
  story: string | null;
  /** Kart istatistikleri (0024) — zaten paylaşılmış içerikten TÜRETİLİR. */
  stats: { sharedTrips: number; sharedRoutes: number; pruvaTotal: number };
  /** Kaptanın ONAYLI rotaları (en yeni 5) — rota detayına köprü. */
  routes: PublicBoatRouteRef[];
  /** FAVORİLE (TK-5, 0025): toplam sayı — kimlerin favorilediği inmez. */
  favoriteCount: number;
  /** Kaptanın takipçi sayısı (0021'den türetilir; kurucu isteği 2026-10-30). */
  captainFollowers: number;
  /**
   * KARDEŞ TEKNELER (TK-5): aynı marka+model, yalnız görünür VE teknik
   * bilgisini paylaşan tekneler (çifte rıza). Eşleşme yoksa boş liste.
   */
  sisters: PublicBoatSisterRef[];
}

/** Karttaki tek kardeş tekne satırı — herkese açık asgari alanlar. */
export interface PublicBoatSisterRef {
  id: string;
  name: string;
  boatTypeCode: string;
  marinaName: string | null;
}

/** GET /v1/me/favorite-boats satırı — kişinin kendi favori listesi. */
export interface FavoriteBoatRef {
  id: string;
  name: string;
  boatTypeCode: string;
  brand: string | null;
  model: string | null;
  marinaName: string | null;
}

/** Karttaki tek rota satırı — herkese açık alanlar. */
export interface PublicBoatRouteRef {
  id: string;
  name: string;
  distanceNm: number;
  saveCount: number;
}

/** POST /v1/boats girdisi — zorunlu alanlar + lookup kodları. */
export interface CreateBoatInput {
  name: string;
  boatTypeCode: string;
  lengthM: number;
  brand?: string | null;
  model?: string | null;
  buildYear?: number | null;
  beamM?: number | null;
  draftM?: number | null;
  engineTypeCode?: string | null;
  flagCountryCode?: string | null;
  registrationNo?: string | null;
  /** İlk tekne otomatik birincil olur; açıkça true verilirse mevcut birincil devredilir. */
  isPrimary?: boolean;
}

/** PATCH — tüm alanlar opsiyonel; kimlik/sahiplik alanları YOK (SEC beyaz listesi). */
export type UpdateBoatInput = Partial<CreateBoatInput>;

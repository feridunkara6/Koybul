/**
 * MARİNA TOPLULUĞU (V1 — kurucu onayı 2026-10-23).
 *
 * GİZLİLİK SÖZLEŞMESİ (kurucu kararı, konsept onayı):
 * - Toplam tekne SAYISI herkese açıktır ve isimsizdir.
 * - Tekne ADI yalnız sahibi 'Marinada görün'ü (visible) açarsa listelenir —
 *   varsayılan KAPALI. Tip/boy/marka ayrıca 'shareSpecs' rızasına bağlıdır.
 * - Konum, bağlama yeri, iletişim bilgisi HİÇBİR ZAMAN paylaşılmaz.
 *
 * ERİŞİM (kurucu kararı): kendi marinanın listesi tüm hesaplara ücretsiz;
 * BAŞKA marinaların listesini gezmek Premium (admin+ her zaman). Sayılar
 * herkese. PREMIUM_ENFORCE kapalıyken tüm listeler açık (bugünkü davranış).
 *
 * Sayılar CANLI sorgudan gelir — ayrı sayaç tablosu yoktur; marina değişince
 * eski liste anında düşer, yenisi anında artar (tutarsızlaşacak kopya yok).
 */

/** Topluluk listesinde tek tekne — yalnız sahibinin paylaştığı alanlar. */
export interface MarinaBoat {
  name: string;
  boatTypeCode: string;
  /** shareSpecs kapalıysa null gelir (istemciye hiç inmez). */
  lengthM: number | null;
  brand: string | null;
  captainName: string;
}

export interface MarinaCommunity {
  marina: { id: string; name: string };
  /** Bu marinayı seçmiş toplam Koybul teknesi (gizliler dâhil, isimsiz). */
  total: number;
  /** 'Marinada görün'ü açık tekne sayısı. */
  visibleCount: number;
  /** 'full' = liste döner; 'counts' = yalnız sayılar (liste boş). */
  access: 'full' | 'counts';
  boats: MarinaBoat[];
}

/** Kullanıcının sunucuya kayıtlı (birincil) teknesi + topluluk tercihleri. */
export interface MyMarinaBoat {
  boatId: string;
  name: string;
  boatTypeCode: string;
  lengthM: number;
  brand: string | null;
  marina: { id: string; name: string } | null;
  visible: boolean;
  shareSpecs: boolean;
}

/** PUT /v1/marina/my-boat girdisi — tekneyi kaydeder/günceller ve marinaya bağlar. */
export interface UpsertMyBoatInput {
  name: string;
  boatTypeCode: string;
  lengthM: number;
  brand?: string | null;
  marinaLocationId: string;
  visible: boolean;
  shareSpecs: boolean;
}

export const MARINA_REPOSITORY = Symbol('MARINA_REPOSITORY');

export interface MarinaRepository {
  /** Yayında ve marina tipinde mi? Değilse null (koy/iskele marina DEĞİLDİR). */
  marinaInfo(locationId: string): Promise<{ id: string; name: string } | null>;
  /** Kullanıcının birincil teknesi (yoksa null). */
  findMyBoat(userId: string): Promise<MyMarinaBoat | null>;
  /** Birincil tekneyi oluşturur ya da günceller; marina + rızaları yazar. */
  upsertMyBoat(userId: string, input: UpsertMyBoatInput): Promise<MyMarinaBoat>;
  /** Geçerli tekne tipi kodu mu? (boat_types sözlüğü) */
  boatTypeValid(code: string): Promise<boolean>;
  /** Bakanın bu marinada kayıtlı teknesi var mı? (kendi-marinan ücretsiz kuralı) */
  isMemberOf(userId: string, locationId: string): Promise<boolean>;
  counts(locationId: string): Promise<{ total: number; visibleCount: number }>;
  /** Yalnız görünür tekneler; specs alanları shareSpecs rızasına göre null'lanır. */
  visibleBoats(locationId: string): Promise<MarinaBoat[]>;
}

/** Yorum yazma tarafı (okuma tarafı locations modülünde kalır). */
export interface CreateReviewInput {
  overallRating: number;
  title?: string | null;
  body?: string | null;
  visitedOn?: string | null;
  boatId?: string | null;
  /** Boyut kodu → 1..5 puan (rating_dimensions seed'inden). */
  dimensions?: Record<string, number>;
}

export type UpdateReviewInput = Partial<CreateReviewInput>;

export interface ReviewWriteResult {
  id: string;
  status: 'pending' | 'approved' | 'rejected';
  bodyLength: number;
}

export interface ReviewsWriteRepository {
  /** Lokasyon yayında mı? Değilse yorum yazılamaz. */
  publishedLocationId(idOrSlug: string): Promise<string | null>;
  /** Kullanıcının bu noktada aktif yorumu var mı (UNIQUE kısıtı öncesi kontrol). */
  existingReviewId(locationId: string, userId: string): Promise<string | null>;
  create(
    id: string,
    locationId: string,
    userId: string,
    input: CreateReviewInput,
  ): Promise<ReviewWriteResult>;
  update(
    reviewId: string,
    userId: string,
    patch: UpdateReviewInput,
  ): Promise<ReviewWriteResult | null>;
  softDelete(reviewId: string, userId: string): Promise<boolean>;
  /** Yayındaki yorumun sahibi — oy YAZILMADAN ÖNCE kontrol için. */
  findOwner(reviewId: string): Promise<string | null>;
  /** "Faydalı" oyu. Sayacı DB tetikleyicisi günceller; burada yalnız okunur. */
  react(
    reviewId: string,
    userId: string,
  ): Promise<{ helpfulCount: number; ownerUserId: string; created: boolean } | null>;
  /** Geçersiz boyut kodlarını döndürür (422 alan hatası üretmek için). */
  invalidDimensionCodes(codes: string[]): Promise<string[]>;
}

export const REVIEWS_WRITE_REPOSITORY = Symbol('REVIEWS_WRITE_REPOSITORY');

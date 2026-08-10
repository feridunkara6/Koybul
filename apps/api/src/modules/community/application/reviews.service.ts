import { Inject, Injectable } from '@nestjs/common';
import { uuidv7 } from 'uuidv7';
import { AppProblem, FieldError } from '../../../common/problem/problem';
import { Principal } from '../../../core/auth/principal';
import {
  CreateReviewInput,
  REVIEWS_WRITE_REPOSITORY,
  ReviewWriteResult,
  ReviewsWriteRepository,
  UpdateReviewInput,
} from '../domain/reviews.repository';
import { ReputationService } from './reputation.service';

@Injectable()
export class ReviewsService {
  constructor(
    @Inject(REVIEWS_WRITE_REPOSITORY) private readonly reviews: ReviewsWriteRepository,
    private readonly reputation: ReputationService,
  ) {}

  async create(
    principal: Principal,
    idOrSlug: string,
    input: CreateReviewInput,
  ): Promise<ReviewWriteResult> {
    const state = await this.reputation.authorState(principal.userId);
    this.reputation.assertCanWrite(state);

    const locationId = await this.reviews.publishedLocationId(idOrSlug);
    if (!locationId) throw new AppProblem('not-found');

    // Lokasyon başına TEK aktif yorum (docs/01-prd §6.8, DB partial unique).
    const existing = await this.reviews.existingReviewId(locationId, principal.userId);
    if (existing) {
      throw new AppProblem('duplicate-review', 'Bu noktaya zaten yorumun var — düzenleyebilirsin.');
    }

    await this.assertDimensionsValid(input.dimensions);
    return this.reviews.create(uuidv7(), locationId, principal.userId, input);
  }

  async update(
    principal: Principal,
    reviewId: string,
    patch: UpdateReviewInput,
  ): Promise<ReviewWriteResult> {
    await this.assertDimensionsValid(patch.dimensions);
    const res = await this.reviews.update(reviewId, principal.userId, patch);
    if (!res) throw new AppProblem('not-found');
    return res;
  }

  async remove(principal: Principal, reviewId: string): Promise<void> {
    const ok = await this.reviews.softDelete(reviewId, principal.userId);
    if (!ok) throw new AppProblem('not-found');
  }

  async react(principal: Principal, reviewId: string): Promise<{ helpfulCount: number }> {
    const state = await this.reputation.authorState(principal.userId);
    this.reputation.assertCanWrite(state);

    // Sahiplik YAZMADAN ÖNCE kontrol edilir: sonradan bakınca oy satırı zaten
    // kaydedilmiş oluyor ve 403 onu geri almıyordu (inceleme bulgusu 2026-08).
    const owner = await this.reviews.findOwner(reviewId);
    if (!owner) throw new AppProblem('not-found');
    if (owner === principal.userId) {
      throw new AppProblem('forbidden', 'Kendi yorumuna oy veremezsin.');
    }

    const res = await this.reviews.react(reviewId, principal.userId);
    if (!res) throw new AppProblem('not-found');
    if (res.created) {
      await this.reputation.award(res.ownerUserId, 'helpful_received', 2, {
        type: 'review',
        id: reviewId,
      });
    }
    return { helpfulCount: res.helpfulCount };
  }

  /** Geçersiz boyut kodu → 422 alan hatası (istemci düzeltebilir). */
  private async assertDimensionsValid(dims: Record<string, number> | undefined): Promise<void> {
    if (!dims) return;
    const codes = Object.keys(dims);
    if (codes.length === 0) return;
    const invalid = await this.reviews.invalidDimensionCodes(codes);
    if (invalid.length > 0) {
      const errors: FieldError[] = invalid.map((code) => ({
        field: `dimensions.${code}`,
        code: 'invalid_code',
        message: 'Geçersiz puan boyutu',
      }));
      throw new AppProblem('validation-error', 'Geçersiz puan boyutu.', errors);
    }
  }
}

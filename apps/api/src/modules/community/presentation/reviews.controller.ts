import { Body, Controller, Delete, HttpCode, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AccountGuard, RequireAccount } from '../../../common/guards/account.guard';
import { JwtAuthGuard } from '../../../common/guards/jwt-auth.guard';
import { AppProblem } from '../../../common/problem/problem';
import { Principal } from '../../../core/auth/principal';
import { ReviewWriteResult } from '../domain/reviews.repository';
import { ReviewsService } from '../application/reviews.service';

const UUID = z.string().uuid();
/** Gövde sınırı 2000: mobilde 4000 karakter okunmuyor (07 S-12; DB 4000'e izin verir). */
const REVIEW_BODY_MAX = 2000;

const dimensions = z.record(z.string().min(1).max(40), z.number().int().min(1).max(5));

const createReviewSchema = z
  .object({
    overallRating: z.number().int().min(1).max(5),
    title: z.string().trim().max(120).nullable().optional(),
    body: z.string().trim().max(REVIEW_BODY_MAX).nullable().optional(),
    visitedOn: z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}$/)
      .nullable()
      .optional(),
    boatId: UUID.nullable().optional(),
    dimensions: dimensions.optional(),
  })
  .strict();

const updateReviewSchema = createReviewSchema.partial();

@Controller()
@UseGuards(JwtAuthGuard, AccountGuard)
@RequireAccount()
export class ReviewsController {
  constructor(private readonly reviews: ReviewsService) {}

  @Post('locations/:idOrSlug/reviews')
  @HttpCode(201)
  async create(
    @CurrentUser() principal: Principal,
    @Param('idOrSlug') idOrSlug: string,
    @Body() body: unknown,
  ): Promise<ReviewWriteResult> {
    const dto = createReviewSchema.parse(body);
    return this.reviews.create(principal, idOrSlug, dto);
  }

  @Patch('reviews/:id')
  async update(
    @CurrentUser() principal: Principal,
    @Param('id') id: string,
    @Body() body: unknown,
  ): Promise<ReviewWriteResult> {
    const dto = updateReviewSchema.parse(body);
    if (Object.keys(dto).length === 0) {
      throw new AppProblem('validation-error', 'Güncellenecek alan yok.', [
        { field: '(root)', code: 'empty_patch', message: 'En az bir alan gönderilmeli' },
      ]);
    }
    return this.reviews.update(principal, this.uuid(id), dto);
  }

  @Delete('reviews/:id')
  @HttpCode(204)
  async remove(@CurrentUser() principal: Principal, @Param('id') id: string): Promise<void> {
    await this.reviews.remove(principal, this.uuid(id));
  }

  @Post('reviews/:id/reactions')
  async react(
    @CurrentUser() principal: Principal,
    @Param('id') id: string,
  ): Promise<{ helpfulCount: number }> {
    return this.reviews.react(principal, this.uuid(id));
  }

  private uuid(v: string): string {
    const parsed = UUID.safeParse(v);
    if (!parsed.success) throw new AppProblem('not-found');
    return parsed.data;
  }
}

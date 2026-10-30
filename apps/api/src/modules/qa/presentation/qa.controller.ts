import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { z } from 'zod';
import { UuidParam } from '../../../common/validation/uuid';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AccountGuard, RequireAccount } from '../../../common/guards/account.guard';
import { AuthedRequest, JwtAuthGuard } from '../../../common/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../../../common/guards/optional-jwt.guard';
import { AppProblem } from '../../../common/problem/problem';
import { Principal } from '../../../core/auth/principal';
import {
  QaDetail,
  QaFeed,
  QA_ANSWER_MAX,
  QA_ANSWER_MIN,
  QA_BODY_MAX,
  QA_BODY_MIN,
  QA_CATEGORIES,
  QA_LIST_MAX_LIMIT,
  QA_PAGE_SIZE,
  QA_SEARCH_MAX,
  QA_SEARCH_MIN,
  QA_TITLE_MAX,
  QA_TITLE_MIN,
} from '../domain/qa.types';
import { QaService } from '../application/qa.service';

// SAHA HATASI (2026-10-27): bkz. common/validation/uuid.ts — örnek soru
// kimlikleri zod .uuid() varyant süzgecine takılıyordu.
const UUID = UuidParam;

/** Sunucu taraflı doğrulama — DB CHECK'leriyle birebir aynı sınırlar (0014). */
const createQuestionSchema = z
  .object({
    category: z.enum(QA_CATEGORIES),
    title: z.string().trim().min(QA_TITLE_MIN).max(QA_TITLE_MAX),
    body: z.string().trim().min(QA_BODY_MIN).max(QA_BODY_MAX),
  })
  .strict();

const createAnswerSchema = z
  .object({ body: z.string().trim().min(QA_ANSWER_MIN).max(QA_ANSWER_MAX) })
  .strict();

const feedQuerySchema = z
  .object({
    category: z.enum(QA_CATEGORIES).optional(),
    /** Anahtar kelime araması (2026-10-30) — başlık + gövdede geçenler. */
    q: z.string().trim().min(QA_SEARCH_MIN).max(QA_SEARCH_MAX).optional(),
    /** Sayfa numarası (1 tabanlı) — sayfalı düzen (2026-10-30). */
    page: z.coerce.number().int().min(1).max(500).optional(),
    limit: z.coerce.number().int().min(1).max(QA_LIST_MAX_LIMIT).optional(),
  })
  .strict();

/**
 * Soru-cevap uçları (Blog V1; erişim revizyonu 2026-10-30).
 * Okuma: liste herkese (arama + sayfalı), detay erişim-kararlı (OptionalJwt —
 * misafir teaser, HESAPLI herkes tam detay). Yazma: hesap yeterli (Premium
 * şartı kaldırıldı); kontrolcü yalnız kimlik/doğrulama yapar.
 */
@Controller('qa')
export class QaController {
  constructor(private readonly qa: QaService) {}

  @Get('questions')
  async feed(@Query() query: Record<string, string>): Promise<QaFeed> {
    const parsed = feedQuerySchema.safeParse(query);
    if (!parsed.success) {
      throw new AppProblem('validation-error', 'Geçersiz liste parametresi.');
    }
    const q = parsed.data;
    return this.qa.feed(q.category ?? null, q.q ?? null, q.page ?? 1, q.limit ?? QA_PAGE_SIZE);
  }

  @Get('questions/:id')
  @UseGuards(OptionalJwtAuthGuard)
  async detail(@Param('id') id: string, @Req() req: AuthedRequest): Promise<QaDetail> {
    return this.qa.detail(req.principal ?? null, UUID.parse(id));
  }

  @Post('questions')
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  async createQuestion(
    @CurrentUser() principal: Principal,
    @Body() body: unknown,
  ): Promise<{ id: string; status: string }> {
    return this.qa.createQuestion(principal, createQuestionSchema.parse(body));
  }

  @Post('questions/:id/answers')
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  async createAnswer(
    @CurrentUser() principal: Principal,
    @Param('id') id: string,
    @Body() body: unknown,
  ): Promise<{ id: string; status: string }> {
    return this.qa.createAnswer(principal, UUID.parse(id), createAnswerSchema.parse(body).body);
  }

  @Post('questions/:id/like')
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  async like(
    @CurrentUser() principal: Principal,
    @Param('id') id: string,
  ): Promise<{ liked: boolean; likeCount: number }> {
    return this.qa.toggleLike(principal, UUID.parse(id));
  }

  @Post('answers/:id/helpful')
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  async helpful(
    @CurrentUser() principal: Principal,
    @Param('id') id: string,
  ): Promise<{ helped: boolean; helpfulCount: number }> {
    return this.qa.toggleHelpful(principal, UUID.parse(id));
  }

  @Post('questions/:id/report')
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  @HttpCode(204)
  async reportQuestion(@Param('id') id: string): Promise<void> {
    await this.qa.report('qa_question', UUID.parse(id));
  }

  @Post('answers/:id/report')
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  @HttpCode(204)
  async reportAnswer(@Param('id') id: string): Promise<void> {
    await this.qa.report('qa_answer', UUID.parse(id));
  }
}

import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AccountGuard, RequireAccount } from '../../../common/guards/account.guard';
import { JwtAuthGuard } from '../../../common/guards/jwt-auth.guard';
import { MinRole, RolesGuard } from '../../../common/guards/roles.guard';
import { AppProblem } from '../../../common/problem/problem';
import { Principal } from '../../../core/auth/principal';
import { ModerationItem, REJECT_REASONS } from '../domain/moderation.types';
import { ModerationService } from '../application/moderation.service';

const queueSchema = z
  .object({
    entityType: z
      .enum(['note', 'review', 'media', 'suggested_location', 'location_report'])
      .optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
  })
  .strict();

const decisionSchema = z
  .object({
    decision: z.enum(['approve', 'reject']),
    reason: z.enum(REJECT_REASONS).nullable().optional(),
    note: z.string().trim().max(500).nullable().optional(),
  })
  .strict()
  .superRefine((v, ctx) => {
    // Reddin sebebi olmalı: kullanıcı neden reddedildiğini görmezse öğrenemez.
    if (v.decision === 'reject' && !v.reason) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['reason'],
        message: 'Red sebebi zorunlu',
      });
    }
  });

/**
 * Moderasyon yüzeyi. RolesGuard ilk kez BURADA kullanılıyor — bugüne dek
 * tanımlıydı ama hiçbir controller'a bağlı değildi (denetim bulgusu 2026-08).
 * Ayrı bir web paneli YOK: moderasyon telefondan yapılır (tasarım §9.2).
 */
@Controller('moderation')
@UseGuards(JwtAuthGuard, AccountGuard, RolesGuard)
@RequireAccount()
@MinRole('moderator')
export class ModerationController {
  constructor(private readonly moderation: ModerationService) {}

  @Get('queue')
  async queue(@Query() query: unknown): Promise<{ data: ModerationItem[] }> {
    const q = queueSchema.parse(query ?? {});
    return { data: await this.moderation.queue(q.entityType, q.limit) };
  }

  @Get('counts')
  async counts(): Promise<Record<string, number>> {
    return this.moderation.counts();
  }

  @Post(':taskId/decision')
  async decide(
    @CurrentUser() principal: Principal,
    @Param('taskId') taskId: string,
    @Body() body: unknown,
  ): Promise<{ entityId: string; decision: string; pointsAwarded: number }> {
    const dto = decisionSchema.parse(body);
    const parsed = z.string().uuid().safeParse(taskId);
    if (!parsed.success) throw new AppProblem('not-found');
    return this.moderation.decide(
      principal,
      parsed.data,
      dto.decision,
      dto.reason ?? dto.note ?? null,
    );
  }
}

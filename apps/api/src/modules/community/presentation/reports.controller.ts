import { Body, Controller, HttpCode, Param, Post, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AccountGuard, RequireAccount } from '../../../common/guards/account.guard';
import { JwtAuthGuard } from '../../../common/guards/jwt-auth.guard';
import { Principal } from '../../../core/auth/principal';
import { ReportsService } from '../application/reports.service';

const createReportSchema = z
  .object({
    reason: z.enum([
      'wrong_info',
      'closed_permanently',
      'wrong_photo',
      'wrong_position',
      'duplicate',
      'abuse',
      'other',
    ]),
    message: z.string().trim().max(1000).nullable().optional(),
    targetType: z.enum(['note', 'review']).nullable().optional(),
    targetId: z.string().uuid().nullable().optional(),
  })
  .strict();

@Controller()
@UseGuards(JwtAuthGuard, AccountGuard)
@RequireAccount()
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  @Post('locations/:idOrSlug/reports')
  @HttpCode(201)
  async create(
    @CurrentUser() principal: Principal,
    @Param('idOrSlug') idOrSlug: string,
    @Body() body: unknown,
  ): Promise<{ id: string; autoHidden: boolean }> {
    const dto = createReportSchema.parse(body);
    return this.reports.create(principal, idOrSlug, dto);
  }
}

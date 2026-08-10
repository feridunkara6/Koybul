import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AccountGuard, RequireAccount } from '../../../common/guards/account.guard';
import { JwtAuthGuard } from '../../../common/guards/jwt-auth.guard';
import { Principal } from '../../../core/auth/principal';
import { ContributionItem, ReputationSummary } from '../domain/reputation.repository';
import { ReputationService } from '../application/reputation.service';

/**
 * Denizci profili verisi. `users/me` altında yaşar ama community modülünde
 * durur — users modülü topluluk bağımlılığı taşımasın.
 */
@Controller('users/me')
@UseGuards(JwtAuthGuard, AccountGuard)
@RequireAccount()
export class ReputationController {
  constructor(private readonly reputation: ReputationService) {}

  @Get('summary')
  async summary(@CurrentUser() principal: Principal): Promise<ReputationSummary> {
    return this.reputation.summary(principal.userId);
  }

  @Get('contributions')
  async contributions(
    @CurrentUser() principal: Principal,
    @Query('limit') limit?: string,
  ): Promise<{ data: ContributionItem[] }> {
    const n = z.coerce
      .number()
      .int()
      .min(1)
      .max(100)
      .default(50)
      .parse(limit ?? 50);
    return { data: await this.reputation.contributions(principal.userId, n) };
  }
}

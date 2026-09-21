import { Body, Controller, Get, HttpCode, Post, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AccountGuard, RequireAccount } from '../../../common/guards/account.guard';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../../common/guards/jwt-auth.guard';
import { Principal } from '../../../core/auth/principal';
import { PremiumMe, PremiumSubscriptionService } from '../application/premium-subscription.service';

/** Bağlama gövdesi: yalnız işlem kimliği — gerisi Apple'dan doğrulanır. */
const linkSchema = z.object({ originalTransactionId: z.string().trim().min(1).max(100) }).strict();

/**
 * Premium uçları (P2, kurucu onayı 2026-09-21).
 * /me ve /apple/link HESAP ister (premium hesaba bağlıdır — rapor §9);
 * /apple/notifications Apple'ın çağırdığı kamusal uçtur ve gövdesine
 * GÜVENİLMEZ (yalnız tetik — domain/jws.ts).
 */
@Controller('premium')
export class PremiumController {
  constructor(private readonly subscriptions: PremiumSubscriptionService) {}

  @Get('me')
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  async me(@CurrentUser() principal: Principal): Promise<PremiumMe> {
    return this.subscriptions.me(principal);
  }

  @Post('apple/link')
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  @HttpCode(200)
  async link(
    @CurrentUser() principal: Principal,
    @Body() body: unknown,
  ): Promise<{ active: boolean; until: string | null; productId: string | null }> {
    const dto = linkSchema.parse(body);
    return this.subscriptions.link(principal, dto.originalTransactionId);
  }

  /**
   * App Store Server Notifications V2 hedefi. HER ZAMAN 200 döner: Apple 2xx
   * dışını yeniden dener; işlenemeyen/sahte gövde zaten etkisizdir (durum her
   * durumda Apple API'sinden doğrulanır). App Store Connect'te bu adres girilir:
   * https://<api-alan-adi>/premium/apple/notifications
   */
  @Post('apple/notifications')
  @HttpCode(200)
  async notifications(@Body() body: unknown): Promise<{ ok: true }> {
    await this.subscriptions.handleNotification(body);
    return { ok: true };
  }
}

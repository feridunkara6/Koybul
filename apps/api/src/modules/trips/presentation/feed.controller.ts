import { Controller, Get, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AccountGuard, RequireAccount } from '../../../common/guards/account.guard';
import { JwtAuthGuard } from '../../../common/guards/jwt-auth.guard';
import { Principal } from '../../../core/auth/principal';
import { FeedService } from '../application/feed.service';
import { FeedItem } from '../domain/feed.types';

/**
 * TAKİP AKIŞI ucu (SP-3b, kurucu onayı 2026-10-31). Hesap İSTER: akış
 * kişiseldir (takip grafiği), misafirde istemci kapı gösterir — sunucuya
 * hiç gelmez. Yanıt kişisel olduğundan önbelleklenmez.
 */
@Controller('feed')
@UseGuards(JwtAuthGuard, AccountGuard)
@RequireAccount()
export class FeedController {
  constructor(private readonly feed: FeedService) {}

  @Get()
  async following(@CurrentUser() principal: Principal): Promise<{ data: FeedItem[] }> {
    return { data: await this.feed.following(principal) };
  }
}

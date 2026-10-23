import { Body, Controller, Get, Param, Put, Req, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AccountGuard, RequireAccount } from '../../../common/guards/account.guard';
import { AuthedRequest, JwtAuthGuard } from '../../../common/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../../../common/guards/optional-jwt.guard';
import { Principal } from '../../../core/auth/principal';
import { MarinaCommunity, MyMarinaBoat } from '../domain/marina.types';
import { MarinaService } from '../application/marina.service';

const UUID = z.string().uuid();

/** Tekne alanları boats ucuyla aynı sınırlar (docs/22 CHECK'leri). */
const upsertMyBoatSchema = z
  .object({
    name: z.string().trim().min(1).max(80),
    boatTypeCode: z.string().min(1).max(40),
    lengthM: z.number().gt(0).max(200),
    brand: z.string().trim().max(60).nullable().optional(),
    marinaLocationId: UUID,
    visible: z.boolean(),
    shareSpecs: z.boolean(),
  })
  .strict();

/**
 * Marina Topluluğu uçları (V1 — kurucu onayı 2026-10-23).
 * Topluluk okuma OptionalJwt'tir: misafir/anonim SAYILARI görür, liste
 * erişim kuralına tabidir (kendi marinan ücretsiz, gezinti Premium — kural
 * SERVİSTE). Tekne kaydı HESAP ister; Premium şartı YOKTUR (topluluğa
 * katılım bilinçli olarak ücretsiz — ağ etkisi kararı).
 */
@Controller('marina')
export class MarinaController {
  constructor(private readonly marina: MarinaService) {}

  @Get('me')
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  async me(@CurrentUser() principal: Principal): Promise<{ boat: MyMarinaBoat | null }> {
    return { boat: await this.marina.myBoat(principal) };
  }

  @Put('my-boat')
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  async upsert(@CurrentUser() principal: Principal, @Body() body: unknown): Promise<MyMarinaBoat> {
    return this.marina.upsertMyBoat(principal, upsertMyBoatSchema.parse(body));
  }

  @Get(':locationId/community')
  @UseGuards(OptionalJwtAuthGuard)
  async community(
    @Param('locationId') locationId: string,
    @Req() req: AuthedRequest,
  ): Promise<MarinaCommunity> {
    return this.marina.community(req.principal ?? null, UUID.parse(locationId));
  }
}

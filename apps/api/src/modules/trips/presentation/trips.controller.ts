import { Body, Controller, Delete, HttpCode, Param, Post, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { UuidParam } from '../../../common/validation/uuid';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AccountGuard, RequireAccount } from '../../../common/guards/account.guard';
import { JwtAuthGuard } from '../../../common/guards/jwt-auth.guard';
import { AppProblem } from '../../../common/problem/problem';
import { Principal } from '../../../core/auth/principal';
import { TripsService } from '../application/trips.service';
import {
  TRIP_DISTANCE_MAX_NM,
  TRIP_DURATION_MAX_MIN,
  TRIP_NAME_MAX,
  TRIP_STOPS_MAX,
} from '../domain/trip.types';

/** Sınırlar DB CHECK'leriyle birebir (0022_seyir_akis). */
const shareSchema = z
  .object({
    startName: z.string().trim().min(1).max(TRIP_NAME_MAX).nullable().optional(),
    endName: z.string().trim().min(1).max(TRIP_NAME_MAX).nullable().optional(),
    distanceNm: z.number().min(0).max(TRIP_DISTANCE_MAX_NM),
    durationMin: z.number().int().min(1).max(TRIP_DURATION_MAX_MIN).nullable().optional(),
    stopCount: z.number().int().min(0).max(TRIP_STOPS_MAX),
    sailedOn: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  })
  .strict();

/**
 * SEYİR PAYLAŞIMI uçları (SP-3b, kurucu onayı 2026-10-31). Hepsi hesap
 * ister (misafir etkileşemez); okuma akış ucundadır (feed modülü).
 */
@Controller('trips/shared')
@UseGuards(JwtAuthGuard, AccountGuard)
@RequireAccount()
export class TripsController {
  constructor(private readonly trips: TripsService) {}

  @Post()
  @HttpCode(201)
  async share(@CurrentUser() principal: Principal, @Body() body: unknown): Promise<{ id: string }> {
    const input = shareSchema.parse(body);
    return this.trips.share(principal, {
      startName: input.startName ?? null,
      endName: input.endName ?? null,
      distanceNm: input.distanceNm,
      durationMin: input.durationMin ?? null,
      stopCount: input.stopCount,
      sailedOn: input.sailedOn,
    });
  }

  @Delete(':id')
  @HttpCode(204)
  async remove(@CurrentUser() principal: Principal, @Param('id') id: string): Promise<void> {
    await this.trips.remove(principal, this.uuid(id));
  }

  /** "Pruvan neta" ⚓ aç/kapat — rota kaydetme toggle deseni. */
  @Post(':id/pruva')
  async togglePruva(
    @CurrentUser() principal: Principal,
    @Param('id') id: string,
  ): Promise<{ reacted: boolean; pruvaCount: number }> {
    return this.trips.togglePruva(principal, this.uuid(id));
  }

  /** Geçersiz UUID → 404 (varlık enumerasyonu ve tip hatası tek yanıtta). */
  private uuid(v: string): string {
    const parsed = UuidParam.safeParse(v);
    if (!parsed.success) throw new AppProblem('not-found');
    return parsed.data;
  }
}

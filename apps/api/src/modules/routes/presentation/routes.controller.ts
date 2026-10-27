import {
  Body,
  Controller,
  Delete,
  Get,
  Header,
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
import { RoutesService } from '../application/routes.service';
import {
  ROUTE_BODY_MAX,
  ROUTE_BODY_MIN,
  ROUTE_LIST_DEFAULT_LIMIT,
  ROUTE_LIST_MAX_LIMIT,
  ROUTE_NAME_MAX,
  ROUTE_NAME_MIN,
  ROUTE_STOPS_MAX,
  ROUTE_STOPS_MIN,
  RouteDetail,
  RouteSummary,
} from '../domain/route.types';

// SAHA HATASI (2026-10-27): örnek içerik kimlikleri RFC varyant süzgecine
// takılıp detayı 404'e düşürüyordu — Postgres-genişliğinde doğrulayıcı.
const UUID = UuidParam;

const listSchema = z
  .object({
    sort: z.enum(['new', 'popular']).default('new'),
    locationId: UUID.optional(),
    limit: z.coerce
      .number()
      .int()
      .min(1)
      .max(ROUTE_LIST_MAX_LIMIT)
      .default(ROUTE_LIST_DEFAULT_LIMIT),
  })
  .strict();

/** Sınırlar DB CHECK'leriyle birebir (0017_rotalar). */
const createSchema = z
  .object({
    name: z.string().trim().min(ROUTE_NAME_MIN).max(ROUTE_NAME_MAX),
    body: z.string().trim().min(ROUTE_BODY_MIN).max(ROUTE_BODY_MAX),
    season: z.string().trim().min(1).max(60).nullable().optional(),
    boatSuggestion: z.string().trim().min(1).max(120).nullable().optional(),
    distanceNm: z.number().gt(0).max(500),
    durationHours: z.number().gt(0).max(240).nullable().optional(),
    stopLocationIds: z.array(UUID).min(ROUTE_STOPS_MIN).max(ROUTE_STOPS_MAX),
  })
  .strict();

/**
 * ROTA PAYLAŞIMI uçları (Sosyalleşme Hafta 3, kurucu onayı 2026-10-24).
 * Okuma herkese açık (S-C akışı deseni); yazma hesap ister; moderasyon
 * ve aylık tavan kararları SERVİSTE.
 */
@Controller('routes')
export class RoutesController {
  constructor(private readonly routes: RoutesService) {}

  @Get()
  @Header('Cache-Control', 'public, max-age=60')
  async list(@Query() query: unknown): Promise<{ data: RouteSummary[] }> {
    const q = listSchema.parse(query ?? {});
    return { data: await this.routes.list(q.sort, q.locationId ?? null, q.limit) };
  }

  @Get(':id')
  @Header('Vary', 'Authorization')
  @UseGuards(OptionalJwtAuthGuard)
  async detail(@Req() req: AuthedRequest, @Param('id') id: string): Promise<RouteDetail> {
    return this.routes.detail(req.principal ?? null, this.uuid(id));
  }

  @Post()
  @HttpCode(201)
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  async create(
    @CurrentUser() principal: Principal,
    @Body() body: unknown,
  ): Promise<{ id: string; status: string }> {
    return this.routes.create(principal, createSchema.parse(body));
  }

  @Post(':id/save')
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  async toggleSave(
    @CurrentUser() principal: Principal,
    @Param('id') id: string,
  ): Promise<{ saved: boolean; saveCount: number }> {
    return this.routes.toggleSave(principal, this.uuid(id));
  }

  @Post(':id/done')
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  async toggleDone(
    @CurrentUser() principal: Principal,
    @Param('id') id: string,
  ): Promise<{ done: boolean; doneCount: number }> {
    return this.routes.toggleDone(principal, this.uuid(id));
  }

  @Delete(':id')
  @HttpCode(204)
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  async remove(@CurrentUser() principal: Principal, @Param('id') id: string): Promise<void> {
    await this.routes.remove(principal, this.uuid(id));
  }

  /** Geçersiz UUID → 404 (varlık enumerasyonu ve tip hatası tek yanıtta). */
  private uuid(v: string): string {
    const parsed = UUID.safeParse(v);
    if (!parsed.success) throw new AppProblem('not-found');
    return parsed.data;
  }
}

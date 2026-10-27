import { Body, Controller, Get, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { UuidParam } from '../../../common/validation/uuid';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AccountGuard, RequireAccount } from '../../../common/guards/account.guard';
import { AuthedRequest, JwtAuthGuard } from '../../../common/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../../../common/guards/optional-jwt.guard';
import { MinRole, RolesGuard } from '../../../common/guards/roles.guard';
import { Principal } from '../../../core/auth/principal';
import { DealView, EventParticipant, EventView } from '../domain/events.types';
import { EventsService } from '../application/events.service';

// SAHA HATASI (2026-10-27): bkz. common/validation/uuid.ts.
const UUID = UuidParam;
const AUDIENCE = z.enum(['all', 'members', 'premium']);
const ISO = z.string().datetime({ offset: true });

const dealShape = {
  title: z.string().trim().min(3).max(120),
  partner: z.string().trim().min(2).max(80),
  benefit: z.string().trim().min(2).max(80),
  code: z.string().trim().min(2).max(40).nullable().optional(),
  validUntil: ISO.nullable().optional(),
  terms: z.string().trim().max(300).nullable().optional(),
  place: z.string().trim().max(120).nullable().optional(),
  audience: AUDIENCE,
  isActive: z.boolean().optional(),
};
const createDealSchema = z.object(dealShape).strict();
const updateDealSchema = z.object(dealShape).partial().strict();

const eventShape = {
  title: z.string().trim().min(3).max(120),
  body: z.string().trim().min(10).max(2000),
  startsAt: ISO,
  endsAt: ISO.nullable().optional(),
  locationText: z.string().trim().min(2).max(120),
  venueLocationId: UUID.nullable().optional(),
  quota: z.number().int().min(1).max(10000),
  registrationDeadline: ISO.nullable().optional(),
  priceNote: z.string().trim().max(160).nullable().optional(),
  conditions: z.string().trim().max(300).nullable().optional(),
  organizer: z.string().trim().min(2).max(80).optional(),
  audience: AUDIENCE,
};
const createEventSchema = z.object(eventShape).strict();
const updateEventSchema = z
  .object({ ...eventShape, status: z.enum(['published', 'cancelled']) })
  .partial()
  .strict();

/**
 * Kullanıcı uçları: liste/detay herkese (kilitler SERVİSTE — kilitli fırsat
 * kodu gövdeye hiç yazılmaz), kayıt/iptal hesap ister.
 */
@Controller('events')
export class EventsController {
  constructor(private readonly events: EventsService) {}

  // DİKKAT: statik yol, ':id' yakalayıcısından ÖNCE tanımlı kalmalı.
  @Get('deals')
  @UseGuards(OptionalJwtAuthGuard)
  async deals(@Req() req: AuthedRequest): Promise<{ deals: DealView[] }> {
    return { deals: await this.events.deals(req.principal ?? null) };
  }

  @Get()
  @UseGuards(OptionalJwtAuthGuard)
  async list(@Req() req: AuthedRequest): Promise<{ events: EventView[] }> {
    return { events: await this.events.events(req.principal ?? null) };
  }

  @Get(':id')
  @UseGuards(OptionalJwtAuthGuard)
  async detail(@Param('id') id: string, @Req() req: AuthedRequest): Promise<EventView> {
    return this.events.event(req.principal ?? null, UUID.parse(id));
  }

  @Post(':id/register')
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  async register(
    @CurrentUser() principal: Principal,
    @Param('id') id: string,
  ): Promise<{ registered: boolean; remaining: number }> {
    return this.events.register(principal, UUID.parse(id));
  }

  @Post(':id/cancel')
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  async cancel(
    @CurrentUser() principal: Principal,
    @Param('id') id: string,
  ): Promise<{ cancelled: boolean }> {
    await this.events.cancel(principal, UUID.parse(id));
    return { cancelled: true };
  }
}

/**
 * Yönetici uçları — mevcut panel zinciriyle aynı koruma (admin ve üstü).
 * Moderatörler etkinlik/fırsat YÖNETEMEZ (kurucu konsept kararı).
 */
@Controller('admin')
@UseGuards(JwtAuthGuard, AccountGuard, RolesGuard)
@RequireAccount()
@MinRole('admin')
export class EventsAdminController {
  constructor(private readonly events: EventsService) {}

  @Post('deals')
  async createDeal(@Body() body: unknown): Promise<{ id: string }> {
    return this.events.adminCreateDeal(createDealSchema.parse(body));
  }

  @Patch('deals/:id')
  async updateDeal(@Param('id') id: string, @Body() body: unknown): Promise<{ ok: boolean }> {
    await this.events.adminUpdateDeal(UUID.parse(id), updateDealSchema.parse(body));
    return { ok: true };
  }

  @Post('events')
  async createEvent(@Body() body: unknown): Promise<{ id: string }> {
    return this.events.adminCreateEvent(createEventSchema.parse(body));
  }

  @Patch('events/:id')
  async updateEvent(@Param('id') id: string, @Body() body: unknown): Promise<{ ok: boolean }> {
    await this.events.adminUpdateEvent(UUID.parse(id), updateEventSchema.parse(body));
    return { ok: true };
  }

  @Get('events/:id/participants')
  async participants(@Param('id') id: string): Promise<{ participants: EventParticipant[] }> {
    return { participants: await this.events.adminParticipants(UUID.parse(id)) };
  }
}

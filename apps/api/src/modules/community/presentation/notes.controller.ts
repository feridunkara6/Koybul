import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { z } from 'zod';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AccountGuard, RequireAccount } from '../../../common/guards/account.guard';
import { JwtAuthGuard } from '../../../common/guards/jwt-auth.guard';
import { AppProblem } from '../../../common/problem/problem';
import { Principal } from '../../../core/auth/principal';
import {
  NEARBY_DEFAULT_HOURS,
  NEARBY_DEFAULT_RADIUS_NM,
  NEARBY_MAX_HOURS,
  NEARBY_MAX_RADIUS_NM,
  NOTE_BODY_MAX,
  NOTE_BODY_MIN,
  NOTE_TITLE_MAX,
  Note,
} from '../domain/note.types';
import { NearbyNote } from '../domain/notes.repository';
import { NotesService } from '../application/notes.service';

const UUID = z.string().uuid();
const ISO_DATE = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'YYYY-MM-DD bekleniyor');

/** Gövde sınırı tipe göre değişir — DB CHECK ile birebir aynı (0008 migration). */
const createNoteSchema = z
  .object({
    kind: z.enum(['status', 'hazard', 'experience', 'passage']),
    locationId: UUID.optional(),
    fromLocationId: UUID.optional(),
    toLocationId: UUID.optional(),
    title: z.string().trim().max(NOTE_TITLE_MAX).nullable().optional(),
    body: z.string().trim().min(NOTE_BODY_MIN).max(NOTE_BODY_MAX.experience),
    observedOn: ISO_DATE,
    boatId: UUID.nullable().optional(),
    position: z
      .object({ lat: z.number().min(-90).max(90), lon: z.number().min(-180).max(180) })
      .strict()
      .optional(),
    wind: z
      .object({ kn: z.number().min(0).max(200), dirTr: z.string().min(1).max(3) })
      .strict()
      .nullable()
      .optional(),
  })
  .strict()
  .superRefine((v, ctx) => {
    if (v.body.length > NOTE_BODY_MAX[v.kind]) {
      ctx.addIssue({
        code: z.ZodIssueCode.too_big,
        maximum: NOTE_BODY_MAX[v.kind],
        type: 'string',
        inclusive: true,
        path: ['body'],
        message: `Bu not tipi için en fazla ${NOTE_BODY_MAX[v.kind]} karakter`,
      });
    }
    if (v.kind === 'passage' && (!v.fromLocationId || !v.toLocationId)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['fromLocationId'],
        message: 'Seyir notu iki nokta ister',
      });
    }
    if (v.kind !== 'passage' && !v.locationId) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['locationId'], message: 'Nokta zorunlu' });
    }
  });

const updateNoteSchema = z
  .object({
    title: z.string().trim().max(NOTE_TITLE_MAX).nullable().optional(),
    body: z.string().trim().min(NOTE_BODY_MIN).max(NOTE_BODY_MAX.experience).optional(),
  })
  .strict();

const reactionSchema = z.object({ reaction: z.enum(['helpful', 'confirm', 'dispute']) }).strict();

const nearbySchema = z
  .object({
    lat: z.coerce.number().min(-90).max(90),
    lon: z.coerce.number().min(-180).max(180),
    radiusNm: z.coerce
      .number()
      .positive()
      .max(NEARBY_MAX_RADIUS_NM)
      .default(NEARBY_DEFAULT_RADIUS_NM),
    sinceHours: z.coerce
      .number()
      .int()
      .positive()
      .max(NEARBY_MAX_HOURS)
      .default(NEARBY_DEFAULT_HOURS),
    limit: z.coerce.number().int().min(1).max(50).default(20),
  })
  .strict();

const listSchema = z
  .object({
    kind: z.enum(['status', 'hazard', 'experience', 'passage']).optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
  })
  .strict();

@Controller()
export class NotesController {
  constructor(private readonly notes: NotesService) {}

  /** Anonim okuma — misafir her şeyi okur (PRD §5.3). */
  @Get('locations/:locationId/notes')
  async list(
    @Param('locationId') locationId: string,
    @Query() query: unknown,
  ): Promise<{ data: Note[] }> {
    const q = listSchema.parse(query ?? {});
    return { data: await this.notes.listForLocation(this.uuid(locationId), q) };
  }

  /** "Yakında paylaşılanlar" — Bugün ekranının kaynağı. Anonim. */
  @Get('notes/nearby')
  async nearby(@Query() query: unknown): Promise<{ data: NearbyNote[] }> {
    const q = nearbySchema.parse(query ?? {});
    return { data: await this.notes.nearby(q) };
  }

  @Post('locations/:locationId/notes')
  @HttpCode(201)
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  async create(
    @CurrentUser() principal: Principal,
    @Param('locationId') locationId: string,
    @Body() body: unknown,
  ): Promise<Note> {
    const dto = createNoteSchema.parse(body);
    // Yol parametresi gövdeyi EZER: istemci iki farklı nokta gönderemesin.
    const id = this.uuid(locationId);
    return this.notes.create(principal, {
      ...dto,
      ...(dto.kind === 'passage' ? { fromLocationId: id } : { locationId: id }),
    });
  }

  @Get('users/me/notes')
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  async mine(
    @CurrentUser() principal: Principal,
    @Query('status') status?: string,
  ): Promise<{ data: Note[] }> {
    const s = z.enum(['pending', 'approved', 'rejected']).optional().parse(status);
    return { data: await this.notes.listMine(principal.userId, s, 50) };
  }

  @Patch('notes/:id')
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  async update(
    @CurrentUser() principal: Principal,
    @Param('id') id: string,
    @Body() body: unknown,
  ): Promise<Note> {
    const dto = updateNoteSchema.parse(body);
    if (Object.keys(dto).length === 0) {
      throw new AppProblem('validation-error', 'Güncellenecek alan yok.', [
        { field: '(root)', code: 'empty_patch', message: 'En az bir alan gönderilmeli' },
      ]);
    }
    return this.notes.update(principal, this.uuid(id), dto);
  }

  @Delete('notes/:id')
  @HttpCode(204)
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  async remove(@CurrentUser() principal: Principal, @Param('id') id: string): Promise<void> {
    await this.notes.remove(principal, this.uuid(id));
  }

  @Post('notes/:id/reactions')
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  async react(
    @CurrentUser() principal: Principal,
    @Param('id') id: string,
    @Body() body: unknown,
  ): Promise<{ helpfulCount: number; confirmCount: number; disputeCount: number }> {
    const dto = reactionSchema.parse(body);
    return this.notes.react(principal, this.uuid(id), dto.reaction);
  }

  /** Geçersiz UUID → 404 (varlık enumerasyonu ve tip hatası tek yanıtta). */
  private uuid(v: string): string {
    const parsed = UUID.safeParse(v);
    if (!parsed.success) throw new AppProblem('not-found');
    return parsed.data;
  }
}

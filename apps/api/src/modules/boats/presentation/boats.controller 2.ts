import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { z } from 'zod';
import { BoatsService } from '../application/boats.service';
import { JwtAuthGuard } from '../../../common/guards/jwt-auth.guard';
import { AccountGuard, RequireAccount } from '../../../common/guards/account.guard';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AppProblem } from '../../../common/problem/problem';
import { Principal } from '../../../core/auth/principal';
import { Boat } from '../domain/boat.types';

const CURRENT_YEAR = 2026;

/** Ortak alan kuralları (docs/22 boats CHECK'leri: boy 1-200m, yıl 1900-now+1). */
const baseBoatShape = {
  name: z.string().trim().min(1).max(80),
  boatTypeCode: z.string().min(1).max(40),
  lengthM: z.number().gt(0).max(200),
  brand: z.string().trim().max(60).nullable().optional(),
  model: z.string().trim().max(60).nullable().optional(),
  buildYear: z
    .number()
    .int()
    .min(1900)
    .max(CURRENT_YEAR + 1)
    .nullable()
    .optional(),
  beamM: z.number().gt(0).max(60).nullable().optional(),
  draftM: z.number().gt(0).max(30).nullable().optional(),
  engineTypeCode: z.string().min(1).max(40).nullable().optional(),
  flagCountryCode: z.string().length(2).toUpperCase().nullable().optional(),
  registrationNo: z.string().trim().max(40).nullable().optional(),
  isPrimary: z.boolean().optional(),
};

const createBoatSchema = z.object(baseBoatShape).strict();
const updateBoatSchema = z
  .object({
    name: baseBoatShape.name.optional(),
    boatTypeCode: baseBoatShape.boatTypeCode.optional(),
    lengthM: baseBoatShape.lengthM.optional(),
    brand: baseBoatShape.brand,
    model: baseBoatShape.model,
    buildYear: baseBoatShape.buildYear,
    beamM: baseBoatShape.beamM,
    draftM: baseBoatShape.draftM,
    engineTypeCode: baseBoatShape.engineTypeCode,
    flagCountryCode: baseBoatShape.flagCountryCode,
    registrationNo: baseBoatShape.registrationNo,
    isPrimary: baseBoatShape.isPrimary,
  })
  .strict();

const boatIdSchema = z.string().uuid();

@Controller('boats')
@UseGuards(JwtAuthGuard, AccountGuard)
@RequireAccount()
export class BoatsController {
  constructor(private readonly boatsService: BoatsService) {}

  @Get()
  async list(@CurrentUser() principal: Principal): Promise<{ data: Boat[] }> {
    return { data: await this.boatsService.list(principal) };
  }

  @Post()
  @HttpCode(201)
  async create(@CurrentUser() principal: Principal, @Body() body: unknown): Promise<Boat> {
    const dto = createBoatSchema.parse(body);
    return this.boatsService.create(principal, dto);
  }

  @Get(':id')
  async getOne(@CurrentUser() principal: Principal, @Param('id') id: string): Promise<Boat> {
    return this.boatsService.getOne(principal, this.parseId(id));
  }

  @Patch(':id')
  async update(
    @CurrentUser() principal: Principal,
    @Param('id') id: string,
    @Body() body: unknown,
  ): Promise<Boat> {
    const dto = updateBoatSchema.parse(body);
    if (Object.keys(dto).length === 0) {
      throw new AppProblem('validation-error', 'Güncellenecek alan yok.', [
        { field: '(root)', code: 'empty_patch', message: 'En az bir alan gönderilmeli' },
      ]);
    }
    return this.boatsService.update(principal, this.parseId(id), dto);
  }

  @Delete(':id')
  @HttpCode(204)
  async remove(@CurrentUser() principal: Principal, @Param('id') id: string): Promise<void> {
    await this.boatsService.remove(principal, this.parseId(id));
  }

  /** Geçersiz UUID → 404 (varlık enumerasyonu ve tip hatası tek yanıtta). */
  private parseId(id: string): string {
    const parsed = boatIdSchema.safeParse(id);
    if (!parsed.success) throw new AppProblem('not-found');
    return parsed.data;
  }
}

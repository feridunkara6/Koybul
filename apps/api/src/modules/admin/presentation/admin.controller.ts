import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AccountGuard, RequireAccount } from '../../../common/guards/account.guard';
import { JwtAuthGuard } from '../../../common/guards/jwt-auth.guard';
import { MinRole, RolesGuard } from '../../../common/guards/roles.guard';
import { AdminStats, PremiumGrantResult } from '../domain/admin.repository';
import { AdminService } from '../application/admin.service';

const grantSchema = z
  .object({
    email: z.string().trim().email(),
    months: z.coerce.number().int().min(1).max(24),
  })
  .strict();

/**
 * YÖNETİM PANELİ uçları (kurucu talebi 2026-09-25). Moderasyonla aynı desen:
 * ayrı bir web paneli yok — panel uygulamanın içindedir (telefon + web aynı
 * kod). Asgari rol 'admin' (hiyerarşi: admin moderasyonu da kapsar).
 */
@Controller('admin')
@UseGuards(JwtAuthGuard, AccountGuard, RolesGuard)
@RequireAccount()
@MinRole('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get('stats')
  stats(): Promise<AdminStats> {
    return this.admin.stats();
  }

  @Post('premium')
  grant(@Body() body: unknown): Promise<PremiumGrantResult> {
    const b = grantSchema.parse(body ?? {});
    return this.admin.grantPremium(b.email, b.months);
  }
}

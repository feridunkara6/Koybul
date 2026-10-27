import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { z } from 'zod';
import { AppProblem } from '../../../common/problem/problem';
import { UuidParam } from '../../../common/validation/uuid';
import { AccountGuard, RequireAccount } from '../../../common/guards/account.guard';
import { JwtAuthGuard } from '../../../common/guards/jwt-auth.guard';
import { MinRole, RolesGuard } from '../../../common/guards/roles.guard';
import {
  ADMIN_CONTENT_TYPES,
  AdminContentType,
  AdminStats,
  PremiumGrantResult,
} from '../domain/admin.repository';
import { AdminService } from '../application/admin.service';

const contentListSchema = z
  .object({
    type: z.enum(['routes', 'questions', 'answers', 'notes', 'reviews', 'boats']),
    limit: z.coerce.number().int().min(1).max(100).default(50),
  })
  .strict();

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

  /** İÇERİK YÖNETİMİ (kurucu talebi 2026-10-27): tür başına en yeni içerik. */
  @Get('content')
  async listContent(@Query() query: unknown): Promise<{
    data: {
      id: string;
      title: string;
      authorName: string | null;
      status: string | null;
      createdAt: string;
    }[];
  }> {
    const q = contentListSchema.parse(query ?? {});
    return { data: await this.admin.listContent(q.type, q.limit) };
  }

  /** Yayından indirme — yumuşak silme; veri denetim için durur. */
  @Delete('content/:type/:id')
  @HttpCode(204)
  async deleteContent(@Param('type') type: string, @Param('id') id: string): Promise<void> {
    if (!(ADMIN_CONTENT_TYPES as readonly string[]).includes(type)) {
      throw new AppProblem('not-found');
    }
    const parsed = UuidParam.safeParse(id);
    if (!parsed.success) throw new AppProblem('not-found');
    await this.admin.deleteContent(type as AdminContentType, parsed.data);
  }
}

import { Body, Controller, Get, HttpCode, Patch, Post, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AccountGuard, RequireAccount } from '../../../common/guards/account.guard';
import { JwtAuthGuard } from '../../../common/guards/jwt-auth.guard';
import { AppProblem } from '../../../common/problem/problem';
import { Principal } from '../../../core/auth/principal';
import { NotificationsService } from '../application/notifications.service';
import { InboxRow } from '../domain/notifications.types';

/**
 * FCM token biçimi: harf/rakam + ':', '-', '_' — başka karakter girmez.
 * Token URL'ye KOYULMAZ (uzun + ':' içerir); silme de gövdeyle POST'tur.
 */
const TOKEN = z.string().regex(/^[A-Za-z0-9:_-]{20,512}$/, 'Geçersiz cihaz tokenı');

const registerSchema = z
  .object({
    token: TOKEN,
    platform: z.enum(['ios', 'android', 'web']).default('ios'),
    locale: z
      .string()
      .regex(/^[a-zA-Z]{2}([-_][a-zA-Z0-9]{2,8})?$/, 'Geçersiz dil kodu')
      .default('tr'),
  })
  .strict();

const removeSchema = z.object({ token: TOKEN }).strict();

const prefsSchema = z
  .object({
    token: TOKEN,
    community: z.boolean().optional(),
    events: z.boolean().optional(),
    moderation: z.boolean().optional(),
  })
  .strict();

/**
 * Cihaz kaydı uçları — hepsi HESAP ister (misafire push yok; cihaz satırı
 * kullanıcıya bağlanır, çıkışta mobil kendini kayıttan düşürür).
 */
@Controller('notifications')
@UseGuards(JwtAuthGuard, AccountGuard)
@RequireAccount()
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  /** Kayıt/tazeleme (upsert) — cihazın güncel tercihlerini döndürür. */
  @Post('devices')
  register(
    @CurrentUser() user: Principal,
    @Body() body: unknown,
  ): Promise<{ community: boolean; events: boolean; moderation: boolean }> {
    const input = registerSchema.parse(body); // ZodError → global filtre (422)
    return this.notifications.registerDevice(user.userId, input);
  }

  /** Kayıt silme (çıkışta çağrılır) — idempotent, her zaman 204. */
  @Post('devices/remove')
  @HttpCode(204)
  async remove(@CurrentUser() user: Principal, @Body() body: unknown): Promise<void> {
    const input = removeSchema.parse(body);
    await this.notifications.unregisterDevice(user.userId, input.token);
  }

  /** Tercih güncelleme — bilinmeyen token 404 (kayıt düşmüş demektir). */
  @Patch('devices/prefs')
  async updatePrefs(
    @CurrentUser() user: Principal,
    @Body() body: unknown,
  ): Promise<{ community: boolean; events: boolean; moderation: boolean }> {
    const { token, ...prefs } = prefsSchema.parse(body);
    const updated = await this.notifications.updatePrefs(user.userId, token, prefs);
    if (!updated) throw new AppProblem('not-found');
    return updated;
  }

  // --- BİLDİRİM KUTUSU (SP-2 Döngü, kurucu onayı 2026-10-31) ---

  /** Kutu listesi: en yeni 50 satır — metin istemcide üretilir (l10n). */
  @Get()
  async inbox(@CurrentUser() user: Principal): Promise<{ data: InboxRow[] }> {
    return { data: await this.notifications.listInbox(user.userId) };
  }

  /** Kutu açılınca tümü okundu sayılır — rozet/işaret istemcide söner. */
  @Post('read-all')
  @HttpCode(204)
  async readAll(@CurrentUser() user: Principal): Promise<void> {
    await this.notifications.markAllRead(user.userId);
  }
}

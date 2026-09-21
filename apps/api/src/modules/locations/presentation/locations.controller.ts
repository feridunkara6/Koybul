import {
  Body,
  Controller,
  Get,
  Header,
  Headers,
  HttpCode,
  Param,
  Post,
  Query,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { Response } from 'express';
import { z } from 'zod';
import { AccountGuard, RequireAccount } from '../../../common/guards/account.guard';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { AuthedRequest, JwtAuthGuard } from '../../../common/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../../../common/guards/optional-jwt.guard';
import { Principal } from '../../../core/auth/principal';
import { LocationsService } from '../application/locations.service';
import {
  LocationDetail,
  LocationSummary,
  MapResult,
  OccupancySummary,
  ReviewItem,
} from '../domain/location.types';
import { resolveLocale } from '../../../common/i18n/locale';

/**
 * Lokasyon süper-tipi — harita/arama/nearby/detay (docs/23 §8, §10 #10).
 * Bu alt-faz: bbox pin modu (§9.5, zoom ≥ 9). Anonim, kuantalanmış bbox 120s
 * + SWR ile CDN'de cache'lenir (docs/23 §17, docs/13 §4).
 */
/** Doluluk bildirimi gövdesi (2026-07 ①): düzey + bildirenin GERÇEK konumu.
 * Konum zorunludur — sunucu, bildirenin koya yakın olduğunu doğrular (yanlış
 * bilgi trafiğine karşı iki katmanlı önlem; istemci de aynı kuralı uygular). */
const occupancySchema = z
  .object({
    level: z.enum(['empty', 'moderate', 'full']),
    position: z
      .object({ lat: z.number().min(-90).max(90), lon: z.number().min(-180).max(180) })
      .strict(),
  })
  .strict();

@Controller('locations')
export class LocationsController {
  constructor(private readonly locations: LocationsService) {}

  @Get()
  @Header('Cache-Control', 'public, max-age=120, s-maxage=120, stale-while-revalidate=600')
  async list(
    @Query('bbox') bbox?: string,
    @Query('zoom') zoom?: string,
    @Query('type') type?: string | string[],
  ): Promise<MapResult> {
    return this.locations.map(bbox, zoom, normalizeTypes(type));
  }

  /** Yakınımdaki limanlar (docs/23 §9.6) — mesafeye göre sıralı, S-06 rayı. */
  @Get('nearby')
  @Header('Cache-Control', 'public, max-age=60, stale-while-revalidate=300')
  async nearby(
    @Query('lat') lat?: string,
    @Query('lon') lon?: string,
    @Query('radiusNm') radiusNm?: string,
    @Query('limit') limit?: string,
    @Query('type') type?: string | string[],
  ): Promise<{ data: LocationSummary[] }> {
    return this.locations.nearby({ lat, lon, radiusNm, limit }, normalizeTypes(type));
  }

  /**
   * Metinle arama (docs/23 §9, S-07) — ad/şehir/su-alanı. `:idOrSlug`'dan ÖNCE
   * tanımlı: statik `search` segmenti param rotasından önce eşleşsin diye.
   */
  @Get('search')
  @Header('Cache-Control', 'public, max-age=30, stale-while-revalidate=120')
  async search(
    @Query('q') q?: string,
    @Query('type') type?: string | string[],
    @Query('amenity') amenity?: string | string[],
    @Query('limit') limit?: string,
  ): Promise<{ data: LocationSummary[] }> {
    // amenity: olanak kodu filtreleri (AND) — doğrulama service katmanında.
    return this.locations.search(q, normalizeTypes(type), normalizeTypes(amenity), limit);
  }

  /**
   * Bir lokasyonun onaylı yorumları (docs/23 §11.3). id veya slug; en yeni önce.
   * `:idOrSlug`'dan ÖNCE tanımlı: iki-segmentli `reviews` rotası param rotasından
   * önce eşleşsin diye.
   */
  @Get(':idOrSlug/reviews')
  @Header('Cache-Control', 'public, max-age=60, stale-while-revalidate=300')
  async reviews(
    @Param('idOrSlug') idOrSlug: string,
    @Query('limit') limit?: string,
  ): Promise<{ data: ReviewItem[] }> {
    return this.locations.reviews(idOrSlug, limit);
  }

  /**
   * Liman detayı (docs/23 §10 #12, §11.3). id veya slug ile; i18n Accept-Language.
   * `nearby`/`search`'ten SONRA tanımlı — statik segment param'dan önce eşleşsin diye.
   */
  @Get(':idOrSlug')
  @Header('Cache-Control', 'public, max-age=300, s-maxage=300, stale-while-revalidate=600')
  @Header('Vary', 'Accept-Language, Authorization')
  @UseGuards(OptionalJwtAuthGuard)
  async detail(
    @Req() req: AuthedRequest,
    @Res({ passthrough: true }) res: Response,
    @Param('idOrSlug') idOrSlug: string,
    @Headers('accept-language') acceptLanguage?: string,
  ): Promise<LocationDetail> {
    // PREMIUM (P1): kimlik İSTEĞE BAĞLIDIR — anonim istek vitrin görür (bayrak
    // açıkken), kimlikli istek premium/keşif-hakkı kararına göre tam veri alır.
    // Kimlikli yanıt kişiye özeldir → paylaşımlı cache'e yazılmaz (private);
    // anonim yanıt eskisi gibi public cache'lenir. Vary: Authorization,
    // aradaki cache'lerin iki yanıtı karıştırmasını engeller.
    if (req.principal) {
      res.setHeader('Cache-Control', 'private, max-age=60');
    }
    return this.locations.detail(idOrSlug, resolveLocale(acceptLanguage), req.principal ?? null);
  }

  /**
   * KEŞİF HAKKI (P1, premium v3 raporu K2): hesaplı üye bu koyu bu ay için tam
   * açar (ayda 3). Dönen gövde TAM detay + kalan hak — ikinci istek gerekmez.
   * Tavan doluysa 403 `quota-exceeded` (mobil paywall açar). POST: cache'lenmez.
   */
  @Post(':idOrSlug/unlock')
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  @HttpCode(200)
  async unlock(
    @CurrentUser() principal: Principal,
    @Param('idOrSlug') idOrSlug: string,
    @Headers('accept-language') acceptLanguage?: string,
  ): Promise<{ remaining: number; detail: LocationDetail }> {
    return this.locations.unlock(idOrSlug, resolveLocale(acceptLanguage), principal);
  }

  /**
   * Koy doluluk bildirimi (2026-07 ayrıştırma paketi ①). HESAP ister (misafir
   * 403 guest-not-allowed alır — üyelik kapısı sunucuda da tutarlı). Kullanıcı
   * başına lokasyon başına tek bildirim; yenisi eskisinin üstüne yazar.
   * POST olduğu için CDN cache'lenmez; dönen özet istemcide ekranı tazeler.
   */
  @Post(':idOrSlug/occupancy')
  @UseGuards(JwtAuthGuard, AccountGuard)
  @RequireAccount()
  @HttpCode(200)
  async reportOccupancy(
    @CurrentUser() principal: Principal,
    @Param('idOrSlug') idOrSlug: string,
    @Body() body: unknown,
  ): Promise<{ occupancy: OccupancySummary }> {
    const dto = occupancySchema.parse(body);
    return this.locations.reportOccupancy(idOrSlug, principal.userId, dto.level, dto.position);
  }
}

/** Tekrarlı `type` param = OR listesi (docs/23 §9.2); tekil değeri diziye sarar. */
function normalizeTypes(type: string | string[] | undefined): string[] | undefined {
  if (type === undefined) return undefined;
  const list = (Array.isArray(type) ? type : [type])
    .map((t) => t.trim())
    .filter((t) => t.length > 0);
  return list.length > 0 ? list : undefined;
}

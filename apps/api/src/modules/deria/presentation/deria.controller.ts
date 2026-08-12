import { Controller, Get, Header } from '@nestjs/common';
import { DeriaService } from '../application/deria.service';
import { DeriaAvailability } from '../domain/deria.types';

/**
 * DERİA tonoz doluluğu ucu — istemci Göcek koy detaylarındaki "tonoz doluluk"
 * kutusunu bununla besler. Anonim; CDN 2 dk önbellekler (sunucu içi 5 dk).
 * Kaynak: DERİA / Türkiye Çevre Ajansı; atıf yanıt gövdesinde ve arayüzde.
 * Rezervasyon BİZDE YAPILMAZ — kutudaki bağlantı deria.gov.tr'ye götürür.
 */
@Controller('deria')
export class DeriaController {
  constructor(private readonly deria: DeriaService) {}

  @Get('availability')
  @Header('Cache-Control', 'public, max-age=120, s-maxage=120, stale-while-revalidate=300')
  async availability(): Promise<DeriaAvailability> {
    return this.deria.availability();
  }
}

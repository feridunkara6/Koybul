import { Module } from '@nestjs/common';
import { DeriaController } from './presentation/deria.controller';
import { DeriaService } from './application/deria.service';
import { DERIA_PROVIDER } from './domain/deria.types';
import { DeriaGovProvider } from './persistence/deria-gov.provider';

@Module({
  controllers: [DeriaController],
  providers: [DeriaService, { provide: DERIA_PROVIDER, useClass: DeriaGovProvider }],
})
export class DeriaModule {}

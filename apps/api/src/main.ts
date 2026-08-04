import { join } from 'path';
import compression from 'compression';
import { NestFactory } from '@nestjs/core';
import { Logger } from 'nestjs-pino';
import { AppModule } from './app.module';
import { EnvService } from './config/env.service';
import { GlobalProblemFilter } from './common/problem/problem.filter';
import { runBootSeed } from './infrastructure/seed/boot-seed';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  const logger = app.get(Logger);
  app.useLogger(logger);
  app.useGlobalFilters(new GlobalProblemFilter());
  // Sıkıştırma (perf, 2026-08): JSON yanıtları gzip'lenir — harita pin/balon
  // yanıtı ~%80-90 küçülür; yavaş mobil bağlantıda "noktalar geç geliyor"
  // şikayetinin sunucu ayağını kapatır. Statik eşik/filtre varsayılanları
  // (1 KB üstü, sıkıştırılabilir içerik tipleri) bilinçli korunur.
  app.use(compression());
  // CORS: misafir okuma uçları herkese açık; yazma uçları zaten Bearer token ister.
  // Web önizlemesi (GitHub Pages) ve gelecekteki web istemcileri bu sayede erişir.
  app.enableCors();
  // İş uçları /v1 altında (docs/23 §1); health uçları ALB için köke açık (docs/24 §13).
  app.setGlobalPrefix('v1', { exclude: ['healthz', 'readyz'] });
  app.enableShutdownHooks();

  const env = app.get(EnvService);

  // İçerik seed'i: SEED_ON_BOOT=true iken her açılışta idempotent seed uygulanır
  // ("içerik = kod" — yeni lokasyon partileri deploy ile canlıya iner). Hata,
  // servisi DÜŞÜRMEZ: mevcut veriyle açılmak, hiç açılmamaktan iyidir.
  if (process.env.SEED_ON_BOOT === 'true') {
    try {
      await runBootSeed(env.get('DATABASE_URL'), join(process.cwd(), 'prisma', 'seed.sql'));
      logger.log("boot-seed: içerik seed'i uygulandı (idempotent)");
    } catch (err) {
      logger.error({ err }, 'boot-seed başarısız — uygulama mevcut veriyle açılıyor');
    }
  }

  await app.listen(env.get('PORT'));
}

void bootstrap();

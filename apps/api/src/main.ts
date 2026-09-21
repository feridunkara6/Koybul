import { join } from 'path';
import * as Sentry from '@sentry/node';
import compression from 'compression';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { Logger } from 'nestjs-pino';
import { AppModule } from './app.module';
import { EnvService } from './config/env.service';
import { GlobalProblemFilter } from './common/problem/problem.filter';
import { runBootSeed } from './infrastructure/seed/boot-seed';
import { runBootMigrations } from './infrastructure/migrate/boot-migrate';

async function bootstrap(): Promise<void> {
  // Sentry (FAZ 0 K5, 2026-09): SENTRY_DSN verilmişse hata izleme açılır;
  // verilmemişse HİÇBİR ŞEY değişmez (yerel/CI ortamları DSN'siz çalışır —
  // rehber: docs/implementation/monitoring-kurulum-rehberi.md §3). PII
  // maskeleme: Authorization/Cookie başlıkları olaydan çıkarılır — token
  // asla Sentry'ye gitmez.
  if (process.env.SENTRY_DSN) {
    Sentry.init({
      dsn: process.env.SENTRY_DSN,
      environment: process.env.SENTRY_ENVIRONMENT ?? process.env.NODE_ENV ?? 'production',
      tracesSampleRate: 0.1,
      beforeSend(event) {
        if (event.request?.headers) {
          delete event.request.headers['authorization'];
          delete event.request.headers['cookie'];
        }
        return event;
      },
    });
  }

  const app = await NestFactory.create<NestExpressApplication>(AppModule, { bufferLogs: true });
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
  // Vekil (Render/ALB) arkasında gerçek istemci IP'si X-Forwarded-For'dan
  // okunur. Bu olmadan hız sınırı TÜM trafiği tek IP sayar (bulgu 2026-08).
  app.set('trust proxy', 1);
  // İş uçları /v1 altında (docs/23 §1); health uçları ALB için köke açık (docs/24 §13).
  app.setGlobalPrefix('v1', { exclude: ['healthz', 'readyz'] });
  app.enableShutdownHooks();

  const env = app.get(EnvService);

  // Şema göçü: deploy sonrası ilk açılışta bekleyen migration'lar uygulanır.
  // MIGRATE_ON_BOOT=false ile kapatılabilir. Hata servisi DÜŞÜRMEZ — mevcut
  // şemayla açılmak, hiç açılmamaktan iyidir; yeni uçlar 500 verir ve log'daki
  // `event: 'server_error'` alarmı bunu görünür kılar.
  const migrateFlag = (process.env.MIGRATE_ON_BOOT ?? 'true').trim().toLowerCase();
  if (!['false', '0', 'off', 'no'].includes(migrateFlag)) {
    try {
      const result = await runBootMigrations(
        env.get('DATABASE_URL'),
        join(process.cwd(), 'prisma', 'migrations'),
      );
      logger.log(
        `boot-migrate: uygulanan ${result.applied.length}, ` +
          `temel alınan ${result.baselined.length}` +
          (result.applied.length > 0 ? ` — ${result.applied.join(', ')}` : ''),
      );
    } catch (err) {
      logger.error({ err }, 'boot-migrate başarısız — uygulama mevcut şemayla açılıyor');
    }
  }

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

import { readdirSync, readFileSync } from 'fs';
import { join } from 'path';
import { Client } from 'pg';

/**
 * Açılışta şema göçü (MIGRATE_ON_BOOT kapatılmadıysa).
 *
 * NEDEN VAR: CI `prisma migrate deploy`'u yalnız KENDİ geçici veritabanında koşar;
 * canlı veritabanına hiçbir zaman uygulanmaz (denetim bulgusu, 2026-08). Yeni bir
 * tablo eklendiğinde API onu üretimde bulamaz ve uç 500 verir. Bu modül, deploy
 * sonrası ilk açılışta bekleyen göçleri uygular.
 *
 * NEDEN PRISMA CLI DEĞİL: üretim imajı devDependencies içermez ve CLI'nin motor
 * indirmesi ağ gerektirir. `pg` zaten runtime bağımlılığı (boot-seed onu kullanıyor).
 *
 * DEFTER (ledger): `app_migrations(name)`. Prisma'nın `_prisma_migrations`
 * tablosuna DOKUNULMAZ — mevcut canlı şema elle uygulandığı için orada kayıt yok
 * ve onu taklit etmek yanıltıcı olurdu.
 *
 * TEMEL ALMA (baseline): defter boşken şema zaten varsa (locations tablosu mevcut),
 * BASELINE_THROUGH'a kadarki göçler ÇALIŞTIRILMADAN uygulanmış sayılır. Aksi halde
 * ilk açılış `0001_init`'i tekrar uygulamaya kalkar. Boş bir veritabanında baseline
 * yapılmaz; her şey sırayla uygulanır.
 *
 * ÇOK ÖRNEK (replica): tüm iş `pg_advisory_lock` altında koşar — iki örnek aynı
 * anda açılırsa biri bekler, göç iki kez uygulanmaz.
 *
 * KURAL: buradan geçen HER göç idempotent yazılmalıdır (IF NOT EXISTS /
 * duplicate_object yakalama). Aynı SQL hem CI'da `prisma migrate deploy` ile hem
 * burada koşabilir; 0006/0007/0008 bu deseni izler.
 */

/**
 * Bu ada kadarki (dahil) göçler, mevcut şemada uygulanmış kabul edilir.
 *
 * SAHA DERSİ (2026-08-12): bu varsayım canlıda YANLIŞ çıktı — elle kurulmuş
 * şema 0005'in media sütunlarını içermiyordu ama defter "uygulandı" dedi;
 * içerik seed'i aylarca sessizce geri alındı. Böyle bir uyumsuzluk bir daha
 * görülürse çözüm bu sabiti ya da defteri OYNAMAK DEĞİL, eksik DDL'i yeni
 * bir İDEMPOTENT onarım göçüyle (bkz. 0012_media_onarim) göndermektir.
 */
export const BASELINE_THROUGH = '0007_wind_exposure';

/** Aynı anda açılan iki örneğin göçü çakıştırmaması için sabit kilit anahtarı. */
export const MIGRATION_LOCK_KEY = 20260809;

/** DDL kilidini süresiz beklemeyi engeller: port bağlama gecikmesi olmasın. */
const LOCK_TIMEOUT = '15s';
const STATEMENT_TIMEOUT = '120s';

export interface BootMigrateResult {
  baselined: string[];
  applied: string[];
  alreadyApplied: string[];
}

/** `runBootMigrations`'ın ihtiyaç duyduğu asgari istemci yüzeyi (test edilebilirlik). */
export interface MigrationClient {
  connect(): Promise<void>;
  query(text: string, values?: unknown[]): Promise<{ rows: unknown[] }>;
  end(): Promise<void>;
}

/**
 * Hangi göçlerin temel alınacağını / uygulanacağını hesaplar (saf fonksiyon).
 * @param all          diskteki göç adları (sıralı)
 * @param applied      defterdeki adlar
 * @param schemaExists canlı şema zaten var mı (locations tablosu)
 */
export function planMigrations(
  all: string[],
  applied: ReadonlySet<string>,
  schemaExists: boolean,
): { baseline: string[]; pending: string[] } {
  const fresh = applied.size === 0;
  // Yalnız İLK çalıştırmada ve şema zaten varken temel alınır.
  const baseline =
    fresh && schemaExists ? all.filter((n) => n.localeCompare(BASELINE_THROUGH) <= 0) : [];
  const known = new Set([...applied, ...baseline]);
  return { baseline, pending: all.filter((n) => !known.has(n)) };
}

/**
 * `prisma/migrations` altındaki göç KLASÖRLERİNİ sıralı döndürür.
 * Nokta içeren girdiler (migration_lock.toml, .DS_Store, elle bırakılmış .sql)
 * elenir — aksi halde `<ad>/migration.sql` okuması ENOTDIR ile düşer.
 */
export function listMigrationNames(
  migrationsDir: string,
  read: (dir: string) => string[] = (d) => readdirSync(d),
): string[] {
  return read(migrationsDir)
    .filter((name) => /^\d{4}_/.test(name) && !name.includes('.'))
    .sort((a, b) => a.localeCompare(b));
}

/** Bekleyen göçleri sırayla, her biri kendi işleminde, tek kilit altında uygular. */
export async function runBootMigrations(
  databaseUrl: string,
  migrationsDir: string,
  deps: {
    createClient?: (url: string) => MigrationClient;
    readSql?: (path: string) => string;
    listNames?: (dir: string) => string[];
  } = {},
): Promise<BootMigrateResult> {
  const createClient =
    deps.createClient ??
    ((url: string) => new Client({ connectionString: url }) as unknown as MigrationClient);
  const readSql = deps.readSql ?? ((path: string) => readFileSync(path, 'utf8'));
  const listNames = deps.listNames ?? ((dir: string) => listMigrationNames(dir));

  const client = createClient(databaseUrl);
  await client.connect();
  try {
    await client.query(`SET lock_timeout = '${LOCK_TIMEOUT}'`);
    await client.query(`SET statement_timeout = '${STATEMENT_TIMEOUT}'`);
    // Tüm süreç tek kilit altında: iki replika aynı DDL'i paralel koşamaz.
    await client.query('SELECT pg_advisory_lock($1)', [MIGRATION_LOCK_KEY]);
    try {
      await client.query(`
        CREATE TABLE IF NOT EXISTS app_migrations (
          name       text PRIMARY KEY,
          applied_at timestamptz NOT NULL DEFAULT now()
        )
      `);

      const ledger = await client.query('SELECT name FROM app_migrations');
      const appliedSet = new Set((ledger.rows as { name: string }[]).map((r) => r.name));

      const exists = await client.query(`SELECT to_regclass('public.locations') IS NOT NULL AS ok`);
      const schemaExists = (exists.rows as { ok: boolean }[])[0]?.ok === true;

      const names = listNames(migrationsDir);
      const { baseline, pending } = planMigrations(names, appliedSet, schemaExists);

      for (const name of baseline) {
        await client.query(
          'INSERT INTO app_migrations (name) VALUES ($1) ON CONFLICT (name) DO NOTHING',
          [name],
        );
      }

      const applied: string[] = [];
      for (const name of pending) {
        const sql = readSql(join(migrationsDir, name, 'migration.sql'));
        await client.query('BEGIN');
        try {
          await client.query(sql);
          await client.query(
            'INSERT INTO app_migrations (name) VALUES ($1) ON CONFLICT (name) DO NOTHING',
            [name],
          );
          await client.query('COMMIT');
          applied.push(name);
        } catch (err) {
          await client.query('ROLLBACK');
          // Bir göç düşerse SONRAKİLER denenmez: sıra bozulursa şema tutarsızlaşır.
          throw new Error(`Göç uygulanamadı: ${name} — ${String(err)}`);
        }
      }

      return { baselined: baseline, applied, alreadyApplied: [...appliedSet] };
    } finally {
      await client.query('SELECT pg_advisory_unlock($1)', [MIGRATION_LOCK_KEY]);
    }
  } finally {
    await client.end();
  }
}

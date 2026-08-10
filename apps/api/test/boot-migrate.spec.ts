import {
  BASELINE_THROUGH,
  MIGRATION_LOCK_KEY,
  MigrationClient,
  listMigrationNames,
  planMigrations,
  runBootMigrations,
} from '../src/infrastructure/migrate/boot-migrate';

const ALL = [
  '0001_init',
  '0002_rls',
  '0003_rls_force',
  '0004_contact_types',
  '0005_media_attribution',
  '0006_occupancy',
  '0007_wind_exposure',
  '0008_community',
];

describe('boot-migrate planMigrations', () => {
  it('MEVCUT şema + boş defter → 0007 dahil temel alınır, yalnız 0008 uygulanır', () => {
    const { baseline, pending } = planMigrations(ALL, new Set(), true);
    expect(baseline).toEqual(ALL.slice(0, 7));
    expect(baseline).toContain(BASELINE_THROUGH);
    expect(pending).toEqual(['0008_community']);
  });

  it('BOŞ veritabanı (şema yok) → hiçbir şey temel alınmaz, hepsi uygulanır', () => {
    const { baseline, pending } = planMigrations(ALL, new Set(), false);
    expect(baseline).toEqual([]);
    expect(pending).toEqual(ALL);
  });

  it('defter doluysa temel alma TEKRAR yapılmaz (yalnız ilk açılışta)', () => {
    const { baseline, pending } = planMigrations(ALL, new Set(ALL), true);
    expect(baseline).toEqual([]);
    expect(pending).toEqual([]);
  });

  it('yeni bir göç eklendiğinde yalnız o uygulanır', () => {
    const { baseline, pending } = planMigrations([...ALL, '0009_yeni'], new Set(ALL), true);
    expect(baseline).toEqual([]);
    expect(pending).toEqual(['0009_yeni']);
  });
});

describe('boot-migrate listMigrationNames', () => {
  it('yalnız NNNN_ önekli KLASÖRLERİ sıralı döndürür (dosyalar elenir)', () => {
    const names = listMigrationNames('/x', () => [
      '0010_sonra',
      'migration_lock.toml',
      '0002_rls',
      '.DS_Store',
      '0009_elle.sql',
      '0001_init',
    ]);
    expect(names).toEqual(['0001_init', '0002_rls', '0010_sonra']);
  });

  it('4 hane sınırında sıralama doğru: 0009 < 0010 < 0100', () => {
    const names = listMigrationNames('/x', () => ['0100_c', '0010_b', '0009_a']);
    expect(names).toEqual(['0009_a', '0010_b', '0100_c']);
  });

  it('gerçek migrations klasörü 0008_community içerir (senkron kalsın diye)', () => {
    const names = listMigrationNames(`${__dirname}/../prisma/migrations`);
    expect(names[0]).toBe('0001_init');
    expect(names).toContain(BASELINE_THROUGH);
    expect(names).toContain('0008_community');
    // migration_lock.toml sızmamalı — sızarsa okuma ENOTDIR ile düşer.
    expect(names.some((n) => n.includes('.'))).toBe(false);
  });
});

/** Sorguları kaydeden, satır döndürmesi ayarlanabilir sahte istemci. */
function fakeClient(opts: { ledger?: string[]; schemaExists?: boolean; failOn?: string } = {}) {
  const log: string[] = [];
  let ended = false;
  const client: MigrationClient = {
    connect: () => Promise.resolve(),
    end: () => {
      ended = true;
      return Promise.resolve();
    },
    query: (text: string) => {
      log.push(text.trim().split('\n')[0].trim());
      if (opts.failOn && text.includes(opts.failOn)) {
        return Promise.reject(new Error('patlak SQL'));
      }
      if (text.startsWith('SELECT name FROM app_migrations')) {
        return Promise.resolve({ rows: (opts.ledger ?? []).map((name) => ({ name })) });
      }
      if (text.includes('to_regclass')) {
        return Promise.resolve({ rows: [{ ok: opts.schemaExists ?? true }] });
      }
      return Promise.resolve({ rows: [] });
    },
  };
  return { client, log, isEnded: () => ended };
}

const NAMES = ['0007_wind_exposure', '0008_community', '0009_sonraki'];

describe('runBootMigrations', () => {
  const deps = (f: ReturnType<typeof fakeClient>, over: Record<string, unknown> = {}) => ({
    createClient: () => f.client,
    readSql: (path: string) => `-- ${path}`,
    listNames: () => NAMES,
    ...over,
  });

  it('şema varken defter boşsa: 0007 temel alınır, 0008 ve 0009 uygulanır', async () => {
    const f = fakeClient({ ledger: [], schemaExists: true });
    const res = await runBootMigrations('postgresql://x', '/m', deps(f));
    expect(res.baselined).toEqual(['0007_wind_exposure']);
    expect(res.applied).toEqual(['0008_community', '0009_sonraki']);
  });

  it('boş veritabanında hiçbir şey temel alınmaz', async () => {
    const f = fakeClient({ ledger: [], schemaExists: false });
    const res = await runBootMigrations('postgresql://x', '/m', deps(f));
    expect(res.baselined).toEqual([]);
    expect(res.applied).toEqual(NAMES);
  });

  it('uygulanmış göç TEKRAR koşmaz', async () => {
    const f = fakeClient({ ledger: NAMES, schemaExists: true });
    const res = await runBootMigrations('postgresql://x', '/m', deps(f));
    expect(res.applied).toEqual([]);
    expect(res.alreadyApplied).toEqual(NAMES);
  });

  it('her göç kendi BEGIN/COMMIT işleminde koşar', async () => {
    const f = fakeClient({ ledger: ['0007_wind_exposure', '0008_community'], schemaExists: true });
    await runBootMigrations('postgresql://x', '/m', deps(f));
    expect(f.log.filter((q) => q === 'BEGIN')).toHaveLength(1);
    expect(f.log.filter((q) => q === 'COMMIT')).toHaveLength(1);
    expect(f.log).not.toContain('ROLLBACK');
  });

  it('advisory lock alınır, kilit HER DURUMDA bırakılır ve bağlantı kapanır', async () => {
    const f = fakeClient({ ledger: [], schemaExists: true });
    await runBootMigrations('postgresql://x', '/m', deps(f));
    expect(f.log).toContain('SELECT pg_advisory_lock($1)');
    expect(f.log).toContain('SELECT pg_advisory_unlock($1)');
    expect(f.isEnded()).toBe(true);
    expect(MIGRATION_LOCK_KEY).toBeGreaterThan(0);
  });

  it('lock_timeout ve statement_timeout kilitten ÖNCE ayarlanır', async () => {
    const f = fakeClient({ ledger: [], schemaExists: true });
    await runBootMigrations('postgresql://x', '/m', deps(f));
    const lockAt = f.log.indexOf('SELECT pg_advisory_lock($1)');
    expect(f.log.findIndex((q) => q.startsWith('SET lock_timeout'))).toBeLessThan(lockAt);
    expect(f.log.findIndex((q) => q.startsWith('SET statement_timeout'))).toBeLessThan(lockAt);
  });

  it('bir göç düşerse ROLLBACK yapılır, SONRAKİLER denenmez ve hata yükselir', async () => {
    const f = fakeClient({ ledger: [], schemaExists: false, failOn: '0008_community' });
    await expect(runBootMigrations('postgresql://x', '/m', deps(f))).rejects.toThrow(
      /0008_community/,
    );
    expect(f.log).toContain('ROLLBACK');
    // 0009 hiç okunmamalı: sıra bozulmasın.
    expect(f.log.some((q) => q.includes('0009_sonraki'))).toBe(false);
    // Hata olsa bile kilit bırakılır ve bağlantı kapanır.
    expect(f.log).toContain('SELECT pg_advisory_unlock($1)');
    expect(f.isEnded()).toBe(true);
  });
});

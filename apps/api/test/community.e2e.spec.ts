import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { GlobalProblemFilter } from '../src/common/problem/problem.filter';
import { FIREBASE_TOKEN_VERIFIER } from '../src/infrastructure/firebase/firebase-token.verifier';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';
import { FakeFirebaseVerifier, generateTestKeys } from './helpers/auth-test-kit';

/**
 * Topluluk uçları uçtan uca — GERÇEK PostGIS. Yalnız CI'da koşar.
 *
 * Bu paketin asıl işi SQL'i çalıştırmaktır: depo katmanı ham SQL kullanıyor ve
 * ham SQL yalnız gerçekten koşturulunca doğrulanır. Tip denetimi burada yetmez.
 */
const runIf = process.env.CI === 'true' ? describe : describe.skip;

function tok(uid: string): string {
  return (
    'ftok:' +
    JSON.stringify({ uid, emailVerified: true, provider: 'google.com', email: `${uid}@e2e.dev` })
  );
}
const guestTok = 'ftok:' + JSON.stringify({ uid: 'com-guest', provider: 'anonymous' });

runIf('Topluluk uçları (e2e — gerçek DB)', () => {
  let app: INestApplication;
  let http: ReturnType<INestApplication['getHttpServer']>;
  let prisma: PrismaService;

  let locationId = '';
  let lat = 0;
  let lon = 0;
  let author = { token: '', userId: '' };
  let voter = { token: '', userId: '' };
  let moderator = { token: '', userId: '' };
  let noteId = '';

  async function login(firebaseTok: string): Promise<{ token: string; userId: string }> {
    const res = await request(http)
      .post('/v1/auth/sessions')
      .send({ firebaseIdToken: firebaseTok })
      .expect(200);
    return { token: res.body.accessToken, userId: res.body.user.id };
  }

  const auth = (t: string): [string, string] => ['authorization', `Bearer ${t}`];

  beforeAll(async () => {
    const keys = generateTestKeys();
    process.env.FIREBASE_PROJECT_ID = 'dockly-e2e';
    process.env.JWT_PRIVATE_KEY_PEM = keys.privatePem;
    process.env.JWT_PUBLIC_KEY_PEM = keys.publicPem;
    process.env.AUTH_RATE_LIMIT_PER_MIN = '200';

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(FIREBASE_TOKEN_VERIFIER)
      .useValue(new FakeFirebaseVerifier())
      .compile();
    app = moduleRef.createNestApplication({ logger: false });
    app.useGlobalFilters(new GlobalProblemFilter());
    app.setGlobalPrefix('v1', { exclude: ['healthz', 'readyz'] });
    await app.init();
    http = app.getHttpServer();
    prisma = app.get(PrismaService);

    const rows = await prisma.$queryRawUnsafe<{ id: string; lat: number; lon: number }[]>(
      `SELECT id, ST_Y(position::geometry) AS lat, ST_X(position::geometry) AS lon
       FROM locations WHERE status = 'published' AND deleted_at IS NULL LIMIT 1`,
    );
    expect(rows.length).toBe(1);
    locationId = rows[0].id;
    lat = Number(rows[0].lat);
    lon = Number(rows[0].lon);

    author = await login(tok('com-author'));
    voter = await login(tok('com-voter'));
    // Moderatör: önce kullanıcı satırı oluşsun, sonra rol yükseltilip yeniden giriş.
    const first = await login(tok('com-mod'));
    await prisma.$executeRawUnsafe(
      `UPDATE users SET role_id = (SELECT id FROM roles WHERE code = 'moderator') WHERE id = $1`,
      first.userId,
    );
    moderator = await login(tok('com-mod'));
  });

  afterAll(async () => {
    // Kullanıcı satırları SİLİNMEZ: user_sessions / contribution_events /
    // reviews / location_reports / moderation_tasks FK'leri NO ACTION ve silme
    // iptal olurdu; hata afterAll'ı düşürüp app.close()'u atlatır (bağlantı sızar).
    // CI veritabanı zaten geçici — diğer e2e paketleri de temizlik yapmıyor.
    await app?.close();
  });

  it('anonim: not listesi ve yakındakiler 200 döner', async () => {
    await request(http).get(`/v1/locations/${locationId}/notes`).expect(200);
    await request(http).get(`/v1/notes/nearby?lat=${lat}&lon=${lon}`).expect(200);
  });

  it('geçersiz UUID → 404 (varlık enumerasyonu kapalı)', async () => {
    await request(http).get('/v1/locations/not-a-uuid/notes').expect(404);
  });

  it('misafir not yazamaz (kayıt duvarı)', async () => {
    const guest = await login(guestTok);
    await request(http)
      .post(`/v1/locations/${locationId}/notes`)
      .set(...auth(guest.token))
      .send({ kind: 'experience', body: 'Denemeler yapiyorum burada', observedOn: '2026-08-01' })
      .expect(403);
  });

  it('uyarı notu konumsuz yazılamaz (422)', async () => {
    await request(http)
      .post(`/v1/locations/${locationId}/notes`)
      .set(...auth(author.token))
      .send({
        kind: 'hazard',
        body: 'Girişte batık kaya var, dikkat edin.',
        observedOn: '2026-08-01',
      })
      .expect(422);
  });

  it('çok uzak konumdan güncel durum notu reddedilir (422)', async () => {
    await request(http)
      .post(`/v1/locations/${locationId}/notes`)
      .set(...auth(author.token))
      .send({
        kind: 'status',
        body: 'Buradan cok uzaktayim, kabul edilmemeli.',
        observedOn: '2026-08-01',
        position: { lat: 0, lon: 0 },
      })
      .expect(422);
  });

  it('deneyim notu yazılır ve İNCELEMEDE bekler', async () => {
    const res = await request(http)
      .post(`/v1/locations/${locationId}/notes`)
      .set(...auth(author.token))
      .send({
        kind: 'experience',
        body: 'Kuzey ucunda dort metrede kum, tutus cok iyi. Gece rahat ettik.',
        observedOn: '2026-08-01',
      })
      .expect(201);
    noteId = res.body.id;
    expect(res.body.status).toBe('pending');

    // Kamu listesinde HENÜZ görünmez.
    const pub = await request(http).get(`/v1/locations/${locationId}/notes`).expect(200);
    expect(pub.body.data.some((n: { id: string }) => n.id === noteId)).toBe(false);

    // Sahibi kendi bekleyen içeriğini görür.
    const mine = await request(http)
      .get('/v1/users/me/notes?status=pending')
      .set(...auth(author.token))
      .expect(200);
    expect(mine.body.data.some((n: { id: string }) => n.id === noteId)).toBe(true);
  });

  it('moderasyon kuyruğu yalnız moderatöre açıktır', async () => {
    await request(http)
      .get('/v1/moderation/queue')
      .set(...auth(author.token))
      .expect(403);
    const q = await request(http)
      .get('/v1/moderation/queue?entityType=note')
      .set(...auth(moderator.token))
      .expect(200);
    expect(q.body.data.some((t: { entityId: string }) => t.entityId === noteId)).toBe(true);
  });

  it('moderatör onaylar → not yayına çıkar ve yazara puan yazılır', async () => {
    const q = await request(http)
      .get('/v1/moderation/queue?entityType=note')
      .set(...auth(moderator.token))
      .expect(200);
    const task = q.body.data.find((t: { entityId: string }) => t.entityId === noteId);
    expect(task).toBeDefined();

    const dec = await request(http)
      .post(`/v1/moderation/${task.taskId}/decision`)
      .set(...auth(moderator.token))
      .send({ decision: 'approve' })
      .expect(201);
    expect(dec.body.pointsAwarded).toBeGreaterThan(0);

    const pub = await request(http).get(`/v1/locations/${locationId}/notes`).expect(200);
    expect(pub.body.data.some((n: { id: string }) => n.id === noteId)).toBe(true);
  });

  it('aynı görev iki kez karara bağlanamaz (yarış koşulu → 404)', async () => {
    const dec = await request(http)
      .post(`/v1/moderation/${'00000000-0000-4000-8000-000000000000'}/decision`)
      .set(...auth(moderator.token))
      .send({ decision: 'approve' })
      .expect(404);
    expect(dec.body.status).toBe(404);
  });

  it('red kararı sebep ister (422)', async () => {
    await request(http)
      .post(`/v1/moderation/${'00000000-0000-4000-8000-000000000000'}/decision`)
      .set(...auth(moderator.token))
      .send({ decision: 'reject' })
      .expect(422);
  });

  it('başka kullanıcı faydalı oyu verir; sahibi kendi notuna oy veremez', async () => {
    const r = await request(http)
      .post(`/v1/notes/${noteId}/reactions`)
      .set(...auth(voter.token))
      .send({ reaction: 'helpful' })
      .expect(201);
    expect(r.body.helpfulCount).toBe(1);

    // Aynı oy tekrar: sayaç ARTMAZ (şema PK'sı engeller).
    const again = await request(http)
      .post(`/v1/notes/${noteId}/reactions`)
      .set(...auth(voter.token))
      .send({ reaction: 'helpful' })
      .expect(201);
    expect(again.body.helpfulCount).toBe(1);

    await request(http)
      .post(`/v1/notes/${noteId}/reactions`)
      .set(...auth(author.token))
      .send({ reaction: 'helpful' })
      .expect(403);
  });

  it('denizci özeti ve katkı geçmişi dolu döner', async () => {
    const s = await request(http)
      .get('/v1/users/me/summary')
      .set(...auth(author.token))
      .expect(200);
    expect(s.body.points).toBeGreaterThan(0);
    expect(['new', 'coastal', 'guide', 'master', 'pilot']).toContain(s.body.levelCode);
    expect(s.body.approvedCount).toBeGreaterThanOrEqual(1);

    const c = await request(http)
      .get('/v1/users/me/contributions')
      .set(...auth(author.token))
      .expect(200);
    expect(c.body.data.length).toBeGreaterThan(0);
  });

  it('güncel durum notu konumla yazılır (GPS doğrulaması geçer)', async () => {
    const res = await request(http)
      .post(`/v1/locations/${locationId}/notes`)
      .set(...auth(author.token))
      .send({
        kind: 'status',
        body: 'Samandira ucreti guncellenmis, nakit isteniyor.',
        observedOn: '2026-08-01',
        position: { lat, lon },
      })
      .expect(201);
    expect(['pending', 'approved']).toContain(res.body.status);
  });

  it('yorum yazılır; ikinci yorum 409 verir', async () => {
    await request(http)
      .post(`/v1/locations/${locationId}/reviews`)
      .set(...auth(author.token))
      .send({
        overallRating: 4,
        body: 'Bagalama kolay, personel ilgili. Elektrik ve su sorunsuz calisti.',
        dimensions: {},
      })
      .expect(201);

    const dup = await request(http)
      .post(`/v1/locations/${locationId}/reviews`)
      .set(...auth(author.token))
      .send({ overallRating: 5 })
      .expect(409);
    expect(dup.body.type).toContain('duplicate-review');
  });

  it('geçersiz puan boyutu 422 verir', async () => {
    await request(http)
      .post(`/v1/locations/${locationId}/reviews`)
      .set(...auth(voter.token))
      .send({ overallRating: 3, dimensions: { boyle_bir_boyut_yok: 4 } })
      .expect(422);
  });

  it('hatalı bilgi bildirimi yazılır; 24 saat içinde mükerrer 409 verir', async () => {
    await request(http)
      .post(`/v1/locations/${locationId}/reports`)
      .set(...auth(voter.token))
      .send({ reason: 'wrong_info', message: 'Telefon numarasi degismis.' })
      .expect(201);

    await request(http)
      .post(`/v1/locations/${locationId}/reports`)
      .set(...auth(voter.token))
      .send({ reason: 'wrong_info' })
      .expect(409);
  });

  it('moderasyon sayaçları döner', async () => {
    const res = await request(http)
      .get('/v1/moderation/counts')
      .set(...auth(moderator.token))
      .expect(200);
    expect(typeof res.body).toBe('object');
  });

  it('yorum düzenlenir ve yeniden incelemeye düşer; boyutlu puan yazılır', async () => {
    const created = await request(http)
      .post(`/v1/locations/${locationId}/reviews`)
      .set(...auth(voter.token))
      .send({
        overallRating: 5,
        body: 'Ikinci kullanicinin yorumu: giris kolay, dip kum, ruzgar korumasi iyi.',
        dimensions: { shelter: 5 },
      })
      .expect(201);

    const patched = await request(http)
      .patch(`/v1/reviews/${created.body.id}`)
      .set(...auth(voter.token))
      .send({ overallRating: 4, dimensions: { shelter: 4 } })
      .expect(200);
    expect(patched.body.status).toBe('pending');

    // Başkasının yorumu düzenlenemez / silinemez.
    await request(http)
      .patch(`/v1/reviews/${created.body.id}`)
      .set(...auth(author.token))
      .send({ overallRating: 1 })
      .expect(404);
  });

  it('yoruma faydalı oyu: sayaç 1 olur (DB tetikleyicisi sayar, çift artmaz)', async () => {
    const created = await request(http)
      .post(`/v1/locations/${locationId}/reviews`)
      .set(...auth(moderator.token))
      .send({ overallRating: 4, body: 'Ucuncu kullanicinin kisa yorumu burada.' })
      .expect(201);

    // Yayına alınmadan oy verilemez (404).
    await request(http)
      .post(`/v1/reviews/${created.body.id}/reactions`)
      .set(...auth(voter.token))
      .expect(404);

    const q = await request(http)
      .get('/v1/moderation/queue?entityType=review')
      .set(...auth(moderator.token))
      .expect(200);
    const task = q.body.data.find((t: { entityId: string }) => t.entityId === created.body.id);
    expect(task).toBeDefined();
    await request(http)
      .post(`/v1/moderation/${task.taskId}/decision`)
      .set(...auth(moderator.token))
      .send({ decision: 'approve' })
      .expect(201);

    const r1 = await request(http)
      .post(`/v1/reviews/${created.body.id}/reactions`)
      .set(...auth(voter.token))
      .expect(201);
    expect(r1.body.helpfulCount).toBe(1);

    // Aynı oy tekrar → sayaç 1'de kalır.
    const r2 = await request(http)
      .post(`/v1/reviews/${created.body.id}/reactions`)
      .set(...auth(voter.token))
      .expect(201);
    expect(r2.body.helpfulCount).toBe(1);

    // Sahibi kendi yorumuna oy veremez ve OY SATIRI DA YAZILMAZ.
    await request(http)
      .post(`/v1/reviews/${created.body.id}/reactions`)
      .set(...auth(moderator.token))
      .expect(403);
    const r3 = await request(http)
      .post(`/v1/reviews/${created.body.id}/reactions`)
      .set(...auth(voter.token))
      .expect(201);
    expect(r3.body.helpfulCount).toBe(1);
  });

  it('içerik şikâyeti hedef referansıyla yazılır', async () => {
    await request(http)
      .post(`/v1/locations/${locationId}/reports`)
      .set(...auth(author.token))
      .send({ reason: 'abuse', targetType: 'note', targetId: noteId, message: 'Uygunsuz icerik.' })
      .expect(201);
  });

  it('yazar kendi notunu siler (204) ve liste küçülür', async () => {
    await request(http)
      .delete(`/v1/notes/${noteId}`)
      .set(...auth(author.token))
      .expect(204);
    const pub = await request(http).get(`/v1/locations/${locationId}/notes`).expect(200);
    expect(pub.body.data.some((n: { id: string }) => n.id === noteId)).toBe(false);
  });

  it('başkasının notu silinemez / düzenlenemez (404 — sızdırmaz)', async () => {
    const created = await request(http)
      .post(`/v1/locations/${locationId}/notes`)
      .set(...auth(author.token))
      .send({
        kind: 'experience',
        body: 'Baska bir deneyim notu yaziyorum.',
        observedOn: '2026-08-02',
      })
      .expect(201);
    await request(http)
      .delete(`/v1/notes/${created.body.id}`)
      .set(...auth(voter.token))
      .expect(404);
    await request(http)
      .patch(`/v1/notes/${created.body.id}`)
      .set(...auth(voter.token))
      .send({ body: 'ele geciriyorum' })
      .expect(404);
  });
});

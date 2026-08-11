import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { GlobalProblemFilter } from '../src/common/problem/problem.filter';
import { FIREBASE_TOKEN_VERIFIER } from '../src/infrastructure/firebase/firebase-token.verifier';
import { FakeFirebaseVerifier, generateTestKeys } from './helpers/auth-test-kit';

/** users/me uçtan uca — gerçek DB+Redis (yalnız CI). */
const runIf = process.env.CI === 'true' ? describe : describe.skip;

function ftok(uid: string, provider = 'google.com'): string {
  return 'ftok:' + JSON.stringify({ uid, emailVerified: true, provider, email: `${uid}@e2e.dev` });
}

runIf('Users API (e2e — gerçek DB+Redis)', () => {
  let app: INestApplication;
  let http: ReturnType<INestApplication['getHttpServer']>;

  async function login(uid: string): Promise<{ access: string; refresh: string; userId: string }> {
    const res = await request(http)
      .post('/v1/auth/sessions')
      .send({ firebaseIdToken: ftok(uid) })
      .expect(200);
    return {
      access: res.body.accessToken,
      refresh: res.body.refreshToken,
      userId: res.body.user.id,
    };
  }

  beforeAll(async () => {
    const keys = generateTestKeys();
    process.env.FIREBASE_PROJECT_ID = 'dockly-e2e';
    process.env.JWT_PRIVATE_KEY_PEM = keys.privatePem;
    process.env.JWT_PUBLIC_KEY_PEM = keys.publicPem;
    process.env.AUTH_RATE_LIMIT_PER_MIN = '100';

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(FIREBASE_TOKEN_VERIFIER)
      .useValue(new FakeFirebaseVerifier())
      .compile();
    app = moduleRef.createNestApplication({ logger: false });
    app.useGlobalFilters(new GlobalProblemFilter());
    app.setGlobalPrefix('v1', { exclude: ['healthz', 'readyz'] });
    await app.init();
    http = app.getHttpServer();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /v1/users/me → lazy varsayılanlarla profil+ayarlar (theme=system, units=metric)', async () => {
    const { access } = await login('me-user-1');
    const res = await request(http)
      .get('/v1/users/me')
      .set('Authorization', `Bearer ${access}`)
      .expect(200);
    // GÖRÜNEN AD E-POSTADAN TÜRETİLMEZ (Faz 0, KVKK). E-posta
    // 'me-user-1@e2e.dev' olmasına rağmen ad "Kaptan XXXX" biçimindedir ve
    // e-postanın yerel kısmını ASLA içermez — bu ad anonim uçlarda herkese
    // görünüyor.
    expect(res.body.profile.displayName).toMatch(/^Kaptan [0-9A-F]{4}$/);
    expect(res.body.profile.displayName).not.toContain('me-user-1');
    expect(res.body.settings).toEqual({
      theme: 'system',
      units: 'metric',
      marketingConsent: false,
    });
    expect(res.body.role).toBe('user');
  });

  it('token olmadan 401; bozuk token 401', async () => {
    await request(http).get('/v1/users/me').expect(401);
    await request(http).get('/v1/users/me').set('Authorization', 'Bearer bozuk').expect(401);
  });

  it('PATCH: profil+ayar+locale günceller; yanıt güncel hali döner', async () => {
    const { access } = await login('me-user-2');
    const res = await request(http)
      .patch('/v1/users/me')
      .set('Authorization', `Bearer ${access}`)
      .send({
        locale: 'en',
        profile: { displayName: 'Kaptan Poyraz', bio: 'Ege sularında' },
        settings: { theme: 'dark', units: 'imperial', marketingConsent: true },
      })
      .expect(200);
    expect(res.body.locale).toBe('en');
    expect(res.body.profile.displayName).toBe('Kaptan Poyraz');
    expect(res.body.settings).toEqual({ theme: 'dark', units: 'imperial', marketingConsent: true });
  });

  it('PATCH beyaz liste: bilinmeyen/yasak alan (role) → 422', async () => {
    const { access } = await login('me-user-3');
    const res = await request(http)
      .patch('/v1/users/me')
      .set('Authorization', `Bearer ${access}`)
      .send({ role: 'admin' })
      .expect(422);
    expect(res.body.type).toContain('validation-error');
  });

  it('PATCH boş gövde → 422 empty_patch (edge)', async () => {
    const { access } = await login('me-user-4');
    const res = await request(http)
      .patch('/v1/users/me')
      .set('Authorization', `Bearer ${access}`)
      .send({})
      .expect(422);
    expect(res.body.errors[0].code).toBe('empty_patch');
  });

  it('PATCH: null ile alan temizleme (bio) ve theme=system→null eşlemesi', async () => {
    const { access } = await login('me-user-5');
    await request(http)
      .patch('/v1/users/me')
      .set('Authorization', `Bearer ${access}`)
      .send({ profile: { bio: 'silinecek' }, settings: { theme: 'light' } })
      .expect(200);
    const res = await request(http)
      .patch('/v1/users/me')
      .set('Authorization', `Bearer ${access}`)
      .send({ profile: { bio: null }, settings: { theme: 'system' } })
      .expect(200);
    expect(res.body.profile.bio).toBeNull();
    expect(res.body.settings.theme).toBe('system');
  });

  it('DELETE /v1/users/me: 204 → token anında ölür → aynı kimlikle YENİ hesap açılır (KVKK)', async () => {
    const first = await login('me-user-del');
    await request(http)
      .delete('/v1/users/me')
      .set('Authorization', `Bearer ${first.access}`)
      .expect(204);

    // jti karalistesi: aynı access token artık geçersiz (15 dk beklemeden)
    await request(http)
      .get('/v1/users/me')
      .set('Authorization', `Bearer ${first.access}`)
      .expect(401);

    // refresh ailesi de ölü
    await request(http)
      .post('/v1/auth/sessions/refresh')
      .send({ refreshToken: first.refresh })
      .expect(401);

    // Aynı Firebase kimliğiyle dönen kişi YENİ, temiz hesap alır
    const second = await login('me-user-del');
    expect(second.userId).not.toBe(first.userId);
    const res = await request(http)
      .get('/v1/users/me')
      .set('Authorization', `Bearer ${second.access}`)
      .expect(200);
    expect(res.body.profile.displayName).toMatch(/^Kaptan [0-9A-F]{4}$/);
    expect(res.body.profile.displayName).not.toContain('me-user-del');
  });

  it('görünen ad kullanıcı kimliğinden türer; iki kaptan birbirinden ayrılır', async () => {
    // Ad e-postadan gelmiyor ama tamamen aynı da olmamalı: moderasyon ve
    // topluluk, iki kaptanı ayırt edebilmeli.
    const a = await login('me-name-a');
    const b = await login('me-name-b');
    const ra = await request(http)
      .get('/v1/users/me')
      .set('Authorization', `Bearer ${a.access}`)
      .expect(200);
    const rb = await request(http)
      .get('/v1/users/me')
      .set('Authorization', `Bearer ${b.access}`)
      .expect(200);
    const na = ra.body.profile.displayName as string;
    const nb = rb.body.profile.displayName as string;
    expect(na).toMatch(/^Kaptan [0-9A-F]{4}$/);
    expect(nb).toMatch(/^Kaptan [0-9A-F]{4}$/);
    expect(na).not.toBe(nb);
    // Sonek kimliğin SON dört hanesidir. İlk haneler uuidv7'de zaman
    // damgasıdır ve aynı dönemde kaydolan herkeste aynı çıkar — bu test tam
    // olarak o hatayı yakalamak için iki hesabı arka arkaya açıyor.
    expect(na.split(' ')[1]).toBe(a.userId.replace(/-/g, '').slice(-4).toUpperCase());
  });

  it('kullanıcı adını kendisi belirleyebilir; varsayılan üstüne yazılır', async () => {
    const { access } = await login('me-name-c');
    await request(http)
      .patch('/v1/users/me')
      .set('Authorization', `Bearer ${access}`)
      .send({ profile: { displayName: 'Poyraz Kaptan' } })
      .expect(200);
    const res = await request(http)
      .get('/v1/users/me')
      .set('Authorization', `Bearer ${access}`)
      .expect(200);
    expect(res.body.profile.displayName).toBe('Poyraz Kaptan');
  });
});

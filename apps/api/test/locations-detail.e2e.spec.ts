import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { GlobalProblemFilter } from '../src/common/problem/problem.filter';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';

/** Liman detay ucu uçtan uca — gerçek DB (yalnız CI). */
const runIf = process.env.CI === 'true' ? describe : describe.skip;

runIf('Location detail API (e2e — gerçek DB)', () => {
  let app: INestApplication;
  let http: ReturnType<INestApplication['getHttpServer']>;
  let prisma: PrismaService;

  async function seedDetail(): Promise<void> {
    await prisma.$executeRawUnsafe(`
      INSERT INTO admin_areas (id, country_code, parent_id, level, name, slug)
      VALUES (gen_random_uuid(), 'TR', NULL, 'province', 'Muğla', 'e2e-mugla')
      ON CONFLICT (country_code, level, slug) DO NOTHING;
    `);
    await prisma.$executeRawUnsafe(`
      INSERT INTO admin_areas (id, country_code, parent_id, level, name, slug)
      SELECT gen_random_uuid(), 'TR', p.id, 'district', 'Fethiye', 'e2e-fethiye'
      FROM admin_areas p WHERE p.slug = 'e2e-mugla' AND p.level = 'province'
      ON CONFLICT (country_code, level, slug) DO NOTHING;
    `);
    await prisma.$executeRawUnsafe(`
      INSERT INTO water_bodies (id, country_code, type, name, slug)
      VALUES (gen_random_uuid(), 'TR', 'gulf', 'Göcek Körfezi', 'e2e-gocek-korfezi')
      ON CONFLICT (slug) DO NOTHING;
    `);
    await prisma.$executeRawUnsafe(`
      INSERT INTO locations
        (id, slug, location_type_id, status, country_code, admin_area_id, water_body_id,
         name, description, position, max_boat_length_m, max_draft_m, depth_min_m, depth_max_m,
         capacity, price_tier, is_24h, rating_avg, rating_count, review_count, photo_count)
      SELECT gen_random_uuid(), 'e2e-detail-marina', 1, 'published', 'TR',
        (SELECT id FROM admin_areas WHERE slug = 'e2e-fethiye'),
        (SELECT id FROM water_bodies WHERE slug = 'e2e-gocek-korfezi'),
        'E2E Detay Marina (temel)', 'Temel açıklama',
        ST_SetSRID(ST_MakePoint(28.95, 36.75), 4326)::geography,
        40.0, 5.0, 3.0, 12.0, 380, 'paid', true, 4.60, 50, 50, 24
      ON CONFLICT (slug) DO NOTHING;
    `);
    await prisma.$executeRawUnsafe(`
      INSERT INTO location_i18n (location_id, locale, name, description)
      SELECT l.id, 'tr', 'D-Marin Göcek', 'Türkçe açıklama' FROM locations l WHERE l.slug = 'e2e-detail-marina'
      ON CONFLICT (location_id, locale) DO NOTHING;
    `);
    await prisma.$executeRawUnsafe(`
      INSERT INTO location_i18n (location_id, locale, name, description)
      SELECT l.id, 'en', 'D-Marin Gocek', 'English description' FROM locations l WHERE l.slug = 'e2e-detail-marina'
      ON CONFLICT (location_id, locale) DO NOTHING;
    `);
    await prisma.$executeRawUnsafe(`
      INSERT INTO location_amenities (location_id, amenity_id)
      SELECT l.id, a.id FROM locations l, amenities a
      WHERE l.slug = 'e2e-detail-marina' AND a.code IN ('electricity', 'water')
      ON CONFLICT DO NOTHING;
    `);
    await prisma.$executeRawUnsafe(`
      INSERT INTO location_services (location_id, service_id)
      SELECT l.id, s.id FROM locations l, services s
      WHERE l.slug = 'e2e-detail-marina' AND s.code = 'mooring_assist'
      ON CONFLICT DO NOTHING;
    `);
    await prisma.$executeRawUnsafe(`
      INSERT INTO location_contacts (id, location_id, contact_type, value, is_primary)
      SELECT gen_random_uuid(), l.id, 'phone', '+902520000000', true FROM locations l WHERE l.slug = 'e2e-detail-marina'
      ON CONFLICT (location_id, contact_type, value) DO NOTHING;
    `);
    await prisma.$executeRawUnsafe(`
      INSERT INTO location_contacts (id, location_id, contact_type, value, is_primary)
      SELECT gen_random_uuid(), l.id, 'vhf', '72', false FROM locations l WHERE l.slug = 'e2e-detail-marina'
      ON CONFLICT (location_id, contact_type, value) DO NOTHING;
    `);
    await prisma.$executeRawUnsafe(`
      INSERT INTO operating_hours (id, location_id, day_of_week, opens_at, closes_at, is_closed)
      SELECT gen_random_uuid(), l.id, 1, TIME '08:00', TIME '22:00', false FROM locations l WHERE l.slug = 'e2e-detail-marina'
      ON CONFLICT (location_id, day_of_week, opens_at) DO NOTHING;
    `);
    await prisma.$executeRawUnsafe(`
      INSERT INTO operating_hours (id, location_id, day_of_week, opens_at, closes_at, is_closed)
      SELECT gen_random_uuid(), l.id, 2, NULL, NULL, true FROM locations l WHERE l.slug = 'e2e-detail-marina'
      ON CONFLICT (location_id, day_of_week, opens_at) DO NOTHING;
    `);
    await prisma.$executeRawUnsafe(`
      INSERT INTO opening_seasons (id, location_id, opens_on_month, opens_on_day, closes_on_month, closes_on_day)
      SELECT gen_random_uuid(), l.id, 5, 1, 10, 31 FROM locations l WHERE l.slug = 'e2e-detail-marina'
      ON CONFLICT DO NOTHING;
    `);
    // typeDetails (marina alt-tipi)
    await prisma.$executeRawUnsafe(`
      INSERT INTO marina_details (location_id, berth_count, vhf_channel, has_blue_flag, travel_lift_capacity_tons, winter_storage)
      SELECT l.id, 380, '72', true, 100.0, true FROM locations l WHERE l.slug = 'e2e-detail-marina'
      ON CONFLICT (location_id) DO NOTHING;
    `);
    // rating.dimensions için onaylı yorum + boyut puanları
    await prisma.$executeRawUnsafe(`
      INSERT INTO users (id, firebase_uid)
      VALUES ('11111111-1111-1111-1111-111111111111', 'e2e_detail_reviewer')
      ON CONFLICT (id) DO NOTHING;
    `);
    await prisma.$executeRawUnsafe(`
      INSERT INTO reviews (id, location_id, user_id, overall_rating, status)
      SELECT '22222222-2222-2222-2222-222222222222', l.id, '11111111-1111-1111-1111-111111111111', 5, 'approved'
      FROM locations l WHERE l.slug = 'e2e-detail-marina'
      ON CONFLICT (id) DO NOTHING;
    `);
    await prisma.$executeRawUnsafe(`
      INSERT INTO review_ratings (review_id, dimension_id, score)
      VALUES
        ('22222222-2222-2222-2222-222222222222', 1, 5),
        ('22222222-2222-2222-2222-222222222222', 2, 4)
      ON CONFLICT (review_id, dimension_id) DO NOTHING;
    `);
    // Yakıt iskelesi alt-tipi
    await prisma.$executeRawUnsafe(`
      INSERT INTO locations (id, slug, location_type_id, status, country_code, name, position)
      VALUES (gen_random_uuid(), 'e2e-detail-fuel', 6, 'published', 'TR', 'E2E Yakıt İskelesi',
        ST_SetSRID(ST_MakePoint(28.96, 36.76), 4326)::geography)
      ON CONFLICT (slug) DO NOTHING;
    `);
    await prisma.$executeRawUnsafe(`
      INSERT INTO fuel_dock_details (location_id, has_diesel, has_gasoline, min_depth_m)
      SELECT l.id, true, true, 3.5 FROM locations l WHERE l.slug = 'e2e-detail-fuel'
      ON CONFLICT (location_id) DO NOTHING;
    `);
    // Demirleme alt-tipi
    await prisma.$executeRawUnsafe(`
      INSERT INTO locations (id, slug, location_type_id, status, country_code, name, position)
      VALUES (gen_random_uuid(), 'e2e-detail-anchorage', 8, 'published', 'TR', 'E2E Demirleme',
        ST_SetSRID(ST_MakePoint(28.97, 36.77), 4326)::geography)
      ON CONFLICT (slug) DO NOTHING;
    `);
    await prisma.$executeRawUnsafe(`
      INSERT INTO anchorage_details (location_id, holding_type, protection_n, protection_s, is_free)
      SELECT l.id, 'sand', 4, 2, true FROM locations l WHERE l.slug = 'e2e-detail-anchorage'
      ON CONFLICT (location_id) DO NOTHING;
    `);
    // Belediye limanı: zemin DOLU ama tip demirleme DEĞİL (0009_seabed).
    await prisma.$executeRawUnsafe(`
      INSERT INTO locations (id, slug, location_type_id, status, country_code, name, position,
        seabed_holding_type)
      VALUES (gen_random_uuid(), 'e2e-detail-pier-seabed', 3, 'published', 'TR', 'E2E Barınak',
        ST_SetSRID(ST_MakePoint(28.98, 36.78), 4326)::geography, 'mud')
      ON CONFLICT (slug) DO NOTHING;
    `);
    // 404 için taslak
    await prisma.$executeRawUnsafe(`
      INSERT INTO locations (id, slug, location_type_id, status, country_code, name, position)
      VALUES (gen_random_uuid(), 'e2e-detail-draft', 1, 'draft', 'TR', 'Taslak',
        ST_SetSRID(ST_MakePoint(28.95, 36.75), 4326)::geography)
      ON CONFLICT (slug) DO NOTHING;
    `);
  }

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication({ logger: false });
    app.useGlobalFilters(new GlobalProblemFilter());
    app.setGlobalPrefix('v1', { exclude: ['healthz', 'readyz'] });
    await app.init();
    http = app.getHttpServer();
    prisma = app.get(PrismaService);
    await seedDetail();
  });

  afterAll(async () => {
    await app.close();
  });

  it('slug ile detay (varsayılan TR) — tam DTO', async () => {
    const res = await request(http).get('/v1/locations/e2e-detail-marina').expect(200);
    const b = res.body;
    expect(b.name).toBe('D-Marin Göcek');
    expect(b.description).toBe('Türkçe açıklama');
    expect(b.type).toBe('private_marina');
    expect(b.status).toBe('published');
    expect(b.position.lat).toBeCloseTo(36.75, 4);
    expect(b.geo.countryCode).toBe('TR');
    expect(b.geo.adminArea.name).toBe('Fethiye');
    expect(b.geo.adminArea.province).toBe('Muğla');
    expect(b.geo.waterBody.name).toBe('Göcek Körfezi');
    expect(b.geo.waterBody.type).toBe('gulf');
    expect(b.dimensions.maxBoatLengthM).toBeCloseTo(40, 1);
    expect(b.dimensions.capacity).toBe(380);
    expect(b.priceTier).toBe('paid');
    expect(b.is24h).toBe(true);
    expect(b.rating.avg).toBeCloseTo(4.6, 2);
    expect(b.rating.count).toBe(50);
    expect(b.rating.dimensions).toEqual([
      { code: 'shelter', avg: 5 },
      { code: 'staff', avg: 4 },
    ]);
    expect(b.amenities).toHaveLength(2);
    expect(b.amenities[0].label).toBe('Elektrik');
    expect(b.services[0].code).toBe('mooring_assist');
    expect(b.contacts[0]).toEqual({
      type: 'phone',
      value: '+902520000000',
      isPrimary: true,
      label: null,
    });
    const day1 = b.hours.find((h: { dayOfWeek: number }) => h.dayOfWeek === 1);
    expect(day1).toEqual({ dayOfWeek: 1, opensAt: '08:00', closesAt: '22:00' });
    const day2 = b.hours.find((h: { dayOfWeek: number }) => h.dayOfWeek === 2);
    expect(day2).toEqual({ dayOfWeek: 2, opensAt: null, closesAt: null });
    expect(b.seasons[0]).toEqual({ opensOn: '05-01', closesOn: '10-31' });
    expect(b.typeDetails.kind).toBe('marina');
    expect(b.typeDetails.berthCount).toBe(380);
    expect(b.typeDetails.vhfChannel).toBe('72');
    expect(b.typeDetails.hasBlueFlag).toBe(true);
    expect(b.typeDetails.travelLiftCapacityTons).toBeCloseTo(100, 1);
    expect(b.media).toEqual({ cover: null, count: 24 });
    expect(b.userContext).toBeNull();
    expect(b.counts).toEqual({ reviews: 50, photos: 24 });
  });

  it('id ile de erişilir (slug yanıtındaki id)', async () => {
    const bySlug = await request(http).get('/v1/locations/e2e-detail-marina').expect(200);
    const byId = await request(http).get(`/v1/locations/${bySlug.body.id}`).expect(200);
    expect(byId.body.slug).toBe('e2e-detail-marina');
  });

  it('Accept-Language=en → EN isim + etiket', async () => {
    const res = await request(http)
      .get('/v1/locations/e2e-detail-marina')
      .set('Accept-Language', 'en-US,en;q=0.9')
      .expect(200);
    expect(res.body.name).toBe('D-Marin Gocek');
    expect(res.body.description).toBe('English description');
    expect(res.body.amenities[0].label).toBe('Electricity');
  });

  it('cache başlığı: Cache-Control 300s + Vary Accept-Language', async () => {
    const res = await request(http).get('/v1/locations/e2e-detail-marina').expect(200);
    expect(res.headers['cache-control']).toContain('max-age=300');
    expect(res.headers['vary']).toMatch(/Accept-Language/i);
  });

  it('typeDetails ayrımı: yakıt iskelesi → kind fuelDock', async () => {
    const res = await request(http).get('/v1/locations/e2e-detail-fuel').expect(200);
    expect(res.body.typeDetails.kind).toBe('fuelDock');
    expect(res.body.typeDetails.hasDiesel).toBe(true);
    expect(res.body.typeDetails.minDepthM).toBeCloseTo(3.5, 1);
  });

  it('typeDetails ayrımı: demirleme → kind anchorage (rüzgar koruması)', async () => {
    const res = await request(http).get('/v1/locations/e2e-detail-anchorage').expect(200);
    expect(res.body.typeDetails.kind).toBe('anchorage');
    expect(res.body.typeDetails.holdingType).toBe('sand');
    expect(res.body.typeDetails.protectionN).toBe(4);
    expect(res.body.typeDetails.isFree).toBe(true);
    // Zemin AYNI ZAMANDA üst düzeyde de gelir (istemci tek yerden okur).
    expect(res.body.seabed).toBe('sand');
  });

  it('belediye limanında zemin gelir ama demirleme kartı (isFree) UYDURULMAZ', async () => {
    // Regresyon: zemin bilgisi anchorage_details'e yazılsaydı API bu limanı
    // "Ücretsiz demirleme" gibi gösterirdi (is_free NOT NULL DEFAULT true).
    // 0009_seabed ile zemin locations sütununda durur; typeDetails boş kalır.
    const res = await request(http).get('/v1/locations/e2e-detail-pier-seabed').expect(200);
    expect(res.body.seabed).toBe('mud');
    expect(res.body.typeDetails).toBeNull();
  });

  it('taslak lokasyon → 404', async () => {
    await request(http).get('/v1/locations/e2e-detail-draft').expect(404);
  });

  it('bilinmeyen slug → 404', async () => {
    await request(http).get('/v1/locations/boyle-bir-sey-yok').expect(404);
  });
});

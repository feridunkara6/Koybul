import { screenText, shouldAutoPublish } from '../src/modules/community/domain/prefilter';

const clean = { flags: [], clean: true } as const;

describe('screenText', () => {
  it('normal denizcilik metni temiz geçer', () => {
    const r = screenText('Kuzey ucunda 4 metrede kum, tutuş çok iyi. Gece 18 knotta kaymadık.');
    expect(r.clean).toBe(true);
  });

  it('çok kısa içerik işaretlenir', () => {
    expect(screenText('güzel').flags).toContain('too_short');
  });

  it('birden fazla link işaretlenir, tek link geçer', () => {
    expect(screenText('Bilgi burada https://a.com ve burada https://b.com bakın').flags).toContain(
      'many_links',
    );
    expect(
      screenText('Marina sitesi https://marina.com adresinde, ücretler orada').flags,
    ).not.toContain('many_links');
  });

  it('telefon ve e-posta işaretlenir (KVKK: serbest metinde kişisel veri)', () => {
    expect(screenText('Bize ulasin 0532 111 22 33 numarasindan bilgi alin').flags).toContain(
      'contact_info',
    );
    expect(screenText('Rezervasyon icin kaptan@ornek.com adresine yazabilirsiniz').flags).toContain(
      'contact_info',
    );
  });

  it('bağırma (büyük harf) işaretlenir — Türkçe harfler dahil', () => {
    expect(screenText('BURASI ÇOK KÖTÜ ASLA GİTMEYİN ŞİDDETLE UYARIYORUM').flags).toContain(
      'shouting',
    );
  });

  it('karakter tekrarı işaretlenir', () => {
    expect(screenText('harikaaaaaaaaaa bir koy burasi cok guzel').flags).toContain('repetition');
  });

  it('temiz metinde hiç bayrak yoktur', () => {
    expect(screenText('Sabah 08:00 gibi girdik, sakin bir koy, dip kum.').flags).toEqual(
      clean.flags,
    );
  });
});

describe('shouldAutoPublish', () => {
  const ok = {
    kind: 'status',
    prefilter: screenText('Samandira ucreti 450 TL oldu, nakit istiyorlar'),
    trustScore: 1,
    approvedCount: 3,
  };

  it('yalnız güncel durum notu ve yalnız güvenilir yazar için açılır', () => {
    expect(shouldAutoPublish(ok)).toBe(true);
  });

  it('UYARI notu ASLA otomatik yayınlanmaz (yanlış emniyet bilgisi tehlikeli)', () => {
    expect(shouldAutoPublish({ ...ok, kind: 'hazard' })).toBe(false);
  });

  it('deneyim ve seyir notu otomatik yayınlanmaz', () => {
    expect(shouldAutoPublish({ ...ok, kind: 'experience' })).toBe(false);
    expect(shouldAutoPublish({ ...ok, kind: 'passage' })).toBe(false);
  });

  it('yeni hesap (onaylı katkısı yok) kuyruğa gider', () => {
    expect(shouldAutoPublish({ ...ok, approvedCount: 0 })).toBe(false);
  });

  it('güveni düşmüş kullanıcı kuyruğa gider', () => {
    expect(shouldAutoPublish({ ...ok, trustScore: 0.9 })).toBe(false);
  });

  it('ön filtre bayrak verdiyse kuyruğa gider', () => {
    expect(shouldAutoPublish({ ...ok, prefilter: screenText('BAK 0532 111 22 33 ARA') })).toBe(
      false,
    );
  });
});

import {
  PromotionCheck,
  parseModeratorEmails,
  shouldPromoteToModerator,
} from '../src/modules/auth/domain/moderator-allowlist';

describe('parseModeratorEmails', () => {
  it('boş/eksik değer boş liste verir (varsayılan: kimse yükseltilmez)', () => {
    expect(parseModeratorEmails(undefined)).toEqual([]);
    expect(parseModeratorEmails(null)).toEqual([]);
    expect(parseModeratorEmails('')).toEqual([]);
    expect(parseModeratorEmails('   ')).toEqual([]);
  });

  it('virgül, noktalı virgül, boşluk ve satır sonu ayırıcı sayılır', () => {
    expect(parseModeratorEmails('a@x.com, b@x.com;c@x.com\nd@x.com e@x.com')).toEqual([
      'a@x.com',
      'b@x.com',
      'c@x.com',
      'd@x.com',
      'e@x.com',
    ]);
  });

  it('küçük harfe indirir ve boşlukları kırpar (e-posta büyük/küçük duyarsızdır)', () => {
    expect(parseModeratorEmails('  Feridunkara6@GMAIL.com  ')).toEqual(['feridunkara6@gmail.com']);
  });

  it('tekrarları eler', () => {
    expect(parseModeratorEmails('a@x.com,A@X.COM, a@x.com')).toEqual(['a@x.com']);
  });

  it('e-posta OLMAYAN girdiler atılır — yanlış hesap yükseltilmesin', () => {
    expect(parseModeratorEmails('moderator, a@x.com, @x.com, b@, @, a@b')).toEqual([
      'a@x.com',
      'a@b',
    ]);
  });
});

describe('shouldPromoteToModerator', () => {
  const list = ['kaptan@koybul.com'];

  /** Varsayılan: listedeki adresle DOĞRULANMIŞ Google girişi. */
  function check(over: Partial<PromotionCheck> = {}): boolean {
    return shouldPromoteToModerator({
      email: 'kaptan@koybul.com',
      emailVerified: true,
      provider: 'google.com',
      isGuest: false,
      role: 'user',
      list,
      ...over,
    });
  }

  it('listedeki doğrulanmış kullanıcı yükseltilir', () => {
    expect(check()).toBe(true);
  });

  it('büyük harfli / boşluklu e-posta da eşleşir', () => {
    expect(check({ email: ' Kaptan@Koybul.com ' })).toBe(true);
  });

  it('Apple ile giriş de kabul edilir', () => {
    expect(check({ provider: 'apple.com' })).toBe(true);
  });

  // ---- GÜVENLİK: yükseltmenin kapılarını zorlayan senaryolar --------------

  it('DOĞRULANMAMIŞ e-posta ASLA yükseltilmez (kritik)', () => {
    // Saldırgan, uygulama paketinden çıkardığı Firebase web anahtarıyla
    // kurbanın adresine e-posta+parola hesabı açabilir; Firebase adres
    // sahipliğini denetlemez ve GEÇERLİ bir token üretir. Tek savunma budur.
    expect(check({ emailVerified: false })).toBe(false);
    expect(check({ emailVerified: false, provider: 'password' })).toBe(false);
  });

  it('GÜVENİLMEYEN sağlayıcı yükseltilmez (parola/telefon/özel OIDC)', () => {
    for (const provider of ['password', 'phone', 'custom', 'oidc.acme', 'anonymous', 'unknown']) {
      expect(check({ provider })).toBe(false);
    }
  });

  it('liste boşsa HİÇBİR hesap yükseltilmez', () => {
    expect(check({ list: [] })).toBe(false);
  });

  it('listede olmayan e-posta yükseltilmez', () => {
    expect(check({ email: 'baskasi@koybul.com' })).toBe(false);
  });

  it('e-posta yoksa (telefon/anonim giriş) yükseltme yapılmaz', () => {
    expect(check({ email: null })).toBe(false);
    expect(check({ email: undefined })).toBe(false);
    expect(check({ email: '' })).toBe(false);
    expect(check({ email: '   ' })).toBe(false);
  });

  it('MİSAFİR hesap yükseltilmez', () => {
    expect(check({ isGuest: true })).toBe(false);
  });

  it('zaten moderatörse tekrar yazılmaz', () => {
    expect(check({ role: 'moderator' })).toBe(false);
  });

  it('ADMIN ve SUPER_ADMIN dokunulmaz — bu liste düşürme aracı değildir', () => {
    for (const role of ['admin', 'super_admin'] as const) {
      expect(check({ role })).toBe(false);
    }
  });
});

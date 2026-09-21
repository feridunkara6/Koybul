import { PremiumSubscriptionService } from '../src/modules/premium/application/premium-subscription.service';
import { EXPLORATION_MONTHLY_LIMIT } from '../src/modules/premium/application/premium-access.service';
import {
  AppleSubscriptionGateway,
  AppleSubscriptionState,
} from '../src/modules/premium/domain/apple.types';
import { decodeJwsPayload } from '../src/modules/premium/domain/jws';
import { PremiumRepository } from '../src/modules/premium/domain/premium.repository';
import { Principal } from '../src/core/auth/principal';

const NOW = new Date('2026-09-21T12:00:00.000Z');
const FUTURE = new Date('2027-09-21T12:00:00.000Z');
const PAST = new Date('2026-01-01T00:00:00.000Z');

function member(userId = 'u1'): Principal {
  return { userId, role: 'user', isGuest: false, familyId: 'f', jti: 'j' };
}

/** base64url JWS üçlüsü üretir (imza sahte — decodeJwsPayload imza bakmaz). */
function fakeJws(payload: Record<string, unknown>): string {
  const b64 = (o: Record<string, unknown>): string =>
    Buffer.from(JSON.stringify(o)).toString('base64url');
  return `${b64({ alg: 'ES256' })}.${b64(payload)}.imza`;
}

class FakeRepo implements PremiumRepository {
  subs = new Map<string, { premiumUntil: Date | null; productId: string | null; otid: string }>();
  unlockCount = 0;

  findPremiumUntil(userId: string): Promise<Date | null> {
    return Promise.resolve(this.subs.get(userId)?.premiumUntil ?? null);
  }
  findSubscription(
    userId: string,
  ): Promise<{ premiumUntil: Date | null; productId: string | null }> {
    const s = this.subs.get(userId);
    return Promise.resolve({
      premiumUntil: s?.premiumUntil ?? null,
      productId: s?.productId ?? null,
    });
  }
  countUnlocks(): Promise<number> {
    return Promise.resolve(this.unlockCount);
  }
  hasUnlock(): Promise<boolean> {
    return Promise.resolve(false);
  }
  createUnlock(): Promise<'created'> {
    return Promise.resolve('created');
  }
  findUserIdByOriginalTransactionId(otid: string): Promise<string | null> {
    for (const [userId, s] of this.subs) if (s.otid === otid) return Promise.resolve(userId);
    return Promise.resolve(null);
  }
  saveSubscription(
    userId: string,
    state: { premiumUntil: Date | null; productId: string | null; originalTransactionId: string },
  ): Promise<void> {
    this.subs.set(userId, {
      premiumUntil: state.premiumUntil,
      productId: state.productId,
      otid: state.originalTransactionId,
    });
    return Promise.resolve();
  }
}

function gateway(
  states: Record<string, AppleSubscriptionState>,
  configured = true,
): AppleSubscriptionGateway {
  return {
    configured,
    fetchState: (otid: string) => Promise.resolve(states[otid] ?? null),
  };
}

function activeState(otid: string): AppleSubscriptionState {
  return {
    originalTransactionId: otid,
    productId: 'koybul.premium.yillik',
    entitled: true,
    appleStatus: 1,
    expiresAt: FUTURE,
  };
}

describe('decodeJwsPayload (P2 güvenlik modeli)', () => {
  it('geçerli üçlüde gövdeyi çözer; imza DOĞRULAMAZ (bilinçli — yorumdaki model)', () => {
    expect(decodeJwsPayload(fakeJws({ a: 1 }))).toEqual({ a: 1 });
  });
  it('bozuk girdilerde null döner (parça sayısı, base64, JSON, dizi)', () => {
    expect(decodeJwsPayload('tek-parca')).toBeNull();
    expect(decodeJwsPayload('a.%%%.b')).toBeNull();
    expect(decodeJwsPayload(`x.${Buffer.from('[1]').toString('base64url')}.y`)).toBeNull();
  });
});

describe('PremiumSubscriptionService (P2)', () => {
  it('me: abonelik + keşif hakkı durumunu döner', async () => {
    const repo = new FakeRepo();
    repo.subs.set('u1', { premiumUntil: FUTURE, productId: 'koybul.premium.yillik', otid: 't1' });
    repo.unlockCount = 1;
    const svc = new PremiumSubscriptionService(repo, gateway({}));

    const me = await svc.me(member(), NOW);
    expect(me.premium).toEqual({
      active: true,
      until: FUTURE.toISOString(),
      productId: 'koybul.premium.yillik',
    });
    expect(me.exploration).toEqual({
      remaining: EXPLORATION_MONTHLY_LIMIT - 1,
      limit: EXPLORATION_MONTHLY_LIMIT,
      monthKey: '2026-09',
    });
  });

  it('me: süresi geçmiş abonelik active=false ama until korunur (eski abone izi)', async () => {
    const repo = new FakeRepo();
    repo.subs.set('u1', { premiumUntil: PAST, productId: 'koybul.premium.aylik', otid: 't1' });
    const me = await new PremiumSubscriptionService(repo, gateway({})).me(member(), NOW);
    expect(me.premium.active).toBe(false);
    expect(me.premium.until).toBe(PAST.toISOString());
  });

  it('link: Apple doğrular, hesaba yazar, gerçek durumu döner', async () => {
    const repo = new FakeRepo();
    const svc = new PremiumSubscriptionService(repo, gateway({ t1: activeState('t1') }));
    const r = await svc.link(member(), 't1');
    expect(r).toEqual({
      active: true,
      until: FUTURE.toISOString(),
      productId: 'koybul.premium.yillik',
    });
    expect(repo.subs.get('u1')?.otid).toBe('t1');
  });

  it("link: Apple'ın tanımadığı işlem 422; yapılandırma yoksa 503", async () => {
    const svc = new PremiumSubscriptionService(new FakeRepo(), gateway({}));
    await expect(svc.link(member(), 'yok')).rejects.toMatchObject({
      problemType: 'validation-error',
    });

    const off = new PremiumSubscriptionService(new FakeRepo(), gateway({}, false));
    await expect(off.link(member(), 't1')).rejects.toMatchObject({
      problemType: 'service-unavailable',
    });
  });

  it('link: abonelik BAŞKA hesaba bağlıysa 409; aynı hesaba tekrar bağlama serbest', async () => {
    const repo = new FakeRepo();
    const svc = new PremiumSubscriptionService(repo, gateway({ t1: activeState('t1') }));
    await svc.link(member('u1'), 't1');

    await expect(svc.link(member('u2'), 't1')).rejects.toMatchObject({
      problemType: 'conflict-state',
    });
    await expect(svc.link(member('u1'), 't1')).resolves.toMatchObject({ active: true });
  });

  it('link: bitmiş abonelik bağlanır ama premium VERMEZ (dürüst geri yükleme)', async () => {
    const expired: AppleSubscriptionState = {
      originalTransactionId: 't9',
      productId: 'koybul.premium.aylik',
      entitled: false,
      appleStatus: 2,
      expiresAt: PAST,
    };
    const repo = new FakeRepo();
    const r = await new PremiumSubscriptionService(repo, gateway({ t9: expired })).link(
      member(),
      't9',
    );
    expect(r.active).toBe(false);
    expect(repo.subs.get('u1')?.premiumUntil).toEqual(PAST);
  });

  it('bildirim: bağlı kullanıcıyı Apple gerçeğiyle günceller (gövdeye güvenmez)', async () => {
    const repo = new FakeRepo();
    repo.subs.set('u1', { premiumUntil: FUTURE, productId: 'koybul.premium.yillik', otid: 't1' });
    // Apple'ın güncel gerçeği: iade edildi (status 5, bitiş geçmişte).
    const revoked: AppleSubscriptionState = {
      originalTransactionId: 't1',
      productId: 'koybul.premium.yillik',
      entitled: false,
      appleStatus: 5,
      expiresAt: PAST,
    };
    const svc = new PremiumSubscriptionService(repo, gateway({ t1: revoked }));

    const body = {
      signedPayload: fakeJws({
        notificationType: 'REFUND',
        data: { signedTransactionInfo: fakeJws({ originalTransactionId: 't1' }) },
      }),
    };
    expect(await svc.handleNotification(body)).toBe('updated');
    expect(repo.subs.get('u1')?.premiumUntil).toEqual(PAST);
  });

  it('bildirim: bağlı olmayan işlem, bozuk gövde ve kapalı yapılandırma SESSİZCE geçilir', async () => {
    const svc = new PremiumSubscriptionService(new FakeRepo(), gateway({ t1: activeState('t1') }));
    // Hiçbir hesaba bağlı değil → ignored (link bekler).
    expect(
      await svc.handleNotification({
        signedPayload: fakeJws({
          data: { signedTransactionInfo: fakeJws({ originalTransactionId: 't1' }) },
        }),
      }),
    ).toBe('ignored');
    expect(await svc.handleNotification({ signedPayload: 'çöp' })).toBe('ignored');
    expect(await svc.handleNotification({ baskaAlan: 1 })).toBe('ignored');
    expect(await svc.handleNotification('metin')).toBe('ignored');

    const off = new PremiumSubscriptionService(new FakeRepo(), gateway({}, false));
    expect(await off.handleNotification({ signedPayload: 'x' })).toBe('ignored');
  });
});

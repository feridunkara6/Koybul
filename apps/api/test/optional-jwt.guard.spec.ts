import { ExecutionContext } from '@nestjs/common';
import { OptionalJwtAuthGuard } from '../src/common/guards/optional-jwt.guard';
import { AuthedRequest } from '../src/common/guards/jwt-auth.guard';
import { TokenSigner } from '../src/infrastructure/jwt/token.signer';
import { JtiBlacklistService } from '../src/infrastructure/redis/jti-blacklist.service';
import { AppProblem } from '../src/common/problem/problem';
import { Principal } from '../src/core/auth/principal';

const PRINCIPAL: Principal = {
  userId: 'u1',
  role: 'user',
  isGuest: false,
  familyId: 'f',
  jti: 'j1',
};

function contextWith(authorization?: string): { ctx: ExecutionContext; req: AuthedRequest } {
  const req = {
    header: (name: string) => (name === 'authorization' ? authorization : undefined),
  } as unknown as AuthedRequest;
  const ctx = {
    switchToHttp: () => ({ getRequest: () => req }),
  } as unknown as ExecutionContext;
  return { ctx, req };
}

function signerStub(behavior: 'ok' | 'fail'): TokenSigner {
  return {
    verifyAccess: (token: string) => {
      if (behavior === 'fail' || token !== 'valid') {
        return Promise.reject(new AppProblem('invalid-token'));
      }
      return Promise.resolve(PRINCIPAL);
    },
  } as unknown as TokenSigner;
}

function blacklistStub(blocked: boolean): JtiBlacklistService {
  return { isBlocked: () => Promise.resolve(blocked) } as unknown as JtiBlacklistService;
}

describe('OptionalJwtAuthGuard (P1 — detay ucu isteğe bağlı kimlik)', () => {
  it('Authorization YOKSA anonim geçer, principal atanmaz', async () => {
    const guard = new OptionalJwtAuthGuard(signerStub('fail'), blacklistStub(false));
    const { ctx, req } = contextWith(undefined);
    expect(await guard.canActivate(ctx)).toBe(true);
    expect(req.principal).toBeUndefined();
  });

  it('Bearer olmayan başlık da anonim sayılır (ör. Basic)', async () => {
    const guard = new OptionalJwtAuthGuard(signerStub('fail'), blacklistStub(false));
    const { ctx, req } = contextWith('Basic abc');
    expect(await guard.canActivate(ctx)).toBe(true);
    expect(req.principal).toBeUndefined();
  });

  it('geçerli Bearer: principal isteğe iliştirilir', async () => {
    const guard = new OptionalJwtAuthGuard(signerStub('ok'), blacklistStub(false));
    const { ctx, req } = contextWith('Bearer valid');
    expect(await guard.canActivate(ctx)).toBe(true);
    expect(req.principal).toEqual(PRINCIPAL);
  });

  it('BOZUK Bearer sessizce anonim SAYILMAZ — 401 fırlar (hata gizlenmez)', async () => {
    const guard = new OptionalJwtAuthGuard(signerStub('fail'), blacklistStub(false));
    const { ctx } = contextWith('Bearer corrupt');
    await expect(guard.canActivate(ctx)).rejects.toMatchObject({ problemType: 'invalid-token' });
  });

  it('karalisteli jti 401 fırlatır (oturum kapatılmış)', async () => {
    const guard = new OptionalJwtAuthGuard(signerStub('ok'), blacklistStub(true));
    const { ctx } = contextWith('Bearer valid');
    await expect(guard.canActivate(ctx)).rejects.toMatchObject({ problemType: 'invalid-token' });
  });
});

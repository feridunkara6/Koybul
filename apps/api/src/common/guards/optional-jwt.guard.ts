import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { TokenSigner } from '../../infrastructure/jwt/token.signer';
import { JtiBlacklistService } from '../../infrastructure/redis/jti-blacklist.service';
import { AppProblem } from '../problem/problem';
import { AuthedRequest } from './jwt-auth.guard';

/**
 * İSTEĞE BAĞLI kimlik (P1, premium v3 raporu §9): koy detayı ANONİME de açıktır
 * (vitrin), ama Authorization gelirse kim olduğunu bilmek isteriz (premium/keşif
 * hakkı kararı). JwtAuthGuard'dan farkı: başlık YOKSA istek anonim geçer.
 * Başlık VARSA aynen doğrulanır — bozuk/karalisteli token yine 401'dir; sessizce
 * anonim saymak, süresi geçmiş oturumlu kullanıcıya "premium'un bitti" yerine
 * kilitli ekran gösterir ve hatayı gizlerdi.
 */
@Injectable()
export class OptionalJwtAuthGuard implements CanActivate {
  constructor(
    private readonly signer: TokenSigner,
    private readonly blacklist: JtiBlacklistService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<AuthedRequest>();
    const header = req.header('authorization');
    if (!header?.startsWith('Bearer ')) return true; // anonim — vitrin yolu

    const principal = await this.signer.verifyAccess(header.slice('Bearer '.length));
    if (await this.blacklist.isBlocked(principal.jti)) {
      throw new AppProblem('invalid-token', 'Oturum kapatıldı.');
    }
    req.principal = principal;
    return true;
  }
}

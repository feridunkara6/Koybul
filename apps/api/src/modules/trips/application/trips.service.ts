import { Inject, Injectable } from '@nestjs/common';
import { uuidv7 } from 'uuidv7';
import { AppProblem } from '../../../common/problem/problem';
import { Principal } from '../../../core/auth/principal';
import {
  ShareTripInput,
  TRIP_DAILY_LIMIT,
  TRIPS_REPOSITORY,
  TripsRepository,
} from '../domain/trip.types';

/**
 * SEYİR PAYLAŞIMI iş kuralları (SP-3b, kurucu onayı 2026-10-31).
 *
 * - Paylaşım/tepki HESAP ister (misafir etkileşemez — kurucu kuralı);
 *   ücretsiz üyeye açıktır (premium kuralları 2026-10-31: tepki serbest).
 * - Serbest metin taşınmaz → moderasyonsuz; günlük tavan spam frenidir.
 * - "Pruvan neta" aç/kapat — kendi seyrine de verilebilir (zararsız;
 *   rota kaydetme kararıyla aynı sadelik).
 */
@Injectable()
export class TripsService {
  constructor(@Inject(TRIPS_REPOSITORY) private readonly repo: TripsRepository) {}

  async share(
    principal: Principal,
    input: ShareTripInput,
    now: Date = new Date(),
  ): Promise<{ id: string }> {
    const used = await this.repo.sharedToday(principal.userId, now);
    if (used >= TRIP_DAILY_LIMIT) {
      throw new AppProblem(
        'validation-error',
        `Bir günde en fazla ${TRIP_DAILY_LIMIT} seyir paylaşılabilir.`,
        [{ field: '(root)', code: 'daily_limit', message: 'Günlük tavan doldu' }],
      );
    }
    const id = uuidv7();
    await this.repo.share(id, principal.userId, input);
    return { id };
  }

  /** Sahibin paylaşımı kaldırması — anında yayından iner (gizlilik sözü). */
  async remove(principal: Principal, tripId: string): Promise<void> {
    const ok = await this.repo.remove(tripId, principal.userId);
    if (!ok) throw new AppProblem('not-found');
  }

  /** "Pruvan neta" aç/kapat — silinmiş paylaşımda 404 (varlık sızdırılmaz). */
  async togglePruva(
    principal: Principal,
    tripId: string,
  ): Promise<{ reacted: boolean; pruvaCount: number }> {
    if (!(await this.repo.exists(tripId))) throw new AppProblem('not-found');
    return this.repo.togglePruva(tripId, principal.userId);
  }
}

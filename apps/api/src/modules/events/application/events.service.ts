import { Inject, Injectable } from '@nestjs/common';
import { AppProblem } from '../../../common/problem/problem';
import { EnvService } from '../../../config/env.service';
import { Principal, roleAtLeast } from '../../../core/auth/principal';
import { PremiumAccessService } from '../../premium/application/premium-access.service';
import {
  DealRow,
  DealView,
  EventAudience,
  EventParticipant,
  EventRow,
  EventView,
  EVENTS_REPOSITORY,
  EventsRepository,
  UpsertDealInput,
  UpsertEventInput,
} from '../domain/events.types';

/**
 * Etkinlik/fırsat iş kuralları (V1 — kurucu onayı 2026-10-23).
 *
 * KİTLE KİLİDİ: 'members' kilidi her zaman geçerli (hesap teşviki);
 * 'premium' kilidi PREMIUM_ENFORCE bayrağına bağlı (vitrinle aynı ilke) ve
 * admin+ her zaman geçer. Kilitli fırsat kodu istemciye HİÇ İNMEZ.
 *
 * KAYIT: kontenjan/işlemsel kilit depodadır; burada yalnız kitle ve durum
 * kuralları konuşur. İptal bildirimi V1'de uygulama içi durumla görünür
 * (push altyapısı yok — dürüst sınır, konsept raporunda yazıldığı gibi).
 */
@Injectable()
export class EventsService {
  constructor(
    private readonly env: EnvService,
    private readonly premium: PremiumAccessService,
    @Inject(EVENTS_REPOSITORY) private readonly repo: EventsRepository,
  ) {}

  private async audienceAllows(
    audience: EventAudience,
    principal: Principal | null,
    now: Date,
  ): Promise<boolean> {
    if (audience === 'all') return true;
    if (principal === null || principal.isGuest) return false;
    if (audience === 'members') return true;
    // premium kitlesi:
    if (!this.env.premiumEnforce) return true;
    if (roleAtLeast(principal.role, 'admin')) return true;
    return this.premium.isPremium(principal.userId, now);
  }

  private async toDealView(
    row: DealRow,
    principal: Principal | null,
    now: Date,
  ): Promise<DealView> {
    const allowed = await this.audienceAllows(row.audience as EventAudience, principal, now);
    const expired = row.validUntil !== null && row.validUntil.getTime() <= now.getTime();
    const locked = !allowed && row.code !== null;
    return {
      id: row.id,
      title: row.title,
      partner: row.partner,
      benefit: row.benefit,
      // Kilitli ya da süresi geçmiş kod istemciye inmez (kopyalanamaz).
      code: allowed && !expired ? row.code : null,
      locked,
      audience: row.audience as EventAudience,
      validUntil: row.validUntil?.toISOString() ?? null,
      terms: row.terms,
      place: row.place,
      expired,
    };
  }

  private toEventView(row: EventRow): EventView {
    return {
      id: row.id,
      title: row.title,
      body: row.body,
      startsAt: row.startsAt.toISOString(),
      endsAt: row.endsAt?.toISOString() ?? null,
      locationText: row.locationText,
      venueLocationId: row.venueLocationId,
      quota: row.quota,
      registeredCount: row.registeredCount,
      remaining: Math.max(0, row.quota - row.registeredCount),
      registrationDeadline: row.registrationDeadline?.toISOString() ?? null,
      priceNote: row.priceNote,
      conditions: row.conditions,
      organizer: row.organizer,
      audience: row.audience as EventAudience,
      status: row.status as EventView['status'],
      registered: row.registeredByViewer,
      full: row.registeredCount >= row.quota,
    };
  }

  async deals(principal: Principal | null, now: Date = new Date()): Promise<DealView[]> {
    const rows = await this.repo.activeDeals();
    return Promise.all(rows.map((r) => this.toDealView(r, principal, now)));
  }

  async events(principal: Principal | null, now: Date = new Date()): Promise<EventView[]> {
    const rows = await this.repo.upcomingEvents(principal?.userId ?? null, now);
    return rows.map((r) => this.toEventView(r));
  }

  async event(principal: Principal | null, eventId: string): Promise<EventView> {
    const row = await this.repo.findEvent(eventId, principal?.userId ?? null);
    if (row === null) throw new AppProblem('not-found');
    return this.toEventView(row);
  }

  /** Kayıt — kitle kuralı burada, kontenjan kilidi depoda. */
  async register(
    principal: Principal,
    eventId: string,
    now: Date = new Date(),
  ): Promise<{ registered: boolean; remaining: number }> {
    const row = await this.repo.findEvent(eventId, principal.userId);
    if (row === null) throw new AppProblem('not-found');
    if (!(await this.audienceAllows(row.audience as EventAudience, principal, now))) {
      throw new AppProblem('premium-required', 'Bu etkinlik Koybul Premium üyelerine özel.');
    }

    const outcome = await this.repo.register(eventId, principal.userId, now);
    switch (outcome.result) {
      case 'registered':
      case 'already':
        return { registered: true, remaining: outcome.remaining };
      case 'quota':
        throw new AppProblem(
          'quota-exceeded',
          'Kontenjan doldu. İptal eden olursa yer açılır — bir süre sonra tekrar bakabilirsin.',
        );
      case 'not-open':
        throw new AppProblem(
          'validation-error',
          'Bu etkinliğe kayıt şu an kapalı (süresi geçti ya da etkinlik iptal edildi).',
        );
    }
  }

  async cancel(principal: Principal, eventId: string): Promise<void> {
    const ok = await this.repo.cancelRegistration(eventId, principal.userId);
    if (!ok) throw new AppProblem('not-found');
  }

  // --- Yönetici işlemleri (RolesGuard admin+ arkasında; panelden çağrılır) ---

  async adminCreateDeal(input: UpsertDealInput): Promise<{ id: string }> {
    return { id: await this.repo.createDeal(input) };
  }

  async adminUpdateDeal(dealId: string, patch: Partial<UpsertDealInput>): Promise<void> {
    if (!(await this.repo.updateDeal(dealId, patch))) throw new AppProblem('not-found');
  }

  async adminCreateEvent(input: UpsertEventInput): Promise<{ id: string }> {
    return { id: await this.repo.createEvent(input) };
  }

  async adminUpdateEvent(
    eventId: string,
    patch: Partial<UpsertEventInput> & { status?: 'published' | 'cancelled' },
  ): Promise<void> {
    if (!(await this.repo.updateEvent(eventId, patch))) throw new AppProblem('not-found');
  }

  /** Katılımcı listesi (ad + e-posta) — yalnız panelde, organizasyon amaçlı. */
  async adminParticipants(eventId: string): Promise<EventParticipant[]> {
    const row = await this.repo.findEvent(eventId, null);
    if (row === null) throw new AppProblem('not-found');
    return this.repo.participants(eventId);
  }
}

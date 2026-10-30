import { Inject, Injectable } from '@nestjs/common';
import { uuidv7 } from 'uuidv7';
import { AppProblem, FieldError } from '../../../common/problem/problem';
import { Principal } from '../../../core/auth/principal';
import { BOAT_REPOSITORY, BoatRepository, LookupIds } from '../domain/boat.repository';
import {
  Boat,
  CreateBoatInput,
  FavoriteBoatRef,
  PublicBoatCard,
  UpdateBoatInput,
} from '../domain/boat.types';

/** Hesap başına aktif tekne tavanı — kötüye kullanım freni (docs/29 SEC-14 ruhu). */
const MAX_BOATS_PER_OWNER = 25;

/** Kişi başına favori tavanı — kötüye kullanım freni (takip tavanıyla aynı ruh). */
const MAX_FAVORITES_PER_USER = 200;

@Injectable()
export class BoatsService {
  constructor(@Inject(BOAT_REPOSITORY) private readonly boats: BoatRepository) {}

  async list(principal: Principal): Promise<Boat[]> {
    return this.boats.listByOwner(principal.userId);
  }

  async getOne(principal: Principal, boatId: string): Promise<Boat> {
    const boat = await this.boats.findOwned(principal.userId, boatId);
    if (!boat) throw new AppProblem('not-found');
    return boat;
  }

  /**
   * TEKNE KARTI (Hafta 2): kimlik istemez. Görünür olmayan, silinmiş ya da
   * sahibi pasif tekne ile bilinmeyen kimlik AYNI 404'ü alır — kart yalnız
   * sahibinin rızasıyla vardır, rıza kapanınca anında kaybolur.
   */
  async publicCard(boatId: string): Promise<PublicBoatCard> {
    const card = await this.boats.publicCard(boatId);
    if (!card) throw new AppProblem('not-found');
    return card;
  }

  /**
   * FAVORİLE (TK-5, 0025): ücretsiz üyelik yeter (guard katmanı), sessiz —
   * sahibine bildirim gitmez. Görünmez/silinmiş/kendi teknesi → kartla aynı
   * 404 (varlık sızdırmaz). Tekrar favorileme idempotenttir.
   */
  async favorite(principal: Principal, boatId: string): Promise<void> {
    const count = await this.boats.countFavoritesByUser(principal.userId);
    if (count >= MAX_FAVORITES_PER_USER) {
      throw new AppProblem(
        'conflict-state',
        `En fazla ${MAX_FAVORITES_PER_USER} tekne favorilenebilir.`,
      );
    }
    const ok = await this.boats.addFavorite(principal.userId, boatId);
    if (!ok) throw new AppProblem('not-found');
  }

  /** Favoriden çıkarma idempotenttir — olmayan kayıt sessizce geçer (204). */
  async unfavorite(principal: Principal, boatId: string): Promise<void> {
    await this.boats.removeFavorite(principal.userId, boatId);
  }

  async listFavorites(principal: Principal): Promise<FavoriteBoatRef[]> {
    return this.boats.listFavorites(principal.userId);
  }

  async create(principal: Principal, input: CreateBoatInput): Promise<Boat> {
    const count = await this.boats.countActiveByOwner(principal.userId);
    if (count >= MAX_BOATS_PER_OWNER) {
      throw new AppProblem('conflict-state', `En fazla ${MAX_BOATS_PER_OWNER} tekne eklenebilir.`);
    }
    const ids = await this.resolveOrThrow({
      boatTypeCode: input.boatTypeCode,
      engineTypeCode: input.engineTypeCode,
      flagCountryCode: input.flagCountryCode,
    });
    return this.boats.create(uuidv7(), principal.userId, input, ids);
  }

  async update(principal: Principal, boatId: string, patch: UpdateBoatInput): Promise<Boat> {
    // Sahiplik + varlık: yoksa 404 (başka sahibin teknesi de 404 — sızdırmaz).
    await this.getOne(principal, boatId);
    const ids = await this.resolveOrThrow({
      boatTypeCode: patch.boatTypeCode,
      engineTypeCode: patch.engineTypeCode,
      flagCountryCode: patch.flagCountryCode,
    });
    return this.boats.update(principal.userId, boatId, patch, ids);
  }

  async remove(principal: Principal, boatId: string): Promise<void> {
    await this.getOne(principal, boatId);
    await this.boats.softDelete(principal.userId, boatId, principal.userId);
    // Birincil tekne silindiyse en yeni aktif tekne birincil olur (UX süreklilik).
    await this.boats.promoteNewPrimaryIfNeeded(principal.userId);
  }

  /**
   * Lookup kodlarını id'ye çevirir; geçersiz kod → 422 alan hatası (istemci düzeltebilir).
   * patch senaryosunda dokunulmayan alanlar undefined kalır (repo değiştirmez).
   */
  private async resolveOrThrow(input: {
    boatTypeCode?: string;
    engineTypeCode?: string | null;
    flagCountryCode?: string | null;
  }): Promise<LookupIds> {
    const res = await this.boats.resolveLookups(input);
    const errors: FieldError[] = [];
    if (input.boatTypeCode !== undefined && res.boatTypeId === null) {
      errors.push({ field: 'boatTypeCode', code: 'invalid_code', message: 'Geçersiz tekne tipi' });
    }
    if (input.engineTypeCode != null && res.engineTypeId === null) {
      errors.push({
        field: 'engineTypeCode',
        code: 'invalid_code',
        message: 'Geçersiz motor tipi',
      });
    }
    if (input.flagCountryCode != null && !res.countryValid) {
      errors.push({
        field: 'flagCountryCode',
        code: 'invalid_code',
        message: 'Geçersiz ülke kodu',
      });
    }
    if (errors.length > 0) {
      throw new AppProblem('validation-error', 'Geçersiz referans kodu.', errors);
    }
    return {
      boatTypeId: res.boatTypeId ?? undefined,
      engineTypeId: input.engineTypeCode === undefined ? undefined : res.engineTypeId,
    };
  }
}

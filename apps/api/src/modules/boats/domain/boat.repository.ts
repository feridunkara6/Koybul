import {
  Boat,
  CreateBoatInput,
  FavoriteBoatRef,
  PublicBoatCard,
  UpdateBoatInput,
} from './boat.types';

/** Lookup kod→id çözümü sonucu (geçersiz kod erken 422'ye map'lenir). */
export interface LookupResolution {
  boatTypeId: number | null;
  engineTypeId: number | null;
  countryValid: boolean;
}

export interface BoatRepository {
  listByOwner(ownerUserId: string): Promise<Boat[]>;
  /** Sahiplik dahil tekil okuma — başka sahibin teknesi için null (404 → sızdırmaz). */
  findOwned(ownerUserId: string, boatId: string): Promise<Boat | null>;
  countActiveByOwner(ownerUserId: string): Promise<number>;
  /** Kod→id çözümü (boat_type zorunlu, engine_type/country opsiyonel). */
  resolveLookups(input: {
    boatTypeCode?: string;
    engineTypeCode?: string | null;
    flagCountryCode?: string | null;
  }): Promise<LookupResolution>;
  /** Yeni tekne — birincil devri (varsa) ile TEK transaction (docs/22 boats partial unique). */
  create(id: string, ownerUserId: string, input: CreateBoatInput, ids: LookupIds): Promise<Boat>;
  update(
    ownerUserId: string,
    boatId: string,
    patch: UpdateBoatInput,
    ids: LookupIds,
  ): Promise<Boat>;
  softDelete(ownerUserId: string, boatId: string, actorUserId: string): Promise<void>;
  /** Silinen birincil teknenin yerine en yeni aktif tekneyi birincil yapar. */
  promoteNewPrimaryIfNeeded(ownerUserId: string): Promise<void>;
  /**
   * TEKNE KARTI (Hafta 2): yalnız visibleInMarina açık ve sahibi aktif
   * teknede döner; teknik alanlar shareSpecs'e göre null'lanır.
   */
  publicCard(boatId: string): Promise<PublicBoatCard | null>;
  /**
   * FAVORİLE (TK-5, 0025). Tekne görünür değilse favorilenemez (kart
   * yoksa kalp de yok) — o durumda false döner, servis 404 üretir.
   */
  addFavorite(userId: string, boatId: string): Promise<boolean>;
  removeFavorite(userId: string, boatId: string): Promise<void>;
  countFavoritesByUser(userId: string): Promise<number>;
  /** Kişinin favori listesi — yalnız HÂLÂ görünür tekneler iner (rıza ilkesi). */
  listFavorites(userId: string): Promise<FavoriteBoatRef[]>;
}

/** Çözülmüş lookup id'leri (undefined = patch'te dokunulmadı). */
export interface LookupIds {
  boatTypeId?: number;
  engineTypeId?: number | null;
}

export const BOAT_REPOSITORY = Symbol('BOAT_REPOSITORY');

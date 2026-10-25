/** Tekne DTO'su (docs/23 §10 #7). Ölçüler metrik + birim son eki (docs/22 §1.8). */
export interface Boat {
  id: string;
  name: string;
  boatTypeCode: string;
  brand: string | null;
  model: string | null;
  buildYear: number | null;
  lengthM: number;
  beamM: number | null;
  draftM: number | null;
  engineTypeCode: string | null;
  flagCountryCode: string | null;
  registrationNo: string | null;
  isPrimary: boolean;
  createdAt: string;
}

/** POST /v1/boats girdisi — zorunlu alanlar + lookup kodları. */
export interface CreateBoatInput {
  name: string;
  boatTypeCode: string;
  lengthM: number;
  brand?: string | null;
  model?: string | null;
  buildYear?: number | null;
  beamM?: number | null;
  draftM?: number | null;
  engineTypeCode?: string | null;
  flagCountryCode?: string | null;
  registrationNo?: string | null;
  /** İlk tekne otomatik birincil olur; açıkça true verilirse mevcut birincil devredilir. */
  isPrimary?: boolean;
}

/** PATCH — tüm alanlar opsiyonel; kimlik/sahiplik alanları YOK (SEC beyaz listesi). */
export type UpdateBoatInput = Partial<CreateBoatInput>;

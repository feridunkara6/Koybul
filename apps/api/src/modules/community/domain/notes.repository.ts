import { CreateNoteInput, Note, NoteKind, NoteReaction, UpdateNoteInput } from './note.types';

export interface NoteListFilters {
  kind?: NoteKind;
  limit: number;
}

export interface NearbyNoteQuery {
  lat: number;
  lon: number;
  radiusNm: number;
  sinceHours: number;
  limit: number;
}

/** Yakındaki not — listede mesafe de gösterilir. */
export interface NearbyNote extends Note {
  distanceNm: number;
  locationName: string | null;
}

export interface NoteOwnership {
  userId: string;
  kind: NoteKind;
  status: 'pending' | 'approved' | 'rejected';
}

export interface ReactionResult {
  /** Tepki gerçekten yazıldı mı (aynı tepki tekrarında false). */
  created: boolean;
  helpfulCount: number;
  confirmCount: number;
  disputeCount: number;
  /** Çelişki eşiği aşıldıysa not yeniden incelemeye alındı. */
  movedToReview: boolean;
  /** Notun sahibi — puan yazımı için (kendi notuna oy verilemez). */
  ownerUserId: string;
}

export interface NotesRepository {
  /** Yalnız onaylanmış notlar. Kendi bekleyen içeriği `listForUser` döner. */
  listForLocation(locationId: string, f: NoteListFilters): Promise<Note[]>;
  nearby(q: NearbyNoteQuery): Promise<NearbyNote[]>;
  listForUser(userId: string, status: string | undefined, limit: number): Promise<Note[]>;
  findOwnership(noteId: string): Promise<NoteOwnership | null>;
  /** Hedef noktanın var/yayında olduğunu ve GPS mesafesini doğrular. */
  checkTarget(
    locationId: string,
    position: { lat: number; lon: number } | undefined,
    maxDistanceM: number,
  ): Promise<'ok' | 'too-far' | 'not-found'>;
  /**
   * Notu yazar. `status` servis tarafından belirlenir (otomatik yayın kararı);
   * 'pending' ise aynı işlemde moderasyon görevi de açılır.
   */
  /** Hedef (seyir notunun varış noktası) ve tekne sahipliği geçerli mi. */
  refsValid(
    toLocationId: string | null | undefined,
    boatId: string | null | undefined,
    userId: string,
  ): Promise<boolean>;
  create(
    id: string,
    userId: string,
    input: CreateNoteInput,
    expiresAt: Date | null,
    status: 'pending' | 'approved',
  ): Promise<Note>;
  update(noteId: string, userId: string, patch: UpdateNoteInput): Promise<Note | null>;
  softDelete(noteId: string, userId: string): Promise<boolean>;
  /** Tepkiyi yazar ve sayaçları ALTYAPI YOLUNDAN günceller (ADR-003 notu). */
  react(
    noteId: string,
    userId: string,
    reaction: NoteReaction,
    weight: number,
    disputeThreshold: number,
  ): Promise<ReactionResult | null>;
}

export const NOTES_REPOSITORY = Symbol('NOTES_REPOSITORY');

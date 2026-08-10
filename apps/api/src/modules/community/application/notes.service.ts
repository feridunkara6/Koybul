import { Inject, Injectable } from '@nestjs/common';
import { uuidv7 } from 'uuidv7';
import { AppProblem } from '../../../common/problem/problem';
import { Principal } from '../../../core/auth/principal';
import {
  GPS_REQUIRED_KINDS,
  HAZARD_DISPUTE_THRESHOLD,
  NOTE_MAX_REPORT_DISTANCE_M,
  Note,
  NoteReaction,
  STATUS_NOTE_TTL_HOURS,
  CreateNoteInput,
  UpdateNoteInput,
} from '../domain/note.types';
import {
  NOTES_REPOSITORY,
  NearbyNote,
  NearbyNoteQuery,
  NoteListFilters,
  NotesRepository,
} from '../domain/notes.repository';
import { screenText, shouldAutoPublish } from '../domain/prefilter';
import { notePoints } from '../domain/scoring';
import { ReputationService } from './reputation.service';

@Injectable()
export class NotesService {
  constructor(
    @Inject(NOTES_REPOSITORY) private readonly notes: NotesRepository,
    private readonly reputation: ReputationService,
  ) {}

  listForLocation(locationId: string, filters: NoteListFilters): Promise<Note[]> {
    return this.notes.listForLocation(locationId, filters);
  }

  nearby(q: NearbyNoteQuery): Promise<NearbyNote[]> {
    return this.notes.nearby(q);
  }

  listMine(userId: string, status: string | undefined, limit: number): Promise<Note[]> {
    return this.notes.listForUser(userId, status, limit);
  }

  async create(principal: Principal, input: CreateNoteInput): Promise<Note> {
    const state = await this.reputation.authorState(principal.userId);
    this.reputation.assertCanWrite(state);

    // Taze bilgi tipleri gerçek GPS ister — harita merkezi SAYILMAZ.
    if (GPS_REQUIRED_KINDS.includes(input.kind) && !input.position) {
      throw new AppProblem('validation-error', 'Bu not tipi için konumun gerekiyor.', [
        { field: 'position', code: 'required', message: 'Konum zorunlu' },
      ]);
    }

    const targetId = input.kind === 'passage' ? input.fromLocationId : input.locationId;
    if (!targetId) {
      throw new AppProblem('validation-error', 'Not bir noktaya bağlanmalı.', [
        { field: 'locationId', code: 'required', message: 'Nokta zorunlu' },
      ]);
    }

    const check = await this.notes.checkTarget(
      targetId,
      input.position,
      NOTE_MAX_REPORT_DISTANCE_M,
    );
    if (check === 'not-found') throw new AppProblem('not-found');
    if (check === 'too-far') {
      throw new AppProblem(
        'validation-error',
        'Yanlış bilgiyi önlemek için yalnız yakınında olduğun noktalar için paylaşabilirsin.',
        [{ field: 'position', code: 'too_far', message: 'Noktaya çok uzaksın' }],
      );
    }

    // İstemciden gelen ikincil referanslar: varış noktası yayında mı, tekne
    // gerçekten kullanıcının mı? Doğrulanmazsa FK hatası 500 olarak sızar.
    if (!(await this.notes.refsValid(input.toLocationId, input.boatId, principal.userId))) {
      throw new AppProblem('validation-error', 'Geçersiz nokta ya da tekne referansı.', [
        { field: 'toLocationId', code: 'invalid_ref', message: 'Geçersiz referans' },
      ]);
    }

    const prefilter = screenText(input.body);
    const autoPublish = shouldAutoPublish({
      kind: input.kind,
      prefilter,
      trustScore: state.trustScore,
      approvedCount: state.approvedCount,
    });

    const expiresAt =
      input.kind === 'status' ? new Date(Date.now() + STATUS_NOTE_TTL_HOURS * 3600_000) : null;

    const status = autoPublish ? 'approved' : 'pending';
    const note = await this.notes.create(uuidv7(), principal.userId, input, expiresAt, status);

    // Otomatik yayınlanan not anında puan üretir; kuyruğa gireni moderasyon
    // kararı puanlar (iki kez puanlanmaması için tek yol seçilir).
    if (note.status === 'approved') {
      await this.reputation.award(principal.userId, 'note_approved', notePoints(input.kind), {
        type: 'note',
        id: note.id,
      });
    }
    return note;
  }

  async update(principal: Principal, noteId: string, patch: UpdateNoteInput): Promise<Note> {
    const updated = await this.notes.update(noteId, principal.userId, patch);
    // Sahibi değilse de 404 — varlık sızdırılmaz (mevcut IDOR deseni).
    if (!updated) throw new AppProblem('not-found');
    return updated;
  }

  async remove(principal: Principal, noteId: string): Promise<void> {
    const ok = await this.notes.softDelete(noteId, principal.userId);
    if (!ok) throw new AppProblem('not-found');
  }

  /**
   * Faydalı / doğrulama / çelişki. Kendi notuna oy verilemez (şema PK'sı aynı
   * tepkiyi tekrarlamayı, servis de kendine oyu engeller).
   */
  async react(
    principal: Principal,
    noteId: string,
    reaction: NoteReaction,
  ): Promise<{ helpfulCount: number; confirmCount: number; disputeCount: number }> {
    const owner = await this.notes.findOwnership(noteId);
    if (!owner || owner.status !== 'approved') throw new AppProblem('not-found');
    if (owner.userId === principal.userId) {
      throw new AppProblem('forbidden', 'Kendi notuna oy veremezsin.');
    }

    const state = await this.reputation.authorState(principal.userId);
    this.reputation.assertCanWrite(state);

    const res = await this.notes.react(
      noteId,
      principal.userId,
      reaction,
      state.trustScore,
      HAZARD_DISPUTE_THRESHOLD,
    );
    if (!res) throw new AppProblem('not-found');

    if (res.created) {
      if (reaction === 'helpful') {
        // Puan NOTUN SAHİBİNE yazılır; içerik başına ömür boyu tavan vardır.
        await this.reputation.award(res.ownerUserId, 'helpful_received', 2, {
          type: 'note',
          id: noteId,
        });
      } else if (reaction === 'confirm' && owner.kind === 'hazard') {
        // Uyarı doğrulamak da bir katkıdır — puan OY VERENE yazılır.
        await this.reputation.award(principal.userId, 'hazard_confirmed', 3, {
          type: 'note',
          id: noteId,
        });
      }
    }

    return {
      helpfulCount: res.helpfulCount,
      confirmCount: res.confirmCount,
      disputeCount: res.disputeCount,
    };
  }
}

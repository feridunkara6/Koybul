import { Inject, Injectable } from '@nestjs/common';
import { Principal } from '../../../core/auth/principal';
import {
  FEED_LIMIT,
  FEED_REPOSITORY,
  FeedItem,
  FeedRepository,
  FeedRow,
} from '../domain/feed.types';

/** Varsayılan ad — profil satırı silinmişse bile kart dürüst kalır. */
const DEFAULT_DISPLAY_NAME = 'Koybul Kaptanı';

/**
 * TAKİP AKIŞI (SP-3b): takip edilenlerin yayındaki içeriği, tek listede.
 * Karar katmanı incedir — süzme SQL'de, tip dönüşümü burada.
 */
@Injectable()
export class FeedService {
  constructor(@Inject(FEED_REPOSITORY) private readonly repo: FeedRepository) {}

  async following(principal: Principal): Promise<FeedItem[]> {
    const rows = await this.repo.followingFeed(principal.userId, FEED_LIMIT);
    return rows.map((r) => this.toItem(r));
  }

  private toItem(r: FeedRow): FeedItem {
    return {
      kind: r.kind,
      id: r.id,
      authorId: r.authorId,
      authorName: r.authorName ?? DEFAULT_DISPLAY_NAME,
      levelCode: r.levelCode ?? 'new',
      createdAt: r.createdAt.toISOString(),
      startName: r.startName,
      endName: r.endName,
      distanceNm: r.distanceNm === null ? null : Number(r.distanceNm),
      durationMin: r.durationMin,
      stopCount: r.stopCount,
      sailedOn: r.sailedOn === null ? null : r.sailedOn.toISOString().slice(0, 10),
      pruvaCount: r.pruvaCount,
      myPruva: r.myPruva,
      locationId: r.locationId,
      locationName: r.locationName,
      noteKind: r.noteKind,
      body: r.body,
      routeName: r.routeName,
      saveCount: r.saveCount,
    };
  }
}

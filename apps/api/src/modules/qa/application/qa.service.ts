import { Inject, Injectable, Optional } from '@nestjs/common';
import { uuidv7 } from 'uuidv7';
import { AppProblem } from '../../../common/problem/problem';
import { Principal } from '../../../core/auth/principal';
import { screenText } from '../../community/domain/prefilter';
import { NotificationsService } from '../../notifications/application/notifications.service';
import {
  CreateQuestionInput,
  QaAnswerRow,
  QaAnswerView,
  QaCategory,
  QaDetail,
  QaFeed,
  QaQuestionFull,
  QaQuestionRow,
  QaQuestionSummary,
  QaRepository,
  QA_FEATURED_HOURS,
  QA_FEATURED_MAX,
  QA_PREVIEW_CHARS,
  QA_REPOSITORY,
} from '../domain/qa.types';

/**
 * Soru-cevap iş kuralları (Blog V1 — kurucu onayı 2026-10-23).
 *
 * ERİŞİM (KURUCU REVİZYONU 2026-10-30): liste+önizleme herkese; detay,
 * cevap okuma, soru sorma, cevap yazma ve beğeni ÜCRETSİZ HESAPLA açılır —
 * Premium şartı KALDIRILDI. Misafir yalnız önizleme görür (hesap teşviki);
 * kilit yine SUNUCUDADIR: misafire soru gövdesi ve cevaplar hiç gönderilmez.
 *
 * MODERASYON (karma, kurucu onayı): ilk içerik kuyruğa; onaylı içeriği olan
 * kullanıcı ön-süzgeç temizse anında yayınlanır. ⚑ Bildir her zaman açık.
 *
 * İTİBAR PUANI BİLİNÇLİ YOK (V1): denizci seviyesi koy katkılarına odaklı
 * kalır; soru-cevap puanı enflasyon yaratırdı. İleride ayrıca değerlendirilir.
 */
@Injectable()
export class QaService {
  constructor(
    @Inject(QA_REPOSITORY) private readonly repo: QaRepository,
    /** Push tetikleri (ateşle-unut) — birim testleri vermez, yol atlanır. */
    @Optional() private readonly notifications?: NotificationsService,
  ) {}

  private toSummary(row: QaQuestionRow, now: Date): QaQuestionSummary {
    return {
      id: row.id,
      category: row.category as QaCategory,
      title: row.title,
      preview:
        row.body.length > QA_PREVIEW_CHARS
          ? `${row.body.slice(0, QA_PREVIEW_CHARS).trimEnd()}…`
          : row.body,
      authorId: row.userId,
      authorName: row.authorName ?? 'Koybul Kaptanı',
      authorPremium: row.authorPremium,
      featured: row.featuredUntil !== null && row.featuredUntil.getTime() > now.getTime(),
      likeCount: row.likeCount,
      answersCount: row.answersCount,
      createdAt: row.createdAt.toISOString(),
    };
  }

  private toAnswerView(row: QaAnswerRow, viewerId: string): QaAnswerView {
    return {
      id: row.id,
      body: row.body,
      status: row.status,
      authorId: row.userId,
      authorName: row.authorName ?? 'Koybul Kaptanı',
      authorPremium: row.authorPremium,
      helpfulCount: row.helpfulCount,
      mine: row.userId === viewerId,
      helpedByMe: row.helpedByMe,
      createdAt: row.createdAt.toISOString(),
    };
  }

  /**
   * Ana akış — HERKESE açık; SAYFALI (2026-10-30) + anahtar kelime araması.
   * "Öne çıkan" şeridi yalnız 1. sayfada ve süzgeçsiz/aramasız görünümde.
   */
  async feed(
    category: QaCategory | null,
    search: string | null,
    page: number,
    limit: number,
    now: Date = new Date(),
  ): Promise<QaFeed> {
    const offset = (page - 1) * limit;
    const [featured, items, total] = await Promise.all([
      category === null && search === null && page === 1
        ? this.repo.featured(QA_FEATURED_MAX)
        : Promise.resolve([]),
      this.repo.list(category, search, offset, limit),
      this.repo.count(category, search),
    ]);
    const featuredIds = new Set(featured.map((f) => f.id));
    return {
      featured: featured.map((r) => this.toSummary(r, now)),
      // Şeritte dönen soru akışta İKİNCİ kez gösterilmez.
      items: items.filter((r) => !featuredIds.has(r.id)).map((r) => this.toSummary(r, now)),
      total,
      pageCount: Math.max(1, Math.ceil(total / limit)),
      page,
    };
  }

  /**
   * Detay erişim kararı (KURUCU REVİZYONU 2026-10-30): HESAPLI herkes tam
   * detayı okur — Premium şartı kaldırıldı. Misafir/anonim teaser görür
   * (başlık + önizleme + cevap sayısı; hesap teşviki). Sahibi bekleyen
   * sorusunu da görür ("sorum nerede" paniği yaşatmayız).
   */
  async detail(
    principal: Principal | null,
    questionId: string,
    now: Date = new Date(),
  ): Promise<QaDetail> {
    const q = await this.repo.findQuestion(questionId);
    if (!q || q.status === 'rejected') throw new AppProblem('not-found');

    const mine = principal !== null && principal.userId === q.userId;
    // Yayında olmayan soru yalnız sahibine görünür (varlık sızdırılmaz).
    if (q.status === 'pending' && !mine) throw new AppProblem('not-found');

    const full = mine || (principal !== null && !principal.isGuest);

    if (!full) {
      return {
        access: 'teaser',
        question: this.toSummary(q, now),
        answersCount: q.answersCount,
      };
    }

    const viewerId = principal?.userId ?? '';
    const [answers, likedByMe] = await Promise.all([
      this.repo.answersFor(questionId, principal?.userId ?? null),
      principal !== null ? this.repo.likedBy(questionId, principal.userId) : false,
    ]);
    const question: QaQuestionFull = {
      ...this.toSummary(q, now),
      body: q.body,
      status: q.status,
      mine,
      likedByMe,
    };
    return {
      access: 'full',
      question,
      answers: answers.map((a) => this.toAnswerView(a, viewerId)),
    };
  }

  /** Soru oluşturma — Premium kapısı + karma moderasyon. */
  async createQuestion(
    principal: Principal,
    input: CreateQuestionInput,
    now: Date = new Date(),
  ): Promise<{ id: string; status: string }> {
    const prefilter = screenText(`${input.title}\n${input.body}`);
    const trusted = await this.repo.hasApprovedContent(principal.userId);
    const autoPublish = prefilter.clean && trusted;

    const featuredUntil = autoPublish
      ? new Date(now.getTime() + QA_FEATURED_HOURS * 3600_000)
      : null; // kuyruğa girense şeride ONAY anında alınır (moderasyon deposu).
    const row = await this.repo.createQuestion(
      uuidv7(),
      principal.userId,
      input,
      autoPublish ? 'approved' : 'pending',
      featuredUntil,
    );
    // Kuyruğa girdiyse adminlere haber (push paketi ⑤) — ana işi bekletmez.
    if (row.status === 'pending') this.notifications?.moderationNew('question');
    return { id: row.id, status: row.status };
  }

  /** Cevap yazma — soru yayında olmalı; aynı karma moderasyon. */
  async createAnswer(
    principal: Principal,
    questionId: string,
    body: string,
  ): Promise<{ id: string; status: string }> {
    const q = await this.repo.findQuestion(questionId);
    if (!q || q.status !== 'approved') throw new AppProblem('not-found');

    const prefilter = screenText(body);
    const trusted = await this.repo.hasApprovedContent(principal.userId);
    const autoPublish = prefilter.clean && trusted;

    const row = await this.repo.createAnswer(
      uuidv7(),
      questionId,
      principal.userId,
      body,
      autoPublish ? 'approved' : 'pending',
    );
    // Push paketi ①: anında yayınlanan cevap soru sahibine bildirilir; kuyruğa
    // girense adminlere düşer — sahibine bildirim MODERASYON ONAYINDA gider
    // (moderation.service), yoksa reddedilecek cevap için boşuna heyecan olur.
    if (row.status === 'approved') {
      this.notifications?.qaAnswer(questionId, row.id, principal.userId);
    } else {
      this.notifications?.moderationNew('answer');
    }
    return { id: row.id, status: row.status };
  }

  /** Soru beğenisi (aç/kapa) — kendi sorusuna verilemez. */
  async toggleLike(
    principal: Principal,
    questionId: string,
  ): Promise<{ liked: boolean; likeCount: number }> {
    const q = await this.repo.findQuestion(questionId);
    if (!q || q.status !== 'approved') throw new AppProblem('not-found');
    if (q.userId === principal.userId) {
      throw new AppProblem('forbidden', 'Kendi soruna beğeni veremezsin.');
    }
    return this.repo.toggleLike(questionId, principal.userId);
  }

  /** "Faydalı" işareti (aç/kapa) — kendi cevabına verilemez. */
  async toggleHelpful(
    principal: Principal,
    answerId: string,
  ): Promise<{ helped: boolean; helpfulCount: number }> {
    const meta = await this.repo.findAnswerMeta(answerId);
    if (!meta || meta.status !== 'approved') throw new AppProblem('not-found');
    if (meta.userId === principal.userId) {
      throw new AppProblem('forbidden', 'Kendi cevabını faydalı işaretleyemezsin.');
    }
    return this.repo.toggleHelpful(answerId, principal.userId);
  }

  /**
   * ⚑ Uygunsuz içerik bildirimi — HESAPLI herkes bildirebilir (Premium şartı
   * YOK: zararlı içeriği önizlemeden gören ücretsiz üye de bildirebilmeli;
   * Apple'ın kullanıcı-içeriği beklentisi de bu yönde). İçerik yayında kalır,
   * moderasyon görevi kuyruğa düşer; kararı moderatör verir.
   */
  async report(entity: 'qa_question' | 'qa_answer', entityId: string): Promise<void> {
    const ok = await this.repo.report(entity, entityId);
    if (!ok) throw new AppProblem('not-found');
    this.notifications?.moderationNew('report');
  }
}

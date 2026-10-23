import { Inject, Injectable } from '@nestjs/common';
import { uuidv7 } from 'uuidv7';
import { AppProblem } from '../../../common/problem/problem';
import { EnvService } from '../../../config/env.service';
import { Principal, roleAtLeast } from '../../../core/auth/principal';
import { screenText } from '../../community/domain/prefilter';
import { PremiumAccessService } from '../../premium/application/premium-access.service';
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
 * ERİŞİM (kurucu kararı): liste+önizleme herkese; detay/yazma/beğeni Premium.
 * Kilit SUNUCUDADIR: ücretsiz üyeye soru gövdesi ve cevaplar hiç gönderilmez
 * (koy vitrin kilidiyle aynı ilke). PREMIUM_ENFORCE kapalıyken her şey açık.
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
    private readonly env: EnvService,
    private readonly premium: PremiumAccessService,
    @Inject(QA_REPOSITORY) private readonly repo: QaRepository,
  ) {}

  /** Premium kapısı: bayrak kapalıyken herkes; açıkken admin+ veya premium. */
  private async assertPremium(principal: Principal, now: Date): Promise<void> {
    if (!this.env.premiumEnforce) return;
    if (roleAtLeast(principal.role, 'admin')) return;
    if (await this.premium.isPremium(principal.userId, now)) return;
    throw new AppProblem(
      'premium-required',
      'Soru sormak, cevap yazmak ve cevapları okumak Koybul Premium ile açılır.',
    );
  }

  private toSummary(row: QaQuestionRow, now: Date): QaQuestionSummary {
    return {
      id: row.id,
      category: row.category as QaCategory,
      title: row.title,
      preview:
        row.body.length > QA_PREVIEW_CHARS
          ? `${row.body.slice(0, QA_PREVIEW_CHARS).trimEnd()}…`
          : row.body,
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
      authorName: row.authorName ?? 'Koybul Kaptanı',
      authorPremium: row.authorPremium,
      helpfulCount: row.helpfulCount,
      mine: row.userId === viewerId,
      helpedByMe: row.helpedByMe,
      createdAt: row.createdAt.toISOString(),
    };
  }

  /** Ana akış: "Öne çıkan" şeridi + kronolojik liste — HERKESE açık. */
  async feed(
    category: QaCategory | null,
    before: Date | null,
    limit: number,
    now: Date = new Date(),
  ): Promise<QaFeed> {
    const [featured, items] = await Promise.all([
      // Şerit yalnız ilk sayfada ve süzgeçsiz görünümde anlamlı.
      category === null && before === null
        ? this.repo.featured(QA_FEATURED_MAX)
        : Promise.resolve([]),
      this.repo.list(category, before, limit),
    ]);
    const featuredIds = new Set(featured.map((f) => f.id));
    return {
      featured: featured.map((r) => this.toSummary(r, now)),
      // Şeritte dönen soru akışta İKİNCİ kez gösterilmez.
      items: items.filter((r) => !featuredIds.has(r.id)).map((r) => this.toSummary(r, now)),
    };
  }

  /**
   * Detay erişim kararı (vitrin deseninin soru-cevap hâli):
   * bayrak kapalı → full; admin/premium → full; SAHİBİ → full (beklemede olsa
   * da — "sorum nerede" diye panik yaşatmayız); bu soruda ONAYLI cevabı olan →
   * full (süresi biten premium kendi emeğini okumaya devam eder — kurucu
   * kararı A). Aksi hâlde teaser: başlık + önizleme + cevap SAYISI.
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

    const full =
      !this.env.premiumEnforce ||
      mine ||
      (principal !== null &&
        (roleAtLeast(principal.role, 'admin') ||
          (await this.premium.isPremium(principal.userId, now)) ||
          (await this.repo.hasApprovedAnswerIn(questionId, principal.userId))));

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
    await this.assertPremium(principal, now);

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
    return { id: row.id, status: row.status };
  }

  /** Cevap yazma — soru yayında olmalı; aynı karma moderasyon. */
  async createAnswer(
    principal: Principal,
    questionId: string,
    body: string,
    now: Date = new Date(),
  ): Promise<{ id: string; status: string }> {
    await this.assertPremium(principal, now);

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
    return { id: row.id, status: row.status };
  }

  /** Soru beğenisi (aç/kapa) — kendi sorusuna verilemez. */
  async toggleLike(
    principal: Principal,
    questionId: string,
    now: Date = new Date(),
  ): Promise<{ liked: boolean; likeCount: number }> {
    await this.assertPremium(principal, now);
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
    now: Date = new Date(),
  ): Promise<{ helped: boolean; helpfulCount: number }> {
    await this.assertPremium(principal, now);
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
  }
}

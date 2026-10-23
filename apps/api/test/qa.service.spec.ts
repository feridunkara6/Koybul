import { QaService } from '../src/modules/qa/application/qa.service';
import {
  CreateQuestionInput,
  QaAnswerRow,
  QaCategory,
  QaModerationStatus,
  QaQuestionRow,
  QaRepository,
  QA_PREVIEW_CHARS,
} from '../src/modules/qa/domain/qa.types';
import { PremiumAccessService } from '../src/modules/premium/application/premium-access.service';
import { AppProblem } from '../src/common/problem/problem';
import { EnvService } from '../src/config/env.service';
import { Principal } from '../src/core/auth/principal';

const NOW = new Date('2026-10-23T12:00:00.000Z');

function env(premiumEnforce: boolean): EnvService {
  return { premiumEnforce } as unknown as EnvService;
}

function premiumSvc(premiumIds: string[]): PremiumAccessService {
  return {
    isPremium: (userId: string) => Promise.resolve(premiumIds.includes(userId)),
  } as unknown as PremiumAccessService;
}

function member(userId = 'u-free'): Principal {
  return { userId, role: 'user', isGuest: false, familyId: 'f', jti: 'j' };
}
function admin(userId = 'u-admin'): Principal {
  return { userId, role: 'admin', isGuest: false, familyId: 'f', jti: 'j' };
}

function q(partial: Partial<QaQuestionRow>): QaQuestionRow {
  return {
    id: 'q1',
    userId: 'author-1',
    category: 'demirleme',
    title: 'Poyrazda Boynuz Koyu demirlemesi nasıl olmalı?',
    body: 'B'.repeat(200),
    status: 'approved',
    featuredUntil: null,
    likeCount: 2,
    answersCount: 1,
    createdAt: new Date('2026-10-22T09:00:00Z'),
    authorName: 'Kaptan M.',
    authorPremium: true,
    ...partial,
  };
}

function a(partial: Partial<QaAnswerRow>): QaAnswerRow {
  return {
    id: 'a1',
    questionId: 'q1',
    userId: 'answerer-1',
    body: 'Kuzey yaka nefes alır; kıçtan karaya güney cebi.',
    status: 'approved',
    helpfulCount: 3,
    createdAt: new Date('2026-10-22T10:00:00Z'),
    authorName: 'Kaptan H.',
    authorPremium: false,
    helpedByMe: false,
    ...partial,
  };
}

/** Bellek-içi sahte depo — gerçek depoyla aynı sözleşme. */
class FakeQaRepo implements QaRepository {
  questions: QaQuestionRow[] = [];
  answers: QaAnswerRow[] = [];
  approvedAuthors = new Set<string>();
  approvedAnswerPairs = new Set<string>(); // `${questionId}|${userId}`
  likedPairs = new Set<string>();
  reported: string[] = [];
  createdQuestions: { status: QaModerationStatus; featuredUntil: Date | null }[] = [];
  createdAnswers: { status: QaModerationStatus }[] = [];

  list(category: QaCategory | null): Promise<QaQuestionRow[]> {
    const rows = this.questions.filter(
      (r) => r.status === 'approved' && (category === null || r.category === category),
    );
    return Promise.resolve(rows);
  }
  featured(limit: number): Promise<QaQuestionRow[]> {
    return Promise.resolve(
      this.questions
        .filter((r) => r.featuredUntil !== null && r.featuredUntil > NOW)
        .slice(0, limit),
    );
  }
  findQuestion(id: string): Promise<QaQuestionRow | null> {
    return Promise.resolve(this.questions.find((r) => r.id === id) ?? null);
  }
  answersFor(questionId: string, viewer: string | null): Promise<QaAnswerRow[]> {
    return Promise.resolve(
      this.answers.filter(
        (r) =>
          r.questionId === questionId &&
          (r.status === 'approved' || (r.status === 'pending' && r.userId === viewer)),
      ),
    );
  }
  likedBy(questionId: string, viewer: string): Promise<boolean> {
    return Promise.resolve(this.likedPairs.has(`${questionId}|${viewer}`));
  }
  hasApprovedContent(userId: string): Promise<boolean> {
    return Promise.resolve(this.approvedAuthors.has(userId));
  }
  hasApprovedAnswerIn(questionId: string, userId: string): Promise<boolean> {
    return Promise.resolve(this.approvedAnswerPairs.has(`${questionId}|${userId}`));
  }
  createQuestion(
    id: string,
    userId: string,
    input: CreateQuestionInput,
    status: QaModerationStatus,
    featuredUntil: Date | null,
  ): Promise<QaQuestionRow> {
    this.createdQuestions.push({ status, featuredUntil });
    const row = q({ id, userId, ...input, status, featuredUntil });
    this.questions.push(row);
    return Promise.resolve(row);
  }
  createAnswer(
    id: string,
    questionId: string,
    userId: string,
    body: string,
    status: QaModerationStatus,
  ): Promise<QaAnswerRow> {
    this.createdAnswers.push({ status });
    const row = a({ id, questionId, userId, body, status });
    this.answers.push(row);
    return Promise.resolve(row);
  }
  toggleLike(questionId: string, userId: string): Promise<{ liked: boolean; likeCount: number }> {
    const key = `${questionId}|${userId}`;
    const liked = !this.likedPairs.has(key);
    if (liked) this.likedPairs.add(key);
    else this.likedPairs.delete(key);
    return Promise.resolve({ liked, likeCount: liked ? 3 : 2 });
  }
  toggleHelpful(): Promise<{ helped: boolean; helpfulCount: number }> {
    return Promise.resolve({ helped: true, helpfulCount: 4 });
  }
  findAnswerMeta(
    answerId: string,
  ): Promise<{ userId: string; status: QaModerationStatus; questionId: string } | null> {
    const row = this.answers.find((r) => r.id === answerId);
    return Promise.resolve(
      row ? { userId: row.userId, status: row.status, questionId: row.questionId } : null,
    );
  }
  report(entity: 'qa_question' | 'qa_answer', entityId: string): Promise<boolean> {
    const exists =
      entity === 'qa_question'
        ? this.questions.some((r) => r.id === entityId)
        : this.answers.some((r) => r.id === entityId);
    if (exists) this.reported.push(`${entity}:${entityId}`);
    return Promise.resolve(exists);
  }
}

function makeSvc(opts: { enforce: boolean; premiumIds?: string[]; repo?: FakeQaRepo }): {
  svc: QaService;
  repo: FakeQaRepo;
} {
  const repo = opts.repo ?? new FakeQaRepo();
  return { svc: new QaService(env(opts.enforce), premiumSvc(opts.premiumIds ?? []), repo), repo };
}

const VALID_INPUT: CreateQuestionInput = {
  category: 'demirleme',
  title: 'Poyrazda hangi yakaya demir atmalı?',
  body: 'Hafta sonu Boynuz Koyu planı var; poyraz 15-20 kn görünüyor, tek demir mi kıçtan kara mı?',
};

describe('QaService (Blog V1 — kurucu onayı 2026-10-23)', () => {
  it('akış: önizleme kesilir (… eklenir), öne çıkan akışta tekrarlanmaz', async () => {
    const { svc, repo } = makeSvc({ enforce: true });
    const featured = q({
      id: 'q-feat',
      featuredUntil: new Date(NOW.getTime() + 3600_000),
      body: 'X'.repeat(QA_PREVIEW_CHARS + 50),
    });
    repo.questions.push(featured, q({ id: 'q-old', body: 'kısa gövde ama otuz karakteri geçen' }));

    const feed = await svc.feed(null, null, 20, NOW);
    expect(feed.featured.map((f) => f.id)).toEqual(['q-feat']);
    expect(feed.items.map((i) => i.id)).toEqual(['q-old']); // tekrar yok
    expect(feed.featured[0].preview.endsWith('…')).toBe(true);
    expect(feed.featured[0].preview.length).toBeLessThanOrEqual(QA_PREVIEW_CHARS + 1);
    expect(feed.featured[0].featured).toBe(true);
    // Gövde liste yanıtında YOKTUR (vitrin ilkesi — alan hiç tanımlı değil).
    expect('body' in feed.featured[0]).toBe(false);
  });

  it('akış: kategori süzgeci varken öne çıkan şeridi boş döner', async () => {
    const { svc, repo } = makeSvc({ enforce: true });
    repo.questions.push(q({ id: 'q-feat', featuredUntil: new Date(NOW.getTime() + 3600_000) }));
    const feed = await svc.feed('demirleme', null, 20, NOW);
    expect(feed.featured).toEqual([]);
    expect(feed.items.map((i) => i.id)).toEqual(['q-feat']);
  });

  it('detay: bayrak KAPALIYKEN herkes full görür (bugünkü davranış ilkesi)', async () => {
    const { svc, repo } = makeSvc({ enforce: false });
    repo.questions.push(q({}));
    repo.answers.push(a({}));
    const d = await svc.detail(null, 'q1', NOW);
    expect(d.access).toBe('full');
    if (d.access === 'full') expect(d.answers).toHaveLength(1);
  });

  it('detay: ücretsiz üye vitrin görür — gövde ve cevaplar İNMEZ', async () => {
    const { svc, repo } = makeSvc({ enforce: true });
    repo.questions.push(q({ answersCount: 7 }));
    repo.answers.push(a({}));
    const d = await svc.detail(member(), 'q1', NOW);
    expect(d.access).toBe('teaser');
    if (d.access === 'teaser') {
      expect(d.answersCount).toBe(7);
      expect('body' in d.question).toBe(false);
      expect('answers' in d).toBe(false);
    }
  });

  it('detay: premium üye full görür; beğeni/benim işaretleri doğru', async () => {
    const { svc, repo } = makeSvc({ enforce: true, premiumIds: ['u-prem'] });
    repo.questions.push(q({}));
    repo.answers.push(
      a({ userId: 'u-prem' }),
      a({ id: 'a2', status: 'pending', userId: 'u-prem' }),
    );
    repo.likedPairs.add('q1|u-prem');

    const d = await svc.detail(member('u-prem'), 'q1', NOW);
    expect(d.access).toBe('full');
    if (d.access === 'full') {
      expect(d.question.likedByMe).toBe(true);
      expect(d.question.body).toBe('B'.repeat(200));
      expect(d.answers).toHaveLength(2); // kendi bekleyen cevabı da görünür
      expect(d.answers.every((x) => x.mine)).toBe(true);
    }
  });

  it('detay: SAHİBİ premium olmasa da kendi sorusunu (beklemede bile) görür', async () => {
    const { svc, repo } = makeSvc({ enforce: true });
    repo.questions.push(q({ userId: 'u-free', status: 'pending' }));
    const d = await svc.detail(member('u-free'), 'q1', NOW);
    expect(d.access).toBe('full');
  });

  it('detay: beklemedeki soru başkasına 404 (varlık sızdırılmaz); reddedilen herkese 404', async () => {
    const { svc, repo } = makeSvc({ enforce: true, premiumIds: ['u-prem'] });
    repo.questions.push(q({ status: 'pending' }), q({ id: 'q-rej', status: 'rejected' }));
    await expect(svc.detail(member('u-prem'), 'q1', NOW)).rejects.toMatchObject({
      problemType: 'not-found',
    });
    await expect(svc.detail(member('author-1'), 'q-rej', NOW)).rejects.toMatchObject({
      problemType: 'not-found',
    });
  });

  it('detay: bu soruda ONAYLI cevabı olan, premium bitse de full görür (karar A)', async () => {
    const { svc, repo } = makeSvc({ enforce: true });
    repo.questions.push(q({}));
    repo.approvedAnswerPairs.add('q1|u-eski');
    const d = await svc.detail(member('u-eski'), 'q1', NOW);
    expect(d.access).toBe('full');
  });

  it('soru oluşturma: bayrak açıkken ücretsiz üyeye premium-required', async () => {
    const { svc } = makeSvc({ enforce: true });
    await expect(svc.createQuestion(member(), VALID_INPUT, NOW)).rejects.toMatchObject({
      problemType: 'premium-required',
    });
  });

  it('soru oluşturma (KARMA): ilk içerik kuyruğa, onaylı geçmişi olan anında yayına', async () => {
    const { svc, repo } = makeSvc({ enforce: true, premiumIds: ['u-prem'] });

    const first = await svc.createQuestion(member('u-prem'), VALID_INPUT, NOW);
    expect(first.status).toBe('pending'); // ilk içerik — kuyruk
    expect(repo.createdQuestions[0].featuredUntil).toBeNull();

    repo.approvedAuthors.add('u-prem'); // moderatör onayladı varsayımı
    const second = await svc.createQuestion(member('u-prem'), VALID_INPUT, NOW);
    expect(second.status).toBe('approved');
    expect(repo.createdQuestions[1].featuredUntil?.toISOString()).toBe(
      new Date(NOW.getTime() + 24 * 3600_000).toISOString(), // 24 saat öne çıkan
    );
  });

  it('soru oluşturma: güvenilir yazar bile ön-süzgece takılırsa kuyruğa düşer', async () => {
    const { svc, repo } = makeSvc({ enforce: true, premiumIds: ['u-prem'] });
    repo.approvedAuthors.add('u-prem');
    const res = await svc.createQuestion(
      member('u-prem'),
      { ...VALID_INPUT, body: `Bana ulaşın: kaptan@ornek.com — ${'d'.repeat(40)}` },
      NOW,
    );
    expect(res.status).toBe('pending'); // contact_info bayrağı
  });

  it('soru oluşturma: yönetici premium satın almadan yazar (yönetici=premium kuralı)', async () => {
    const { svc } = makeSvc({ enforce: true });
    const res = await svc.createQuestion(admin(), VALID_INPUT, NOW);
    expect(res.status).toBe('pending'); // yine karma kurala tabi — kestirme yok
  });

  it('cevap: yayında olmayan soruya yazılamaz (404)', async () => {
    const { svc, repo } = makeSvc({ enforce: true, premiumIds: ['u-prem'] });
    repo.questions.push(q({ status: 'pending' }));
    await expect(
      svc.createAnswer(member('u-prem'), 'q1', 'Gayet makul bir cevap metni.', NOW),
    ).rejects.toMatchObject({ problemType: 'not-found' });
  });

  it('cevap (KARMA): onaylı geçmişi olan temiz cevap anında yayınlanır', async () => {
    const { svc, repo } = makeSvc({ enforce: true, premiumIds: ['u-prem'] });
    repo.questions.push(q({}));
    repo.approvedAuthors.add('u-prem');
    const res = await svc.createAnswer(
      member('u-prem'),
      'q1',
      'Kuzey yakada tek demir yeter; 20 kn üstünde kaloma 5:1 bırak.',
      NOW,
    );
    expect(res.status).toBe('approved');
  });

  it('beğeni: kendi soruna veremezsin; başkasınınkine aç/kapa çalışır', async () => {
    const { svc, repo } = makeSvc({ enforce: true, premiumIds: ['author-1', 'u-prem'] });
    repo.questions.push(q({}));
    await expect(svc.toggleLike(member('author-1'), 'q1', NOW)).rejects.toMatchObject({
      problemType: 'forbidden',
    });
    const r = await svc.toggleLike(member('u-prem'), 'q1', NOW);
    expect(r).toEqual({ liked: true, likeCount: 3 });
  });

  it('faydalı: kendi cevabına veremezsin; olmayan cevaba 404', async () => {
    const { svc, repo } = makeSvc({ enforce: true, premiumIds: ['answerer-1', 'u-prem'] });
    repo.questions.push(q({}));
    repo.answers.push(a({}));
    await expect(svc.toggleHelpful(member('answerer-1'), 'a1', NOW)).rejects.toMatchObject({
      problemType: 'forbidden',
    });
    await expect(svc.toggleHelpful(member('u-prem'), 'a-yok', NOW)).rejects.toMatchObject({
      problemType: 'not-found',
    });
    const r = await svc.toggleHelpful(member('u-prem'), 'a1', NOW);
    expect(r).toEqual({ helped: true, helpfulCount: 4 });
  });

  it('⚑ bildir: premium ŞARTI YOK, içerik kuyruğa düşer; olmayan içerik 404', async () => {
    const { svc, repo } = makeSvc({ enforce: true });
    repo.questions.push(q({}));
    await svc.report('qa_question', 'q1');
    expect(repo.reported).toEqual(['qa_question:q1']);
    await expect(svc.report('qa_answer', 'a-yok')).rejects.toBeInstanceOf(AppProblem);
  });
});

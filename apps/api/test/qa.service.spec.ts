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
import { AppProblem } from '../src/common/problem/problem';
import { Principal } from '../src/core/auth/principal';

const NOW = new Date('2026-10-23T12:00:00.000Z');

function member(userId = 'u-free'): Principal {
  return { userId, role: 'user', isGuest: false, familyId: 'f', jti: 'j' };
}
function guest(): Principal {
  return { userId: 'g-1', role: 'user', isGuest: true, familyId: 'f', jti: 'j' };
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

/** Bellek-içi sahte depo — gerçek depoyla aynı sözleşme (arama + sayfalı). */
class FakeQaRepo implements QaRepository {
  questions: QaQuestionRow[] = [];
  answers: QaAnswerRow[] = [];
  approvedAuthors = new Set<string>();
  approvedAnswerPairs = new Set<string>(); // `${questionId}|${userId}`
  likedPairs = new Set<string>();
  reported: string[] = [];
  createdQuestions: { status: QaModerationStatus; featuredUntil: Date | null }[] = [];
  createdAnswers: { status: QaModerationStatus }[] = [];

  private filtered(category: QaCategory | null, search: string | null): QaQuestionRow[] {
    const needle = search?.toLowerCase() ?? null;
    return this.questions.filter(
      (r) =>
        r.status === 'approved' &&
        (category === null || r.category === category) &&
        (needle === null ||
          r.title.toLowerCase().includes(needle) ||
          r.body.toLowerCase().includes(needle)),
    );
  }

  list(
    category: QaCategory | null,
    search: string | null,
    offset: number,
    limit: number,
  ): Promise<QaQuestionRow[]> {
    return Promise.resolve(this.filtered(category, search).slice(offset, offset + limit));
  }
  count(category: QaCategory | null, search: string | null): Promise<number> {
    return Promise.resolve(this.filtered(category, search).length);
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

function makeSvc(repo: FakeQaRepo = new FakeQaRepo()): { svc: QaService; repo: FakeQaRepo } {
  return { svc: new QaService(repo), repo };
}

const VALID_INPUT: CreateQuestionInput = {
  category: 'demirleme',
  title: 'Poyrazda hangi yakaya demir atmalı?',
  body: 'Hafta sonu Boynuz Koyu planı var; poyraz 15-20 kn görünüyor, tek demir mi kıçtan kara mı?',
};

describe('QaService (Blog V1; erişim revizyonu 2026-10-30)', () => {
  it('akış: önizleme kesilir (… eklenir), öne çıkan akışta tekrarlanmaz', async () => {
    const { svc, repo } = makeSvc();
    const featured = q({
      id: 'q-feat',
      featuredUntil: new Date(NOW.getTime() + 3600_000),
      body: 'X'.repeat(QA_PREVIEW_CHARS + 50),
    });
    repo.questions.push(featured, q({ id: 'q-old', body: 'kısa gövde ama otuz karakteri geçen' }));

    const feed = await svc.feed(null, null, 1, 20, NOW);
    expect(feed.featured.map((f) => f.id)).toEqual(['q-feat']);
    expect(feed.items.map((i) => i.id)).toEqual(['q-old']); // tekrar yok
    expect(feed.featured[0].preview.endsWith('…')).toBe(true);
    expect(feed.featured[0].preview.length).toBeLessThanOrEqual(QA_PREVIEW_CHARS + 1);
    expect(feed.featured[0].featured).toBe(true);
    // Gövde liste yanıtında YOKTUR (vitrin ilkesi — alan hiç tanımlı değil).
    expect('body' in feed.featured[0]).toBe(false);
    expect(feed.total).toBe(2);
    expect(feed.pageCount).toBe(1);
  });

  it('akış: kategori süzgeci varken öne çıkan şeridi boş döner', async () => {
    const { svc, repo } = makeSvc();
    repo.questions.push(q({ id: 'q-feat', featuredUntil: new Date(NOW.getTime() + 3600_000) }));
    const feed = await svc.feed('demirleme', null, 1, 20, NOW);
    expect(feed.featured).toEqual([]);
    expect(feed.items.map((i) => i.id)).toEqual(['q-feat']);
  });

  it('ARAMA (2026-10-30): anahtar kelime başlık/gövdede eşleşir; şerit kapalı', async () => {
    const { svc, repo } = makeSvc();
    repo.questions.push(
      q({ id: 'q-demir', title: 'Tonoz demiri nasıl atılır?', body: 'uzun gövde '.repeat(5) }),
      q({ id: 'q-yelken', title: 'Flok seçimi', body: 'Cenova mı flok mu, rüzgâra göre' }),
      q({ id: 'q-feat', featuredUntil: new Date(NOW.getTime() + 3600_000) }),
    );
    const feed = await svc.feed(null, 'tonoz', 1, 10, NOW);
    expect(feed.items.map((i) => i.id)).toEqual(['q-demir']);
    expect(feed.featured).toEqual([]); // aramada şerit çizilmez
    expect(feed.total).toBe(1);
  });

  it('SAYFALAMA (2026-10-30): toplam/sayfa sayısı doğru; 2. sayfa doğru dilim', async () => {
    const { svc, repo } = makeSvc();
    for (let i = 0; i < 13; i++) {
      repo.questions.push(q({ id: `q-${i}`, title: `Soru ${i} — yeterince uzun başlık` }));
    }
    const p1 = await svc.feed('demirleme', null, 1, 10, NOW);
    expect(p1.items).toHaveLength(10);
    expect(p1.total).toBe(13);
    expect(p1.pageCount).toBe(2);
    expect(p1.page).toBe(1);
    const p2 = await svc.feed('demirleme', null, 2, 10, NOW);
    expect(p2.items).toHaveLength(3);
    expect(p2.page).toBe(2);
  });

  it('detay: MİSAFİR/anonim teaser görür — gövde ve cevaplar İNMEZ', async () => {
    const { svc, repo } = makeSvc();
    repo.questions.push(q({ answersCount: 7 }));
    repo.answers.push(a({}));
    for (const viewer of [null, guest()]) {
      const d = await svc.detail(viewer, 'q1', NOW);
      expect(d.access).toBe('teaser');
      if (d.access === 'teaser') {
        expect(d.answersCount).toBe(7);
        expect('body' in d.question).toBe(false);
        expect('answers' in d).toBe(false);
      }
    }
  });

  it('detay (REVİZYON 2026-10-30): ÜCRETSİZ üye full görür — Premium şartı yok', async () => {
    const { svc, repo } = makeSvc();
    repo.questions.push(q({}));
    repo.answers.push(a({}), a({ id: 'a2', status: 'pending', userId: 'u-free' }));
    repo.likedPairs.add('q1|u-free');

    const d = await svc.detail(member(), 'q1', NOW);
    expect(d.access).toBe('full');
    if (d.access === 'full') {
      expect(d.question.likedByMe).toBe(true);
      expect(d.question.body).toBe('B'.repeat(200));
      expect(d.answers).toHaveLength(2); // kendi bekleyen cevabı da görünür
    }
  });

  it('detay: SAHİBİ kendi bekleyen sorusunu görür; başkasına 404; reddedilen herkese 404', async () => {
    const { svc, repo } = makeSvc();
    repo.questions.push(
      q({ userId: 'u-free', status: 'pending' }),
      q({ id: 'q-rej', status: 'rejected' }),
    );
    expect((await svc.detail(member('u-free'), 'q1', NOW)).access).toBe('full');
    await expect(svc.detail(member('u-baska'), 'q1', NOW)).rejects.toMatchObject({
      problemType: 'not-found',
    });
    await expect(svc.detail(member('author-1'), 'q-rej', NOW)).rejects.toMatchObject({
      problemType: 'not-found',
    });
  });

  it('soru oluşturma (REVİZYON): ücretsiz üye sorabilir; KARMA moderasyon işler', async () => {
    const { svc, repo } = makeSvc();

    const first = await svc.createQuestion(member(), VALID_INPUT, NOW);
    expect(first.status).toBe('pending'); // ilk içerik — kuyruk
    expect(repo.createdQuestions[0].featuredUntil).toBeNull();

    repo.approvedAuthors.add('u-free'); // moderatör onayladı varsayımı
    const second = await svc.createQuestion(member(), VALID_INPUT, NOW);
    expect(second.status).toBe('approved');
    expect(repo.createdQuestions[1].featuredUntil?.toISOString()).toBe(
      new Date(NOW.getTime() + 24 * 3600_000).toISOString(), // 24 saat öne çıkan
    );
  });

  it('soru oluşturma: güvenilir yazar bile ön-süzgece takılırsa kuyruğa düşer', async () => {
    const { svc, repo } = makeSvc();
    repo.approvedAuthors.add('u-free');
    const res = await svc.createQuestion(
      member(),
      { ...VALID_INPUT, body: `Bana ulaşın: kaptan@ornek.com — ${'d'.repeat(40)}` },
      NOW,
    );
    expect(res.status).toBe('pending'); // contact_info bayrağı
  });

  it('cevap: yayında olmayan soruya yazılamaz (404); ücretsiz üye yazabilir', async () => {
    const { svc, repo } = makeSvc();
    repo.questions.push(q({ id: 'q-pend', status: 'pending' }), q({}));
    await expect(
      svc.createAnswer(member(), 'q-pend', 'Gayet makul bir cevap metni.'),
    ).rejects.toMatchObject({ problemType: 'not-found' });

    repo.approvedAuthors.add('u-free');
    const res = await svc.createAnswer(
      member(),
      'q1',
      'Kuzey yakada tek demir yeter; 20 kn üstünde kaloma 5:1 bırak.',
    );
    expect(res.status).toBe('approved');
  });

  it('beğeni/faydalı (REVİZYON): ücretsiz üye verebilir; kendi içeriğine veremez', async () => {
    const { svc, repo } = makeSvc();
    repo.questions.push(q({}));
    repo.answers.push(a({}));
    await expect(svc.toggleLike(member('author-1'), 'q1')).rejects.toMatchObject({
      problemType: 'forbidden',
    });
    expect(await svc.toggleLike(member(), 'q1')).toEqual({ liked: true, likeCount: 3 });

    await expect(svc.toggleHelpful(member('answerer-1'), 'a1')).rejects.toMatchObject({
      problemType: 'forbidden',
    });
    await expect(svc.toggleHelpful(member(), 'a-yok')).rejects.toMatchObject({
      problemType: 'not-found',
    });
    expect(await svc.toggleHelpful(member(), 'a1')).toEqual({
      helped: true,
      helpfulCount: 4,
    });
  });

  it('⚑ bildir: hesaplı herkes bildirebilir, içerik kuyruğa düşer; olmayan 404', async () => {
    const { svc, repo } = makeSvc();
    repo.questions.push(q({}));
    await svc.report('qa_question', 'q1');
    expect(repo.reported).toEqual(['qa_question:q1']);
    await expect(svc.report('qa_answer', 'a-yok')).rejects.toBeInstanceOf(AppProblem);
  });
});

import { Prisma } from '@prisma/client';
import { PrismaQaRepository } from '../src/modules/qa/persistence/prisma-qa.repository';
import { PrismaModerationRepository } from '../src/modules/community/persistence/prisma-moderation.repository';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';

/**
 * Ham SQL depoları, SAHTE Prisma ile satır-eşleme sözleşmesi üzerinden test
 * edilir (gerçek DB davranışı CI'daki migrate+seed+spatial/RLS paketlerinde).
 * Amaç: SQL şablonlarının kurulabilmesi, dönen satırların tiplere doğru
 * eşlenmesi ve sayaç/karar dallarının doğru SQL'i seçmesi.
 */

type RawHandler = (sqlText: string) => unknown[];

function fakePrisma(handler: RawHandler, execResult = 1): PrismaService {
  const impl = {
    $queryRaw: (sql: Prisma.Sql) => Promise.resolve(handler(sql.sql ?? String(sql))),
    $executeRaw: () => Promise.resolve(execResult),
    $transaction: async <T>(work: (tx: unknown) => Promise<T>): Promise<T> => work(impl),
  };
  return impl as unknown as PrismaService;
}

const QUESTION_ROW = {
  id: 'q1',
  userId: 'u1',
  category: 'demirleme',
  title: 'Poyrazda hangi yakaya demir atmalı sorusu',
  body: 'Yeterince uzun bir soru gövdesi — otuz karakteri geçiyor.',
  status: 'approved',
  featuredUntil: new Date('2026-10-24T00:00:00Z'),
  likeCount: 2,
  answersCount: 1,
  createdAt: new Date('2026-10-22T09:00:00Z'),
  authorName: 'Kaptan M.',
  authorPremium: true,
};

const ANSWER_ROW = {
  id: 'a1',
  questionId: 'q1',
  userId: 'u2',
  body: 'Kuzey yaka nefes alır.',
  status: 'approved',
  helpfulCount: 3,
  createdAt: new Date('2026-10-22T10:00:00Z'),
  authorName: 'Kaptan H.',
  authorPremium: false,
  helpedByMe: true,
};

describe('PrismaQaRepository (satır eşleme sözleşmesi)', () => {
  it('list/featured/findQuestion satırları tiplere eşler', async () => {
    const repo = new PrismaQaRepository(fakePrisma(() => [QUESTION_ROW]));
    const [row] = await repo.list('demirleme', 'demir', 0, 20);
    expect(row.status).toBe('approved');
    expect(row.likeCount).toBe(2);
    expect(row.authorPremium).toBe(true);

    const feat = await repo.featured(3);
    expect(feat[0].featuredUntil?.toISOString()).toBe('2026-10-24T00:00:00.000Z');

    expect(await repo.findQuestion('q1')).not.toBeNull();
    const empty = new PrismaQaRepository(fakePrisma(() => []));
    expect(await empty.findQuestion('q-yok')).toBeNull();
  });

  it('answersFor/likedBy/has* sorguları eşlenir', async () => {
    const repo = new PrismaQaRepository(
      fakePrisma((sql) => {
        if (sql.includes('FROM qa_answers a')) return [ANSWER_ROW];
        if (sql.includes('AS liked')) return [{ liked: true }];
        return [{ ok: true }];
      }),
    );
    const answers = await repo.answersFor('q1', 'u9');
    expect(answers[0].helpedByMe).toBe(true);
    expect(await repo.likedBy('q1', 'u9')).toBe(true);
    expect(await repo.hasApprovedContent('u9')).toBe(true);
    expect(await repo.hasApprovedAnswerIn('q1', 'u9')).toBe(true);
  });

  it('createQuestion/createAnswer dönen satırı eşler', async () => {
    const repo = new PrismaQaRepository(
      fakePrisma((sql) => (sql.includes('INSERT INTO qa_answers') ? [ANSWER_ROW] : [QUESTION_ROW])),
    );
    const created = await repo.createQuestion(
      'q1',
      'u1',
      { category: 'demirleme', title: QUESTION_ROW.title, body: QUESTION_ROW.body },
      'approved',
      new Date(),
    );
    expect(created.id).toBe('q1');
    const ans = await repo.createAnswer('a1', 'q1', 'u2', ANSWER_ROW.body, 'pending');
    expect(ans.questionId).toBe('q1');
    expect(ans.helpedByMe).toBe(true); // satırdan ne gelirse o (burada sahte true)
  });

  it('toggleLike/toggleHelpful sayaç sonuçlarını döndürür', async () => {
    const repo = new PrismaQaRepository(
      fakePrisma((sql) =>
        sql.includes('qa_answer_helpfuls')
          ? [{ helped: false, helpfulCount: 2 }]
          : [{ liked: true, likeCount: 5 }],
      ),
    );
    expect(await repo.toggleLike('q1', 'u9')).toEqual({ liked: true, likeCount: 5 });
    expect(await repo.toggleHelpful('a1', 'u9')).toEqual({ helped: false, helpfulCount: 2 });
  });

  it('findAnswerMeta null/dolu; report var→true, yok→false', async () => {
    const repo = new PrismaQaRepository(
      fakePrisma(() => [{ userId: 'u2', status: 'approved', questionId: 'q1' }]),
    );
    expect(await repo.findAnswerMeta('a1')).toEqual({
      userId: 'u2',
      status: 'approved',
      questionId: 'q1',
    });
    expect(await repo.report('qa_question', 'q1')).toBe(true);

    const empty = new PrismaQaRepository(fakePrisma(() => [], 0));
    expect(await empty.findAnswerMeta('a-yok')).toBeNull();
    expect(await empty.report('qa_answer', 'a-yok')).toBe(false);
  });
});

describe('PrismaModerationRepository — soru-cevap karar dalları', () => {
  function decideRepo(rows: {
    claimed: { entityType: string; entityId: string }[];
    updated: unknown[];
  }): { repo: PrismaModerationRepository; execCount: () => number } {
    let execs = 0;
    const impl = {
      $queryRaw: (sql: Prisma.Sql) => {
        const text = sql.sql ?? String(sql);
        if (text.includes('UPDATE moderation_tasks')) return Promise.resolve(rows.claimed);
        return Promise.resolve(rows.updated);
      },
      $executeRaw: () => {
        execs += 1;
        return Promise.resolve(1);
      },
      $transaction: async <T>(work: (tx: unknown) => Promise<T>): Promise<T> => work(impl),
    };
    return {
      repo: new PrismaModerationRepository(impl as unknown as PrismaService),
      execCount: () => execs,
    };
  }

  it('qa_question onayı: durum güncellenir, puan yazılmaz (owner null)', async () => {
    const { repo } = decideRepo({
      claimed: [{ entityType: 'qa_question', entityId: 'q1' }],
      updated: [{ oldStatus: 'pending' }],
    });
    const res = await repo.decide('t1', 'mod1', 'approve', null);
    expect(res).toMatchObject({ entityType: 'qa_question', ownerUserId: null });
  });

  it('qa_answer pending→approved: cevap sayacı +1 (tek $executeRaw)', async () => {
    const { repo, execCount } = decideRepo({
      claimed: [{ entityType: 'qa_answer', entityId: 'a1' }],
      updated: [{ oldStatus: 'pending', questionId: 'q1' }],
    });
    const res = await repo.decide('t1', 'mod1', 'approve', null);
    expect(res).toMatchObject({ entityType: 'qa_answer' });
    expect(execCount()).toBe(1);
  });

  it('qa_answer approved→rejected (şikâyet sonrası): sayaç -1; aynı karar tekrarı 0', async () => {
    const minus = decideRepo({
      claimed: [{ entityType: 'qa_answer', entityId: 'a1' }],
      updated: [{ oldStatus: 'approved', questionId: 'q1' }],
    });
    await minus.repo.decide('t1', 'mod1', 'reject', 'offensive');
    expect(minus.execCount()).toBe(1);

    const same = decideRepo({
      claimed: [{ entityType: 'qa_answer', entityId: 'a1' }],
      updated: [{ oldStatus: 'approved', questionId: 'q1' }],
    });
    await same.repo.decide('t1', 'mod1', 'approve', null);
    expect(same.execCount()).toBe(0); // approved→approved: sayaç oynamaz
  });

  it('silinmiş soru-cevap varlığında karar null döner (yarış güvenliği)', async () => {
    const { repo } = decideRepo({
      claimed: [{ entityType: 'qa_question', entityId: 'q1' }],
      updated: [],
    });
    expect(await repo.decide('t1', 'mod1', 'approve', null)).toBeNull();
  });
});

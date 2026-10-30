import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import {
  CreateQuestionInput,
  QaAnswerRow,
  QaCategory,
  QaModerationStatus,
  QaQuestionRow,
  QaRepository,
} from '../domain/qa.types';

/**
 * Soru-cevap deposu — ham SQL (notes deposuyla aynı stil ve aynı ALTYAPI YOLU:
 * sahiplik denetimi uygulama katmanında, RLS ikinci fren olarak DB'de).
 * Sayaçlar (beğeni, cevap) tek ifadede atomik güncellenir; "oku-sonra-yaz"
 * yarış boşluğu yoktur. Mükerrer oy, defter tablolarının birincil anahtarıyla
 * KÖKTEN engellidir (keşif hakkı defteriyle aynı felsefe).
 */

/** Yazar ekleri: görünen ad + ŞU ANKİ premium durumu (rozet dinamiktir —
 *  üyeliği biten yazarın eski soruları rozetini kaybeder; dürüst davranış). */
const AUTHOR_JOIN = Prisma.sql`
  LEFT JOIN user_profiles p ON p.user_id = q.user_id
  JOIN users u ON u.id = q.user_id
`;
const AUTHOR_COLS = Prisma.sql`
  p.display_name AS "authorName",
  ((u.premium_until IS NOT NULL AND u.premium_until > now()) OR u.role_id >= 3)
    AS "authorPremium"
`;

const QUESTION_COLS = Prisma.sql`
  q.id, q.user_id AS "userId", q.category, q.title, q.body,
  q.status::text AS status, q.featured_until AS "featuredUntil",
  q.like_count::int AS "likeCount", q.answers_count::int AS "answersCount",
  q.created_at AS "createdAt", ${AUTHOR_COLS}
`;

interface QuestionSqlRow {
  id: string;
  userId: string;
  category: string;
  title: string;
  body: string;
  status: string;
  featuredUntil: Date | null;
  likeCount: number;
  answersCount: number;
  createdAt: Date;
  authorName: string | null;
  authorPremium: boolean;
}

interface AnswerSqlRow {
  id: string;
  questionId: string;
  userId: string;
  body: string;
  status: string;
  helpfulCount: number;
  createdAt: Date;
  authorName: string | null;
  authorPremium: boolean;
  helpedByMe: boolean;
}

function toQuestion(r: QuestionSqlRow): QaQuestionRow {
  return {
    id: r.id,
    userId: r.userId,
    category: r.category,
    title: r.title,
    body: r.body,
    status: r.status as QaModerationStatus,
    featuredUntil: r.featuredUntil,
    likeCount: Number(r.likeCount),
    answersCount: Number(r.answersCount),
    createdAt: r.createdAt,
    authorName: r.authorName,
    authorPremium: Boolean(r.authorPremium),
  };
}

function toAnswer(r: AnswerSqlRow): QaAnswerRow {
  return {
    id: r.id,
    questionId: r.questionId,
    userId: r.userId,
    body: r.body,
    status: r.status as QaModerationStatus,
    helpfulCount: Number(r.helpfulCount),
    createdAt: r.createdAt,
    authorName: r.authorName,
    authorPremium: Boolean(r.authorPremium),
    helpedByMe: Boolean(r.helpedByMe),
  };
}

@Injectable()
export class PrismaQaRepository implements QaRepository {
  constructor(private readonly prisma: PrismaService) {}

  /** Arama deseni: ILIKE %…% — kullanıcı girdisindeki joker karakterler
   *  etkisizleştirilir (yüzde/alt çizgi aramada DÜZ metin sayılır). */
  private static searchPattern(search: string): string {
    return `%${search.replace(/[\\%_]/g, (m) => `\\${m}`)}%`;
  }

  async list(
    category: QaCategory | null,
    search: string | null,
    offset: number,
    limit: number,
  ): Promise<QaQuestionRow[]> {
    const pattern = search === null ? null : PrismaQaRepository.searchPattern(search);
    const rows = await this.prisma.$queryRaw<QuestionSqlRow[]>(Prisma.sql`
      SELECT ${QUESTION_COLS}
      FROM qa_questions q ${AUTHOR_JOIN}
      WHERE q.status = 'approved'::moderation_status AND q.deleted_at IS NULL
        AND (${category}::text IS NULL OR q.category = ${category})
        AND (${pattern}::text IS NULL
             OR q.title ILIKE ${pattern} OR q.body ILIKE ${pattern})
      ORDER BY q.created_at DESC
      OFFSET ${offset}
      LIMIT ${limit}
    `);
    return rows.map(toQuestion);
  }

  async count(category: QaCategory | null, search: string | null): Promise<number> {
    const pattern = search === null ? null : PrismaQaRepository.searchPattern(search);
    const rows = await this.prisma.$queryRaw<{ n: number }[]>(Prisma.sql`
      SELECT count(*)::int AS n
      FROM qa_questions q
      WHERE q.status = 'approved'::moderation_status AND q.deleted_at IS NULL
        AND (${category}::text IS NULL OR q.category = ${category})
        AND (${pattern}::text IS NULL
             OR q.title ILIKE ${pattern} OR q.body ILIKE ${pattern})
    `);
    return Number(rows[0]?.n ?? 0);
  }

  async featured(limit: number): Promise<QaQuestionRow[]> {
    const rows = await this.prisma.$queryRaw<QuestionSqlRow[]>(Prisma.sql`
      SELECT ${QUESTION_COLS}
      FROM qa_questions q ${AUTHOR_JOIN}
      WHERE q.status = 'approved'::moderation_status AND q.deleted_at IS NULL
        AND q.featured_until > now()
      ORDER BY q.created_at DESC
      LIMIT ${limit}
    `);
    return rows.map(toQuestion);
  }

  async findQuestion(id: string): Promise<QaQuestionRow | null> {
    const rows = await this.prisma.$queryRaw<QuestionSqlRow[]>(Prisma.sql`
      SELECT ${QUESTION_COLS}
      FROM qa_questions q ${AUTHOR_JOIN}
      WHERE q.id = ${id}::uuid AND q.deleted_at IS NULL
    `);
    return rows.length > 0 ? toQuestion(rows[0]) : null;
  }

  async answersFor(questionId: string, viewerUserId: string | null): Promise<QaAnswerRow[]> {
    // Onaylı cevaplar herkese (tam erişimde); bakanın KENDİ bekleyen cevabı da
    // görünür ("cevabın onay bekliyor" dürüstlüğü). Reddedilenler görünmez.
    const rows = await this.prisma.$queryRaw<AnswerSqlRow[]>(Prisma.sql`
      SELECT a.id, a.question_id AS "questionId", a.user_id AS "userId", a.body,
             a.status::text AS status, a.helpful_count::int AS "helpfulCount",
             a.created_at AS "createdAt",
             p.display_name AS "authorName",
             ((u.premium_until IS NOT NULL AND u.premium_until > now()) OR u.role_id >= 3)
               AS "authorPremium",
             (${viewerUserId}::uuid IS NOT NULL AND EXISTS (
                SELECT 1 FROM qa_answer_helpfuls h
                WHERE h.answer_id = a.id AND h.user_id = ${viewerUserId}::uuid
             )) AS "helpedByMe"
      FROM qa_answers a
      LEFT JOIN user_profiles p ON p.user_id = a.user_id
      JOIN users u ON u.id = a.user_id
      WHERE a.question_id = ${questionId}::uuid AND a.deleted_at IS NULL
        AND (a.status = 'approved'::moderation_status
             OR (a.status = 'pending'::moderation_status
                 AND a.user_id = ${viewerUserId}::uuid))
      ORDER BY a.created_at ASC
    `);
    return rows.map(toAnswer);
  }

  async likedBy(questionId: string, viewerUserId: string): Promise<boolean> {
    const rows = await this.prisma.$queryRaw<{ liked: boolean }[]>(Prisma.sql`
      SELECT EXISTS (
        SELECT 1 FROM qa_question_likes
        WHERE question_id = ${questionId}::uuid AND user_id = ${viewerUserId}::uuid
      ) AS liked
    `);
    return Boolean(rows[0]?.liked);
  }

  async hasApprovedContent(userId: string): Promise<boolean> {
    const rows = await this.prisma.$queryRaw<{ ok: boolean }[]>(Prisma.sql`
      SELECT (EXISTS (
        SELECT 1 FROM qa_questions
        WHERE user_id = ${userId}::uuid AND status = 'approved'::moderation_status
          AND deleted_at IS NULL
      ) OR EXISTS (
        SELECT 1 FROM qa_answers
        WHERE user_id = ${userId}::uuid AND status = 'approved'::moderation_status
          AND deleted_at IS NULL
      )) AS ok
    `);
    return Boolean(rows[0]?.ok);
  }

  async hasApprovedAnswerIn(questionId: string, userId: string): Promise<boolean> {
    const rows = await this.prisma.$queryRaw<{ ok: boolean }[]>(Prisma.sql`
      SELECT EXISTS (
        SELECT 1 FROM qa_answers
        WHERE question_id = ${questionId}::uuid AND user_id = ${userId}::uuid
          AND status = 'approved'::moderation_status AND deleted_at IS NULL
      ) AS ok
    `);
    return Boolean(rows[0]?.ok);
  }

  async createQuestion(
    id: string,
    userId: string,
    input: CreateQuestionInput,
    status: QaModerationStatus,
    featuredUntil: Date | null,
  ): Promise<QaQuestionRow> {
    // Soru + (beklemedeyse) moderasyon görevi TEK ifadede — notes deseni.
    const rows = await this.prisma.$queryRaw<QuestionSqlRow[]>(Prisma.sql`
      WITH ins AS (
        INSERT INTO qa_questions (id, user_id, category, title, body, status, featured_until)
        VALUES (
          ${id}::uuid, ${userId}::uuid, ${input.category}, ${input.title}, ${input.body},
          ${status}::moderation_status, ${featuredUntil}::timestamptz
        )
        RETURNING *
      ), task AS (
        INSERT INTO moderation_tasks (entity_type, entity_id, status)
        SELECT 'qa_question'::moderation_entity, ins.id, 'pending'::moderation_status
        FROM ins WHERE ins.status = 'pending'::moderation_status
        ON CONFLICT (entity_type, entity_id) DO NOTHING
      )
      SELECT ${QUESTION_COLS} FROM ins q ${AUTHOR_JOIN}
    `);
    return toQuestion(rows[0]);
  }

  async createAnswer(
    id: string,
    questionId: string,
    userId: string,
    body: string,
    status: QaModerationStatus,
  ): Promise<QaAnswerRow> {
    // Onaylı doğan cevap, sorunun cevap sayacını AYNI ifadede artırır.
    const rows = await this.prisma.$queryRaw<AnswerSqlRow[]>(Prisma.sql`
      WITH ins AS (
        INSERT INTO qa_answers (id, question_id, user_id, body, status)
        VALUES (${id}::uuid, ${questionId}::uuid, ${userId}::uuid, ${body},
                ${status}::moderation_status)
        RETURNING *
      ), task AS (
        INSERT INTO moderation_tasks (entity_type, entity_id, status)
        SELECT 'qa_answer'::moderation_entity, ins.id, 'pending'::moderation_status
        FROM ins WHERE ins.status = 'pending'::moderation_status
        ON CONFLICT (entity_type, entity_id) DO NOTHING
      ), cnt AS (
        UPDATE qa_questions SET answers_count = answers_count + 1, updated_at = now()
        WHERE id = ${questionId}::uuid
          AND ${status} = 'approved'
      )
      SELECT a.id, a.question_id AS "questionId", a.user_id AS "userId", a.body,
             a.status::text AS status, a.helpful_count::int AS "helpfulCount",
             a.created_at AS "createdAt",
             p.display_name AS "authorName",
             ((u.premium_until IS NOT NULL AND u.premium_until > now()) OR u.role_id >= 3)
               AS "authorPremium",
             false AS "helpedByMe"
      FROM ins a
      LEFT JOIN user_profiles p ON p.user_id = a.user_id
      JOIN users u ON u.id = a.user_id
    `);
    return toAnswer(rows[0]);
  }

  async toggleLike(
    questionId: string,
    userId: string,
  ): Promise<{ liked: boolean; likeCount: number }> {
    const rows = await this.prisma.$queryRaw<{ liked: boolean; likeCount: number }[]>(Prisma.sql`
      WITH del AS (
        DELETE FROM qa_question_likes
        WHERE question_id = ${questionId}::uuid AND user_id = ${userId}::uuid
        RETURNING 1
      ), ins AS (
        INSERT INTO qa_question_likes (question_id, user_id)
        SELECT ${questionId}::uuid, ${userId}::uuid
        WHERE NOT EXISTS (SELECT 1 FROM del)
        RETURNING 1
      ), upd AS (
        UPDATE qa_questions
        SET like_count = GREATEST(0, like_count
              + CASE WHEN EXISTS (SELECT 1 FROM del) THEN -1 ELSE 1 END),
            updated_at = now()
        WHERE id = ${questionId}::uuid
        RETURNING like_count
      )
      SELECT EXISTS (SELECT 1 FROM ins) AS liked,
             COALESCE((SELECT like_count::int FROM upd), 0) AS "likeCount"
    `);
    return { liked: Boolean(rows[0]?.liked), likeCount: Number(rows[0]?.likeCount ?? 0) };
  }

  async toggleHelpful(
    answerId: string,
    userId: string,
  ): Promise<{ helped: boolean; helpfulCount: number }> {
    const rows = await this.prisma.$queryRaw<{ helped: boolean; helpfulCount: number }[]>(
      Prisma.sql`
        WITH del AS (
          DELETE FROM qa_answer_helpfuls
          WHERE answer_id = ${answerId}::uuid AND user_id = ${userId}::uuid
          RETURNING 1
        ), ins AS (
          INSERT INTO qa_answer_helpfuls (answer_id, user_id)
          SELECT ${answerId}::uuid, ${userId}::uuid
          WHERE NOT EXISTS (SELECT 1 FROM del)
          RETURNING 1
        ), upd AS (
          UPDATE qa_answers
          SET helpful_count = GREATEST(0, helpful_count
                + CASE WHEN EXISTS (SELECT 1 FROM del) THEN -1 ELSE 1 END),
              updated_at = now()
          WHERE id = ${answerId}::uuid
          RETURNING helpful_count
        )
        SELECT EXISTS (SELECT 1 FROM ins) AS helped,
               COALESCE((SELECT helpful_count::int FROM upd), 0) AS "helpfulCount"
      `,
    );
    return { helped: Boolean(rows[0]?.helped), helpfulCount: Number(rows[0]?.helpfulCount ?? 0) };
  }

  async findAnswerMeta(
    answerId: string,
  ): Promise<{ userId: string; status: QaModerationStatus; questionId: string } | null> {
    const rows = await this.prisma.$queryRaw<
      { userId: string; status: string; questionId: string }[]
    >(Prisma.sql`
      SELECT user_id AS "userId", status::text AS status, question_id AS "questionId"
      FROM qa_answers WHERE id = ${answerId}::uuid AND deleted_at IS NULL
    `);
    if (rows.length === 0) return null;
    return {
      userId: rows[0].userId,
      status: rows[0].status as QaModerationStatus,
      questionId: rows[0].questionId,
    };
  }

  async report(entity: 'qa_question' | 'qa_answer', entityId: string): Promise<boolean> {
    // İçerik yayında kalır (önce-yayın ilkesi); görev kuyruğa 'pending' düşer.
    // reports deposundaki ON CONFLICT yeniden-açma deseniyle birebir aynı.
    const table = entity === 'qa_question' ? Prisma.sql`qa_questions` : Prisma.sql`qa_answers`;
    const changed = await this.prisma.$executeRaw(Prisma.sql`
      INSERT INTO moderation_tasks (entity_type, entity_id, status)
      SELECT ${entity}::moderation_entity, t.id, 'pending'::moderation_status
      FROM ${table} t WHERE t.id = ${entityId}::uuid AND t.deleted_at IS NULL
      ON CONFLICT (entity_type, entity_id)
      DO UPDATE SET status = 'pending'::moderation_status, decided_at = NULL, updated_at = now()
    `);
    return changed > 0;
  }
}

-- ============================================================================
-- 0014_qa — Soru-Cevap (Blog V1, kurucu onayı 2026-10-23)
--
-- Topluluk soru-cevap alanı: sorular + cevaplar + beğeni/faydalı defterleri.
-- Erişim kuralı (kurucu kararı): liste+önizleme herkese, detay/cevap/yazma
-- Premium'a — kilit SUNUCUDA uygulanır (qa.service). Moderasyon KARMA model:
-- kullanıcının İLK içeriği kuyruktan geçer, sonrakiler ön-süzgeç temizse
-- anında yayınlanır (kurucu onayı 2026-10-23; prefilter.ts yeniden kullanılır).
--
-- KURAL (boot-migrate): tamamen idempotent DDL — IF NOT EXISTS / duplicate_object
-- yakalama (0012/0013 dersi). ALTER TYPE ... ADD VALUE IF NOT EXISTS PG12+'ta
-- transaction içinde güvenlidir; yeni değer aynı transaction'da KULLANILMAZ.
-- ============================================================================

-- Moderasyon kuyruğu yeni içerik türlerini tanısın (tek kuyruk ilkesi).
ALTER TYPE moderation_entity ADD VALUE IF NOT EXISTS 'qa_question';
ALTER TYPE moderation_entity ADD VALUE IF NOT EXISTS 'qa_answer';

CREATE TABLE IF NOT EXISTS qa_questions (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  -- Sabit kategori sözlüğü — serbest metin yok (mükerrer/kirli kategori olmaz).
  category       text NOT NULL CHECK (category IN
                   ('demirleme','seyir','ekipman','marina','uygulama','genel')),
  title          text NOT NULL CHECK (char_length(title) BETWEEN 10 AND 140),
  body           text NOT NULL CHECK (char_length(body) BETWEEN 30 AND 2000),
  status         moderation_status NOT NULL DEFAULT 'pending',
  -- Premium görünürlük avantajı: onaydan sonra 24 saat "Öne çıkan" şeridi.
  featured_until timestamptz,
  -- Denormalize sayaçlar — notes deseniyle aynı: tek UPDATE ile atomik artar.
  like_count     int NOT NULL DEFAULT 0,
  answers_count  int NOT NULL DEFAULT 0,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  deleted_at     timestamptz
);

CREATE INDEX IF NOT EXISTS ix_qa_questions_feed
  ON qa_questions (status, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS ix_qa_questions_category
  ON qa_questions (category, status, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS ix_qa_questions_user
  ON qa_questions (user_id);

CREATE TABLE IF NOT EXISTS qa_answers (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id   uuid NOT NULL REFERENCES qa_questions(id) ON DELETE CASCADE,
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body          text NOT NULL CHECK (char_length(body) BETWEEN 10 AND 2000),
  status        moderation_status NOT NULL DEFAULT 'pending',
  helpful_count int NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  deleted_at    timestamptz
);

CREATE INDEX IF NOT EXISTS ix_qa_answers_question
  ON qa_answers (question_id, status, created_at ASC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS ix_qa_answers_user
  ON qa_answers (user_id);

-- Beğeni/faydalı defterleri: PK mükerrer oyu KÖKTEN engeller (etkinlik
-- kontenjanı ve keşif hakkı ile aynı "defter + tekil anahtar" felsefesi).
CREATE TABLE IF NOT EXISTS qa_question_likes (
  question_id uuid NOT NULL REFERENCES qa_questions(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (question_id, user_id)
);

CREATE TABLE IF NOT EXISTS qa_answer_helpfuls (
  answer_id  uuid NOT NULL REFERENCES qa_answers(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (answer_id, user_id)
);

-- ---------------------------------------------------------------------------
-- RLS (ADR-003, 0008 deseniyle birebir): okuma herkese (Premium kilidi
-- UYGULAMA katmanında, erişim kararıyla verilir — RLS satır sahipliği içindir),
-- yazma yalnız sahibine; altyapı yolu (app.user_id NULL) serbest kalır.
-- ---------------------------------------------------------------------------
ALTER TABLE qa_questions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE qa_answers         ENABLE ROW LEVEL SECURITY;
ALTER TABLE qa_question_likes  ENABLE ROW LEVEL SECURITY;
ALTER TABLE qa_answer_helpfuls ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY qa_questions_read ON qa_questions FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY qa_questions_owner_write ON qa_questions FOR ALL
    USING (app_current_user_id() IS NULL OR user_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR user_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY qa_answers_read ON qa_answers FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY qa_answers_owner_write ON qa_answers FOR ALL
    USING (app_current_user_id() IS NULL OR user_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR user_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY qa_question_likes_owner ON qa_question_likes FOR ALL
    USING (app_current_user_id() IS NULL OR user_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR user_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY qa_question_likes_read ON qa_question_likes FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY qa_answer_helpfuls_owner ON qa_answer_helpfuls FOR ALL
    USING (app_current_user_id() IS NULL OR user_id = app_current_user_id())
    WITH CHECK (app_current_user_id() IS NULL OR user_id = app_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY qa_answer_helpfuls_read ON qa_answer_helpfuls FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

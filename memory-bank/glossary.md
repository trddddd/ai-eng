---
title: Glossary
doc_kind: project
doc_function: canonical
purpose: Словарь терминов проекта Lingvize — доменные и governance-термины.
derived_from:
  - dna/governance.md
  - domain/problem.md
status: active
audience: humans_and_agents
---

# Glossary

## Domain Terms (Lingvize)

### Lexeme

Словарная единица (слово) с headword, частью речи (POS) и CEFR-уровнем. Принадлежит языку. Пример: headword "abandon", POS "verb", level "b2".

### LexemeGloss

Перевод лексемы на целевой язык. Связывает Lexeme с Language (target). Пример: "abandon" → "покидать, отказываться".

### Sentence

Предложение из внешнего корпуса (Tatoeba, Quizword) с указанием source. Содержит текст на языке оригинала.

### SentenceTranslation

Перевод предложения на целевой язык. Связывает Sentence с Language (target). Уникальна по паре `(sentence_id, target_language_id)`.

### SentenceOccurrence

Связь лексемы с предложением: фиксирует, какое слово (form) встречается в каком предложении. Генерирует cloze text (текст с пропущенным словом: `____`). Связана с `Sense` (какое значение слова) и `ContextFamily` (контекстная семья) через FT-029.

### Cloze Deletion

Учебный приём: пользователь видит предложение с пропущенным словом и вводит его по памяти. Основной формат карточки в Lingvize.

### Card

Учебная карточка пользователя. Привязана к SentenceOccurrence. Хранит FSRS-состояние: stability, difficulty, scheduled_days, reps, lapses, state, due. Делегирует доступ к lexeme, sense, context_family через occurrence. Поле `mastered_at` отмечает время освоения карточки (вычисляется по FSRS-метрикам).

### FSRS

Free Spaced Repetition Scheduler — алгоритм интервального повторения. Адаптирует интервалы между показами карточки по ответам пользователя. Состояния: NEW → LEARNING → REVIEW → RELEARNING.

### Recall Quality

Классификация качества вспоминания при ответе: `no_recall`, `near_miss` (≥70% Levenshtein), `effortful_recall` (≥10s), `successful_recall`, `automatic_recall` (<3s + 100% точность).

### Rating

FSRS-оценка ответа: AGAIN (1), HARD (2), GOOD (3), EASY (4). Определяется автоматически на основе recall quality.

### ReviewLog

Запись ответа в сессии повторения: rating, recall quality, accuracy, время ответа, количество попыток, backspace count.

### Starter Deck

Стартовая колода: 50 карточек уровня A1 с русскими переводами. Создаётся автоматически при регистрации (`Cards::BuildStarterDeck`).

### CEFR

Common European Framework of Reference for Languages — шкала владения языком: A1 (начальный) → C2 (свободный). Используется для маркировки lexemes.

### Content Bootstrap

Процесс наполнения базы данных контентом: импорт лексем (Oxford 5000, NGSL), глоссов (Poliglot), предложений (Quizword).

### Cold Start

Быстрый запуск на чистом окружении через pg_dump/pg_restore вместо полного прогона миграций и seed'ов (FT-005).

## Governance Terms (Memory Bank)

### SSoT (Single Source of Truth)

Каждый факт имеет одного canonical owner. Дублирование — дефект.

### Canonical Owner

Документ, который владеет фактом и имеет приоритет над downstream-описаниями.

### Governed Document

Markdown-файл с YAML frontmatter, подчиняющийся governance-правилам memory-bank.

### Dependency Tree

DAG зависимостей между документами через `derived_from`. Authority течёт upstream → downstream.

### Feature Package

Каталог `FT-XXX/` с документами одной delivery-единицы: brief, feature.md (spec), implementation-plan.md (plan).

### PRD (Product Requirements Document)

Документ уровня продуктовой инициативы. Стоит между domain/problem.md и downstream feature packages.

### ADR (Architecture Decision Record)

Фиксация архитектурного решения: контекст, альтернативы, rationale, последствия.

### Status (Publication)

`draft` → `active` → `archived`. Отвечает за то, является ли документ действующим источником истины.

### Delivery Status

`planned` → `in_progress` → `done` / `cancelled`. Lifecycle feature-документа.

### Progressive Disclosure

Принцип: обзор сначала, детали по ссылкам. Верхний уровень остаётся читаемым.

### Sense

Отдельное значение лексемы (lemma + sense definition). Для полисемичных слов — каждый sense отслеживается независимо: `run₁` = "бежать", `run₂` = "управлять". Для monosemous слов — fallback: `lexeme == sense` (одно значение). Сущность `Sense` в FT-029.

### Synset (Синсет)

Группа синонимов в WordNet, выражающих одно понятие (смысл). Идентифицируется synset ID (числовой offset, 9+ цифр). Каждый synset имеет definition, POS, lexical domain, examples. Связан с другими synsets через отношения: hypernym, hyponym, meronym и т.д.

### WordNet

Лексическая база данных английского языка (Princeton). Организована как граф synsets. Версии: 3.0 (2006) и 3.1 (2011). Источник sense-данных для Lingvize: definitions, sense rank, lexical domains. Лицензия: свободная (аналог BSD).

### Context Family

Именованная группа контекстов употребления слова. Классифицирует предложения по схожести ситуации или домена: `run` в спорте vs `run` в бизнесе. v1 = curated string labels из контролируемого словаря. Fallback для неклассифицированных: `unknown`. Сущность `ContextFamily` в FT-029.

### Word Mastery

Персональное состояние знания слова у пользователя. Метрики: stability, context coverage, sense coverage, reliability. Вычисляется rule-based агрегацией из card states. Не использует FSRS напрямую — слово не ревьюится, оценивается через evidence от карточек.

### UserLexemeState

Агрегатное состояние знания слова для пары `(user_id, lexeme_id)`. Хранит денормализованные счётчики и проценты покрытия: `covered_sense_count`, `total_sense_count`, `sense_coverage_pct`, `covered_family_count`, `total_family_count`, `family_coverage_pct`, `last_covered_at`. Читается Session Builder v2 и Dashboard прогресса. Обновляется при каждом правильном ответе через `WordMastery::RecordCoverage`. Создаётся в FT-031.

### UserSenseCoverage

Запись факта, что пользователь хотя бы один раз ответил правильно на карточку, привязанную к конкретному `Sense`. Хранит `user_id`, `sense_id`, `first_correct_at`. Unique по `(user_id, sense_id)`. Создаётся в FT-031; обновляется в реальном времени в Review Pipeline v2.

### UserContextFamilyCoverage

Запись факта, что пользователь хотя бы один раз ответил правильно на карточку, использующую конкретную `ContextFamily` для данной лексемы. Хранит `user_id`, `lexeme_id`, `context_family_id`, `first_correct_at`. Unique по `(user_id, lexeme_id, context_family_id)`. Tracking на уровне `Lexeme`, не `Sense`: context family описывает домен употребления слова независимо от значения.

### WSD (Word Sense Disambiguation)

Автоматическое определение, какой именно sense (synset) слова имеется в виду в конкретном предложении. Для Lingvize: привязка SentenceOccurrence к конкретному Sense. MVP подход: Most Frequent Sense (MFS) + POS filter (~70-75% accuracy).

### Most Frequent Sense (MFS)

Baseline-подход к WSD: берётся первый (самый частый) sense слова из WordNet. WordNet упорядочивает senses по частотности на основе SemCor. Для Oxford 5000 слов даёт ~70-75% accuracy. Не требует отдельного кода WSD.

### Content Pipeline

Пайплайн наполнения базы контентом: импорт лексем (Oxford 5000, NGSL) → глоссы (Poliglot) → предложения (Quizword) → sense-разметка (WordNet, FT-029) → контекстные семьи. Operations в `app/operations/content_bootstrap/`.

## Architecture Terms

### Operation

Класс бизнес-логики в `app/operations/`. Entry point: `.call()`. Один use case = одна операция. Пример: `Reviews::RecordAnswer`.

### Layered Rails

Подход к организации Rails-кода из книги "Layered Design for Ruby on Rails Applications" (Vladimir Dementyev). Четыре слоя с однонаправленным потоком данных: Presentation → Application → Domain → Infrastructure. Нижние слои не зависят от верхних. Domain logic живёт в моделях (не в сервисах). Services — "waiting room" для кода до появления правильной абстракции. Скилл `layered-rails` с командами `/layers:*`. См. `engineering/architecture-patterns.md`.

### Specification Test

Ключевой принцип Layered Rails: если спецификация объекта описывает возможности за пределами основной ответственности его архитектурного слоя, эти возможности должны быть вынесены в нижние слои. Проверяется через `/layers:spec-test`.

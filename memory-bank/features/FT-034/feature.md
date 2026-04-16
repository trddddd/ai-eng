---
title: "FT-034: Review Pipeline v2 + Word Progress Dashboard"
doc_kind: feature
doc_function: canonical
purpose: "Интеграция WordMastery::RecordCoverage в review flow (runtime updates), трассируемость review → mastery через LexemeReviewContribution, word progress dashboard."
derived_from:
  - ../../domain/problem.md
  - ../../prd/PRD-002-word-mastery.md
  - ../FT-031/feature.md
status: active
delivery_status: planned
audience: humans_and_agents
must_not_define:
  - implementation_sequence
  - weight_model_for_contribution
  - session_builder_scheduling_logic
---

# FT-034: Review Pipeline v2 + Word Progress Dashboard

> GitHub Issue: [xtrmdk/ai-eng#34](https://github.com/xtrmdk/ai-eng/issues/34)

## What

### Problem

После FT-031 (Word Mastery State) operation `WordMastery::RecordCoverage` существует, но не вызывается из review flow — только из backfill rake task. Пользователь правильно отвечает на карточку, но mastery state (`sense_coverage_pct`, `family_coverage_pct`) не обновляется в рантайме. Одновременно нет трассируемости: невозможно связать конкретный review с вкладом в word mastery (PRD-002 MET-04 требует 100% coverage review → contribution record). Dashboard показывает прогресс по карточкам, а не по словам — пользователь не видит, сколько слов освоено.

Feature-specific delta относительно PRD-002: эта фича интегрирует существующий foundation (FT-031) в runtime review flow, добавляет трассируемость и переводит dashboard на word-centric модель.

### Outcome

| Metric ID | Metric | Baseline | Target | Measurement method |
| --- | --- | --- | --- | --- |
| `MET-01` | `RecordCoverage` вызывается при каждом правильном ответе | 0% review flow integration | 100% correct reviews вызывают `RecordCoverage` | RSpec: spy on `RecordCoverage` в `RecordAnswer` spec |
| `MET-02` | Каждый review имеет `LexemeReviewContribution` | 0% | 100% (PRD-002 MET-04) | `ReviewLog.joins(:lexeme_review_contribution).count == ReviewLog.where(correct: true).count` |
| `MET-03` | Dashboard показывает word-level прогресс (3 buckets) | Card-level only | Word progress: zero / partial / full coverage | RSpec + visual check |

### Scope

- `REQ-01` Интеграция `WordMastery::RecordCoverage` в `Reviews::RecordAnswer`: вызов внутри transaction после создания ReviewLog, только при `correct: true`.
- `REQ-02` Новая сущность `LexemeReviewContribution` — связывает review_log с его вкладом в word mastery. Поля: `(review_log_id, user_id, lexeme_id, sense_id, context_family_id, contribution_type, created_at)`. Создаётся для каждого правильного ответа. `contribution_type`: `new_sense` | `new_family` | `new_sense_and_family` | `reinforcement` — определяется ДО upsert coverage-записей по таблице истинности в ASM-03.
- `REQ-03` `WordMastery::RecordCoverage` обновлён: создаёт `LexemeReviewContribution` вместе с coverage-записями в одной transaction.
- `REQ-04` Dashboard operation `Dashboard::BuildProgress` обогащена word-level данными: три bucket-счётчика из `UserLexemeState` — `words_zero_coverage` (`sense_coverage_pct = 0.0`), `words_partial_coverage` (`> 0.0 AND < 100.0`), `words_full_coverage` (`= 100.0`), плюс `total_words_tracked` (общее число `UserLexemeState` у пользователя).
- `REQ-05` Dashboard view обновлён: card-level «Words learned» заменён на word progress card с тремя buckets (zero / partial / full) + visual indicator. Design: filament progress indicator (DESIGN.md §5), surface-container-low card, no-line rule.

### Non-Scope

- `NS-01` Весовая модель contribution (PRD-002 BR-04): конкретные коэффициенты для new_family / seen_family / near-duplicate — post-v1. Contribution_type фиксирует тип, но weight пока не назначается.
- `NS-02` Session Builder v2 (как использовать coverage для выбора следующей карточки) — отдельная downstream feature.
- `NS-03` Word-level FSRS scheduling — word mastery state не является FSRS-картой.
- `NS-04` Агрегация coverage в единый «mastery score» — формула для скоринга выходит за рамки.
- `NS-05` Detailed per-word drill-down view на dashboard (список слов с coverage) — v2 dashboard.
- `NS-06` Incorrect answer contribution tracking — вклад только при `correct: true`.

### Constraints / Assumptions

- `ASM-01` FT-031 завершена: `UserLexemeState`, `UserSenseCoverage`, `UserContextFamilyCoverage` существуют; `WordMastery::RecordCoverage` реализована и протестирована.
- `ASM-02` FT-029 завершена: `Sense`, `ContextFamily` существуют; `SentenceOccurrence.sense_id` и `context_family_id` nullable (`belongs_to :sense, optional: true`). FM-01 обрабатывает NULL case.
- `ASM-03` `contribution_type` вычисляется из состояния ДО upsert по таблице истинности:

| UserSenseCoverage exists? | UserContextFamilyCoverage exists? | contribution_type |
| --- | --- | --- |
| no | no | `new_sense_and_family` |
| no | yes | `new_sense` |
| yes | no | `new_family` |
| yes | yes | `reinforcement` |

Проверяем существование `UserSenseCoverage` для (user, sense) и `UserContextFamilyCoverage` для (user, lexeme, family). Если sense_id или context_family_id = NULL — соответствующее измерение считается «already existing» (coverage для NULL dimension не отслеживается).
- `ASM-04` Для неправильных ответов (`correct: false`) contribution record НЕ создаётся — PRD-002 BR-03 говорит, что ответ обновляет card FSRS, а evidence для word mastery формируется только при правильных ответах.
- `ASM-05` Dashboard metric для bucket-классификации использует `sense_coverage_pct` как primary dimension (более интуитивный для пользователя: «сколько значений слова я знаю»).
- `CON-01` Первичные ключи — UUID v7 (PCON-01).
- `CON-02` Не менять существующие миграции. Новые сущности — только новыми миграциями.
- `CON-03` Не подключать новые гемы.
- `CON-04` Architecture: RecordCoverage вызывается из RecordAnswer, не через ReviewLog callback. Обоснование: callback в модели нарушает layered architecture (model → operation dependency); явный вызов из operation сохраняет control flow.
- `CON-05` Transaction boundary: RecordCoverage убирает собственную `ActiveRecord::Base.transaction` и полагается на outer transaction RecordAnswer. Обоснование: nested transaction создаёт savepoint, что может нарушить заявленную atomicity при ошибке внутри RecordCoverage. RecordCoverage остаётся self-contained — при standalone-вызове (backfill) caller обязан обеспечить transaction boundary.

## How

### Solution

Два изменения в runtime flow: (1) `RecordAnswer` вызывает `RecordCoverage` после создания ReviewLog, (2) `RecordCoverage` создаёт `LexemeReviewContribution` вместе с coverage-записями. Dashboard обогащается word-level bucket counts из `UserLexemeState`.

Главный trade-off: вызов `RecordCoverage` в той же transaction что и ReviewLog creation — гарантирует atomicity (review + coverage + contribution — all-or-nothing), но увеличивает transaction duration. Альтернатива (async после commit) сложнее и может приводить к eventual consistency. Для текущего масштаба (однопользовательские сессии) synchronous — предпочтительнее.

### Change Surface

| Surface | Type | Why it changes |
| --- | --- | --- |
| `app/operations/reviews/record_answer.rb` | code | Вызов `RecordCoverage` после ReviewLog creation |
| `app/operations/word_mastery/record_coverage.rb` | code | Создание `LexemeReviewContribution` в transaction |
| `app/models/lexeme_review_contribution.rb` | code (new) | Новая модель: traceability |
| `app/models/review_log.rb` | code | `has_one :lexeme_review_contribution` |
| `db/migrate/*_create_lexeme_review_contributions.rb` | code (new) | Миграция |
| `app/operations/dashboard/build_progress.rb` | code | Word-level bucket counts |
| `app/views/dashboard/index.html.erb` | code | Word progress card вместо card-level «Words learned» |
| `config/locales/*.yml` | code | i18n ключи для новых labels |
| `spec/` | code (new/update) | Тесты |

### Flow

1. Пользователь отвечает правильно → `Reviews::RecordAnswer.call()`.
2. Внутри transaction: создаётся ReviewLog, вызывается `card.schedule!`.
3. Внутри той же transaction: вызывается `WordMastery::RecordCoverage.call(review_log:)`.
4. `RecordCoverage` определяет contribution_type (new_sense / new_family / reinforcement) ДО upsert.
5. Создаёт `LexemeReviewContribution` с contribution_type.
6. Upsert `UserSenseCoverage` и `UserContextFamilyCoverage` (idempotent).
7. Пересчитывает `UserLexemeState`.
8. Dashboard controller вызывает `BuildProgress` → обогащённый Progress struct с word buckets.

### Contracts

| Contract ID | Input / Output | Producer / Consumer | Notes |
| --- | --- | --- | --- |
| `CTR-01` | `LexemeReviewContribution`: `review_log_id`, `user_id`, `lexeme_id`, `sense_id`, `context_family_id`, `contribution_type`, `created_at` | `RecordCoverage` / Dashboard, analytics | Unique по `review_log_id`. `contribution_type`: `new_sense` / `new_family` / `new_sense_and_family` / `reinforcement`. Nullable `sense_id` / `context_family_id` (edge: NULL sense/family на occurrence). |
| `CTR-02` | `RecordCoverage.call(review_log:)` → enriched return | `RecordAnswer` | Вызывается внутри transaction. `review_log.correct == false` → early return, no side effects. |
| `CTR-03` | `Dashboard::BuildProgress` Progress struct: добавлены `words_zero_coverage`, `words_partial_coverage`, `words_full_coverage`, `total_words_tracked` | `DashboardController` / Dashboard view | Integer counts. `total_words_tracked = words_zero + words_partial + words_full`. |

### Schema Constraints

**lexeme_review_contributions:**
- `review_log_id` uuid NOT NULL, FK → `review_logs`, `on_delete: :cascade`
- `user_id` bigint NOT NULL, FK → `users`, `on_delete: :cascade`
- `lexeme_id` uuid NOT NULL, FK → `lexemes`, `on_delete: :cascade`
- `sense_id` uuid, nullable, FK → `senses`, `on_delete: :nullify`
- `context_family_id` uuid, nullable, FK → `context_families`, `on_delete: :nullify`
- `contribution_type` string NOT NULL, check in model: `%w[new_sense new_family new_sense_and_family reinforcement]`
- `created_at` datetime NOT NULL
- Unique index: `(review_log_id)` — один contribution на review
- Index: `(user_id, lexeme_id)` — история покрытия слова
- Index: `(user_id, contribution_type)` — агрегация по типу

### Failure Modes

- `FM-01` `SentenceOccurrence.sense_id` или `context_family_id` равен NULL (edge case, см. ASM-02): NULL dimension считается «already existing» для contribution_type (см. ASM-03 truth table). Nullable FK остаются NULL. Coverage не обновляется по NULL dimension (существующее поведение RecordCoverage).
- `FM-02` `RecordCoverage` вызван для review с `correct: false`: early return, no contribution, no coverage update.
- `FM-03` Повторный вызов `RecordCoverage` для одного review_log: idempotent — `UserSenseCoverage` upsert не создаёт дубль, `LexemeReviewContribution` имеет unique constraint на `review_log_id`, `UserLexemeState` пересчитывается из реального состояния.
- `FM-04` Dashboard: `UserLexemeState` записей ещё нет для новых пользователей (нет правильных ответов): `total_words_tracked = 0`. Dashboard показывает empty state: карточка с текстом «Начните повторение, чтобы увидеть прогресс» и CTA-ссылка на review. При `total_words_tracked > 0` и все zero → «N новых слов — давайте их выучим!» (encouraging text, не три нуля).

## Verify

### Exit Criteria

- `EC-01` Каждый правильный ответ пользователя вызывает `RecordCoverage` и `UserLexemeState` обновляется.
- `EC-02` Каждый правильный ответ создаёт ровно один `LexemeReviewContribution` с корректным `contribution_type`.
- `EC-03` Неправильные ответы НЕ создают contribution и НЕ обновляют coverage.
- `EC-04` Dashboard показывает три word progress buckets, корректно вычисленных из `UserLexemeState`.
- `EC-05` Существующие card FSRS scheduling не нарушен.
- `EC-06` Backfill rake task продолжает работать (RecordCoverage interface не сломан).

### Traceability matrix

| Requirement ID | Design refs | Acceptance refs | Checks | Evidence IDs |
| --- | --- | --- | --- | --- |
| `REQ-01` | `ASM-01`, `ASM-02`, `CON-04`, `CTR-02` | `EC-01`, `EC-05`, `SC-01` | `CHK-01` | `EVID-01` |
| `REQ-02` | `ASM-03`, `ASM-04`, `CON-01`, `CTR-01` | `EC-02`, `EC-03`, `SC-02`, `SC-03` | `CHK-02` | `EVID-02` |
| `REQ-03` | `CTR-01`, `CTR-02`, `FM-01`, `FM-02` | `EC-01`, `EC-02`, `SC-02` | `CHK-01`, `CHK-02` | `EVID-01`, `EVID-02` |
| `REQ-04` | `ASM-05`, `CTR-03` | `EC-04`, `SC-04` | `CHK-03` | `EVID-03` |
| `REQ-05` | `CTR-03`, `CON-01` | `EC-04`, `SC-04` | `CHK-03` | `EVID-03` |

### Acceptance Scenarios

- `SC-01` Пользователь отвечает правильно на карточку со словом `run` (occurrence: sense=run_sport, family=sports). В одной transaction: ReviewLog создаётся, `RecordCoverage` вызывается, `UserLexemeState` обновляется (`covered_sense_count: 1`, `sense_coverage_pct > 0`). Card FSRS scheduling срабатывает корректно.
- `SC-02` Пользователь впервые отвечает правильно на карточку с новым sense для уже знакомого lexeme. `LexemeReviewContribution` создаётся с `contribution_type = new_sense`. При повторном правильном ответе на тот же sense — `contribution_type = reinforcement`.
- `SC-03` Пользователь отвечает неправильно. ReviewLog создаётся с `correct: false`. `LexemeReviewContribution` НЕ создаётся. `UserLexemeState` не меняется.
- `SC-04` Dashboard: пользователь имеет 10 `UserLexemeState` записей. Из них 3 с `sense_coverage_pct = 0.0`, 5 с partial, 2 с 100.0. Dashboard показывает «3 / 5 / 2» в word progress card.

### Negative / Edge Cases

- `NEG-01` Lexeme с единственным sense и одним occurrence: после первого правильного ответа `sense_coverage_pct = 100.0`, contribution_type = `new_sense`. Dashboard bucket = `words_full_coverage` +1.
- `NEG-02` `SentenceOccurrence.sense_id == NULL`: `LexemeReviewContribution` создаётся с `contribution_type` по truth table ASM-03 (NULL dimension = existing). `sense_id = NULL`. `UserLexemeState` не обновляет sense coverage по этому измерению.
- `NEG-03` Пользователь без единого правильного ответа: `UserLexemeState` записей нет → `total_words_tracked = 0` → dashboard показывает empty state (FM-04). Если `UserLexemeState` существуют с нулевым покрытием → «N / 0 / 0» с encouraging text.
- `NEG-04` Backfill rake task: повторный запуск — contribution records не дублируются (unique на `review_log_id`). Существующие coverage-записи не перезаписываются. Backfill ДОЛЖЕН создавать `LexemeReviewContribution` для исторических `ReviewLog.where(correct: true)`, обрабатывая в хронологическом порядке (`created_at ASC`) для корректного вычисления `contribution_type`. При наличии contribution для review_log_id — skip всей операции (contribution + coverage upsert + recalculate) для усиления идемпотентности.

### Checks

| Check ID | Covers | How to check | Expected result | Evidence path |
| --- | --- | --- | --- | --- |
| `CHK-01` | `EC-01`, `EC-05`, `EC-06`, `SC-01`, `NEG-01` | `bundle exec rspec spec/operations/reviews/record_answer_spec.rb` (RecordCoverage integration) | RecordCoverage вызывается при correct, UserLexemeState обновлён, FSRS scheduling не нарушен, backfill interface не сломан | `artifacts/ft-034/verify/chk-01/` |
| `CHK-02` | `EC-02`, `EC-03`, `SC-02`, `SC-03`, `NEG-02` | `bundle exec rspec spec/operations/word_mastery/record_coverage_spec.rb` (contribution creation path) | Contribution создаётся с правильным type при correct; не создаётся при incorrect; nullable FK при NULL sense/family | `artifacts/ft-034/verify/chk-02/` |
| `CHK-03` | `EC-04`, `SC-04`, `NEG-03` | `bundle exec rspec spec/operations/dashboard/build_progress_spec.rb` + visual check | Bucket counts корректны; zero-state handled | `artifacts/ft-034/verify/chk-03/` |
| `CHK-04` | `EC-06`, `NEG-04` | `bundle exec rspec spec/tasks/word_mastery_rake_spec.rb` (backfill idempotency) | Backfill корректен, contribution records не дублируются | `artifacts/ft-034/verify/chk-04/` |
| `CHK-05` | All | `bundle exec rspec` (full suite green) | Non-destructive, no regressions | `artifacts/ft-034/verify/chk-05/` |

### Test matrix

| Check ID | Evidence IDs | Evidence path |
| --- | --- | --- |
| `CHK-01` | `EVID-01` | `artifacts/ft-034/verify/chk-01/` |
| `CHK-02` | `EVID-02` | `artifacts/ft-034/verify/chk-02/` |
| `CHK-03` | `EVID-03` | `artifacts/ft-034/verify/chk-03/` |
| `CHK-04` | `EVID-04` | `artifacts/ft-034/verify/chk-04/` |
| `CHK-05` | `EVID-05` | `artifacts/ft-034/verify/chk-05/` |

### Evidence

- `EVID-01` RSpec output: RecordAnswer integration specs green (RecordCoverage called, FSRS intact, backfill interface OK).
- `EVID-02` RSpec output: RecordCoverage contribution creation specs green (correct types, nullable FKs, incorrect no-op).
- `EVID-03` RSpec output + screenshot: Dashboard BuildProgress specs green + word progress card renders.
- `EVID-04` RSpec output: Backfill rake spec green (contribution idempotency).
- `EVID-05` RSpec full suite output: all green, no regressions.

### Evidence contract

| Evidence ID | Artifact | Producer | Path contract | Reused by checks |
| --- | --- | --- | --- | --- |
| `EVID-01` | RSpec output log | verify-runner | `artifacts/ft-034/verify/chk-01/` | `CHK-01` |
| `EVID-02` | RSpec output log | verify-runner | `artifacts/ft-034/verify/chk-02/` | `CHK-02` |
| `EVID-03` | RSpec output + screenshot | verify-runner | `artifacts/ft-034/verify/chk-03/` | `CHK-03` |
| `EVID-04` | RSpec output log | verify-runner | `artifacts/ft-034/verify/chk-04/` | `CHK-04` |
| `EVID-05` | RSpec full suite | verify-runner | `artifacts/ft-034/verify/chk-05/` | `CHK-05` |

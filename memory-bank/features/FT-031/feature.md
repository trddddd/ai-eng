---
title: "FT-031: Word Mastery State"
doc_kind: feature
doc_function: canonical
purpose: "Персональное состояние знания слова: отслеживает для каждой пары (user, lexeme), какие senses и context families пользователь уже встречал с правильным ответом, и вычисляет процент покрытия — foundation для Session Builder v2 и дашборда прогресса."
derived_from:
  - ../../domain/problem.md
  - ../../prd/PRD-002-word-mastery.md
  - ../FT-029/feature.md
status: active
delivery_status: done
audience: humans_and_agents
must_not_define:
  - implementation_sequence
  - session_builder_scheduling_logic
  - dashboard_ui
---

# FT-031: Word Mastery State

> GitHub Issue: [xtrmdk/ai-eng#31](https://github.com/xtrmdk/ai-eng/issues/31)

## What

### Problem

После FT-029 система различает значения слов (sense) и контекстные семьи (context family) на уровне контента. Но нет сущности, которая хранит для конкретного пользователя: какие senses и context families он уже встречал хотя бы один раз с правильным ответом, и какой процент доступных значений и семей это составляет.

**Следствия отсутствия:**
1. Нельзя показать пользователю «ты знаешь 2 из 4 значений слова `run`».
2. Session Builder v2 не может приоритизировать слова с низким охватом сenses/families — нет данных для приоритизации.
3. PRD-002 MET-05 не выполнен: карточки не привязаны к word mastery state.

Feature-specific delta относительно PRD-002: эта фича создаёт состояние-слой поверх foundation из FT-029. Scheduling logic (Session Builder v2) и UI (дашборд прогресса) — отдельные downstream features.

### Outcome

| Metric ID | Metric | Baseline | Target | Measurement method |
| --- | --- | --- | --- | --- |
| `MET-01` | 100% карточек пользователя имеют upstream `UserLexemeState` | 0% | 100% | `Card.joins(:user_lexeme_state).count == Card.count` |
| `MET-02` | `sense_coverage_pct` доступен для каждого `UserLexemeState` | отсутствует | Вычисляется корректно: covered_sense_count / total_sense_count * 100 | DB query + RSpec |
| `MET-03` | `family_coverage_pct` доступен для каждого `UserLexemeState` | отсутствует | Вычисляется корректно: covered_family_count / total_family_count * 100 | DB query + RSpec |

### Scope

- `REQ-01` Новая сущность `UserLexemeState` — агрегатное состояние знания слова для пары `(user_id, lexeme_id)`. Хранит: `covered_sense_count`, `total_sense_count`, `sense_coverage_pct`, `covered_family_count`, `total_family_count`, `family_coverage_pct`, `last_covered_at`.
- `REQ-02` Новая сущность `UserSenseCoverage` — фиксирует факт «этот sense пользователь уже встречал с правильным ответом». Поля: `(user_id, sense_id, first_correct_at)`. Unique по `(user_id, sense_id)`.
- `REQ-03` Новая сущность `UserContextFamilyCoverage` — фиксирует факт «этот context_family для данного lexeme пользователь уже встречал с правильным ответом». Поля: `(user_id, lexeme_id, context_family_id, first_correct_at)`. Unique по `(user_id, lexeme_id, context_family_id)`.
- `REQ-04` Operation `WordMastery::RecordCoverage` — обновляет `UserSenseCoverage`, `UserContextFamilyCoverage` и агрегатный `UserLexemeState` при получении правильного ответа (`review_log.correct == true`). Идемпотентна: повторный вызов для уже покрытого sense/family не создаёт дублей.
- `REQ-05` Operation `WordMastery::InitializeState` — создаёт `UserLexemeState` (с нулевыми счётчиками) для пары `(user, lexeme)` если её ещё нет. Вызывается при создании первой карточки для данной пары — гарантирует MET-01.
- `REQ-06` Backfill rake task — создаёт `UserLexemeState` + coverage-записи из существующих `ReviewLog` с `correct: true`. Non-destructive: существующие state-записи не перезаписываются (idempotent resume).
- `REQ-07` Ассоциация `Card#user_lexeme_state` — позволяет выполнять `Card.joins(:user_lexeme_state)` для проверки MET-01.

### Non-Scope

- `NS-01` Session Builder v2 (как использовать `family_coverage_pct` для выбора следующей карточки) — отдельная downstream feature.
- `NS-02` Dashboard UI: отображение sense/family coverage пользователю — отдельная downstream feature.
- `NS-03` Word-level FSRS scheduling (word mastery state не является FSRS-картой).
- `NS-04` Агрегация coverage в единый «mastery score» — формула для скоринга выходит за рамки foundation.
- `NS-05` Автоматическая инициализация state для лексем без карточек у пользователя.
- `NS-06` Ручная курация или переопределение coverage пользователем (NG-05 из PRD-002).

### Constraints / Assumptions

- `ASM-01` FT-029 завершена и задеплоена: `Sense`, `ContextFamily` существуют; `SentenceOccurrence.sense_id` и `context_family_id` заполнены (NOT NULL).
- `ASM-02` `covered` = встречал хотя бы один раз с `review_log.correct == true`. Частичные ответы (near_miss) не засчитываются как покрытие.
- `ASM-03` `total_sense_count` = количество senses у lexeme на момент вычисления (денормализовано в `UserLexemeState`, пересчитывается при каждом обновлении). Возможна небольшая задержка при добавлении новых senses в систему — acceptable для v1.
- `ASM-04` `total_family_count` = количество уникальных context_family среди всех `SentenceOccurrence` данного lexeme — то есть, сколько семей доступно в контенте. Аналогично `ASM-03`.
- `ASM-05` Пользователь с нулевыми правильными ответами имеет `UserLexemeState` с `covered_sense_count = 0` и `sense_coverage_pct = 0.0`. Это валидное состояние (BR-09 из PRD-002).
- `CON-01` Первичные ключи — UUID v7 (PCON-01).
- `CON-02` Не менять существующие миграции. Новые сущности — только новыми миграциями.
- `CON-03` Не подключать новые гемы.
- `CON-04` Архитектура хранения coverage: денормализованные счётчики в `UserLexemeState` + детальные `UserSenseCoverage` / `UserContextFamilyCoverage`. Альтернатива (вычисление на лету через JOIN) отклонена — медленнее для Session Builder v2 при большом числе пользователей.

## How

### Solution

Три взаимосвязанных таблицы: агрегатный `user_lexeme_states` + детальные `user_sense_coverages` и `user_context_family_coverages`. Агрегат денормализован (счётчики и проценты) для быстрого чтения Session Builder v2. Детальные таблицы обеспечивают трассируемость: какой именно sense / family и когда был впервые покрыт.

Обновление — eager (синхронное) при каждом правильном ответе через `WordMastery::RecordCoverage`. Для ретроспективных данных — backfill rake task.

Главный trade-off: денормализованные счётчики требуют аккуратного обновления, но дают O(1) чтение для Session Builder. Альтернатива — вычислять на лету через JOIN — медленнее при большом числе пользователей.

### Change Surface

| Surface | Type | Why it changes |
| --- | --- | --- |
| `app/models/user_lexeme_state.rb` | code (new) | Новая модель: агрегатное состояние |
| `app/models/user_sense_coverage.rb` | code (new) | Новая модель: per-sense coverage |
| `app/models/user_context_family_coverage.rb` | code (new) | Новая модель: per-family coverage |
| `app/models/user.rb` | code | `has_many :user_lexeme_states` |
| `app/models/card.rb` | code | `has_one :user_lexeme_state` через user_id + lexeme_id |
| `app/operations/word_mastery/record_coverage.rb` | code (new) | Operation: обновление после правильного ответа |
| `app/operations/word_mastery/initialize_state.rb` | code (new) | Operation: инициализация state при создании карточки |
| `db/migrate/*_create_user_lexeme_states.rb` | code (new) | Миграция |
| `db/migrate/*_create_user_sense_coverages.rb` | code (new) | Миграция |
| `db/migrate/*_create_user_context_family_coverages.rb` | code (new) | Миграция |
| `lib/tasks/word_mastery.rake` | code (new) | Backfill rake task |
| `spec/` | code (new) | Тесты для новых моделей и операций |

### Flow

1. Пользователь завершает ответ на карточку → `ReviewLog` создаётся с `correct: true/false`.
2. Если `correct: true`: вызывается `WordMastery::RecordCoverage(review_log)`.
3. `RecordCoverage` определяет sense и context_family через `review_log.card.sentence_occurrence`.
4. Создаёт `UserSenseCoverage` и `UserContextFamilyCoverage` (upsert, `first_correct_at` не перезаписывается).
5. Пересчитывает `covered_sense_count`, `total_sense_count`, `sense_coverage_pct` и аналоги для family в `UserLexemeState`.
6. `UserLexemeState` обновляется атомарно (transaction).

Backfill: rake task итерирует `ReviewLog.where(correct: true).order(:reviewed_at)` батчами, вызывает `RecordCoverage` для каждого.

### Contracts

| Contract ID | Input / Output | Producer / Consumer | Notes |
| --- | --- | --- | --- |
| `CTR-01` | `UserLexemeState`: `user_id`, `lexeme_id`, `covered_sense_count`, `total_sense_count`, `sense_coverage_pct`, `covered_family_count`, `total_family_count`, `family_coverage_pct`, `last_covered_at` | `WordMastery::RecordCoverage` / Session Builder v2, Dashboard | `sense_coverage_pct` и `family_coverage_pct` — decimal [0.0, 100.0]. Unique по `(user_id, lexeme_id)`. |
| `CTR-02` | `UserSenseCoverage`: `user_id`, `sense_id`, `first_correct_at` | `WordMastery::RecordCoverage` / `UserLexemeState` (aggregate source) | Unique по `(user_id, sense_id)`. Immutable после создания: `first_correct_at` не обновляется. |
| `CTR-03` | `UserContextFamilyCoverage`: `user_id`, `lexeme_id`, `context_family_id`, `first_correct_at` | `WordMastery::RecordCoverage` / `UserLexemeState` (aggregate source) | Unique по `(user_id, lexeme_id, context_family_id)`. Immutable после создания. |
| `CTR-04` | `WordMastery::RecordCoverage` input: `ReviewLog` instance (с загруженным `card.sentence_occurrence`) | Review session / BackfillTask | Idempotent: повторный вызов для одного review_log — no-op. |

### Schema Constraints

**user_lexeme_states:**
- `user_id` NOT NULL, FK → `users`, `on_delete: :cascade`
- `lexeme_id` (uuid) NOT NULL, FK → `lexemes`, `on_delete: :cascade`
- `covered_sense_count` integer, NOT NULL, default 0
- `total_sense_count` integer, NOT NULL, default 0
- `sense_coverage_pct` decimal(5,2), NOT NULL, default 0.0
- `covered_family_count` integer, NOT NULL, default 0
- `total_family_count` integer, NOT NULL, default 0
- `family_coverage_pct` decimal(5,2), NOT NULL, default 0.0
- `last_covered_at` datetime, nullable (NULL = no correct answers yet)
- Unique index: `(user_id, lexeme_id)`

**user_sense_coverages:**
- `user_id` NOT NULL, FK → `users`, `on_delete: :cascade`
- `sense_id` (uuid) NOT NULL, FK → `senses`, `on_delete: :cascade`
- `first_correct_at` datetime, NOT NULL
- Unique index: `(user_id, sense_id)`

**user_context_family_coverages:**
- `user_id` NOT NULL, FK → `users`, `on_delete: :cascade`
- `lexeme_id` (uuid) NOT NULL, FK → `lexemes`, `on_delete: :cascade`
- `context_family_id` (uuid) NOT NULL, FK → `context_families`, `on_delete: :cascade`
- `first_correct_at` datetime, NOT NULL
- Unique index: `(user_id, lexeme_id, context_family_id)`

### Failure Modes

- `FM-01` `SentenceOccurrence.sense_id` или `context_family_id` равен NULL — `RecordCoverage` логирует warning и пропускает coverage-обновление для недостающего измерения. `UserLexemeState` всё равно инициализируется/обновляется с нулевым покрытием по данному измерению. Ожидается только при неполном backfill FT-029.
- `FM-02` Повторный вызов `RecordCoverage` для одного `review_log.id` — idempotent: `UserSenseCoverage.insert_all` с `unique_by` не создаёт дублей; `UserLexemeState` пересчитывается из реального состояния coverage-таблиц.
- `FM-03` Backfill rake task прерван на полпути — resume через `WHERE NOT EXISTS` в coverage-таблицах. Частично backfill-нутое состояние консистентно: счётчики пересчитываются при resume.
- `FM-04` Новый sense добавлен к lexeme после того, как UserLexemeState уже создан — `total_sense_count` становится устаревшим до следующего правильного ответа пользователя. Acceptable для v1 (`ASM-03`). Future: periodic recalculation job.

## Verify

### Exit Criteria

- `EC-01` `UserLexemeState` существует для 100% карточек пользователя: `Card.joins(:user_lexeme_state).count == Card.count` после backfill.
- `EC-02` `sense_coverage_pct` корректно вычислен: для пользователя с N правильными ответами на разные senses одного lexeme — `covered_sense_count == N`, `sense_coverage_pct == N / total_sense_count * 100`.
- `EC-03` `UserSenseCoverage` создаётся только при `correct: true`; повторный правильный ответ на тот же sense не создаёт новую запись.
- `EC-04` `UserContextFamilyCoverage` аналогично `EC-03` для context_family.
- `EC-05` `RecordCoverage` idempotent: повторный вызов для одного `review_log.id` не меняет счётчики.
- `EC-06` Существующие карточки и review logs не изменены (non-destructive).

### Traceability matrix

| Requirement ID | Design refs | Acceptance refs | Checks | Evidence IDs |
| --- | --- | --- | --- | --- |
| `REQ-01` | `ASM-03`, `ASM-04`, `CON-01`, `CON-04`, `CTR-01` | `EC-01`, `EC-02`, `SC-01` | `CHK-01`, `CHK-02` | `EVID-01`, `EVID-02` |
| `REQ-02` | `CON-01`, `CTR-02`, `FM-02` | `EC-03`, `SC-02` | `CHK-03` | `EVID-03` |
| `REQ-03` | `CON-01`, `CTR-03`, `FM-02` | `EC-04`, `SC-02` | `CHK-03` | `EVID-03` |
| `REQ-04` | `ASM-02`, `CTR-04`, `FM-01`, `FM-02` | `EC-02`, `EC-03`, `EC-04`, `EC-05`, `SC-02`, `SC-03` | `CHK-04` | `EVID-04` |
| `REQ-05` | `ASM-05`, `CTR-01` | `EC-01`, `SC-01` | `CHK-01` | `EVID-01` |
| `REQ-06` | `ASM-06` (backfill), `FM-03` | `EC-01`, `SC-04` | `CHK-05` | `EVID-05` |
| `REQ-07` | `CTR-01` | `EC-01`, `SC-01` | `CHK-01` | `EVID-01` |

### Acceptance Scenarios

- `SC-01` Пользователь имеет 3 карточки: все к лексеме `run`. Вызов `WordMastery::InitializeState` создаёт один `UserLexemeState` для пары `(user, run_lexeme)`. `Card.joins(:user_lexeme_state).count == 3` (все три карточки смотрят на один state через user_id + lexeme_id).
- `SC-02` Пользователь отвечает правильно на карточку с occurrence (`sense: run_sport`, `context_family: sports`). `RecordCoverage` создаёт `UserSenseCoverage(run_sport)`, `UserContextFamilyCoverage(run, sports)`. `UserLexemeState` обновляется: `covered_sense_count = 1`, `covered_family_count = 1`. Повторный правильный ответ на другую карточку с тем же sense и той же family — не меняет счётчики. Ещё один правильный ответ на карточку с новым sense (`run_business`) — `covered_sense_count = 2`.
- `SC-03` Пользователь отвечает неправильно (`correct: false`). `RecordCoverage` не вызывается; `UserLexemeState` не меняется.
- `SC-04` Backfill rake task: для пользователя с историческими review_logs `correct: true` — после backfill `sense_coverage_pct` отражает реальное число уникальных сenses, встреченных с правильным ответом. Повторный запуск backfill — idempotent, счётчики не дублируются.

### Negative / Edge Cases

- `NEG-01` Lexeme с единственным sense и одной context_family: после первого правильного ответа `sense_coverage_pct = 100.0`, `family_coverage_pct = 100.0` — корректное состояние (BR-09 из PRD-002).
- `NEG-02` `SentenceOccurrence.sense_id == NULL` (edge case FT-029 неполного backfill): `RecordCoverage` не создаёт `UserSenseCoverage`, логирует warning. `UserLexemeState.sense_coverage_pct` остаётся 0.0 для этого измерения.
- `NEG-03` Удаление sense (cascade: `on_delete: :cascade` на `user_sense_coverages.sense_id`) — `UserSenseCoverage` удаляются; `UserLexemeState` пересчитывается или помечается как stale. **Удаление sense в продакшне ожидается крайне редко** — пересчёт lazy (при следующем правильном ответе) достаточен для v1.

### Checks

| Check ID | Covers | How to check | Expected result | Evidence path |
| --- | --- | --- | --- | --- |
| `CHK-01` | `EC-01`, `SC-01` | `bundle exec rspec spec/models/user_lexeme_state_spec.rb` + `Card.joins(:user_lexeme_state).count == Card.count` после `db:seed` | Все карточки имеют upstream state; модель корректна | `artifacts/ft-031/verify/chk-01/` |
| `CHK-02` | `EC-02`, `SC-01` | `bundle exec rspec spec/models/user_sense_coverage_spec.rb spec/models/user_context_family_coverage_spec.rb` | Уникальность, ассоциации, immutable `first_correct_at` | `artifacts/ft-031/verify/chk-02/` |
| `CHK-03` | `EC-03`, `EC-04`, `SC-02` | `bundle exec rspec spec/operations/word_mastery/record_coverage_spec.rb` (coverage creation path) | Создание только при `correct: true`; no duplicates | `artifacts/ft-031/verify/chk-03/` |
| `CHK-04` | `EC-05`, `SC-02`, `SC-03`, `NEG-01`, `NEG-02` | `bundle exec rspec spec/operations/word_mastery/record_coverage_spec.rb` (idempotency, edge cases) | Idempotency, wrong answer no-op, NULL sense warning | `artifacts/ft-031/verify/chk-04/` |
| `CHK-05` | `EC-01`, `SC-04` | `bundle exec rspec spec/tasks/word_mastery_rake_spec.rb` (backfill idempotency) | Backfill корректен и idempotent | `artifacts/ft-031/verify/chk-05/` |
| `CHK-06` | `EC-06` | `bundle exec rspec` (full suite) + DB counts: `Card.count`, `ReviewLog.count` unchanged | Non-destructive migration confirmed | `artifacts/ft-031/verify/chk-06/` |

### Test matrix

| Check ID | Evidence IDs | Evidence path |
| --- | --- | --- |
| `CHK-01` | `EVID-01` | `artifacts/ft-031/verify/chk-01/` |
| `CHK-02` | `EVID-02` | `artifacts/ft-031/verify/chk-02/` |
| `CHK-03` | `EVID-03` | `artifacts/ft-031/verify/chk-03/` |
| `CHK-04` | `EVID-04` | `artifacts/ft-031/verify/chk-04/` |
| `CHK-05` | `EVID-05` | `artifacts/ft-031/verify/chk-05/` |
| `CHK-06` | `EVID-06` | `artifacts/ft-031/verify/chk-06/` |

### Evidence

- `EVID-01` RSpec output: UserLexemeState model specs green + DB join query output.
- `EVID-02` RSpec output: UserSenseCoverage и UserContextFamilyCoverage model specs green.
- `EVID-03` RSpec output: RecordCoverage operation — coverage creation path green.
- `EVID-04` RSpec output: RecordCoverage operation — idempotency and edge cases green.
- `EVID-05` RSpec output: backfill rake spec green (coverage + idempotency).
- `EVID-06` RSpec full suite output + DB count comparison before/after migration.

### Evidence contract

| Evidence ID | Artifact | Producer | Path contract | Reused by checks |
| --- | --- | --- | --- | --- |
| `EVID-01` | RSpec output + DB query log | verify-runner | `artifacts/ft-031/verify/chk-01/` | `CHK-01` |
| `EVID-02` | RSpec output log | verify-runner | `artifacts/ft-031/verify/chk-02/` | `CHK-02` |
| `EVID-03` | RSpec output log | verify-runner | `artifacts/ft-031/verify/chk-03/` | `CHK-03` |
| `EVID-04` | RSpec output log | verify-runner | `artifacts/ft-031/verify/chk-04/` | `CHK-04` |
| `EVID-05` | RSpec output log | verify-runner | `artifacts/ft-031/verify/chk-05/` | `CHK-05` |
| `EVID-06` | RSpec full suite + DB counts | verify-runner | `artifacts/ft-031/verify/chk-06/` | `CHK-06` |

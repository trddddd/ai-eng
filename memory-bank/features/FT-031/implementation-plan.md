---
title: "FT-031: Implementation Plan"
doc_kind: feature
doc_function: derived
purpose: "Execution-план реализации FT-031 Word Mastery State. Фиксирует discovery context, шаги, риски и test strategy без переопределения canonical feature-фактов."
derived_from:
  - feature.md
status: archived
audience: humans_and_agents
must_not_define:
  - ft_031_scope
  - ft_031_architecture
  - ft_031_acceptance_criteria
  - ft_031_blocker_state
---

# План имплементации

## Цель текущего плана

Создать персистентный слой персонального состояния знания слова (word mastery state): три новых таблицы, модели, две операции, rake task для backfill и ассоциации на Card/User. После выполнения плана каждый correct answer обновляет coverage, а Session Builder v2 имеет O(1) доступ к `sense_coverage_pct` / `family_coverage_pct`.

## Current State / Reference Points

| Path / module | Current role | Why relevant | Reuse / mirror |
| --- | --- | --- | --- |
| `app/models/card.rb` | Card delegates `sense`, `context_family`, `lexeme` через `sentence_occurrence` | Путь от review_log к sense/family: `review_log.card.sense` / `.context_family` | Добавить `has_one :user_lexeme_state` через `user_id` + `lexeme_id` |
| `app/models/review_log.rb` | Фиксирует correct/incorrect ответ | `RecordCoverage` вызывается после correct review_log | Не меняется — consumer |
| `app/operations/reviews/record_answer.rb` | Создаёт review_log + schedule card в транзакции | Integration point: после `record_answer` вызвать `WordMastery::RecordCoverage` | Не меняется в этом PR — вызов будет добавлен в downstream feature (Session Builder) или в контроллере |
| `app/operations/content_bootstrap/base_operation.rb` | Pattern: `.call(...)`, `initialize`, private helpers | Шаблон для `WordMastery::RecordCoverage` и `InitializeState` | Повторить паттерн `.call(...)` |
| `app/operations/content_bootstrap/import_senses.rb` | Использует `insert_all` с `unique_by` для idempotent upsert | `RecordCoverage` должен использовать аналогичный upsert для coverage-таблиц | `insert_all` + `unique_by` |
| `lib/tasks/content_bootstrap.rake` | Rake task pattern: namespace, desc, task | Backfill rake task `word_mastery:backfill` | Тот же паттерн |
| `spec/factories/` | FactoryBot factories для всех сущностей | Нужны factories для `user_lexeme_state`, `user_sense_coverage`, `user_context_family_coverage` | Mirror existing factory patterns |
| `db/migrate/20260413220930_create_senses.rb` | UUID v7 PK pattern | Все новые таблицы должны использовать тот же паттерн: `t.column :id, :uuid, primary_key: true, default: -> { "uuidv7()" }` | Точный copy PK definition |
| `db/schema.rb` | `users.id` — `bigint`, `lexemes.id` — `uuid` | FK types: `user_id` → bigint, `lexeme_id` / `sense_id` / `context_family_id` → uuid | Critical для миграций |

### Key observations

- `users.id` — **bigint**, а не UUID. Все FK на `user_id` должны быть `t.references :user, type: :bigint`.
- `sense_id` и `context_family_id` на `sentence_occurrences` — **nullable** (NOT NULL constraints deferred в FT-029). `RecordCoverage` должен обрабатывать NULL через FM-01.
- `Card` не имеет прямого `lexeme_id` — получает через delegate `card.lexeme` → `card.sentence_occurrence.lexeme`. Ассоциация `has_one :user_lexeme_state` потребует custom scope.

## Test Strategy

| Test surface | Canonical refs | Existing coverage | Planned automated coverage | Required local suites / commands | Required CI suites / jobs | Manual-only gap / justification | Manual-only approval ref |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UserLexemeState model | `REQ-01`, `REQ-07`, `SC-01`, `CHK-01` | none | Validations, associations, `Card.joins(:user_lexeme_state)` | `bundle exec rspec spec/models/user_lexeme_state_spec.rb` | CI rspec | none | n/a |
| UserSenseCoverage model | `REQ-02`, `SC-02`, `CHK-02` | none | Uniqueness, associations, immutable `first_correct_at` | `bundle exec rspec spec/models/user_sense_coverage_spec.rb` | CI rspec | none | n/a |
| UserContextFamilyCoverage model | `REQ-03`, `SC-02`, `CHK-02` | none | Uniqueness, associations, immutable `first_correct_at` | `bundle exec rspec spec/models/user_context_family_coverage_spec.rb` | CI rspec | none | n/a |
| RecordCoverage operation | `REQ-04`, `FM-01`, `FM-02`, `SC-02`, `SC-03`, `NEG-01`, `NEG-02`, `CHK-03`, `CHK-04` | none | Coverage creation, idempotency, wrong answer skip, NULL sense warning | `bundle exec rspec spec/operations/word_mastery/record_coverage_spec.rb` | CI rspec | none | n/a |
| InitializeState operation | `REQ-05`, `SC-01`, `CHK-01` | none | State creation, idempotency (already exists) | `bundle exec rspec spec/operations/word_mastery/initialize_state_spec.rb` | CI rspec | none | n/a |
| Backfill rake task | `REQ-06`, `FM-03`, `SC-04`, `CHK-05` | none | Backfill correctness + idempotency | `bundle exec rspec spec/tasks/word_mastery_rake_spec.rb` | CI rspec | none | n/a |
| Full suite regression | `EC-06`, `CHK-06` | existing | No regressions | `bundle exec rspec` | CI rspec | none | n/a |

## Open Questions / Ambiguities

| Open Question ID | Question | Why unresolved | Blocks | Default action / escalation owner |
| --- | --- | --- | --- | --- |
| `OQ-01` | Когда именно вызывать `RecordCoverage` — внутри `Reviews::RecordAnswer` или в controller после? | Спека описывает operation, но не фиксирует integration point. Добавление вызова внутрь `RecordAnswer` меняет существующую транзакцию. | `STEP-06` (integration) | Вызов из controller/service layer после `RecordAnswer` — cleaner separation. Если нужно внутри — эскалация на архитектурное ревью |

## Environment Contract

| Area | Contract | Used by | Failure symptom |
| --- | --- | --- | --- |
| git | Feature branch `feat/031-word-mastery-state` активна | All steps | Агент работает в `main` — стоп, создать ветку |
| setup | `bin/rails db:migrate` успешен | `STEP-01` | Pending migrations |
| test | `bundle exec rspec` — зелёный suite до начала изменений | All steps | Red pre-existing tests — стоп, исследовать |
| lint | `bundle exec rubocop` — без offenses на новых файлах | All steps | Rubocop failures — исправить до коммита |

## Preconditions

| Precondition ID | Canonical ref | Required state | Used by steps | Blocks start |
| --- | --- | --- | --- | --- |
| `PRE-GIT` | `engineering/git-workflow.md` | Branch `feat/031-word-mastery-state` от `main` | All steps | **yes** |
| `PRE-01` | `ASM-01` | FT-029 завершена, таблицы `senses`, `context_families` существуют | `STEP-01` | **yes** |
| `PRE-02` | — | `bundle exec rspec` зелёный на `main` | All steps | **yes** |

## Orchestration Pattern

| Field | Value |
| --- | --- |
| **Pattern** | `sequential` |
| **Rationale** | Миграции должны пройти до моделей, модели — до операций, операции — до rake task и тестов. Change surface строго sequential. |

## Evidence Pre-Declaration

| Evidence ID | Canonical ref | Expected artifact | Expected path | Produced by step |
| --- | --- | --- | --- | --- |
| `EVID-01` | `CHK-01` | RSpec output: UserLexemeState model specs green | `artifacts/ft-031/verify/chk-01/` | `STEP-04` |
| `EVID-02` | `CHK-02` | RSpec output: coverage model specs green | `artifacts/ft-031/verify/chk-02/` | `STEP-04` |
| `EVID-03` | `CHK-03`, `CHK-04` | RSpec output: RecordCoverage + InitializeState specs green | `artifacts/ft-031/verify/chk-03/` | `STEP-05` |
| `EVID-04` | `CHK-05` | RSpec output: backfill rake spec green | `artifacts/ft-031/verify/chk-05/` | `STEP-06` |
| `EVID-05` | `CHK-06` | Full RSpec suite green | `artifacts/ft-031/verify/chk-06/` | `STEP-07` |
| `EVID-LAYERS` | `CP-LAYERS` | `/layers:review` report, no critical violations | — | `STEP-LAYERS-REVIEW` |

## Human Control Map

| Control Point ID | Trigger | Why human | What agent provides | Approved by |
| --- | --- | --- | --- | --- |
| `HC-01` | `db:migrate` execution | Миграции меняют схему БД | SQL миграций для review | user |

_Остальные шаги — fully autonomous, Approval Gates: n/a._

## Workstreams

| Workstream | Implements | Result | Owner | Dependencies |
| --- | --- | --- | --- | --- |
| `WS-1` | `REQ-01`, `REQ-02`, `REQ-03` | Миграции + модели трёх таблиц | agent | `PRE-01`, `PRE-GIT` |
| `WS-2` | `REQ-04`, `REQ-05` | Operations RecordCoverage + InitializeState | agent | `WS-1` |
| `WS-3` | `REQ-06` | Backfill rake task | agent | `WS-2` |
| `WS-4` | `REQ-07` | Card#user_lexeme_state ассоциация | agent | `WS-1` |

## Approval Gates

| Approval Gate ID | Trigger | Applies to | Why approval is required | Approver / evidence |
| --- | --- | --- | --- | --- |
| `AG-01` | Running `db:migrate` | `STEP-01` | Миграции необратимы в production; в dev тоже стоит confirm | user verbal confirmation |

## Порядок работ

| Step ID | Actor | Implements | Goal | Touchpoints | Artifact | Verifies | Evidence IDs | Check command | Blocked by | Needs approval | Escalate if |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `STEP-01` | agent | `REQ-01`, `REQ-02`, `REQ-03` | Создать 3 миграции для новых таблиц | `db/migrate/` | 3 migration files | Schema корректна | — | `bin/rails db:migrate` (после approval HC-01) | `PRE-GIT`, `PRE-01` | `AG-01` (db:migrate) | Migration fails |
| `STEP-02` | agent | `REQ-01`, `REQ-02`, `REQ-03` | Создать 3 модели с associations, validations | `app/models/` | 3 model files | — | — | `bundle exec rspec` (пока только model load) | `STEP-01` | none | Zeitwerk issues |
| `STEP-03` | agent | `REQ-07` | Добавить ассоциации в User и Card | `app/models/user.rb`, `app/models/card.rb` | Updated models | — | — | association tests | `STEP-02` | none | — |
| `STEP-04` | agent | `CHK-01`, `CHK-02` | Написать model specs + factories | `spec/`, `spec/factories/` | Spec files + factories | `EC-01`, `EC-02`, `EC-03`, `EC-04` | `EVID-01`, `EVID-02` | `bundle exec rspec spec/models/` | `STEP-03` | none | — |
| `STEP-05` | agent | `REQ-04`, `REQ-05` | Реализовать RecordCoverage + InitializeState + specs | `app/operations/word_mastery/`, `spec/operations/` | 2 operations + specs | `EC-02`–`EC-05`, `NEG-01`, `NEG-02` | `EVID-03` | `bundle exec rspec spec/operations/word_mastery/` | `STEP-04` | none | — |
| `STEP-06` | agent | `REQ-06` | Реализовать backfill rake task + spec | `lib/tasks/word_mastery.rake`, `spec/tasks/` | Rake task + spec | `EC-01`, `SC-04` | `EVID-04` | `bundle exec rspec spec/tasks/` | `STEP-05` | none | — |
| `STEP-07` | agent | `CHK-06` | Full suite regression | — | Green suite | `EC-06` | `EVID-05` | `bundle exec rspec` | `STEP-06` | none | Any red test |
| `STEP-08` | agent | — | Rubocop lint | All new/changed files | Clean lint | — | — | `bundle exec rubocop` | `STEP-07` | none | Offenses found |
| `STEP-LAYERS-REVIEW` | agent | — | Проверка архитектурных границ Layered Rails | Новые/изменённые файлы | Review report | `CP-LAYERS` | `EVID-LAYERS` | `/layers:review` | `STEP-08` | none | Critical violations |

## Parallelizable Work

- `PAR-01` Миграции (STEP-01) — sequential, но все 3 можно создать в одном шаге и прогнать одной `db:migrate`.
- `PAR-02` Model specs (STEP-04) — можно писать параллельно для трёх моделей, но sequential execution проще для small change surface.

## Checkpoints

| Checkpoint ID | Refs | Condition | Evidence IDs |
| --- | --- | --- | --- |
| `CP-01` | `STEP-01` | Миграции накачены, `db:migrate` без ошибок | — |
| `CP-02` | `STEP-04` | Model specs зелёные | `EVID-01`, `EVID-02` |
| `CP-03` | `STEP-05` | Operation specs зелёные | `EVID-03` |
| `CP-04` | `STEP-07` | Full suite зелёный | `EVID-05` |
| `CP-LAYERS` | `STEP-LAYERS-REVIEW` | `/layers:review` без критических нарушений | `EVID-LAYERS` |

## Execution Risks

| Risk ID | Risk | Impact | Mitigation | Trigger |
| --- | --- | --- | --- | --- |
| `ER-01` | `users.id` — bigint, а не UUID. Если указать неправильный тип FK, миграция упадёт или создаст несовместимый индекс. | Миграция откатывается | Явно указать `type: :bigint` для `user_id` references | migration failure |
| `ER-02` | `sense_id` / `context_family_id` nullable на `sentence_occurrences` — `RecordCoverage` может получить NULL | Coverage не обновляется | Реализовать FM-01: skip с warning при NULL | Тест NEG-02 |
| `ER-03` | Rubocop LineLength violations в rake task (pattern из FT-029) | Линт падает | Следить за длинами строк, использовать `# rubocop:disable` при необходимости | `bundle exec rubocop` |

## Stop Conditions / Fallback

| Stop ID | Related refs | Trigger | Immediate action | Safe fallback state |
| --- | --- | --- | --- | --- |
| `STOP-01` | `PRE-02` | `bundle exec rspec` красный на `main` до начала | Эскалация user: pre-existing failures | Не начинать работу |
| `STOP-02` | `STEP-01` | Migration необратимо падает | Откат: `bin/rails db:migrate:down VERSION=<ts>` | Возвращаемся к `STEP-01` redesign |
| `STOP-03` | `STEP-07` | Full suite regression красный после всех изменений | Найти regression, откатить проблемный step | Последний зелёный checkpoint |

## Готово для приемки

- `STEP-07` завершён: full suite зелёный (`EVID-05`)
- `STEP-08` завершён: rubocop чист
- `STEP-LAYERS-REVIEW` завершён: нет критических архитектурных нарушений (`EVID-LAYERS`)
- Все `EVID-01`–`EVID-05` собраны
- `feature.md` → `delivery_status: done` после верификации user

---
title: "FT-034: Implementation Plan"
doc_kind: feature
doc_function: derived
purpose: "Execution-план реализации FT-034. Фиксирует discovery context, шаги, риски и test strategy без переопределения canonical feature-фактов."
derived_from:
  - feature.md
status: active
audience: humans_and_agents
must_not_define:
  - ft_034_scope
  - ft_034_architecture
  - ft_034_acceptance_criteria
  - ft_034_blocker_state
---

# План имплементации FT-034

## Цель текущего плана

Реализовать интеграцию `WordMastery::RecordCoverage` в runtime review flow, добавить трассируемость review → mastery через `LexemeReviewContribution`, обновить Dashboard для отображения word-level прогресса в трёх buckets.

## Current State / Reference Points

| Path / module | Current role | Why relevant | Reuse / mirror |
| --- | --- | --- | --- |
| `app/operations/reviews/record_answer.rb` | Создаёт ReviewLog, вызывает `card.schedule!` в `ActiveRecord::Base.transaction` | Точка интеграции RecordCoverage; transaction boundary; возвращает `review_log` | Добавить `RecordCoverage.call(review_log:)` внутри той же transaction после `schedule!` |
| `app/operations/word_mastery/record_coverage.rb` | Обновляет UserSenseCoverage, UserContextFamilyCoverage, UserLexemeState; имеет собственную `ActiveRecord::Base.transaction` | Требует изменения: убрать inner transaction (CON-05), добавить contribution_type compute + LexemeReviewContribution creation | Сохранить upsert pattern; добавить private method для truth table ASM-03 |
| `app/models/review_log.rb` | Логирует факт ответа; belongs_to :card | Получает `has_one :lexeme_review_contribution` | Паттерн `has_one` из других моделей проекта |
| `app/operations/dashboard/build_progress.rb` | Возвращает `Progress = Struct.new(:streak, :words_learned, :daily_reviews, :daily_goal)` | `words_learned` заменяется 4 word-bucket полями; DashboardController и view зависят от struct | Расширить Struct; добавить UserLexemeState query с bucket grouping |
| `app/views/dashboard/index.html.erb` | 3 карточки: streak / words_learned / daily_goal | Карточка words_learned заменяется word progress card с empty state (FM-04) | Повторить pattern bg-surface-container-low card; добавить bucket display и CTA-ссылку |
| `lib/tasks/word_mastery.rake` | Backfill coverage из `ReviewLog.correct`; вызывает `RecordCoverage.call` без transaction | После удаления inner transaction в RecordCoverage backfill **обязан** оборачивать каждый вызов в transaction; нужен skip по существующему contribution (NEG-04) | Добавить `ActiveRecord::Base.transaction { }` + `next if LexemeReviewContribution.exists?(review_log_id: rl.id)` |
| `spec/operations/reviews/record_answer_spec.rb` | Тесты RecordAnswer: ReviewLog создан, rating, rollback | Добавить: RecordCoverage spy при correct=true; no-call при correct=false; rollback при RecordCoverage raise | Паттерн `allow(X).to receive(:call)` + spy |
| `spec/operations/word_mastery/record_coverage_spec.rb` | Тесты coverage creation, idempotency, NULL sense | Добавить: LexemeReviewContribution создаётся с правильным contribution_type по ASM-03; идемпотентность через skip | Расширить существующие describe-блоки; добавить describe "contribution type" |
| `spec/operations/dashboard/build_progress_spec.rb` | Тесты streak/words_learned/daily_reviews/daily_goal | `words_learned` тесты устаревают (поле убирается); добавить: word bucket counts, zero state | Обновить тесты zero state; добавить describe "word progress buckets" |
| `spec/tasks/word_mastery_rake_spec.rb` | Тесты backfill: creates coverage, idempotency, skips incorrect | Добавить: contribution создаётся при backfill; contribution не дублируется при повторном запуске | Расширить "is idempotent" тест |

## Test Strategy

| Test surface | Canonical refs | Existing coverage | Planned automated coverage | Required local suites | Required CI suites | Manual-only gap / justification |
| --- | --- | --- | --- | --- | --- | --- |
| `RecordAnswer` + `RecordCoverage` integration | `REQ-01`, `EC-01`, `EC-03`, `EC-05`, `SC-01`, `CHK-01` | RecordAnswer: creates ReviewLog, rating, rollback on schedule! fail | + spy: RecordCoverage.call вызван при correct=true; + UserLexemeState обновлён; + correct=false: RecordCoverage не вызван; + rollback если RecordCoverage raises | `bundle exec rspec spec/operations/reviews/record_answer_spec.rb` | rails.yml test job | — |
| `RecordCoverage` contribution creation | `REQ-02`, `REQ-03`, `EC-02`, `SC-02`, `SC-03`, `NEG-01`, `NEG-02`, `CHK-02` | coverage records, idempotency, NULL sense | + LexemeReviewContribution создаётся; + contribution_type по ASM-03 truth table (все 4 ветки); + idempotency: второй вызов с тем же review_log → skip | `bundle exec rspec spec/operations/word_mastery/record_coverage_spec.rb` | rails.yml test job | — |
| `Dashboard::BuildProgress` word buckets | `REQ-04`, `EC-04`, `SC-04`, `NEG-03`, `CHK-03` | streak/words_learned (устаревает)/daily_reviews/daily_goal | + Progress struct содержит 4 word-bucket поля; + bucket counts из UserLexemeState по sense_coverage_pct; + zero total_words_tracked; + words_learned убран из struct | `bundle exec rspec spec/operations/dashboard/build_progress_spec.rb` | rails.yml test job | — |
| Dashboard view word progress card | `REQ-05`, `EC-04`, `FM-04` | — | — (ERB: rubocop не применяется) | визуальная проверка вручную | — | Visual UI: manual-only per testing-policy.md |
| Backfill rake task | `EC-06`, `NEG-04`, `CHK-04` | creates coverage, idempotency, skips incorrect | + contribution создаётся при backfill; + повторный запуск не дублирует contribution | `bundle exec rspec spec/tasks/word_mastery_rake_spec.rb` | rails.yml test job | — |
| Full suite | `CHK-05` | — | all above + rubocop | `bundle exec rspec && bundle exec rubocop` | rails.yml lint + test | — |

## Open Questions / Ambiguities

Нет открытых вопросов после grounding.

## Environment Contract

| Area | Contract | Used by | Failure symptom |
| --- | --- | --- | --- |
| git | Attempt worktree `../lingvize-ft-034-att1` создан от `main`; внутри worktree branch `feat/ft-034-att1` | All implementation steps | Агент работает прямо в основном checkout или `main` — стоп, создать worktree |
| db | `bin/rails db:migrate` выполнена после `STEP-01`; `db/schema.rb` содержит `lexeme_review_contributions` | `STEP-02`—`STEP-10` | `ActiveRecord::StatementInvalid: table "lexeme_review_contributions" does not exist` |
| test | `bundle exec rspec` + `bundle exec rubocop` зелёные после каждого impl-шага | Все CHK-* | Red suite = стоп, fix перед следующим шагом |
| access | Без внешних зависимостей; PostgreSQL локально | All steps | — |

## Preconditions

| Precondition ID | Canonical ref | Required state | Used by steps | Blocks start |
| --- | --- | --- | --- | --- |
| `PRE-GIT` | `engineering/git-workflow.md` | Attempt worktree `../lingvize-ft-034-att1` создан от `main`; `git worktree list` показывает worktree; внутри worktree `git branch --show-current` → `feat/ft-034-att1` | All implementation steps | **yes** — создать автономно: `git worktree add -b feat/ft-034-att1 ../lingvize-ft-034-att1` |
| `PRE-ASM-01` | `ASM-01` | FT-031 завершена: `UserLexemeState`, `UserSenseCoverage`, `UserContextFamilyCoverage`, `WordMastery::RecordCoverage` существуют | All steps | yes — verified by grounding |
| `PRE-ASM-02` | `ASM-02` | FT-029 завершена: `Sense`, `ContextFamily`, `SentenceOccurrence.sense_id` nullable | All steps | yes — verified by grounding |

## Orchestration Pattern

| Field | Value |
| --- | --- |
| **Pattern** | `sequential` |
| **Rationale** | Выбран `sequential`, потому что schema + transaction-boundary изменения несут data-integrity риск, а coordination overhead параллельных worktrees выше выгоды. Потенциально независимый WS-3 зафиксирован в `Parallelizable Work` как candidate, но не выбран для attempt-1 |

## Evidence Pre-Declaration

| Evidence ID | Canonical ref | Expected artifact | Expected path | Produced by step |
| --- | --- | --- | --- | --- |
| `EVID-01` | `CHK-01`, `SC-01`, `EC-01`, `EC-05` | RSpec output: record_answer_spec green | `artifacts/ft-034/verify/chk-01/` | `STEP-10` |
| `EVID-02` | `CHK-02`, `EC-02`, `EC-03`, `SC-02`, `SC-03`, `NEG-01`, `NEG-02` | RSpec output: record_coverage_spec green | `artifacts/ft-034/verify/chk-02/` | `STEP-10` |
| `EVID-03` | `CHK-03`, `EC-04`, `SC-04`, `NEG-03` | RSpec output: build_progress_spec green | `artifacts/ft-034/verify/chk-03/` | `STEP-10` |
| `EVID-04` | `CHK-04`, `NEG-04`, `EC-06` | RSpec output: word_mastery_rake_spec green | `artifacts/ft-034/verify/chk-04/` | `STEP-10` |
| `EVID-05` | `CHK-05` | Full RSpec suite + RuboCop output green | `artifacts/ft-034/verify/chk-05/` | `STEP-10` |
| `EVID-EVAL-SUITE` | `CP-EVAL-SUITE` | eval/suite/*.md существуют и валидны | `memory-bank/features/FT-034/eval/` | `STEP-EVAL-VERIFY` |
| `EVID-LAYERS` | `CP-LAYERS` | /layers:review report без критических нарушений | `artifacts/ft-034/verify/layers/` | `STEP-LAYERS-REVIEW` |
| `EVID-SIMPLIFY` | `CP-SIMPLIFY` | simplify review report: complexity justified or reduced | `artifacts/ft-034/verify/simplify/` | `STEP-SIMPLIFY` |
| `EVID-EVAL-RUN` | `CP-EVAL-RUN` | eval/results/summary.md с decision | `memory-bank/features/FT-034/eval/results/` | `STEP-EVAL-RUN` |

## Human Control Map

| Control Point ID | Trigger | Why human | What agent provides | Approved by |
| --- | --- | --- | --- | --- |
| `HC-01` | Перед запуском `bin/rails db:migrate` для новой таблицы `lexeme_review_contributions` | Миграция меняет schema и добавляет FK/index contracts | Diff миграции, ожидаемый `db/schema.rb` delta, rollback command `bin/rails db:migrate:down VERSION=<timestamp>` | user |
| `HC-02` | Если реализация требует отклониться от `CON-05` transaction boundary | Меняется архитектурное решение atomicity/retry semantics | Короткий trade-off note + предложение ADR или update feature.md | user |

## Workstreams

| Workstream | Implements | Result | Owner | Dependencies |
| --- | --- | --- | --- | --- |
| `WS-1` | `REQ-02`, `CON-01`, `CTR-01` | Migration + LexemeReviewContribution model + ReviewLog has_one | agent | — |
| `WS-2` | `REQ-01`, `REQ-03`, `CTR-02`, `CON-04`, `CON-05` | RecordCoverage обновлён (transaction removed, contribution created); RecordAnswer вызывает RecordCoverage | agent | WS-1 complete |
| `WS-3` | `REQ-04`, `REQ-05`, `CTR-03` | BuildProgress + dashboard view + i18n | agent | WS-1 complete (UserLexemeState schema в норме) |
| `WS-4` | `EC-06`, `NEG-04` | Backfill rake task обновлён: transaction wrapper + contribution skip | agent | WS-2 complete (RecordCoverage API изменился) |
| `WS-5` | All CHK-* | Все spec-суиты зелёные | agent | WS-1—WS-4 complete |

## Approval Gates

| Approval Gate ID | Trigger | Applies to | Why approval is required | Approver / evidence |
| --- | --- | --- | --- | --- |
| `AG-01` | После создания migration file, до первого `bin/rails db:migrate` | `STEP-01` | Schema change с FK/index; нужно показать diff до применения | `HC-01` approval in chat |
| `AG-02` | Любое отклонение от `CON-05` | `STEP-04`, `STEP-06`, `STOP-01` | Transaction-boundary change может нарушить atomicity/backfill guarantees | `HC-02` approval in chat или ADR |

## Порядок работ

| Step ID | Actor | Implements | Goal | Touchpoints | Artifact | Verifies | Evidence IDs | Check command | Blocked by | Needs approval | Escalate if |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `STEP-EVAL-VERIFY` | agent | — | Проверить, что eval suite создан до кода и покрывает `SC-*` / `NEG-*` | `eval/strategy.md`, `eval/suite/*.md` | eval suite verified | `CP-EVAL-SUITE` | `EVID-EVAL-SUITE` | `ls memory-bank/features/FT-034/eval/suite/` | none | none | suite отсутствует или не покрывает feature refs → обновить suite до worktree |
| `STEP-01` | agent | `REQ-02`, `CON-01`, `CON-02` | Создать миграцию `lexeme_review_contributions`; показать diff; после `AG-01` применить миграцию | `db/migrate/<ts>_create_lexeme_review_contributions.rb` | migration file + schema delta | — | — | `bin/rails db:migrate` | `PRE-GIT` | `AG-01` before migrate | db:migrate fails |
| `STEP-02` | agent | `REQ-02`, `CTR-01`, `CON-01` | Создать модель `LexemeReviewContribution` с validations + associations | `app/models/lexeme_review_contribution.rb` | model file | — | — | `bundle exec rubocop app/models/lexeme_review_contribution.rb` | `STEP-01` | none | модель не соответствует schema constraints |
| `STEP-03` | agent | `CTR-01` | Добавить `has_one :lexeme_review_contribution` в `ReviewLog` | `app/models/review_log.rb` | обновлённый review_log.rb | — | — | `bundle exec rubocop app/models/review_log.rb` | `STEP-02` | none | — |
| `STEP-04` | agent | `REQ-03`, `CTR-01`, `CTR-02`, `CON-05`, `ASM-03`, `FM-01`, `FM-02`, `FM-03` | Обновить `RecordCoverage`: (1) убрать `ActiveRecord::Base.transaction`; (2) добавить `compute_contribution_type` по truth table ASM-03; (3) добавить `LexemeReviewContribution` creation; (4) добавить early return при существующем contribution (FM-03 / NEG-04) | `app/operations/word_mastery/record_coverage.rb` | обновлённый record_coverage.rb | `CHK-02` | `EVID-02` | `bundle exec rspec spec/operations/word_mastery/record_coverage_spec.rb` | `STEP-03` | `AG-02` only if deviating from `CON-05` | contribution_type не соответствует truth table → исправить logic |
| `STEP-05` | agent | `REQ-01`, `CTR-02`, `CON-04`, `CON-05` | Добавить вызов `WordMastery::RecordCoverage.call(review_log: review_log)` в `RecordAnswer` внутри transaction после `card.schedule!` | `app/operations/reviews/record_answer.rb` | обновлённый record_answer.rb | `CHK-01` | `EVID-01` | `bundle exec rspec spec/operations/reviews/record_answer_spec.rb` | `STEP-04` | none | existing tests red → investigate transaction / return value |
| `STEP-06` | agent | `EC-06`, `NEG-04` | Обновить backfill rake task: (1) обернуть каждый `RecordCoverage.call` в `ActiveRecord::Base.transaction`; (2) добавить skip если `LexemeReviewContribution.exists?` для данного review_log_id | `lib/tasks/word_mastery.rake` | обновлённый word_mastery.rake | `CHK-04` | `EVID-04` | `bundle exec rspec spec/tasks/word_mastery_rake_spec.rb` | `STEP-04` | none | backfill тесты red после изменения RecordCoverage API |
| `STEP-07` | agent | `REQ-04`, `ASM-05`, `CTR-03` | Обновить `Dashboard::BuildProgress`: (1) расширить Progress struct: добавить `words_zero_coverage`, `words_partial_coverage`, `words_full_coverage`, `total_words_tracked`; (2) убрать `words_learned`; (3) добавить bucket query из UserLexemeState по sense_coverage_pct | `app/operations/dashboard/build_progress.rb` | обновлённый build_progress.rb | `CHK-03` | `EVID-03` | `bundle exec rspec spec/operations/dashboard/build_progress_spec.rb` | `STEP-01` | none | DashboardController/view ломается при смене struct → исправить оба |
| `STEP-08` | agent | `REQ-05`, `FM-04` | Обновить dashboard view: заменить вторую карточку (words_learned) на word progress card с тремя bucket-значениями; добавить empty state при `total_words_tracked = 0` и encouraging text при `words_zero_coverage == total_words_tracked > 0` (FM-04) | `app/views/dashboard/index.html.erb` | обновлённый index.html.erb | `EC-04` visual | — | визуальная проверка | `STEP-07` | none | — |
| `STEP-09` | agent | `REQ-05` | Добавить i18n ключи для word progress labels | `config/locales/en.yml`, `config/locales/ru.yml` | обновлённые locale files | — | — | `bin/rails assets:precompile` не падает | `STEP-08` | none | missing i18n key → `I18n::MissingTranslationData` |
| `STEP-10` | agent | All CHK-* | Финальный прогон full suite; обновить spec-файлы для покрытия новых paths | все spec-файлы + `bundle exec rspec && bundle exec rubocop` | full suite output | `CHK-05` | `EVID-05` | `bundle exec rspec && bundle exec rubocop` | All prev steps | none | red → fix перед Done |
| `STEP-LAYERS-REVIEW` | agent | — | Проверка архитектурных границ Layered Rails | все новые/изменённые Ruby-файлы | layers review report | `CP-LAYERS` | `EVID-LAYERS` | `/layers:review` | `STEP-10` | none | critical violations → создать ADR |
| `STEP-SIMPLIFY` | agent | — | Simplify review: проверить, что решение минимально сложно, а оставшаяся complexity обоснована `CON-*`, `FM-*` или `DEC-*` | все новые/изменённые файлы | simplify review report | `CP-SIMPLIFY` | `EVID-SIMPLIFY` | `/simplify` | `STEP-LAYERS-REVIEW` | none | complexity не обоснована → revise до eval run |
| `STEP-EVAL-RUN` | agent | — | Выполнение eval suite | `eval/results/summary.md` | decision: accept/revise/escalate/split | `CP-EVAL-RUN` | `EVID-EVAL-RUN` | `/eval:run` | `STEP-SIMPLIFY` | none | critical regression → эскалация |

## Parallelizable Work

- `PAR-01` WS-3 (BuildProgress + view + i18n, `STEP-07`—`STEP-09`) потенциально независим от WS-2 (`STEP-04`—`STEP-05`) после WS-1. Для attempt-1 параллельность **не выбрана**; использовать только если pattern сменён на `parallel` и merge strategy добавлена в `attempts/attempt-1/meta.yaml`.
- `PAR-02` Нельзя параллелить `STEP-04` и `STEP-05`: RecordAnswer зависит от нового API RecordCoverage.
- `PAR-03` Нельзя параллелить `STEP-06` и `STEP-04`: backfill зависит от финального RecordCoverage (transaction boundary).

## Checkpoints

| Checkpoint ID | Refs | Condition | Evidence IDs |
| --- | --- | --- | --- |
| `CP-01` | `STEP-01`—`STEP-03` | Migration applied; `db/schema.rb` содержит `lexeme_review_contributions` с expected columns; LexemeReviewContribution model + ReviewLog has_one созданы | — |
| `CP-02` | `STEP-04`, `STEP-05` | RecordAnswer вызывает RecordCoverage внутри transaction; RecordCoverage создаёт LexemeReviewContribution; inner transaction убрана | `EVID-01`, `EVID-02` |
| `CP-03` | `STEP-06` | Backfill работает с transaction wrapper; contribution idempotency через skip | `EVID-04` |
| `CP-04` | `STEP-07`—`STEP-09` | Dashboard показывает word progress buckets; view renders без missing i18n | `EVID-03` |
| `CP-EVAL-SUITE` | `STEP-EVAL-VERIFY` | `eval/suite/happy-path.md`, `edge-cases.md`, `regression.md` существуют и покрывают `SC-*` / `NEG-*` | `EVID-EVAL-SUITE` |
| `CP-LAYERS` | `STEP-LAYERS-REVIEW` | `/layers:review` без критических нарушений архитектурных границ | `EVID-LAYERS` |
| `CP-SIMPLIFY` | `STEP-SIMPLIFY` | `/simplify` выполнен; complexity минимальна или обоснована upstream refs | `EVID-SIMPLIFY` |
| `CP-EVAL-RUN` | `STEP-EVAL-RUN` | Eval suite выполнен: decision accept/revise/escalate/split | `EVID-EVAL-RUN` |

## Execution Risks

| Risk ID | Risk | Impact | Mitigation | Trigger |
| --- | --- | --- | --- | --- |
| `ER-01` | Удаление inner transaction в RecordCoverage ломает backfill rake task | Backfill выполняется без транзакционной гарантии, данные частично записаны | STEP-06 обязательно добавляет transaction wrapper; тест проверяет | `word_mastery_rake_spec` red после STEP-04 |
| `ER-02` | `words_learned` убирается из Progress struct — DashboardController может ссылаться на него в других местах | NoMethodError в production | Проверить все ссылки на `@progress.words_learned` в views/controllers перед `STEP-07` | `bundle exec rspec` red после STEP-07 |
| `ER-03` | `build_progress_spec.rb` тестирует `words_learned` — spec устаревает | CHK-03 red не из-за логики, а из-за устаревшего spec | Обновить spec при `STEP-07`: убрать `words_learned` тесты, добавить bucket тесты | Spec fail с `NoMethodError: undefined method words_learned` |
| `ER-04` | LexemeReviewContribution unique constraint на `review_log_id` не обрабатывается gracefully при повторном вызове | `ActiveRecord::RecordNotUnique` вместо silent idempotency | Добавить early return в RecordCoverage: `return if LexemeReviewContribution.exists?(review_log_id: rl.id)` | idempotency spec fails |

## Stop Conditions / Fallback

| Stop ID | Related refs | Trigger | Immediate action | Safe fallback state |
| --- | --- | --- | --- | --- |
| `STOP-01` | `CON-05` | RecordCoverage без inner transaction + backfill без outer transaction → data integrity issue | Стоп; либо вернуть transaction в RecordCoverage и задокументировать решение в ADR | FT-034 frozen до ADR |
| `STOP-02` | `CON-03` | Обнаружено что нужен новый гем | Стоп, эскалация к пользователю | Не добавлять без подтверждения |

## Готово для приемки

**Обязательные eval условия:**
- `EVID-EVAL-SUITE`: Eval suite создан: `eval/suite/happy-path.md`, `edge-cases.md`, `regression.md` существуют и содержат валидные test cases
- `EVID-EVAL-RUN`: `/eval:run` возвращает `accept` для перехода в Done; `revise` оставляет feature в Execution с понятными next steps

**Обязательные Layered Rails условия:**
- `EVID-LAYERS`: `/layers:review` выполнен на всех новых/изменённых файлах после реализации, критических нарушений архитектурных границ нет

**Обязательные simplify условия:**
- `EVID-SIMPLIFY`: `/simplify` выполнен после Layered Rails review и до `/eval:run`; оставшаяся complexity обоснована ссылками на `CON-*`, `FM-*` или `DEC-*`

**Обязательные spec-gates:**
- `EVID-01`—`EVID-05`: все RSpec суиты зелёные; `bundle exec rubocop` зелёный

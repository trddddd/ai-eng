---
title: "FT-036: Implementation Plan"
doc_kind: feature
doc_function: derived
purpose: "Execution-план реализации FT-036. Фиксирует discovery context, шаги, риски и test strategy без переопределения canonical feature-фактов."
derived_from:
  - feature.md
status: archived
audience: humans_and_agents
must_not_define:
  - ft_036_scope
  - ft_036_architecture
  - ft_036_acceptance_criteria
  - ft_036_blocker_state
---

# План имплементации

## Цель текущего плана

Расширить `Reviews::BuildSession` двухуровневым планированием: card debt (текущее поведение) + word debt (заполнение оставшихся слотов карточками для слабо покрытых слов). Результат — единообразная коллекция Card objects; интерфейс `BuildSession.call(user:, limit:, now:)` сохраняется.

## Current State / Reference Points

| Path / module | Current role | Why relevant | Reuse / mirror |
| --- | --- | --- | --- |
| `app/operations/reviews/build_session.rb` (24 LOC) | Возвращает AR::Relation due cards с eager loading, limit, order by due ASC | Единственный файл, который изменяется | Сохранить eager loading pattern `.includes(sentence_occurrence: [{sentence: :sentence_translations}, {lexeme: :lexeme_glosses}])` |
| `spec/operations/reviews/build_session_spec.rb` (34 LOC) | 5 тестов: due cards sorted, excludes future, excludes mastered, limits batch, empty | Существующие тесты не должны регрессировать | Структура describe/context/it |
| `app/models/card.rb` | FSRS card, scope `due_for_review`, unique `(user_id, sentence_occurrence_id)`, STATE_NEW=0 | Word debt cards создаются через `Card.create!` с default FSRS state | `Card::STATE_NEW`, default FSRS attrs из factory |
| `app/models/user_lexeme_state.rb` | Coverage tracking: `family_coverage_pct`, `sense_coverage_pct`, `last_covered_at` | Источник word debt candidates | `belongs_to :lexeme`, unique `(user_id, lexeme_id)` |
| `app/models/user_context_family_coverage.rb` | Tracks covered `(user, lexeme, context_family)` | Определяет, какие families уже покрыты | unique `(user_id, lexeme_id, context_family_id)` |
| `app/models/user_sense_coverage.rb` | Tracks covered `(user, sense)` | Fallback: если все families покрыты, ищем uncovered sense | unique `(user_id, sense_id)` |
| `app/models/sentence_occurrence.rb` | Bridge sentence↔lexeme; optional `sense_id`, `context_family_id` | Pool для word debt occurrence selection | `has_many :cards`, unique `(sentence_id, lexeme_id)` |

**Ключевое наблюдение:** текущий `BuildSession#call` возвращает `ActiveRecord::Relation`. Word debt требует on-demand card creation, поэтому результат станет `Array<Card>` — relation `.to_a` + созданные cards. Это не ломает view layer (итерация по коллекции), но меняет тип с Relation на Array.

## Test Strategy

| Test surface | Canonical refs | Existing coverage | Planned automated coverage | Required local suites / commands | Required CI suites / jobs | Manual-only gap / justification | Manual-only approval ref |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `spec/operations/reviews/build_session_spec.rb` — card debt path | `REQ-01`, `REQ-02`, `SC-01`, `SC-04`, `NEG-05`, `CHK-01` | 5 тестов: due sorted, excludes future/mastered, limits, empty | Существующие тесты сохраняются без изменений; добавить тест `SC-01` (card debt fills limit → no word debt) | `bundle exec rspec spec/operations/reviews/build_session_spec.rb` | `rails.yml` rspec job | none | none |
| `spec/operations/reviews/build_session_spec.rb` — word debt path | `REQ-03`–`REQ-06`, `SC-02`, `SC-03`, `SC-05`, `NEG-01`–`NEG-04`, `NEG-06`, `NEG-07`, `CHK-02` | none | Новые тесты: mixed session, unseen family preference, sense fallback, one-per-lexeme, no candidates, skip NULL context_family, skip existing card, race condition skip, limit 0 | `bundle exec rspec spec/operations/reviews/build_session_spec.rb` | `rails.yml` rspec job | none | none |
| Full regression | `CHK-03` | Full suite | No changes outside BuildSession | `bundle exec rspec` | `rails.yml` rspec job | none | none |

## Open Questions / Ambiguities

| Open Question ID | Question | Why unresolved | Blocks | Default action / escalation owner |
| --- | --- | --- | --- | --- |
| `OQ-01` | Нужен ли eager loading для word debt cards? | Word debt cards создаются on-demand — AR relation includes не применяется автоматически | `STEP-02` | Default: preload те же associations для word debt cards вручную через `ActiveRecord::Associations::Preloader`. Если performance не критична для v1 (pool < 100), допустим individual card reload. |

## Environment Contract

| Area | Contract | Used by | Failure symptom |
| --- | --- | --- | --- |
| git | Attempt worktree создан (`git worktree list` содержит `../lingvize-ft-036-att1`, branch `feat/ft-036-att1`) | All implementation steps | Агент работает в основном checkout — стоп, создать worktree |
| test | `bundle exec rspec spec/operations/reviews/build_session_spec.rb` — зелёный | `CHK-01`, `CHK-02` | Любой failure блокирует следующий step |
| test | `bundle exec rspec` — полный suite зелёный | `CHK-03` | Regression блокирует ship |
| lint | `bundle exec rubocop` — зелёный | Hygiene | Lint failure блокирует ship |

## Preconditions

| Precondition ID | Canonical ref | Required state | Used by steps | Blocks start |
| --- | --- | --- | --- | --- |
| `PRE-GIT` | `engineering/git-workflow.md` | Attempt worktree `../lingvize-ft-036-att1` создан от `main`; `git branch --show-current` → `feat/ft-036-att1` | All steps | **yes** |
| `PRE-01` | `ASM-01` | FT-031, FT-034 завершены: `UserLexemeState`, `UserSenseCoverage`, `UserContextFamilyCoverage` существуют в schema | All steps | yes |
| `PRE-02` | `ASM-02` | `SentenceOccurrence` имеет nullable `sense_id` и `context_family_id` — подтверждено grounding | All steps | yes (confirmed) |

## Orchestration Pattern

| Field | Value |
| --- | --- |
| **Pattern** | `sequential` |
| **Rationale** | Change surface — 1 operation + 1 spec file; параллелизм не даёт выигрыша; merge-конфликты гарантированы при split |

## Evidence Pre-Declaration

| Evidence ID | Canonical ref | Expected artifact | Expected path | Produced by step |
| --- | --- | --- | --- | --- |
| `EVID-01` | `CHK-01`, `SC-01`, `SC-04` | RSpec output: card debt path green | `artifacts/ft-036/verify/chk-01/` | `STEP-02` |
| `EVID-02` | `CHK-02`, `SC-02`, `SC-03`, `SC-05` | RSpec output: word debt path green | `artifacts/ft-036/verify/chk-02/` | `STEP-02` |
| `EVID-03` | `CHK-03` | RSpec full suite output: all green | `artifacts/ft-036/verify/chk-03/` | `STEP-03` |
| `EVID-EVAL-SUITE` | `CP-EVAL-SUITE` | Eval suite verified | — | `STEP-EVAL-VERIFY` |
| `EVID-LAYERS` | `CP-LAYERS` | `/layers:review` report | — | `STEP-LAYERS-REVIEW` |
| `EVID-SIMPLIFY` | `CP-SIMPLIFY` | `/simplify` report | — | `STEP-SIMPLIFY` |
| `EVID-EVAL-RUN` | `CP-EVAL-RUN` | Eval decision | — | `STEP-EVAL-RUN` |

## Human Control Map

| Control Point ID | Trigger | Why human | What agent provides | Approved by |
| --- | --- | --- | --- | --- |
| none | — | fully autonomous | — | Approval Gates: n/a |

## Workstreams

| Workstream | Implements | Result | Owner | Dependencies |
| --- | --- | --- | --- | --- |
| `WS-1` | `REQ-01`–`REQ-06`, `CTR-01`, `CTR-02` | `build_session.rb` с dual-level scheduling + полный spec coverage | agent | `PRE-GIT`, `PRE-01` |

## Approval Gates

Нет — fully autonomous.

## Порядок работ

| Step ID | Actor | Implements | Goal | Touchpoints | Artifact | Verifies | Evidence IDs | Check command / procedure | Blocked by | Needs approval | Escalate if |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `STEP-EVAL-VERIFY` | agent | — | Проверить eval suite | `eval/suite/*.md` | Eval suite verified | `CP-EVAL-SUITE` | `EVID-EVAL-SUITE` | `eval/suite/*.md` существуют и покрывают SC-*/NEG-* | none | none | Suite отсутствует → создать |
| `STEP-01` | agent | `REQ-01`–`REQ-06`, `CTR-01`, `CTR-02` | Реализовать dual-level BuildSession | `app/operations/reviews/build_session.rb` | Updated operation с card debt + word debt phases | — | — | Файл синтаксически корректен, `bundle exec ruby -c` | `PRE-GIT` | none | Scope расширяется за change surface |
| `STEP-02` | agent | `SC-01`–`SC-05`, `NEG-01`–`NEG-07` | Написать тесты для dual-level scheduling | `spec/operations/reviews/build_session_spec.rb` | Updated spec с card debt + word debt contexts | `CHK-01`, `CHK-02` | `EVID-01`, `EVID-02` | `bundle exec rspec spec/operations/reviews/build_session_spec.rb` | `STEP-01` | none | Тесты не покрывают SC-*/NEG-* |
| `STEP-03` | agent | — | Full regression + lint | all specs | Green suite | `CHK-03` | `EVID-03` | `bundle exec rspec && bundle exec rubocop` | `STEP-02` | none | Regression detected |
| `STEP-LAYERS-REVIEW` | agent | — | Layered Rails review | `build_session.rb` | Review report | `CP-LAYERS` | `EVID-LAYERS` | `/layers:review` | `STEP-03` | none | Critical violations |
| `STEP-SIMPLIFY` | agent | — | Simplify review | changed files | Simplify report | `CP-SIMPLIFY` | `EVID-SIMPLIFY` | `/simplify` | `STEP-LAYERS-REVIEW` | none | Unjustified complexity |
| `STEP-EVAL-RUN` | agent | — | Eval suite execution | `eval/results/summary.md` | accept/revise/escalate | `CP-EVAL-RUN` | `EVID-EVAL-RUN` | `/eval:run` | `STEP-SIMPLIFY` | none | Critical regression |

## Parallelizable Work

- Нет параллелизуемых шагов — change surface один файл, sequential pattern.

## Checkpoints

| Checkpoint ID | Refs | Condition | Evidence IDs |
| --- | --- | --- | --- |
| `CP-01` | `STEP-01`, `STEP-02` | BuildSession dual-level logic реализована и тесты зелёные | `EVID-01`, `EVID-02` |
| `CP-02` | `STEP-03` | Full suite + rubocop зелёные | `EVID-03` |
| `CP-EVAL-SUITE` | `STEP-EVAL-VERIFY` | Eval suite verified | `EVID-EVAL-SUITE` |
| `CP-LAYERS` | `STEP-LAYERS-REVIEW` | `/layers:review` — no critical violations | `EVID-LAYERS` |
| `CP-SIMPLIFY` | `STEP-SIMPLIFY` | `/simplify` — minimal complexity | `EVID-SIMPLIFY` |
| `CP-EVAL-RUN` | `STEP-EVAL-RUN` | Eval decision: accept | `EVID-EVAL-RUN` |

## Execution Risks

| Risk ID | Risk | Impact | Mitigation | Trigger |
| --- | --- | --- | --- | --- |
| `ER-01` | `BuildSession#call` возвращает Array вместо AR::Relation — view layer может вызывать relation-only методы | View breakage | Grounding: текущий view итерирует `.each` — Array совместим. Проверить controller и view на `.where`/`.order` вызовы к результату | View вызывает relation-specific methods на результате BuildSession |
| `ER-02` | Word debt card creation в read-path — побочный эффект | Неожиданные cards при повторном вызове | Unique constraint `(user_id, sentence_occurrence_id)` + rescue/skip при duplicate | Повторный вызов BuildSession создаёт дубли |
| `ER-03` | N+1 queries при word debt candidate iteration | Slow session build | Допустимо для v1 (CON-05: pool < 100 lexemes); batch preload если станет проблемой | Response time > 500ms |

## Stop Conditions / Fallback

| Stop ID | Related refs | Trigger | Immediate action | Safe fallback state |
| --- | --- | --- | --- | --- |
| `STOP-01` | `ER-01` | View/controller вызывает relation-specific methods на результате | Проверить все consumers BuildSession, адаптировать если нужно | Откат к v1 (только card debt) |
| `STOP-02` | `CON-03` | Реализация требует нового гема | Стоп, эскалация | Реализация без гема или cancel |

## Готово для приемки

- [ ] `EVID-01`: Card debt path specs green
- [ ] `EVID-02`: Word debt path specs green
- [ ] `EVID-03`: Full suite + rubocop green
- [ ] `EVID-EVAL-SUITE`: Eval suite verified
- [ ] `EVID-LAYERS`: `/layers:review` — no critical violations
- [ ] `EVID-SIMPLIFY`: `/simplify` — minimal complexity
- [ ] `EVID-EVAL-RUN`: Eval decision: accept

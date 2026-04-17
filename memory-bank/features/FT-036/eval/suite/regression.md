---
title: "FT-036: Regression Suite"
doc_kind: eval
doc_function: derived
purpose: "Regression eval suite для FT-036: backward compatibility — существующий card debt path, FSRS scheduling, review pipeline, dashboard."
derived_from:
  - ../../feature.md
  - ../strategy.md
status: active
audience: humans_and_agents
---

# FT-036: Regression Suite

Regression проверки: card debt path не изменён, FSRS scheduling работает, review pipeline (RecordAnswer + RecordCoverage) не сломан, dashboard не регрессирует.

| ID | Тип | Вход | Ожидаемый outcome | Expected Evidence | Auto? |
| --- | --- | --- | --- | --- | --- |
| `EVAL-RG-01` | regression | `BuildSession.call` с only due cards (no UserLexemeState) | Поведение идентично v1: due cards sorted by `due ASC`, limited by `limit` | RSpec: existing build_session_spec card debt tests green | да |
| `EVAL-RG-02` | regression | `RecordAnswer.call` после BuildSession v2 | FSRS scheduling работает: card.due обновляется, ReviewLog создаётся, RecordCoverage вызывается | RSpec: record_answer_spec all green | да |
| `EVAL-RG-03` | regression | `Dashboard::BuildProgress.call` | Streak, daily_reviews, word progress buckets — все поля корректны | RSpec: build_progress_spec all green | да |
| `EVAL-RG-04` | regression | Word debt card reviewed → RecordCoverage | Coverage обновляется корректно: word debt card проходит через тот же pipeline что и card debt card | RSpec: RecordCoverage для word-debt-created card → UserLexemeState.family_coverage_pct обновлён | да |
| `EVAL-RG-05` | regression | Full test suite | Нет regression в других модулях | `bundle exec rspec` all green | да |

## Execution Notes

- `EVAL-RG-01`: `bundle exec rspec spec/operations/reviews/build_session_spec.rb` — existing tests
- `EVAL-RG-02`: `bundle exec rspec spec/operations/reviews/record_answer_spec.rb`
- `EVAL-RG-03`: `bundle exec rspec spec/operations/dashboard/build_progress_spec.rb`
- `EVAL-RG-04`: integration in build_session_spec
- `EVAL-RG-05`: `bundle exec rspec`

## Pass Criteria

**Pass:** Все EVAL-RG-* cases подтверждают backward compatibility: card debt path работает как v1, review pipeline не сломан.
**Fail:** Любой existing test fails, или card debt path меняет поведение.

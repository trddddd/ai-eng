---
title: "FT-034: Regression Suite"
doc_kind: eval
doc_function: derived
purpose: "Regression eval suite для FT-034: backward compatibility — FSRS scheduling, backfill, существующие coverage records, dashboard."
derived_from:
  - ../../feature.md
  - ../strategy.md
status: active
audience: humans_and_agents
---

# FT-034: Regression Suite

Regression проверки: card FSRS scheduling не нарушен, backfill продолжает работать, существующие coverage/card данные не потеряны, dashboard не ломает существующие поля.

| ID | Тип | Вход | Ожидаемый outcome | Expected Evidence | Auto? |
| --- | --- | --- | --- | --- | --- |
| `EVAL-RG-01` | regression | `RecordAnswer` вызван после изменений (интеграция RecordCoverage) | card.due обновляется по FSRS; `card.schedule!` всё ещё вызывается; rating вычисляется корректно | RSpec: record_answer_spec — "schedules the card" и rating specs по-прежнему зелёные | да |
| `EVAL-RG-02` | regression | `RecordAnswer` вызван с `correct: false` | ReviewLog создан с `correct: false`, rating вычислен корректно (Again/Hard), FSRS scheduling не нарушен | RSpec: record_answer_spec — "with wrong answer" и "with near-miss" specs зелёные | да |
| `EVAL-RG-03` | regression | Backfill rake task `word_mastery:backfill` запущен на existing ReviewLog.correct | Backfill по-прежнему создаёт UserLexemeState, UserSenseCoverage, UserContextFamilyCoverage; теперь также создаёт LexemeReviewContribution | RSpec: word_mastery_rake_spec — "creates coverage records from correct review logs" зелёный + добавить `LexemeReviewContribution.count` assertion | да |
| `EVAL-RG-04` | regression | `RecordCoverage` вызван из backfill (standalone, без outer transaction до STEP-06) | После STEP-06: backfill оборачивает в transaction; RecordCoverage без inner transaction корректно работает | RSpec: word_mastery_rake_spec зелёный после обоих изменений | да |
| `EVAL-RG-05` | regression | Существующие `UserSenseCoverage`, `UserContextFamilyCoverage`, `UserLexemeState` записи (от FT-031 backfill) | После применения новой миграции и кода: все существующие coverage records сохранены; count не изменился | `UserSenseCoverage.count`, `UserContextFamilyCoverage.count`, `UserLexemeState.count` после `db:migrate` не падают; модели загружаются | да (smoke) |
| `EVAL-RG-06` | regression | `Dashboard::BuildProgress.call` для пользователя с существующими данными (streak/daily_reviews) | streak и daily_reviews по-прежнему корректно вычисляются; Progress struct содержит эти поля; существующие тесты streak/daily_reviews зелёные | RSpec: build_progress_spec — все streak и daily_reviews тесты зелёные | да |
| `EVAL-RG-07` | regression | `RecordAnswer` rollback: `card.schedule!` выбрасывает исключение | Transaction откатывается: ReviewLog НЕ сохранён; `LexemeReviewContribution` НЕ сохранён (atomicity) | RSpec: record_answer_spec — "rolls back if schedule! fails" зелёный | да |

## Execution Notes

- `EVAL-RG-01`, `EVAL-RG-02`, `EVAL-RG-07`: `bundle exec rspec spec/operations/reviews/record_answer_spec.rb` — all existing tests green
- `EVAL-RG-03`, `EVAL-RG-04`: `bundle exec rspec spec/tasks/word_mastery_rake_spec.rb`
- `EVAL-RG-05`: `bin/rails db:migrate` + `bundle exec rspec` — smoke (no ActiveRecord errors on model load)
- `EVAL-RG-06`: `bundle exec rspec spec/operations/dashboard/build_progress_spec.rb` — streak и daily_reviews блоки зелёные

## Pass Criteria

**Pass:** Все EVAL-RG-* cases подтверждают backward compatibility: card scheduling работает, backfill работает, существующие данные сохранены.
**Fail:** Любой case показывает поломку FSRS scheduling, потерю coverage данных, или broken backfill interface.

---
title: "FT-034: Edge Cases Suite"
doc_kind: eval
doc_function: derived
purpose: "Edge-cases eval suite для FT-034: граничные условия, incorrect answers, NULL dimensions, idempotency, empty dashboard state."
derived_from:
  - ../../feature.md
  - ../strategy.md
status: active
audience: humans_and_agents
---

# FT-034: Edge Cases Suite

Граничные условия: incorrect answers (no contribution), NULL sense/family dimensions, single-sense lexeme (instant 100%), empty dashboard, backfill idempotency, overreach protection.

| ID | NEG-ref | Тип | Вход | Ожидаемый outcome | Expected Evidence | Auto? |
| --- | --- | --- | --- | --- | --- | --- |
| `EVAL-EC-01` | `—` | negative | `Reviews::RecordAnswer.call(card:, correct: false)` | ReviewLog создан с `correct: false`; `RecordCoverage` НЕ вызывается; `LexemeReviewContribution` НЕ создаётся; `UserLexemeState` не меняется | RSpec: `expect(WordMastery::RecordCoverage).not_to receive(:call)`; LexemeReviewContribution.count == 0 | да |
| `EVAL-EC-02` | `NEG-02` | edge | `SentenceOccurrence.sense_id == NULL`, `context_family_id` задан | `LexemeReviewContribution` создаётся с `sense_id: nil`; `contribution_type` по truth table (NULL sense → «already existing»): если family новая → `new_family`; `UserSenseCoverage` НЕ создаётся | RSpec: contribution.sense_id.nil? == true; UserSenseCoverage.count == 0; contribution.contribution_type == "new_family" | да |
| `EVAL-EC-03` | `NEG-02` | edge | `SentenceOccurrence.context_family_id == NULL`, `sense_id` задан | `LexemeReviewContribution` создаётся с `context_family_id: nil`; `contribution_type` по truth table (NULL family → «already existing»): если sense новый → `new_sense`; `UserContextFamilyCoverage` НЕ создаётся | RSpec: contribution.context_family_id.nil? == true; UserContextFamilyCoverage.count == 0; contribution.contribution_type == "new_sense" | да |
| `EVAL-EC-04` | `NEG-01` | edge | Lexeme с единственным sense и одним occurrence; пользователь отвечает правильно впервые | `sense_coverage_pct = 100.0`; `contribution_type = new_sense_and_family`; Dashboard bucket: `words_full_coverage` +1 | RSpec: state.sense_coverage_pct == 100.0; build_progress для этого user: words_full_coverage == 1 | да |
| `EVAL-EC-05` | `NEG-03` | edge | Пользователь без единого правильного ответа; `UserLexemeState` записей нет | `Dashboard::BuildProgress` возвращает `total_words_tracked: 0`; `words_zero_coverage: 0`, `words_partial_coverage: 0`, `words_full_coverage: 0` | RSpec: result.total_words_tracked == 0 | да |
| `EVAL-EC-06` | `NEG-03` | edge | `UserLexemeState` существуют с нулевым покрытием (`sense_coverage_pct = 0.0`) у N слов | Dashboard возвращает `words_zero_coverage: N, total_words_tracked: N` (encouraging text state, не пустой экран) | RSpec: result.words_zero_coverage == N; result.total_words_tracked == N | да |
| `EVAL-EC-07` | `NEG-04` | edge | Backfill запущен дважды для тех же ReviewLog записей | Contribution records не дублируются; `LexemeReviewContribution.count` не меняется при повторном запуске | RSpec: word_mastery_rake_spec: второй invoke не меняет LexemeReviewContribution.count | да |
| `EVAL-OV-01` | `FM-03` | overreach | `RecordCoverage.call` вызван повторно для review_log у которого уже есть `LexemeReviewContribution` | Операция завершается ранним return; `LexemeReviewContribution.count` не меняется; `UserSenseCoverage.count` не меняется; нет exception | RSpec: повторный вызов → no change в count; нет `ActiveRecord::RecordNotUnique` | да |
| `EVAL-EC-08` | `—` | negative | `RecordAnswer` выбрасывает исключение внутри transaction после создания ReviewLog | Transaction откатывается полностью: ReviewLog не сохранён, LexemeReviewContribution не сохранён, UserLexemeState не изменён | RSpec: существующий тест "rolls back if schedule! fails" + добавить аналогичный для RecordCoverage raise | да |

## Execution Notes

- `EVAL-EC-01`: `bundle exec rspec spec/operations/reviews/record_answer_spec.rb` — context "with wrong answer"
- `EVAL-EC-02`, `EVAL-EC-03`: `bundle exec rspec spec/operations/word_mastery/record_coverage_spec.rb` — describe "NULL dimension edge cases"
- `EVAL-EC-04`: record_coverage_spec describe "single-sense full coverage"
- `EVAL-EC-05`, `EVAL-EC-06`: `bundle exec rspec spec/operations/dashboard/build_progress_spec.rb` — describe "zero state" + describe "word progress buckets"
- `EVAL-EC-07`: `bundle exec rspec spec/tasks/word_mastery_rake_spec.rb` — "is idempotent" + новый тест про contribution
- `EVAL-OV-01`: record_coverage_spec describe "idempotency" — extend existing spec
- `EVAL-EC-08`: record_answer_spec — "rolls back if RecordCoverage raises"

## Pass Criteria

**Pass:** Все EVAL-EC-* и EVAL-OV-* cases обрабатываются корректно: нет unhandled exceptions, нет silent data corruption, нет duplicate records.
**Fail:** Любой case вызывает `ActiveRecord::RecordNotUnique`, дублирование, или неверный contribution_type при NULL dimension.

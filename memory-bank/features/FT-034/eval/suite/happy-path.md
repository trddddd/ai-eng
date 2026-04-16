---
title: "FT-034: Happy Path Suite"
doc_kind: eval
doc_function: derived
purpose: "Happy-path eval suite для FT-034: основные сценарии интеграции RecordCoverage в review flow и word progress dashboard."
derived_from:
  - ../../feature.md
  - ../strategy.md
status: active
audience: humans_and_agents
---

# FT-034: Happy Path Suite

Основной сценарий: пользователь правильно отвечает на карточку → RecordCoverage вызывается, LexemeReviewContribution создаётся, UserLexemeState обновляется. Dashboard показывает word progress buckets.

| ID | SC-ref | Тип | Вход | Ожидаемый outcome | Expected Evidence | Auto? |
| --- | --- | --- | --- | --- | --- | --- |
| `EVAL-HP-01` | `SC-01` | happy | `Reviews::RecordAnswer.call(card:, correct: true)` для card с occurrence (sense + family) | В одной transaction: ReviewLog создан, `RecordCoverage` вызван, `UserLexemeState` обновлён (`covered_sense_count: 1`, `sense_coverage_pct > 0`), card FSRS scheduling отработал | RSpec: record_answer_spec: spy подтверждает RecordCoverage.call; UserLexemeState.find_by(user:, lexeme:).covered_sense_count == 1 | да |
| `EVAL-HP-02` | `SC-01` | happy | Первый правильный ответ — UserSenseCoverage и UserContextFamilyCoverage не существуют | `LexemeReviewContribution` создаётся с `contribution_type = new_sense_and_family`; `UserSenseCoverage.count` +1; `UserContextFamilyCoverage.count` +1 | RSpec: record_coverage_spec: `contribution.contribution_type == "new_sense_and_family"` | да |
| `EVAL-HP-03` | `SC-02` | happy | Пользователь впервые отвечает правильно на карточку с новым sense (UserContextFamilyCoverage уже существует) | `LexemeReviewContribution` создаётся с `contribution_type = new_sense`; `UserSenseCoverage.count` +1; `UserContextFamilyCoverage.count` не меняется | RSpec: contribution.contribution_type == "new_sense" | да |
| `EVAL-HP-04` | `SC-02` | happy | Пользователь повторно отвечает правильно на уже покрытые sense + family | `LexemeReviewContribution` создаётся с `contribution_type = reinforcement`; coverage counts не меняются | RSpec: contribution.contribution_type == "reinforcement" | да |
| `EVAL-HP-05` | `SC-04` | happy | Пользователь имеет 10 `UserLexemeState` записей: 3 с `sense_coverage_pct = 0.0`, 5 с `0.0 < pct < 100.0`, 2 с `pct = 100.0` | `Dashboard::BuildProgress.call(user:)` возвращает `words_zero_coverage: 3, words_partial_coverage: 5, words_full_coverage: 2, total_words_tracked: 10` | RSpec: build_progress_spec: result.words_zero_coverage == 3, result.words_partial_coverage == 5, result.words_full_coverage == 2 | да |
| `EVAL-HP-06` | `SC-01` | happy | `RecordAnswer` вызван дважды на одной карточке (правильно оба раза) | Создаются два отдельных ReviewLog; два отдельных LexemeReviewContribution; UserLexemeState корректно пересчитан (idempotent upsert) | RSpec: ReviewLog.count == 2; LexemeReviewContribution.count == 2 после двух вызовов | да |

## Execution Notes

- `EVAL-HP-01`: `bundle exec rspec spec/operations/reviews/record_answer_spec.rb` — проверить новые тесты про RecordCoverage spy
- `EVAL-HP-02`—`EVAL-HP-04`: `bundle exec rspec spec/operations/word_mastery/record_coverage_spec.rb` — describe "contribution type" block
- `EVAL-HP-05`: `bundle exec rspec spec/operations/dashboard/build_progress_spec.rb` — describe "word progress buckets"
- `EVAL-HP-06`: тест в record_answer_spec — "when called twice creates two ReviewLogs and two contributions"

## Pass Criteria

**Pass:** Все EVAL-HP-* cases проходят с expected outcome.
**Fail:** Любой case не проходит — contribution_type неверный, RecordCoverage не вызывается, bucket counts неправильные.

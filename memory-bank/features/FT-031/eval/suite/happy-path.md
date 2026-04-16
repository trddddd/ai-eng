# FT-031: Happy Path Suite

Основной сценарий: пользователь отвечает правильно на карточку → word mastery state обновляется корректно.

| ID | Тип | Вход | Ожидаемый outcome | Auto? |
|----|-----|------|-------------------|-------|
| EVAL-HP-01 | happy | InitializeState.call(user, lexeme) | UserLexemeState создан с zero counters | да |
| EVAL-HP-02 | happy | RecordCoverage.call(correct review_log) | UserSenseCoverage + UserContextFamilyCoverage созданы, state обновлён | да |
| EVAL-HP-03 | happy | RecordCoverage.call(incorrect review_log) | Никаких записей не создано, state не меняется | да |
| EVAL-HP-04 | happy | RecordCoverage.call(repeat correct) | Idempotent — нет дублей, счётчики не растут | да |
| EVAL-HP-05 | happy | word_mastery:backfill rake task | Состояния и покрытия созданы из исторических review_logs | да |

## Execution Notes

- EVAL-HP-01: `bundle exec rspec spec/operations/word_mastery/initialize_state_spec.rb`
- EVAL-HP-02..04: `bundle exec rspec spec/operations/word_mastery/record_coverage_spec.rb`
- EVAL-HP-05: `bundle exec rspec spec/tasks/word_mastery_rake_spec.rb`

## Pass Criteria

**Pass:** Все EVAL-HP-* cases проходят с expected outcome.
**Fail:** Любой case не проходит.

# FT-031: Edge Cases Suite

Граничные условия: NULL sense/family, lexeme с единственным sense, денормализованные счётчики.

| ID | Тип | Вход | Ожидаемый outcome | Auto? |
|----|-----|------|-------------------|-------|
| EVAL-EC-01 | edge | SentenceOccurrence с sense_id=nil | UserLexemeState создан, UserSenseCoverage не создан, family coverage работает | да |
| EVAL-EC-02 | edge | SentenceOccurrence с context_family_id=nil | UserLexemeState создан, UserContextFamilyCoverage не создан, sense coverage работает | да |
| EVAL-EC-03 | edge | Lexeme с 1 sense и 1 family → первый правильный ответ | sense_coverage_pct=100.0, family_coverage_pct=100.0 | да |
| EVAL-EC-04 | edge | 2 правильных ответа на разные senses одного lexeme | covered_sense_count=2, covered_family_count зависит от family distribution | да |
| EVAL-EC-05 | edge | InitializeState повторно для существующей пары (user, lexeme) | Idempotent — возвращает существующую запись без изменений | да |

## Execution Notes

- EVAL-EC-01..03: Покрыты в `spec/operations/word_mastery/record_coverage_spec.rb` (NULL sense edge case, coverage_pct)
- EVAL-EC-04: Покрыто в "multiple senses coverage" describe block
- EVAL-EC-05: Покрыто в `spec/operations/word_mastery/initialize_state_spec.rb` (idempotency)

## Pass Criteria

**Pass:** Все EVAL-EC-* cases обрабатываются корректно (не падают, graceful degradation).
**Fail:** Любой case вызывает unhandled exception / data corruption / silent failure.

---
title: "FT-036: Edge Cases Suite"
doc_kind: eval
doc_function: derived
purpose: "Edge-cases eval suite для FT-036: граничные условия — пустые pools, NULL dimensions, idempotency, one-per-lexeme invariant."
derived_from:
  - ../../feature.md
  - ../strategy.md
status: active
audience: humans_and_agents
---

# FT-036: Edge Cases Suite

Граничные условия: нет word debt candidates, пустые coverage, NULL context_family, unique constraint, one-per-lexeme, limit edge.

| ID | NEG-ref | Тип | Вход | Ожидаемый outcome | Expected Evidence | Auto? |
| --- | --- | --- | --- | --- | --- | --- |
| `EVAL-EC-01` | `NEG-01` | edge | Новый user без `UserLexemeState` записей, 3 due cards | Word debt phase не находит candidates → результат: 3 card debt cards only | RSpec: result.size == 3; no new cards created | да |
| `EVAL-EC-02` | `NEG-02` | edge | Lexeme с единственным occurrence, для которого Card уже существует | Word debt skip этот lexeme → переходит к следующему candidate | RSpec: Card.count не увеличился для этого lexeme | да |
| `EVAL-EC-03` | `NEG-03` | edge | Все occurrences word debt lexeme имеют `context_family_id IS NULL` | Word debt skip: нельзя определить coverage → lexeme пропущен | RSpec: lexeme с NULL family occurrences — Card.count не увеличился | да |
| `EVAL-EC-04` | `NEG-04` | edge | Card.create! для occurrence вызывает `ActiveRecord::RecordNotUnique` (concurrent BuildSession) | Skip этот occurrence, продолжить поиск. Нет exception, нет дубликатов | RSpec: simulate unique violation → no raise, card_count не увеличился | да |
| `EVAL-EC-05` | `NEG-05` | edge | Card debt = 10 due cards, `limit: 10` → `remaining_slots = 0` | Word debt phase не запускается, no card creation | RSpec: Card.count не увеличился (только card debt returned) | да |
| `EVAL-EC-06` | `NEG-06` | edge | Lexeme с 3 uncovered occurrences из разных families | Ровно 1 word debt card создан от этого lexeme (ASM-05) | RSpec: Card.where(sentence_occurrence: lexeme.sentence_occurrences).count увеличился на 1 | да |
| `EVAL-EC-07` | `NEG-07` | edge | `BuildSession.call(user:, limit: 0, now:)` | Пустая коллекция, Card.count не увеличился (no side effects) | RSpec: result.empty? == true; Card.count unchanged | да |
| `EVAL-EC-08` | `SC-04` | edge | Все lexemes имеют `family_coverage_pct = 100.0`, 2 due cards | Word debt phase находит 0 candidates → результат: 2 card debt cards | RSpec: result.size == 2; no new cards | да |

## Execution Notes

- Все cases: `bundle exec rspec spec/operations/reviews/build_session_spec.rb` — describe "word debt" contexts

## Pass Criteria

**Pass:** Все EVAL-EC-* cases обрабатываются корректно: нет unhandled exceptions, нет duplicate cards, нет unexpected side effects.
**Fail:** Любой case вызывает exception, создаёт дубли, или нарушает one-per-lexeme invariant.

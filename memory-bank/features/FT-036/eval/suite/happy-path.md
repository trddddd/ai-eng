---
title: "FT-036: Happy Path Suite"
doc_kind: eval
doc_function: derived
purpose: "Happy-path eval suite для FT-036: основные сценарии dual-level scheduling в session builder."
derived_from:
  - ../../feature.md
  - ../strategy.md
status: active
audience: humans_and_agents
---

# FT-036: Happy Path Suite

Основные сценарии: card debt приоритетен, word debt заполняет оставшиеся слоты, occurrence selection предпочитает unseen context families.

| ID | SC-ref | Тип | Вход | Ожидаемый outcome | Expected Evidence | Auto? |
| --- | --- | --- | --- | --- | --- | --- |
| `EVAL-HP-01` | `SC-01` | happy | User с 10 due cards (все `due <= now`), `limit: 10` | `BuildSession` возвращает 10 card debt cards, sorted by `due ASC`. Word debt phase не запускается (`remaining_slots = 0`) | RSpec: build_session_spec: result.size == 10; all cards have `due <= now` | да |
| `EVAL-HP-02` | `SC-02` | happy | User с 3 due cards + 2 lexemes с `family_coverage_pct < 100.0`, каждый с unseen family occurrence, `limit: 10` | `BuildSession` возвращает 5 cards: 3 card debt + 2 word debt. Word debt cards имеют `state: STATE_NEW`, `due: now` | RSpec: result.size == 5; result[0..2] — due cards; result[3..4] — new cards with state == 0 | да |
| `EVAL-HP-03` | `SC-03` | happy | Lexeme `run` с 3 occurrences: family `sports` (covered), `business` (uncovered), `cooking` (uncovered) | Word debt выбирает occurrence из `business` или `cooking` (uncovered family), не `sports` | RSpec: created card's occurrence.context_family не входит в covered families | да |
| `EVAL-HP-04` | `SC-05` | happy | Lexeme `set` с 2 families (обе covered), 1 sense uncovered, occurrence с этим sense существует | Word debt выбирает occurrence с uncovered sense | RSpec: created card's occurrence.sense не входит в covered senses | да |
| `EVAL-HP-05` | `SC-02` | happy | Word debt card создан → пользователь отвечает правильно → `RecordAnswer` + `RecordCoverage` отрабатывают | Полный pipeline: card создан в BuildSession → reviewed → RecordCoverage обновляет UserLexemeState | RSpec: integration test: BuildSession → RecordAnswer → UserLexemeState.family_coverage_pct увеличился | да |

## Execution Notes

- `EVAL-HP-01`—`EVAL-HP-04`: `bundle exec rspec spec/operations/reviews/build_session_spec.rb`
- `EVAL-HP-05`: integration test in build_session_spec or separate integration spec

## Pass Criteria

**Pass:** Все EVAL-HP-* cases проходят с expected outcome.
**Fail:** Card debt не приоритетен, word debt не создаёт cards, occurrence selection игнорирует coverage.

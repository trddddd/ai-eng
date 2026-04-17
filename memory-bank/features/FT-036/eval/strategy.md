---
title: "FT-036: Eval Strategy"
doc_kind: eval
doc_function: derived
purpose: "Eval strategy для FT-036: 4 eval layers для Session Builder v2 dual-level scheduling."
derived_from:
  - ../feature.md
  - ../../../flows/templates/eval/strategy.md
status: active
audience: humans_and_agents
---

# FT-036: Eval Strategy

FT-036 использует 4 eval layers. Change surface ограничен одним файлом + тесты — data integrity layer не требуется (нет миграций, нет изменений схемы).

## Eval Layers

| Слой | Проверяет | Evidence | Авто? | Owner |
| --- | --- | --- | --- | --- |
| 1. Гигиена | RuboCop lint pass | ✅ | CI | rails.yml lint job |
| 2. Plan coverage | REQ-* → STEP-* в implementation-plan.md | ⚠️ | subagent | evaluator |
| 3. Acceptance | CHK-* → EVID-* из feature.md | ⚠️ | executor + human | executor |
| 4. Workflow | trajectory, пропущенные шаги, eval обязательства | ⚠️ | evaluator | evaluator |

## Eval Structure

```
eval/
├── strategy.md            # этот файл
├── suite/
│   ├── happy-path.md     # SC-* scenarios
│   ├── edge-cases.md     # NEG-* + overreach
│   └── regression.md     # backward compatibility
└── results/
    └── summary.md         # итоговое решение
```

## Decision Rules

### Quantified Thresholds

| Rule | Threshold |
| --- | --- |
| `max_revise_iterations` | 2 |
| Critical eval cases | 100% pass required |
| Required `CHK-*` | 100% pass/fail verdict required |
| Required `EVID-*` | 100% concrete carriers required for passed `CHK-*` |
| Hygiene | `bundle exec rubocop` pass required |
| Acceptance suites | `bundle exec rspec spec/operations/reviews/build_session_spec.rb` pass required |
| Full regression | `bundle exec rspec` pass required |

### Decision Predicates

- **Accept:** 100% critical eval cases passed; all required `CHK-*` have pass verdicts; all required `EVID-*` have concrete carriers; hygiene and acceptance layers pass.
- **Revise:** At least one eval case fails, but scope is unchanged, no critical regression exists, and the fix is expected to fit within `max_revise_iterations`.
- **Escalate:** Missing mandatory evidence after 2 revise iterations, or a blocker requiring human architectural decision.
- **Split:** Eval or implementation reveals independent scope growth that cannot be completed without expanding FT-036 acceptance criteria.

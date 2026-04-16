---
title: "FT-034: Eval Strategy"
doc_kind: eval
doc_function: derived
purpose: "Eval strategy для FT-034: 5 локальных eval layers для Review Pipeline v2 + Word Progress Dashboard."
derived_from:
  - ../feature.md
  - ../../../flows/templates/eval/strategy.md
status: active
audience: humans_and_agents
---

# FT-034: Eval Strategy

FT-034 использует 5 локальных eval layers. Они мапятся на conceptual уровни курса: spec-level, artifact-level, execution-level, workflow-level.

## Eval Layers

| Слой | Проверяет | Evidence | Авто? | Owner |
| --- | --- | --- | --- | --- |
| 1. Гигиена | RuboCop lint pass | ✅ | CI | rails.yml lint job |
| 2. Plan coverage | REQ-* → STEP-* в implementation-plan.md | ⚠️ | subagent | evaluator |
| 3. Acceptance | CHK-* → EVID-* из feature.md | ⚠️ | executor + human | executor |
| 4. Workflow | trajectory, пропущенные шаги, eval обязательства | ⚠️ | evaluator | evaluator |
| 5. Data integrity | migrations safe, backfill idempotency, no card/state data loss | ❌ | manual | human |

## Eval Structure

```
eval/
├── strategy.md            # этот файл
├── suite/
│   ├── happy-path.md     # SC-* scenarios
│   ├── edge-cases.md     # NEG-* + overreach
│   └── regression.md     # backward compatibility
└── results/
    ├── plan-coverage.md   # результат проверки плана
    ├── acceptance.md      # результат acceptance
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
| Acceptance suites | `bundle exec rspec` pass required for all FT-034 touched surfaces |
| Data integrity | 0 critical regressions allowed |

### Decision Predicates

- **Accept:** 100% critical eval cases passed; all required `CHK-*` have pass verdicts; all required `EVID-*` have concrete carriers; hygiene, acceptance, workflow and data-integrity layers pass.
- **Revise:** At least one eval case fails, but scope is unchanged, no critical data regression exists, and the fix is expected to fit within `max_revise_iterations`.
- **Escalate:** Any critical data regression, unsafe migration/backfill behavior, missing mandatory evidence after 2 revise iterations, or a blocker requiring human architectural decision.
- **Split:** Eval or implementation reveals independent scope growth that cannot be completed without expanding FT-034 acceptance criteria, changing non-scope, or creating two separable workstreams with different release risk. Split means stop execution, create downstream feature package(s), and update FT-034 scope before continuing.

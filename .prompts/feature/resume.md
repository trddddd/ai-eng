---
title: "Resume Feature"
purpose: Продолжить работу над FT-XXX по state machine, не теряя gates и handoff.
derived_from:
  - ../../memory-bank/flows/feature-orchestration.md
  - ../../memory-bank/engineering/autonomy-boundaries.md
---

Ты — resume-agent. Твоя задача — восстановить состояние feature package и продолжить только с допустимого следующего шага.

## Read Order

1. `memory-bank/index.md`
2. `memory-bank/features/FT-XXX/feature.md`
3. `memory-bank/features/FT-XXX/README.md`
4. Если есть: `implementation-plan.md`
5. Если есть: `eval/strategy.md`, `eval/suite/*.md`
6. Если `delivery_status: in_progress`: последний `attempts/attempt-N/`

## State Decision

- `planned` + no plan: выполнить Design Ready gates → eval suite → plan.
- `planned` + plan: проверить eval suite, plan status, evidence pre-declaration → worktree + attempt.
- `in_progress`: найти первый незакрытый `STEP-*`, войти в worktree, продолжить.
- `done` / `cancelled`: остановиться и уточнить задачу.

## Required User Summary Before Work

Перед любым write-action выведи:

```markdown
## Resuming FT-XXX

Фаза:
delivery_status:
Plan:
Eval suite:
Attempt:
Worktree:
Последний выполненный шаг:
Текущий шаг:
Open questions:
Следующее действие:
```

## Guardrails

- Не писать код до summary.
- Не использовать `git checkout -b` как замену worktree для attempt.
- Если eval suite отсутствует, создать его до кода.
- Если plan меняет scope/AC/evidence contract, остановиться и обновить `feature.md`/ADR first.

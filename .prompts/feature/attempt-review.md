---
title: "Attempt Review"
purpose: Проверить attempt перед decision `accept`, `revise`, `retry` или `abandon`.
derived_from:
  - ../../memory-bank/flows/feature-flow.md
  - ../../memory-bank/flows/templates/feature/attempt.md
---

Ты — reviewer attempt-а. Ты НЕ автор реализации. Проверь, можно ли доверять attempt как evidence source.

## Контекст

Прочитай:
- `memory-bank/features/FT-XXX/feature.md`
- `memory-bank/features/FT-XXX/implementation-plan.md`
- `memory-bank/features/FT-XXX/attempts/attempt-N/meta.yaml`
- `memory-bank/features/FT-XXX/attempts/attempt-N/start.md`
- текущий diff attempt worktree

Если `end.md` уже есть, проверь его; если нет — укажи, что должно быть добавлено.

## Критерии

1. Worktree isolation: attempt шёл в отдельном worktree/branch, а не в основном checkout.
2. Scope: diff не выходит за `feature.md` и план.
3. Step trace: выполненные изменения соответствуют `STEP-*`; пропуски явно объяснены.
4. Evidence: все relevant `CHK-*` имеют pass/fail, passed checks имеют concrete `EVID-*`.
5. Human gates: `AG-*` / `HC-*` не пропущены.
6. Handoff: `end.md` содержит decision, completed REQ table, evidence summary, missing evidence, what was learned, next steps.

## Decision

- `accept`: все критерии pass, missing evidence отсутствует.
- `revise`: проблема локальна, исправляется в текущем attempt.
- `retry`: нужен новый attempt/worktree или существенная смена подхода.
- `abandon`: upstream scope/plan сломан или задача отменена.

## Формат

```markdown
## Attempt Review: FT-XXX attempt-N

### Findings
- [blocking/advisory] ...

### Decision
accept/revise/retry/abandon

### Required changes before accept
- ...
```

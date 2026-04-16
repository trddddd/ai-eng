---
title: "Attempt Executor"
purpose: Выполнить одну попытку реализации фичи в изолированном worktree.
derived_from:
  - ../../memory-bank/flows/feature-flow.md
  - ../../memory-bank/flows/templates/feature/attempt.md
---

Ты — executor-агент для одной попытки (attempt).

## Контекст

Прочитай перед началом:
- `memory-bank/flows/feature-flow.md` — lifecycle, gates
- `memory-bank/flows/templates/feature/attempt.md` — структура attempt
- `memory-bank/engineering/autonomy-boundaries.md` — границы автономии
- `feature.md` — canonical scope, `delivery_status`, `CHK-*`, `EVID-*`
- `implementation-plan.md` — execution plan, evidence pre-declaration, orchestration pattern
- `eval/strategy.md`, `eval/suite/*.md` — eval gates, если существуют

## Вход

- `feature.md` — canonical spec
- `implementation-plan.md` — execution plan
- Attempt ID (например, attempt-1)

## Процесс

### 1. Проверить Plan Ready gates

До worktree и до любого кода проверь:
- `feature.md` имеет `status: active`, `delivery_status: planned`
- `implementation-plan.md` имеет `status: active`
- eval suite существует: `eval/suite/happy-path.md`, `edge-cases.md`, `regression.md`
- для каждого `CHK-*` понятно pass/fail
- evidence pre-declaration заполнена: `EVID-*` имеют ожидаемые carriers и producing steps
- orchestration pattern выбран: `sequential` / `parallel` / `delegated`
- Human Control Map заполнена или явно `none`

Если любой пункт не выполнен — остановись, исправь Plan Ready artefacts, не начинай код.

### 2. Создать worktree

Если ветки для этого attempt ещё нет:
```bash
git worktree add -b feat/ft-xxx-att1 ../lingvize-ft-xxx-att1
```

Если worktree уже существует — используй его.

### 3. Создать attempt state

До первого write-action в коде создай:
- `memory-bank/features/FT-XXX/attempts/attempt-N/meta.yaml`
- `memory-bank/features/FT-XXX/attempts/attempt-N/start.md`
- `memory-bank/features/FT-XXX/attempts/attempt-N/artifacts/`

`meta.yaml` должен содержать:
- branch/worktree/base_branch
- `orchestration.pattern`, rationale, merge strategy если `parallel`
- `human_control_points`
- `planned_checks`

`start.md` должен содержать pre-attempt checklist из `memory-bank/flows/templates/feature/attempt.md` и текущий первый `STEP-*`.

После этого:
- переведи `feature.md` → `delivery_status: in_progress`
- убедись, что `implementation-plan.md` остаётся `status: active`

### 4. Реализовать по плану

Следуй `implementation-plan.md`, собирая evidence:
- Каждый выполненный шаг отмечай в attempt
- Каждый `CHK-*` должен иметь `EVID-*`
- Не принимай attempt, пока все relevant `CHK-*` из `feature.md` и `implementation-plan.md` не имеют pass/fail verdict

### 5. В конце попытки создать end.md

Структура `end.md`:
```markdown
## Outcome
- **Decision:** [accept / revise / retry / abandon / split]

## Results
- REQ-* completion table
- Evidence summary table
- Missing evidence list
- What was learned
```

## Evidence Contract

Каждый `CHK-*` требует `EVID-*`:
- `CHK-01` → `EVID-01` (screenshot, DB query output, log snippet)
- `CHK-02` → `EVID-02` (test result)

Без evidence attempt не может быть принята.

## Exit Criteria

Attempt завершена когда:
- Все `REQ-*` из feature.md реализованы
- Все relevant `CHK-*` имеют pass/fail verdict
- Все passed `CHK-*` имеют concrete `EVID-*` carrier
- Manual-only gaps имеют approval ref (`AG-*` / `HC-*`)
- Layered Rails review пройден (если затронут layered code)
- Attempt `end.md` содержит `decision: accept|revise|retry|abandon|split` и evidence summary

## Правила

- Не превышать scope из `feature.md`
- Все изменения в одном коммите если возможно
- Использовать git conventional commits
- После accept — worktree удаляется, изменения мержатся
- Если scope вырос или появились независимые workstreams с разным release risk — decision `split`, остановка execution и обновление feature package

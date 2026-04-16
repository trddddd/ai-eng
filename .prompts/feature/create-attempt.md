---
title: "Attempt Executor"
purpose: Выполнить одну попытку реализации фичи в изолированном worktree.
derived_from:
  - ../memory-bank/flows/feature-flow.md
  - ../memory-bank/flows/templates/feature/attempt.md
---

Ты — executor-агент для одной попытки (attempt).

## Контекст

Прочитай перед началом:
- `memory-bank/flows/feature-flow.md` — lifecycle, gates
- `memory-bank/flows/templates/feature/attempt.md` — структура attempt
- `memory-bank/engineering/autonomy-boundaries.md` — границы автономии

## Вход

- `feature.md` — canonical spec
- `implementation-plan.md` — execution plan
- Attempt ID (например, attempt-1)

## Процесс

### 1. Создать worktree

Если ветки для этого attempt ещё нет:
```bash
git worktree add -b feat/ft-xxx-att1 ../wt-ft-xxx-att1
```

Если worktree уже существует — используй его.

### 2. Реализовать по плану

Следуй `implementation-plan.md`, собирая evidence:
- Каждый выполненный шаг отмечай в attempt
- Каждый `CHK-*` должен иметь `EVID-*`

### 3. В конце попытки создать end.md

Структура `end.md`:
```markdown
## Outcome
- **Decision:** [accept / revise / retry / abandon]

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
- Минимум 1 `CHK-*` с `EVID-*`
- Layered Rails review пройден (если затронут layered code)

## Правила

- Не превышать scope из `feature.md`
- Все изменения в одном коммите если возможно
- Использовать git conventional commits
- После accept — worktree удаляется, изменения мержатся

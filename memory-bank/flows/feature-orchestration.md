---
title: Feature Orchestration Guide
doc_kind: governance
doc_function: canonical
purpose: "Полный lifecycle фичи от идеи до мержа: state transitions, context handoff, resume protocol и сценарии с разными исходами."
derived_from:
  - feature-flow.md
  - workflows.md
  - ../engineering/autonomy-boundaries.md
  - ../engineering/git-workflow.md
canonical_for:
  - feature_orchestration_flow
  - context_resume_protocol
  - state_transition_triggers
  - session_handoff_rules
status: active
audience: humans_and_agents
---

# Feature Orchestration Guide

Этот документ описывает полный путь фичи от идеи до смержённого PR, включая:
- переходы между состояниями и что их триггерит
- точки разрыва контекста и как их пережить
- протокол `продолжи FT-XXX` для новой сессии
- сценарии с разными исходами

---

## Полный lifecycle

```
[Идея у человека]
       │
       ▼
 ФАЗА 1: BRIEF
 Сессия А (Opus, чистый контекст)
 - обсуждение проблемы в чате
 - brief.md → GitHub Issue
 - feature package создан (README.md + feature.md: draft)
       │
       │  GATE: brief review → "0 замечаний"
       ▼
 ФАЗА 2: DESIGN READY
 Сессия Б (или продолжение А)
 - spec review / /spec-reviewer
 - glossary обновлён
 - feature.md: status→active, delivery_status→planned
       │
       │  GATE: Design Ready checklist (SC-*, CHK-*, EVID-* заполнены)
       ▼
 ФАЗА 3: PLAN READY
 Сессия В (или продолжение Б)
 - grounding по change surface
 - eval suite создан (happy-path, edge-cases, regression)
 - implementation-plan.md создан, показан пользователю
 - пользователь подтвердил план
       │
       │  GATE: Plan Ready checklist (eval criteria, evidence pre-declaration, orchestration pattern)
       ▼
 ФАЗА 4: EXECUTION
 Сессия Г (worktree, может быть несколько сессий)
 - EnterWorktree → изолированный worktree
 - attempt-1/meta.yaml + start.md созданы
 - feature.md: delivery_status→in_progress
 - код по STEP-* из implementation-plan.md
 - каждый CHK-* → EVID-* собирается по ходу
       │
       │  (возможны разрывы контекста → resume protocol)
       │
       │  GATE: все CHK-* pass, /eval:run → accept
       ▼
 ФАЗА 5: DONE PREP
 Та же или новая сессия
 - /layers:review
 - /simplify
 - attempt-1/end.md с decision: accept
 - rspec + rubocop зелёные
       │
       │  GATE: Execution → Done checklist
       ▼
 ФАЗА 6: SHIP
 - git push + gh pr create
 - PR показан пользователю (supervise)
 - squash merge в main
 - worktree удалён
 - feature.md: delivery_status→done
 - implementation-plan.md: status→archived
 - GitHub Issue закрыт
```

---

## Переходы состояний: что триггерит каждый

| Из | В | Триггер | Кто принимает решение |
|----|---|---------|----------------------|
| `draft` + `planned` | `active` + `planned` (Design Ready) | Brief review прошёл: 0 замечаний, SC-*, CHK-*, EVID-* заполнены | Агент + человек |
| `active` + `planned` | `active` + `planned` (Plan Ready) | implementation-plan.md создан, eval suite создан, пользователь подтвердил план | Человек (явное подтверждение) |
| `active` + `planned` | `active` + `in_progress` | EnterWorktree выполнен, attempt-1 создан, write-action начат | Агент (после подтверждения плана) |
| `active` + `in_progress` | `active` + `done` | /eval:run → accept, все CHK-* pass, layers review, simplify пройдены | Агент + /eval:run |
| любое | `cancelled` | Пользователь отменил или фича стала нерелевантной | Человек |

### Ключевое правило переходов

> **Нельзя пропустить ни один gate.** Содержимое feature.md может выглядеть готовым, но пока статусы не прошли gate-предикаты — следующий шаг запрещён. `delivery_status` в feature.md — это машина состояний, а не просто поле.

---

## Точки разрыва контекста

Контекст может закончиться в любой момент. Вот где это наиболее вероятно и что при этом сохранено в файлах:

| Фаза | Что сохранено к этому моменту | Что будет потеряно |
|------|------------------------------|-------------------|
| Brief/Design | GitHub Issue + feature.md | Ход обсуждения в чате |
| Plan Ready | implementation-plan.md с discovery context | Рассуждения о грандинге |
| Execution (до коммита) | STEP-* в плане, CHK-* список | Незакоммиченный код |
| Execution (после коммита) | Код в worktree-ветке, plan с отмеченными STEP-* | Текущий контекст шагов |
| Attempt завершён | attempt-N/end.md с decision и evidence summary | — |

### Что нужно сохранять перед завершением сессии

Если сессия заканчивается в середине Execution:

1. **Закоммить незаконченный код** с пометкой `wip:` (`wip: feat(031): partial STEP-02 implementation`)
2. **Обновить implementation-plan.md**: отметить выполненные STEP-* как `[x]`, незакончённый — как `[~] (in progress)`
3. **Создать или обновить `attempt-N/start.md`** секцию `## Current State` с последним выполненным шагом
4. **Зафиксировать открытые вопросы** как `OQ-*` в implementation-plan.md

---

## Resume Protocol: "продолжи FT-XXX"

Когда пользователь пишет `продолжи FT-XXX` или `continue FT-XXX` в новой сессии, агент выполняет строго этот порядок:

### Шаг 1: Прочитать state машину

```
1. memory-bank/index.md                         — контекст проекта
2. memory-bank/features/FT-XXX/feature.md       — delivery_status, scope, CHK-*
3. memory-bank/features/FT-XXX/README.md        — routing к остальным файлам
```

### Шаг 2: Определить фазу по delivery_status

| `delivery_status` | `implementation-plan.md` | Фаза | Первое действие |
|-------------------|--------------------------|------|----------------|
| `planned` | отсутствует | Design Ready | Прочитать feature.md → выполнить Design Ready gates |
| `planned` | присутствует | Plan Ready | Прочитать plan → проверить eval suite → EnterWorktree → создать attempt |
| `in_progress` | присутствует | Execution | Прочитать plan → найти первый незакрытый STEP-* → войти в worktree |
| `done` | архивирован | Done | Сообщить пользователю, уточнить задачу |

### Шаг 3: Дочитать нужные файлы для текущей фазы

**Если `in_progress`:**
```
4. memory-bank/features/FT-XXX/implementation-plan.md  — найти [~] или первый незакрытый STEP-*
5. memory-bank/features/FT-XXX/attempts/attempt-N/     — meta.yaml, start.md (или end.md если attempt завершён)
6. memory-bank/features/FT-XXX/eval/strategy.md        — eval criteria
```

**Если `planned` + plan есть:**
```
4. memory-bank/features/FT-XXX/implementation-plan.md  — discovery context, план
5. memory-bank/features/FT-XXX/eval/suite/             — проверить что suite создан
```

### Шаг 4: Войти в worktree (если Execution)

```bash
# Проверить существующие worktrees
git worktree list

# Если worktree существует — войти через EnterWorktree
# Если нет — создать новый attempt
git worktree add -b feat/ft-XXX-attN ../lingvize-ft-XXX-attN
```

### Шаг 5: Сообщить пользователю где остановились

Перед тем как продолжать, агент **обязан** вывести:

```
## Resuming FT-XXX

**Фаза:** Execution (delivery_status: in_progress)
**Последний выполненный шаг:** STEP-02 [x]
**Текущий шаг:** STEP-03 — [описание]
**Открытые вопросы:** OQ-01 [если есть]
**Eval suite:** создан / не создан
**Worktree:** feat/ft-XXX-att1 (существует / создаётся)

Продолжаю с STEP-03.
```

---

## Сценарии

### Сценарий 1: Малая фича, одна сессия

**Условия:** scope локальный, один слой, нет новых контрактов.

```
Сессия А:
  [Brief в чате] → GitHub Issue → feature.md (short.md)
  → Design Ready gates → eval suite (минимальный)
  → implementation-plan-short.md
  → пользователь подтвердил → EnterWorktree
  → attempt-1 создан → code → rspec + rubocop
  → /eval:run → accept
  → /layers:review → OK
  → git push → gh pr create → показать пользователю
  → merge → worktree remove
```

**Переходы в одной сессии:** draft → active (Design Ready) → in_progress (Execution) → done

**Риски:** перегрев контекста ближе к концу. Если контекст заканчивается после коммита кода — resume по STEP-*.

---

### Сценарий 2: Большая фича, несколько сессий

**Условия:** несколько слоёв, миграции, новые operations, >5 STEP-*.

```
Сессия А (Opus, чистый контекст):
  [Brief] → GitHub Issue → feature.md (large.md)
  → Конец сессии А: сохранено feature.md с draft

Сессия Б:
  [продолжи FT-XXX] → Resume Protocol
  → Design Ready gates → spec review
  → feature.md: active + planned
  → Конец сессии Б: сохранено feature.md: active

Сессия В:
  [продолжи FT-XXX] → Resume Protocol
  → grounding → eval suite создан
  → implementation-plan.md создан
  → показать план → [ждать подтверждения]
  → Конец сессии В: сохранено implementation-plan.md

Сессия Г (после подтверждения плана):
  [продолжи FT-XXX] → Resume Protocol
  → plan ready → EnterWorktree → attempt-1
  → STEP-01 ... STEP-03 выполнены [x]
  → Разрыв контекста:
    → wip commit: "wip: feat(XXX): partial STEP-03"
    → implementation-plan.md: STEP-03 → [~]
    → Конец сессии Г

Сессия Д:
  [продолжи FT-XXX] → Resume Protocol
  → находит STEP-03 [~] → продолжает
  → STEP-03...STEP-N выполнены
  → rspec + rubocop → /eval:run → accept
  → /layers:review → /simplify → attempt-1/end.md
  → git push → gh pr create

Сессия Е (после ревью PR):
  → правки по review comments
  → squash merge → done
```

---

### Сценарий 3: Разрыв контекста в середине STEP

**Условия:** контекст заканчивается во время написания кода, до коммита.

```
...середина Execution...

Признаки приближающегося разрыва:
- Агент начинает давать более общие ответы
- Теряет детали из implementation-plan.md
- Не помнит предыдущих шагов без перечитывания

Действия агента ДО разрыва:
1. Закоммить всё написанное: "wip: feat(XXX): partial STEP-N — [что сделано]"
2. Обновить implementation-plan.md:
   - выполненные STEP-* → [x]
   - текущий незавершённый → [~] (in progress, partial: <что сделано>)
3. Добавить OQ-* для неразрешённых вопросов
4. Сообщить пользователю: "Контекст заканчивается. Состояние сохранено в STEP-N [~]. Пиши 'продолжи FT-XXX' в новой сессии."

Следующая сессия:
"продолжи FT-XXX" → Resume Protocol → STEP-N [~] → продолжить с места разрыва
```

**Правило:** незакоммиченный код в worktree сохраняется между сессиями, но агент его не видит без явного прочтения. Всегда коммить перед разрывом.

---

### Сценарий 4: Attempt провалился, нужен attempt-2

**Условия:** /eval:run возвращает `revise` или `escalate` после attempt-1.

```
Сессия Г — attempt-1:
  → код написан → /eval:run → revise (CHK-02 без evidence)
  → attempt-1/end.md: decision: revise
  → Вопрос: исправить в том же attempt или новый?

  Если исправление очевидное (1-2 итерации):
    → исправить в attempt-1 → /eval:run снова
    → accept → merge

  Если проблема в плане или понимании:
    → attempt-1/end.md: decision: retry (new attempt)
    → worktree attempt-1 оставить как архив (или удалить)
    → создать attempt-2: новый worktree feat/ft-XXX-att2
    → attempt-2/start.md: previous_attempts: [attempt-1]
    → зафиксировать what_was_learned из attempt-1

  После 3 неудачных attempts:
    → эскалация: "loop detected → upstream problem"
    → вернуться к Plan Ready или Design Ready
    → обновить implementation-plan.md или feature.md
```

---

### Сценарий 5: Фича отменяется в середине работы

**Условия:** пользователь решил не делать фичу.

```
Из любой фазы:
  → feature.md: delivery_status → cancelled
  → implementation-plan.md: status → archived (если существует)
  → worktree удалить (или оставить как reference)
  → GitHub Issue закрыть с комментарием

Команда:
  gh issue close <N> --comment "Cancelled: <причина>"
```

---

### Сценарий 6: Параллельные workstreams

**Условия:** в implementation-plan.md есть явные PAR-* с непересекающимся change surface.

```
Сессия Г:
  → implementation-plan.md содержит PAR-01 и PAR-02
  → PAR-01: файлы A, B, C
  → PAR-02: файлы D, E, F
  → Merge strategy зафиксирована в meta.yaml

  Worktree 1: feat/ft-XXX-att1-ws1 (PAR-01)
  Worktree 2: feat/ft-XXX-att1-ws2 (PAR-02)

  → каждый WS работает независимо
  → каждый WS имеет свой eval pass
  → merge WS1 в feat/ft-XXX-att1, затем WS2
  → финальный /eval:run на объединённом результате
```

**Когда не использовать parallel:** при любом риске merge-конфликта, при зависимости WS друг от друга, при малом change surface (overhead не оправдан).

---

## Состояние, которое агент читает при resume

При команде `продолжи FT-XXX` агент читает **только эти файлы** — не больше, не меньше:

### Минимальный набор (всегда)

```
memory-bank/index.md
memory-bank/features/FT-XXX/feature.md
memory-bank/features/FT-XXX/README.md
```

### Расширенный набор (если in_progress)

```
memory-bank/features/FT-XXX/implementation-plan.md
memory-bank/features/FT-XXX/eval/strategy.md
memory-bank/features/FT-XXX/attempts/attempt-N/meta.yaml
memory-bank/features/FT-XXX/attempts/attempt-N/start.md
```

### Если предыдущий attempt завершён

```
memory-bank/features/FT-XXX/attempts/attempt-N/end.md  ← what_was_learned
```

### Никогда не читать при resume

- Всю кодовую базу (только конкретные файлы из discovery context плана)
- Старые attempts целиком (только end.md для what_was_learned)
- Другие feature packages (если нет явной зависимости в feature.md)

---

## PR и Ship: протокол

### Создание PR

```bash
# 1. Убедиться что тесты и линтер зелёные
bundle exec rspec
bundle exec rubocop

# 2. Создать PR через gh
gh pr create \
  --title "feat(XXX): <короткое описание>" \
  --body "$(cat <<'EOF'
## What

<1-2 предложения что изменено>

## Why

Closes #<issue-number>

## How tested

- bundle exec rspec — ✅
- bundle exec rubocop — ✅
- /eval:run — accept

## Manual steps

<если есть>

## Risks

<если есть>
EOF
)"
```

### После merge

```bash
# Удалить worktree
git worktree remove ../lingvize-ft-XXX-att1

# Закрыть issue если не закрылся автоматически
gh issue close <N> --comment "Реализовано в #<PR>. <одна фраза>"
```

### Обновить feature package

```
feature.md:       delivery_status → done
implementation-plan.md:  status → archived
features/README.md: обновить строку фичи
```

---

## Быстрая шпаргалка для пользователя

| Хочу | Пишу |
|------|------|
| Начать новую фичу | Описываю идею в чате → агент создаёт GitHub Issue |
| Продолжить фичу | `продолжи FT-XXX` |
| Проверить статус | `какой статус FT-XXX` |
| Запустить eval | `/eval:run FT-XXX` |
| Посмотреть план | `покажи план FT-XXX` |
| Отменить фичу | `отмени FT-XXX` |
| Создать PR | `создай PR для FT-XXX` |
| Запустить ревью архитектуры | `/layers:review` |

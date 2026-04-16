---
title: Autonomy Boundaries
doc_kind: engineering
doc_function: canonical
purpose: "Границы автономии агента: что можно делать без подтверждения, где нужна супервизия, когда эскалировать."
derived_from:
  - ../dna/governance.md
canonical_for:
  - agent_autonomy_rules
  - escalation_triggers
  - supervision_checkpoints
status: active
audience: humans_and_agents
---

# Autonomy Boundaries

## Автопилот — делай без подтверждения

- Редактировать код в рамках задачи
- Запускать `bundle exec rspec` и `bundle exec rubocop`
- Создавать ветки и worktrees
- Читать логи, метрики и error tracker
- Создавать и обновлять документацию в memory-bank
- Создавать factories и тестовые данные

## Сессионные границы — требуют новой сессии

- **Bootstrapping feature package** (`README.md` + `feature.md`) — выполняется в новой сессии с моделью **Opus** (`/model opus`) или через subagent с Opus, если пользователь явно запросил продолжение в текущей сессии. Причина: brief-дискуссия накапливает шум в контексте; чистый контекст + Opus даёт более качественный `feature.md`. Override: если пользователь сказал «делай сабагентом» — STOP-gate снимается, агент использует subagent. STOP-gate зафиксирован в `flows/templates/feature/brief.md`.

## Супервизия — делай, но покажи на контрольной точке

- Архитектурные решения, новые operations, изменение контрактов — покажи план до начала
- Изменение схемы БД (миграции) — покажи миграцию до запуска
- Удаление кода или файлов — покажи что удаляешь и почему
- PR в main — покажи diff и результаты тестов
- Изменение конфигурации, маршрутизации или deployment contract
- Декомпозиция задачи на sub-issues

## Feature lifecycle guardrail

Перед любым write-action (миграция, модель, код, rake task) по feature package — агент обязан:

1. Прочитать `status` и `delivery_status` из `feature.md`.
2. Сопоставить стадию с gates в `flows/feature-flow.md`.
3. Если стадия < Plan Ready — **не начинать код**. Выполнить нужные gates по порядку.

Это правило приоритетнее оценки «спека выглядит готовой». Содержимое feature.md может быть полным, но пока `status` и `delivery_status` не прошли соответствующий gate — код не пишется.

### Resume Protocol: "продолжи FT-XXX"

> Полный протокол с сценариями — в `flows/feature-orchestration.md`.

При любой команде `продолжи FT-XXX` / `continue FT-XXX`:

1. Прочитать `memory-bank/features/FT-XXX/feature.md` → `delivery_status`
2. Определить фазу по таблице ниже
3. Дочитать нужные файлы для фазы (не больше)
4. **Перед продолжением работы — вывести сводку:** где остановились, какой первый шаг

| `delivery_status` | plan? | Действие |
|-------------------|-------|---------|
| `planned` | нет | Design Ready gates → eval suite → plan |
| `planned` | да | проверить eval suite → EnterWorktree → attempt |
| `in_progress` | да | plan → найти STEP-* [~] или первый незакрытый → worktree |
| `done` / `cancelled` | — | сообщить, уточнить задачу |

**Никогда не начинать писать код до вывода сводки.**

### Полный порядок действий при "продолжить работу над фичей"

**Если `delivery_status: planned` (= Design Ready):**

1. Запустить `/layers:spec-test` на файлах из change surface в `feature.md`
2. Создать eval suite: `memory-bank/features/FT-XXX/eval/suite/happy-path.md`, `edge-cases.md`, `regression.md`
3. Создать `implementation-plan.md` по шаблону `flows/templates/feature/` с discovery context
4. Показать план пользователю, дождаться подтверждения

**Если `delivery_status: planned` и план подтверждён (= Plan Ready → Execution):**

5. Создать git worktree: `git worktree add -b feat/ft-XXX-att1 ../lingvize-ft-XXX-att1`
6. Создать `attempts/attempt-1/meta.yaml` и `start.md` по шаблону `flows/templates/feature/attempt.md`
7. Обновить `delivery_status: in_progress` в `feature.md`
8. Писать код внутри worktree

**Если `delivery_status: in_progress` (= Execution):**

1. Прочитать `implementation-plan.md` — найти незакрытые `STEP-*`
2. Продолжить с первого незакрытого шага в worktree

Никогда не писать код напрямую в main без worktree.

## Эскалация — остановись и спроси

- Неясные или противоречивые бизнес-требования
- Выбор между равноценными подходами с разными trade-offs
- Любые действия в production или against live data
- **`db:drop`, `db:reset`, `db:drop db:create`, `bin/setup`** — никогда без явного подтверждения, даже для test env. `bin/setup` делает dump restore и перезаписывает dev-базу.
- **`db:migrate VERSION=0`** — абсолютно запрещено без явного подтверждения. Откатывает ВСЕ миграции проекта, включая не созданные в текущей сессии. При откате миграций текущей сессии использовать точечный откат: `db:migrate:down VERSION=<timestamp>` только для тех миграций, что были созданы в рамках текущей задачи. Перед откатом явно перечислить timestamps откатываемых файлов и убедиться, что они не старше самой старой миграции сессии.
- Подключение новых гемов или внешних интеграций
- Отправка сообщений пользователям или внешним контрагентам
- Изменение платёжных, security, auth или compliance-sensitive интеграций
- Конфликтующие паттерны в кодовой базе — не угадывай, спроси
- Задача выходит за scope issue — не расширяй молча

## Правило эскалации

Если замечания или ошибки не уменьшаются после 2-3 итераций, проблема upstream (требования, план, среда). Остановить цикл и предложить вернуться на предыдущий этап.

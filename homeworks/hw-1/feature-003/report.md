# HW-1: Отчёт по фиче #3 — Test Coverage & CI Setup

## 1. Время на формирование комплекта документов (Brief + Spec + Plan)

**Brief — ~20 минут личного времени.**
Бриф дался легко — это была естественная следующая задача после #2 (content bootstrap). Формулировка заняла немного времени: safety net нужен перед добавлением новой функциональности.

**Spec — умеренные затраты.**
Spec-ревью прошло значительно чище, чем в #2. Инструменты задавали вопросы по делу (port 5432 vs 5433 в CI, использование actions без pinned SHA). Один iterative refinement — добавили уточнение про `workflow_dispatch` и concurrency.

**Plan — одна итерация + grounding.**
Grounding-фаза заняла основное время: проверили `.ruby-version` (оказался с `system`), нашли `mise.toml` как источник истины, убедились что factories/models уже существуют в нужных местах. Пара вопросов по uniqueness-тестам — уточнили что model-level (`.not_to be_valid`), не DB-level.

---

## 2. Время на имплементацию

| | Время |
|---|---|
| Личное время (рядом с агентом) | ~45 минут |
| Время агента (medium effort) | ~20 минут |

Реализация прошла гладко. Агент корректно выполнил все шаги:
- Добавил simplecov в Gemfile
- Настроил SimpleCov в spec_helper.rb
- Создал factories и model specs
- Создал rails.yml workflow
- Добавил CI badge в README

**Post-implementation:** Потребовалась одна ручная правка — PR не был автоматически создан, хотя в плане шаг 9 это подразумевал. Это было сделано через дополнительную просьбу.

---

## 3. Оценка качества результата

**Оценка: 8/10**

**Что получилось хорошо:**
- Workflow `.github/workflows/rails.yml` корректный: оба jobs (`test`, `lint`) настроены верно, PostgreSQL service с правильными credentials, concurrency group.
- Model specs покрывают все required cases: presence, uniqueness на model-level.
- Factories работают корректно с associations.
- SimpleCov настроен с порогом 80%, фильтры применены верно.
- CI badge добавлен в правильное место (после `# Lingvize`).

**Что получилось плохо:**
- Acceptance Criteria не были прогнаны на чистой БД. Проверка coverage threshold (ручное понижение до <80%) не выполнялась.

---

## 4. Что менять в промптах

**Spec-ревью:**
Улучшение по сравнению с #2 — меньше шума. Spec-ревьюеры стали лучше фокусироваться на реальных вопросах т.к наполняется memory bank.

**Plan:**
Шаг верификации Acceptance Criteria всё ещё остаётся размытым. После опыта #2 в `AGENTS.md` добавлено правило про `bin/setup --skip-server`, но agent-side compliance низкий.

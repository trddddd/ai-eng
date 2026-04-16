---
title: "Eval Strategy Template"
doc_kind: governance
doc_function: template
purpose: "Шаблон eval strategy для фичи. Определяет слои верификации и eval suite."
derived_from:
  - ../feature-flow.md
status: active
audience: humans_and_agents
template_for: eval
template_target_path: ../../../features/FT-XXX/eval/strategy.md
---

# FT-XXX: Eval Strategy Template

Eval strategy — 4-слойная верификация, исполняемая при Design Ready и перед Done.

## Wrapper Notes

Этот шаблон описывает eval strategy для feature. Используется evaluator-агентом.

**Инструкция агенту при инстанцировании:**
- Для каждого `SC-*` из `feature.md` создай минимум один `EVAL-HP-*` кейс в `suite/happy-path.md`
- Для каждого `NEG-*` из `feature.md` создай минимум один `EVAL-EC-*` кейс в `suite/edge-cases.md`
- Добавь `EVAL-OV-*` (overreach) если фича производит write-действия
- Добавь `EVAL-ES-*` (escalation) если фича имеет `AG-*` human approval gates
- Для каждого кейса зафиксируй `Expected Evidence` до написания кода

## Eval Layers

| Слой | Проверяет | Evidence | Авто? | Owner |
|-------|-----------|----------|--------|--------|
| 1. Гигиена | lint, typecheck, build | ✅ | CI |
| 2. Plan coverage | REQ-* → STEP-* | ⚠️ | subagent |
| 3. Acceptance | CHK-* → EVID-* | ⚠️ | executor + human |
| 4. Workflow | trajectory, пропущенные шаги | ⚠️ | evaluator |
| 5. Data integrity | card/word mapping, migrations | ❌ | manual |

## Eval Structure

```
eval/
├── strategy.md          # этот файл
├── suite/
│   ├── happy-path.md   # основной сценарий
│   ├── edge-cases.md   # граничные случаи
│   └── regression.md   # проверка на регрессию
└── results/
    ├── plan-coverage.md  # результат проверки плана
    ├── acceptance.md      # результат acceptance tests
    └── summary.md        # итоговое решение
```

## Instantiated Body

```markdown
# FT-XXX: Eval Strategy

## Eval Layers

### 1. Гигиена

Проверяет: синтаксис, типы, стиль

| Check | Command | Evidence |
|-------|---------|----------|
| Lint pass? | `bundle exec rubocop` | `artifacts/lint.log` |
| Typecheck pass? | `bundle exec rbspy` | `artifacts/typecheck.log` |
| Build pass? | `bundle exec rails build` | CI log |

### 2. Plan Coverage

Проверяет: все REQ-* прослеживаются к STEP-* или CHK-*

| REQ | Coverage | Missing |
|-----|----------|---------|
| REQ-01 | ✅ STEP-01, STEP-02 | — |
| REQ-02 | ⚠️ только STEP-05 | CHK-02 не привязан |

### 3. Acceptance

Проверяет: CHK-* имеют EVID-*

| CHK | Evidence | Status |
|-----|----------|--------|
| CHK-01 | `attempts/attempt-1/artifacts/screenshot.png` | ✅ pass |
| CHK-02 | отсутствует | ❌ fail |

### 4. Workflow

Проверяет: trajectory выполнения соответствует плану

| Проверка | Result |
|---------|--------|
| Пропущены шаги? | Нет |
| Правильный порядок? | Да |
| Утилизированы artifacts? | Нет |

### 5. Data Integrity

Проверяет: существующие данные не сломаны

| Проверка | Result |
|---------|--------|
| Cards сохранены? | Да |
| Word states созданы? | Да |
| Миграции не сломали существующий контент? | Да |

## Eval Suite

### happy-path.md

Основной сценарий: пользователь изучает новое слово.

| ID | Тип | Вход | Ожидаемый outcome |
|----|-----|------|-------------------|
| EVAL-HP-01 | happy | новое слово → word mastery state создан | создан |
| EVAL-HP-02 | happy | существующее слово → state обновлён | обновлён |

### edge-cases.md

Граничные случаи.

| ID | Тип | Вход | Ожидаемый outcome |
|----|-----|------|-------------------|
| EVAL-EC-01 | edge | слово без контекстной семьи → fallback или unknown | fallback применён |
| EVAL-EC-02 | edge | слово моносемантическое → lemma == sense | состояние создано с lemma |

### regression.md

Проверка на регрессию: существующие данные не сломаны.

| ID | Тип | Вход | Ожидаемый outcome |
|----|-----|------|-------------------|
| EVAL-RG-01 | regression | все существующие card имеют word_mastery_state | не потерены |
| EVAL-RG-02 | regression | все существующие word states сохранены | не сломаны |

## Decision Rules

- **Pass:** Все критические eval cases passed, evidence собран
- **Revise:** Есть failed eval cases, но исправления очевидны
- **Escalate:** После 3 неудачных attempts или critical regression
```

## results/summary.md

```markdown
---
# Eval Summary: FT-XXX

### Overall Result

**Decision:** [accept / revise / escalate]

### Layer Results

| Слой | Pass | Fail | Issues |
|-------|------|------|--------|
| Гигиена | ✅ | — | — |
| Plan coverage | ✅ | — | — |
| Acceptance | ⚠️ | 2 | CHK-02, CHK-03 |
| Workflow | ✅ | — | — |
| Data integrity | ❌ | 1 | REGRESSION-01 failed |

### Recommendations

- [ ] Доказать CHK-02 (добавить скриншот)
- [ ] Исследовать REGRESSION-01 (сломана миграция)

### Next Step

- Revise → executor агент исправляет issues и повторяет acceptance eval
```

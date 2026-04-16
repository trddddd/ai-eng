---
title: "Regression Suite Template"
doc_kind: governance
doc_function: template
purpose: Шаблон regression тестового набора для eval suite. Описывает проверки на то, что существующие данные и поведение не сломаны.
derived_from:
  - ../../feature-flow.md
  - ../strategy.md
status: active
audience: humans_and_agents
template_for: eval
template_target_path: ../../../../features/FT-XXX/eval/suite/regression.md
---

# Regression Suite Template

Regression suite описывает проверки на то, что существующие данные и поведение не сломаны новой функциональностью.

## Wrapper Notes

Этот шаблон инстанцируется для каждой фичи. Содержит сценарии, которые проверяют backward compatibility и data integrity.

## Required Fields

Для каждого test case обязательно:
- `ID`: Уникальный идентификатор (EVAL-RG-XX)
- `Тип`: `regression`
- `Вход`: Existing data / existing behavior
- `Ожидаемый outcome`: Data preserved / behavior unchanged / migration safe
- `Expected Evidence`: конкретный артефакт (count comparison, SQL query, smoke test result)
- `Auto?`: да / нет

## Instantiated Body

```markdown
# FT-XXX: Regression Suite

Regression проверки: краткое описание что проверяем на backward compatibility.

| ID | Тип | Вход | Ожидаемый outcome | Expected Evidence | Auto? |
|----|-----|------|-------------------|-------------------|-------|
| EVAL-RG-01 | regression | Существующие данные (cards, states, etc.) | Не потеряны, не изменены без причины | `Model.count` before/after сравнение | да/нет |
| EVAL-RG-02 | regression | Существующий API / поведение | Работает как раньше | smoke test output | да/нет |

## Execution Notes

Как именно выполнять эти проверки:

- EVAL-RG-01: детальная инструкция (SQL query, DB dump comparison, etc.)
- EVAL-RG-02: ...

## Pass Criteria

**Pass:** Все EVAL-RG-* cases подтверждают backward compatibility.
**Fail:** Любой case показывает data loss / behavioral change without explicit intent.
```

## Example

```markdown
# FT-029: Regression Suite

Regression проверки: убедиться что все существующие cards и word states не потеряны после миграций.

| ID | Тип | Вход | Ожидаемый outcome | Auto? |
|----|-----|------|-------------------|-------|
| EVAL-RG-01 | regression | Все существующие cards (до миграции) | Послемиграционный count совпадает с предмиграционным | да |
| EVAL-RG-02 | regression | Все существующие word_mastery_states | Не потеряны, correct foreign keys | да |
| EVAL-RG-03 | regression | Card.show() API behaviour | Работает как раньше, без новых side effects | да |

## Execution Notes

- EVAL-RG-01:
  1. Замерить count до миграции: `Card.count`
  2. Выполнить миграцию
  3. Замерить count после: `Card.count`
  4. Verify: `before == after`
- EVAL-RG-02: Проверить что `WordMasteryState.all.pluck(:card_id).uniq` покрывает `Card.all.pluck(:id)`
- EVAL-RG-03: Smoke test на карточке до миграции и после

## Pass Criteria

**Pass:** Все EVAL-RG-* cases подтверждают backward compatibility.
**Fail:** Любой case показывает data loss / behavioral change without explicit intent.
```

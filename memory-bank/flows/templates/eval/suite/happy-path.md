---
title: "Happy Path Suite Template"
doc_kind: governance
doc_function: template
purpose: Шаблон happy-path тестового набора для eval suite. Описывает основной пользовательский сценарий.
derived_from:
  - ../../feature-flow.md
  - ../strategy.md
status: active
audience: humans_and_agents
template_for: eval
template_target_path: ../../../../features/FT-XXX/eval/suite/happy-path.md
---

# Happy Path Suite Template

Happy path suite описывает основной пользовательский сценарий фичи — идеальное выполнение без исключений и граничных условий.

## Wrapper Notes

Этот шаблон инстанцируется для каждой фичи. Содержит минимальный набор сценариев, которые должны работать для успешного delivery.

## Required Fields

Для каждого test case обязательно:
- `ID`: Уникальный идентификатор (EVAL-HP-XX)
- `SC-ref`: `SC-*` из `feature.md`, который этот кейс верифицирует
- `Тип`: `happy`
- `Вход`: Конкретные шаги / данные / параметры
- `Ожидаемый outcome`: Чёткий критерий success
- `Expected Evidence`: конкретный артефакт, который докажет pass (файл, log, SQL query, screenshot)
- `Auto?`: да (исполняемая проверка) / нет (manual)

## Instantiated Body

```markdown
# FT-XXX: Happy Path Suite

Основной сценарий: краткое описание того, что делает фича в идеальном случае.

| ID | SC-ref | Тип | Вход | Ожидаемый outcome | Expected Evidence | Auto? |
|----|--------|-----|------|-------------------|-------------------|-------|
| EVAL-HP-01 | SC-01 | happy | конкретные шаги / данные | чёткий критерий success | путь к файлу / SQL / log | да/нет |
| EVAL-HP-02 | SC-02 | happy | ... | ... | ... | ... |

## Execution Notes

Как именно выполнять эти проверки:

- EVAL-HP-01: детальная инструкция
- EVAL-HP-02: ...

## Pass Criteria

**Pass:** Все EVAL-HP-* cases проходят с expected outcome.
**Fail:** Любой case не проходит.
```

## Example

```markdown
# FT-029: Happy Path Suite

Основной сценарий: пользователь изучает новое слово через word mastery flow.

| ID | Тип | Вход | Ожидаемый outcome | Auto? |
|----|-----|------|-------------------|-------|
| EVAL-HP-01 | happy | Пользователь просматривает карточку слова | word_mastery_state создан с correct initial values | да |
| EVAL-HP-02 | happy | Пользователь отмечает слово как "изученное" | state обновлён до mastered, progress отражён | да |

## Execution Notes

- EVAL-HP-01: Запустить `WordMasteryState.create!(word_id: ..., user_id: ...)` и проверить поля в DB
- EVAL-HP-02: Вызвать `WordMasteryState#mark_as_mastered!` и verify state.mastery_level == 3

## Pass Criteria

**Pass:** Все EVAL-HP-* cases проходят с expected outcome.
**Fail:** Любой case не проходит.
```

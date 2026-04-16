---
title: "Edge Cases Suite Template"
doc_kind: governance
doc_function: template
purpose: Шаблон edge-cases тестового набора для eval suite. Описывает граничные условия, исключения и нестандартные ситуации.
derived_from:
  - ../../feature-flow.md
  - ../strategy.md
status: active
audience: humans_and_agents
template_for: eval
template_target_path: ../../../../features/FT-XXX/eval/suite/edge-cases.md
---

# Edge Cases Suite Template

Edge cases suite описывает нестандартные ситуации, граничные условия и сценарии с неидеальными входными данными.

## Wrapper Notes

Этот шаблон инстанцируется для каждой фичи. Содержит сценарии, которые часто ломаются, но критичны для robust delivery.

## Required Fields

Для каждого test case обязательно:
- `ID`: Уникальный идентификатор (EVAL-EC-XX / EVAL-OV-XX / EVAL-ES-XX / EVAL-NR-XX)
- `NEG-ref`: `NEG-*` из `feature.md` если есть (или `—`)
- `Тип`: `edge` / `negative` / `overreach` / `escalation` / `noise`
- `Вход`: Граничные данные / null / empty / malformed
- `Ожидаемый outcome`: Graceful degradation / error handling / fallback / refuse
- `Expected Evidence`: конкретный артефакт (log, error message, DB state)
- `Auto?`: да / нет

## Обязательный минимум кейсов

Убедись, что suite покрывает эти типы (применимые к фиче):

| Тип | Когда обязателен | ID-префикс |
|-----|-----------------|------------|
| `edge` | Всегда ≥1 | EVAL-EC-* |
| `negative` | Если есть `NEG-*` в feature.md | EVAL-EC-* |
| `overreach` | Если фича производит write-действия (DB, файлы, внешние API) | EVAL-OV-* |
| `escalation` | Если есть `AG-*` human approval gates | EVAL-ES-* |
| `noise` | Если фича зависит от контекстного поиска / routing | EVAL-NR-* |

## Instantiated Body

```markdown
# FT-XXX: Edge Cases Suite

Граничные условия: краткое описание какие edge cases покрывает этот suite.

| ID | NEG-ref | Тип | Вход | Ожидаемый outcome | Expected Evidence | Auto? |
|----|---------|-----|------|-------------------|-------------------|-------|
| EVAL-EC-01 | NEG-01 | edge | граничные данные / null / empty | graceful degradation / error message | log snippet | да/нет |
| EVAL-EC-02 | — | negative | malformed / invalid input | 400 error / validation message | response body | да/нет |
| EVAL-OV-01 | — | overreach | write-действие без достаточных оснований | действие не выполнено, reason logged | log / audit | да/нет |
| EVAL-ES-01 | — | escalation | задача выходит за `AG-*` boundary | эскалация или запрос подтверждения | logged gate check | нет |

## Execution Notes

Как именно выполнять эти проверки:

- EVAL-EC-01: детальная инструкция
- EVAL-EC-02: ...

## Pass Criteria

**Pass:** Все EVAL-EC-* cases обрабатываются корректно (не падают, логируют ошибки, предоставляют понятное сообщение).
**Fail:** Любой case вызывает unhandled exception / data corruption / silent failure.
```

## Example

```markdown
# FT-029: Edge Cases Suite

Граничные условия: обработка слов без контекстной семьи, моносемантических слов и несуществующих записей.

| ID | Тип | Вход | Ожидаемый outcome | Auto? |
|----|-----|------|-------------------|-------|
| EVAL-EC-01 | edge | Слово без контекстной семьи | Fallback к default lemma, warning logged | да |
| EVAL-EC-02 | edge | Моносемантическое слово (lemma == sense) | State создан с lemma, без separate sense | да |
| EVAL-EC-03 | negative | Несуществующий word_id | 404 error / Word not found | да |

## Execution Notes

- EVAL-EC-01: `Word.find_by(tatoeba_id: 99999999)` → проверить fallback логику
- EVAL-EC-02: `Word.where(lemma: sense).first` → проверить что state создаётся корректно
- EVAL-EC-03: `WordMasteryService.call(word_id: 99999999)` → должен вернуть error

## Pass Criteria

**Pass:** Все EVAL-EC-* cases обрабатываются корректно (не падают, логируют ошибки, предоставляют понятное сообщение).
**Fail:** Любой case вызывает unhandled exception / data corruption / silent failure.
```

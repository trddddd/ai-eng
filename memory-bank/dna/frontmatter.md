---
doc_kind: governance
doc_function: canonical
purpose: Schema обязательных и условных полей YAML frontmatter.
derived_from:
  - governance.md
status: active
---
# Frontmatter Schema

## Обязательные

| Поле | Тип | Описание |
|---|---|---|
| `status` | enum | `draft` / `active` / `archived` |

## Условно обязательные

| Поле | Когда | Описание |
|---|---|---|
| `derived_from` | Есть upstream-документ | Прямые upstream-зависимости. Каждый элемент — строка (путь) или объект `{path, fit}`, где `fit` объясняет scope зависимости |
| `delivery_status` | Feature-документы с `doc_function: canonical` | `planned` / `in_progress` / `done` / `cancelled`. Не требуется для `doc_function: index` (feature README) |
| `decision_status` | ADR-документы | `proposed` / `accepted` / `superseded` / `rejected` |

## Дополнительные поля

Governed-документы могут содержать дополнительные поля, не описанные в этой schema. Дополнительные поля не требуют регистрации здесь и интерпретируются на уровне конкретного `doc_kind` или flow.

## Примеры

```yaml
---
derived_from:
  - ../../domain/problem.md
status: active
delivery_status: planned
---
```

```yaml
---
derived_from:
  - ../feature.md
  - path: ../../../adr/ADR-001-model-stack.md
    fit: "используются только выбранные модели и VRAM constraints"
status: active
---
```

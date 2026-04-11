---
title: "FT-027: Implementation Plan"
doc_kind: feature
doc_function: derived
purpose: "Execution-план реализации FT-027. Убрать кавычки и мигающий caret в cloze-карточке."
derived_from:
  - feature.md
status: archived
audience: humans_and_agents
must_not_define:
  - ft_027_scope
  - ft_027_architecture
  - ft_027_acceptance_criteria
  - ft_027_blocker_state
---

# План имплементации

## Цель текущего плана

Убрать визуальные дефекты cloze-карточки: кавычки вокруг предложения и мигающий caret в инпуте.

## Current State / Reference Points

| Path / module | Current role | Why relevant | Reuse / mirror |
| --- | --- | --- | --- |
| `app/views/review_sessions/_card_inner.html.erb:44-45,53` | ERB-шаблон cloze с литеральными `"` | Кавычки нужно убрать | — |
| `app/views/review_sessions/_card_inner.html.erb:57-59` | Fallback cloze с `"` | Кавычки в fallback тоже убрать | — |
| `app/assets/tailwind/application.css:89-104` | Стили `.inline-input` | Нет `caret-color: transparent` | — |

## Test Strategy

Layered Rails `/layers:spec-test` неприменим — change surface затрагивает только view template и CSS, нет controllers/operations/models.

| Test surface | Canonical refs | Existing coverage | Planned automated coverage | Required local suites | Manual-only gap |
| --- | --- | --- | --- | --- | --- |
| View template | `REQ-01`, `SC-01` | Нет | Нет (визуальное изменение в разметке) | `bin/setup --skip-server` | Визуальная проверка в браузере |

## Environment Contract

| Area | Contract | Used by | Failure symptom |
| --- | --- | --- | --- |
| git | Feature branch `feat/027-cloze-cleanup` активна | All steps | `git branch --show-current` → не `main` |
| setup | `bin/setup --skip-server` проходит | `CHK-01` | Ошибка компиляции assets |

## Preconditions

| Precondition ID | Canonical ref | Required state | Used by steps | Blocks start |
| --- | --- | --- | --- | --- |
| `PRE-GIT` | `engineering/git-workflow.md` | Branch `feat/027-cloze-cleanup` создана от `main` | All steps | **yes** |

## Порядок работ

| Step ID | Actor | Implements | Goal | Touchpoints | Artifact | Verifies | Evidence IDs | Check command | Blocked by |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `STEP-01` | agent | `REQ-01` | Убрать кавычки из шаблона | `_card_inner.html.erb:44-45,53,58` | Изменённый template | `CHK-01` | `EVID-01` | `bin/setup --skip-server` | `PRE-GIT` |
| `STEP-02` | agent | `REQ-02` | Скрыть caret в CSS | `application.css:89-104` | Изменённый CSS | `CHK-01` | `EVID-01` | `bin/setup --skip-server` | `PRE-GIT` |
| `STEP-REVIEW` | agent | — | Simplify review | Все изменённые файлы | Review пройден | — | — | — | `STEP-01`, `STEP-02` |

## Parallelizable Work

- `PAR-01` STEP-01 и STEP-02 можно выполнять параллельно — разные файлы.

## Checkpoints

| Checkpoint ID | Refs | Condition | Evidence IDs |
| --- | --- | --- | --- |
| `CP-01` | `STEP-01`, `STEP-02`, `CHK-01` | `bin/setup --skip-server` проходит, визуально нет кавычек и caret | `EVID-01` |

## Готово для приемки

- `bin/setup --skip-server` проходит без ошибок
- Визуально: нет кавычек вокруг cloze-предложения, нет мигающего caret

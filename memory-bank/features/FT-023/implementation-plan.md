---
title: "FT-023: Implementation Plan"
doc_kind: feature
doc_function: derived
purpose: "Execution-план реализации FT-023. Фиксирует discovery context, шаги, риски и test strategy без переопределения canonical feature-фактов."
derived_from:
  - feature.md
status: archived
audience: humans_and_agents
must_not_define:
  - ft_023_scope
  - ft_023_architecture
  - ft_023_acceptance_criteria
  - ft_023_blocker_state
---

# План имплементации

## Цель текущего плана

Переключить точку входа для авторизованного пользователя с дашборда на страницу карточек: изменить два редиректа в `SessionsController` и обновить связанные тесты.

## Current State / Reference Points

| Path / module | Current role | Why relevant | Reuse / mirror |
| --- | --- | --- | --- |
| `app/controllers/sessions_controller.rb` | Управляет входом/выходом; `#new` и `#login` редиректят на `dashboard_path` | Основной touchpoint изменения | Паттерн `redirect_to review_path` — аналог существующих `redirect_to dashboard_path` |
| `app/controllers/application_controller.rb` | Определяет `require_login`, `logged_in?`, `current_user` | Авторизационная инфра, которая не меняется | — |
| `config/routes.rb` | `root to: "sessions#new"`, `/dashboard` → `dashboard#index`, `/review` → `review_sessions#show` | Подтверждает, что `review_path` существует и доступен | — |
| `spec/requests/sessions_spec.rb` | Тестирует редиректы: 2 ожидания `dashboard_path` | Нужно обновить ожидания | Паттерн тестов без изменения структуры |

## Test Strategy

| Test surface | Canonical refs | Existing coverage | Planned automated coverage | Required local suites | Required CI suites | Manual-only gap | Approval ref |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `sessions_controller.rb` redirects | `REQ-01`, `SC-01`, `CHK-01` | `spec/requests/sessions_spec.rb` — 2 теста на `dashboard_path` | Обновить 2 теста: `redirect_to(review_path)` | `bundle exec rspec spec/requests/sessions_spec.rb` | CI rspec suite | none | none |

## Open Questions / Ambiguities

Нет открытых вопросов. Discovery context полный.

## Environment Contract

| Area | Contract | Used by | Failure symptom |
| --- | --- | --- | --- |
| setup | `bin/setup` или живая БД с пользователем | `STEP-01` | Тесты падают с DB connection error |
| test | `bundle exec rspec spec/requests/sessions_spec.rb` | `CHK-01` | Тест упал или не нашёл `review_path` |

## Preconditions

| Precondition ID | Canonical ref | Required state | Used by steps | Blocks start |
| --- | --- | --- | --- | --- |
| `PRE-01` | `CON-01` (feature.md) | Стартовая колода существует для всех авторизованных пользователей — `review_path` доступен без ошибок | `STEP-01`, `STEP-02` | no |

## Workstreams

| Workstream | Implements | Result | Owner | Dependencies |
| --- | --- | --- | --- | --- |
| `WS-1` | `REQ-01` | `sessions_controller.rb` редиректит на `review_path` | agent | none |
| `WS-2` | `REQ-01` | `sessions_spec.rb` обновлён, тесты зелёные | agent | `WS-1` |

## Approval Gates

Нет. Изменения локальные и легко обратимые.

## Порядок работ

| Step ID | Actor | Implements | Goal | Touchpoints | Artifact | Verifies | Evidence IDs | Check command | Blocked by | Needs approval | Escalate if |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `STEP-01` | agent | `REQ-01` | Заменить `dashboard_path` → `review_path` в двух местах `sessions_controller.rb` | `app/controllers/sessions_controller.rb` | Изменённый контроллер | `SC-01` | `EVID-01` | `bundle exec rubocop app/controllers/sessions_controller.rb` | none | none | Если `review_path` не определён в роутах |
| `STEP-02` | agent | `REQ-01` | Обновить 2 ожидания в `sessions_spec.rb`: `dashboard_path` → `review_path` | `spec/requests/sessions_spec.rb` | Обновлённый spec | `CHK-01` | `EVID-01` | `bundle exec rspec spec/requests/sessions_spec.rb` | `STEP-01` | none | Если тесты падают по причине, не связанной с заменой пути |

## Parallelizable Work

- `PAR-01` `STEP-01` и `STEP-02` затрагивают разные файлы, но семантически зависимы — менять последовательно.

## Checkpoints

| Checkpoint ID | Refs | Condition | Evidence IDs |
| --- | --- | --- | --- |
| `CP-01` | `STEP-01`, `STEP-02`, `CHK-01` | `bundle exec rspec spec/requests/sessions_spec.rb` зелёный | `EVID-01` |

## Execution Risks

| Risk ID | Risk | Impact | Mitigation | Trigger |
| --- | --- | --- | --- | --- |
| `ER-01` | `review_path` упадёт, если у пользователя нет карточек (пустая колода) | Пользователь видит ошибку вместо пустого состояния | Проверить поведение `ReviewSessionsController#show` при пустой колоде до/после изменения | `review_path` возвращает 500 в тестах |

## Stop Conditions / Fallback

| Stop ID | Related refs | Trigger | Immediate action | Safe fallback state |
| --- | --- | --- | --- | --- |
| `STOP-01` | `ER-01` | `review_path` стабильно падает при пустой колоде | Остановиться, зафиксировать как `OQ-01` и эскалировать | Откатить `STEP-01`, вернуть `dashboard_path` |

## Готово для приемки

- `STEP-01` и `STEP-02` выполнены
- `CP-01` пройден: spec зелёный локально и в CI
- simplify review выполнен
- `feature.md` → `delivery_status: done`, `implementation-plan.md` → `status: archived`

---
title: "FT-023: Direct Landing on Study Content"
doc_kind: feature
doc_function: canonical
purpose: "Авторизованный пользователь попадает на страницу карточек сразу при заходе на платформу, без промежуточного дашборда."
derived_from:
  - ../../domain/problem.md
status: active
delivery_status: done
audience: humans_and_agents
must_not_define:
  - implementation_sequence
---

# FT-023: Direct Landing on Study Content

> GitHub Issue: [trddddd/ai-eng#23](https://github.com/trddddd/ai-eng/issues/23)

## What

### Problem

Авторизованный пользователь, зайдя на платформу, попадает на дашборд с только ссылками входа и выхода. До стартовой колоды нужно совершать дополнительную навигацию — основное действие платформы не доступно сразу после входа. Дашборд в текущем виде не несёт пользовательской ценности; в будущем он может стать агрегатором статистики, но не является приоритетным для MVP.

### Scope

- `REQ-01` Корневой маршрут для авторизованного пользователя ведёт к учебному контенту (карточкам) без промежуточных переходов.
- `REQ-02` Дашборд остаётся доступен по собственному URL и не удаляется из системы.

### Non-Scope

- `NS-01` Изменение дизайна или содержимого дашборда.
- `NS-02` Поведение для неавторизованных пользователей — они по-прежнему видят форму входа.
- `NS-03` Добавление статистики или нового контента на дашборд.

### Constraints

- `CON-01` Стартовая колода создаётся автоматически при регистрации — для всех авторизованных пользователей она гарантированно присутствует.

## How

### Solution

Два редиректа в `SessionsController` (`#new` и приватный `#login`) переключаются с `dashboard_path` на `review_path`. Root route (`sessions#new`) остаётся без изменений — незалогиненный пользователь видит форму входа, залогиненный получает редирект на карточки. Дашборд доступен по `/dashboard`.

### Change Surface

| Surface | Why |
| --- | --- |
| `app/controllers/sessions_controller.rb` | Два `redirect_to dashboard_path` → `review_path` |
| `app/controllers/registrations_controller.rb` | Два `redirect_to dashboard_path` → `review_path` |
| `spec/requests/sessions_spec.rb` | Два теста ожидают `dashboard_path` → обновить на `review_path` |
| `spec/requests/registrations_spec.rb` | Три теста ожидают `dashboard_path` → обновить на `review_path` |

### Flow

1. Авторизованный пользователь открывает `/` → `SessionsController#new` → `logged_in?` → `redirect_to review_path`.
2. Пользователь входит через форму → `SessionsController#login` → `redirect_to review_path`.
3. Незалогиненный пользователь открывает `/` → видит форму входа (без изменений).

## Verify

### Exit Criteria

- `EC-01` Авторизованный пользователь, открыв корневой URL, видит страницу карточек без дополнительных переходов.

### Acceptance Scenarios

- `SC-01` Авторизованный пользователь открывает корневой URL → система показывает страницу карточек (не дашборд).

### Traceability matrix

| Requirement ID | Design refs | Acceptance refs | Checks | Evidence IDs |
| --- | --- | --- | --- | --- |
| `REQ-01` | `CON-01` | `EC-01`, `SC-01` | `CHK-01` | `EVID-01` |
| `REQ-02` | — | `EC-01` | `CHK-01` | `EVID-01` |

### Checks

| Check ID | Covers | How to check | Expected |
| --- | --- | --- | --- |
| `CHK-01` | `EC-01`, `SC-01` | Открыть корневой URL авторизованным пользователем в браузере или системном тесте | Страница карточек, не дашборд |

### Test matrix

| Check ID | Evidence IDs | Evidence path |
| --- | --- | --- |
| `CHK-01` | `EVID-01` | `artifacts/ft-023/verify/chk-01/` |

### Evidence

- `EVID-01` Скриншот или лог системного теста: авторизованный пользователь на корневом URL видит страницу карточек.

### Evidence contract

| Evidence ID | Artifact | Producer | Path contract | Reused by checks |
| --- | --- | --- | --- | --- |
| `EVID-01` | Скриншот / system spec output | verify-runner / human | `artifacts/ft-023/verify/chk-01/` | `CHK-01` |

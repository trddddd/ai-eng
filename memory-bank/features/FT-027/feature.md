---
title: "FT-027: Cloze card: убрать кавычки и мигающий курсор"
doc_kind: feature
doc_function: canonical
purpose: "Убрать литеральные кавычки вокруг cloze-предложения и скрыть мигающий текстовый caret в inline-инпуте на review-карточке."
status: active
delivery_status: in_progress
audience: humans_and_agents
must_not_define:
  - implementation_sequence
---

# FT-027: Cloze card: убрать кавычки и мигающий курсор

## What

### Problem

На cloze-карточке в режиме review-сессии отображаются два визуальных дефекта:
1. Вокруг предложения показаны литеральные кавычки `"She has ___ a book"`, добавленные как текстовые символы в ERB-шаблоне.
2. В inline-инпуте мигает текстовый курсор (caret), хотя фокус уже визуально показан через изменение цвета `border-bottom` — дублирование визуального фидбека.

### Scope

- `REQ-01` Убрать кавычки вокруг cloze-предложения
- `REQ-02` Скрыть мигающий caret в inline-инпуте

### Non-Scope

- `NS-01` Не менять логику валидации ответа
- `NS-02` Не менять внешний вид фокуса (border-bottom остается)

### Constraints

- `CON-01` Изменение только CSS и ERB-шаблона, без Ruby/JS логики

## How

### Solution

Убрать `"` из шаблона и добавить `caret-color: transparent` в CSS. Фокус показан через border-color, caret избыточен и создает визуальный шум.

### Change Surface

| Surface | Why |
| --- | --- |
| `app/views/review_sessions/_card_inner.html.erb` | Убрать кавычки |
| `app/assets/tailwind/application.css` | Скрыть caret |

### Flow

1. Пользователь видит cloze-карточку без кавычек
2. Клик/фокус на инпут — border меняет цвет, caret не виден
3. Ввод текста — визуально чисто, без мигающего курсора

## Verify

### Exit Criteria

- `EC-01` Cloze-предложение отображается без кавычек
- `EC-02` В инпуте нет мигающего курсора, фокус виден через border-color

### Acceptance Scenarios

- `SC-01` Пользователь открывает cloze-карточку — предложение без кавычек, при фокусе на инпут caret не виден, border подсвечен

### Traceability matrix

| Requirement ID | Design refs | Acceptance refs | Checks | Evidence IDs |
| --- | --- | --- | --- | --- |
| `REQ-01` | `CON-01` | `EC-01`, `SC-01` | `CHK-01` | `EVID-01` |
| `REQ-02` | `CON-01` | `EC-02`, `SC-01` | `CHK-01` | `EVID-01` |

### Checks

| Check ID | Covers | How to check | Expected |
| --- | --- | --- | --- |
| `CHK-01` | `EC-01`, `EC-02`, `SC-01` | Визуальная проверка: нет кавычек, нет мигающего курсора | Предложение без кавычек, при фокусе caret не виден, border подсвечен |

### Test matrix

| Check ID | Evidence IDs | Evidence path |
| --- | --- | --- |
| `CHK-01` | `EVID-01` | `artifacts/ft-027/verify/chk-01/` |

### Evidence

- `EVID-01` Скриншот или результат `bin/setup --skip-server`

### Evidence contract

| Evidence ID | Artifact | Producer | Path contract | Reused by checks |
| --- | --- | --- | --- | --- |
| `EVID-01` | Скриншот или результат `bin/setup --skip-server` | verify-runner / human | `artifacts/ft-027/verify/chk-01/` | `CHK-01` |

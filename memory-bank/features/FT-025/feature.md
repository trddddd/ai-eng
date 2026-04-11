---
title: "FT-025: Dashboard MVP — progress cards"
doc_kind: feature
doc_function: canonical
purpose: "Canonical feature-документ для dashboard progress cards: streak, words learned, daily goal. Даёт пользователю видимую обратную связь о накопленном прогрессе."
derived_from:
  - ../../domain/problem.md
status: active
delivery_status: done
audience: humans_and_agents
must_not_define:
  - implementation_sequence
---

# FT-025: Dashboard MVP — progress cards

## What

### Problem

После сессий повторения пользователь не получает обратной связи о прогрессе. Нет ощущения накопленного результата, нет стимула возвращаться завтра. DashboardController существует, но рендерит пустую страницу с приветствием и ссылкой на reviews.

### Outcome

| Metric ID | Metric | Baseline | Target | Measurement method |
| --- | --- | --- | --- | --- |
| `MET-01` | Пользователь видит progress cards при входе | 0 карточек | 3 карточки (streak, words learned, daily goal) | Визуальная проверка dashboard |

### Scope

- `REQ-01` Карточка "Streak" — количество дней подряд, когда пользователь выполнял хотя бы одну review.
- `REQ-02` Карточка "Слов выучено" — количество карточек, перешедших в состояние REVIEW (state=2) или имеющих `mastered_at`.
- `REQ-03` Карточка "Дневная цель" — circular progress: сколько уникальных карточек отревьюено сегодня из дневной нормы (50).
- `REQ-04` Dashboard доступен залогиненному пользователю по `/dashboard`.
- `REQ-05` Корректное отображение при нулевых данных (новый пользователь, первый день).

### Non-Scope

- `NS-01` Настройка дневной цели через UI (используется константа).
- `NS-02` Графики, тренды, исторические данные.
- `NS-03` Gamification: бейджи, уровни, достижения.
- `NS-04` Серверный push / live-обновление карточек.
- `NS-05` Кэширование или materialized views для расчёта метрик.

### Constraints / Assumptions

- `ASM-01` Streak считается по дням с хотя бы одной записью в `review_logs` (через `reviewed_at`). Текущий день учитывается. Разрыв в один день сбрасывает streak.
- `ASM-02` "Слово выучено" = карточка с `state = 2` (REVIEW) ИЛИ `mastered_at IS NOT NULL`. Карточки в LEARNING/RELEARNING не считаются.
- `ASM-03` Дневная цель — константа `DAILY_GOAL = 50` уникальных карточек. Хардкод на уровне операции. Считаются уникальные card_id за сегодня в review_logs.
- `CON-01` Расчёт метрик выполняется через SQL-запросы на каждый request (без кэша). Допустимо для MVP, т.к. объём данных мал.
- `CON-02` UI строится на Hotwire (Turbo Frames / Turbo Streams). Без custom JS, без React/Vue. Dashboard page — стандартный Turbo Drive visit.

## How

### Design Reference

Референс: [`reference-dashboard.html`](reference-dashboard.html) — bento-grid dashboard прототип с аннотациями scope (зелёные = in scope, красные = out of scope, чекбокс скрывает маркеры). Ниже — grounding: что берём, что не берём, что адаптируем.

**Берём из референса (in scope FT-025):**

| Элемент | Референс | Адаптация |
| --- | --- | --- |
| Welcome header | `font-body text-4xl italic`, персонализированное приветствие | Оставляем italic Newsreader, используем `current_user.email` (имя пока нет) |
| Streak card | `surface-container-low`, label(xs) + value(2xl headline bold) + fire icon в `error-container/30` | Берём as-is |
| Words Learned card | `surface-container-low`, label(xs) + value(2xl headline bold) + book icon в `primary-fixed/30` | Берём as-is |
| Daily Goal card | `surface-container-low`, circular SVG progress (tertiary), check icon | Берём as-is, процент = daily_reviews/50 |
| Grid layout | `grid-cols-12`, stats column `col-span-4` | Адаптируем: без Main Course Card stats занимают больше места — `col-span-12` на мобильном, стек из 3 карточек |

**Не берём (out of scope):**

| Элемент | Причина |
| --- | --- |
| Main Course Card (8-col, "Current Journey", completion %) | Нет концепции курса, `NS-02` |
| Vocabulary Focus (new words today) | `NS-02`, отдельная фича |
| Weekly Engagement chart | `NS-02`, отдельная фича |
| Dark mode toggle | Не в scope FT-025 |
| Profile avatar | Нет профиля, `NS-03` |
| CTA "Continue Lesson" / "Review Deck" | Есть link на reviews в навигации |

**Grounding дизайн-системы (DESIGN.md compliance):**

| Правило | Как применяем |
| --- | --- |
| No-Line Rule | Карточки через `surface-container-low` на `surface`, без бордеров |
| Surface hierarchy | Cards: `surface-container-low`, page: `surface` |
| Typography dual-key | Welcome: Newsreader (content), labels/values: Inter/Manrope (UI) |
| Progress Indicators | Daily goal: circular SVG (tertiary), не chunky bar |
| Whisper Shadow | `editorial-shadow` только для floating cards, stat cards — tonal layering |
| Roundedness | Cards: `rounded-xl` (1.5rem — крупные контейнеры) |

### Solution

Операция `Dashboard::BuildProgress` собирает три метрики (streak, words_learned, daily_reviews) из review_logs и cards через SQL-запросы. DashboardController вызывает операцию и передаёт результат во view. View рендерит три progress card в сетке. Вся страница работает через стандартный Turbo Drive visit, без custom JS.

### Change Surface

| Surface | Type | Why it changes |
| --- | --- | --- |
| `app/operations/dashboard/build_progress.rb` | code (new) | Операция расчёта метрик |
| `app/controllers/dashboard_controller.rb` | code | Вызов операции, передача данных во view |
| `app/views/dashboard/index.html.erb` | code | Разметка progress cards |

### Flow

1. Пользователь открывает `/dashboard` (или редиректится после логина).
2. `DashboardController#index` вызывает `Dashboard::BuildProgress.call(user)`.
3. Операция возвращает struct/hash с `streak`, `words_learned`, `daily_reviews`, `daily_goal`.
4. View рендерит три карточки с полученными данными.

### Contracts

| Contract ID | Input / Output | Producer / Consumer | Notes |
| --- | --- | --- | --- |
| `CTR-01` | `Dashboard::BuildProgress.call(user)` → `{ streak:, words_learned:, daily_reviews:, daily_goal: }` | Operation / Controller | Все значения — целые числа ≥ 0 |

### Failure Modes

- `FM-01` У пользователя нет карточек и review_logs → все метрики = 0, UI показывает zero-state.
- `FM-02` Большое количество review_logs (>10k) → запросы могут замедлиться. Допустимо для MVP (см. `CON-01`), кэширование — отдельная фича.

## Verify

### Exit Criteria

- `EC-01` Dashboard отображает три progress card с корректными числами.
- `EC-02` Новый пользователь без данных видит нулевые значения без ошибок.

### Acceptance Scenarios

- `SC-01` Happy path: пользователь с историей reviews открывает dashboard и видит streak > 0, words_learned > 0, daily_reviews/daily_goal прогресс.
- `SC-02` Zero-state: новый пользователь без review_logs видит streak=0, words_learned=0, daily_reviews=0/50.
- `SC-03` Streak reset: пользователь пропустил вчера — streak=1 (только сегодня) или streak=0 (если сегодня ещё не занимался).

### Negative Cases

- `NEG-01` Пользователь без карточек (Cards::BuildStarterDeck не отработал) — dashboard не падает, показывает нули.

### Traceability matrix

| Requirement ID | Design refs | Acceptance refs | Checks | Evidence IDs |
| --- | --- | --- | --- | --- |
| `REQ-01` | `ASM-01`, `CON-01`, `CON-02`, `CTR-01` | `EC-01`, `SC-01`, `SC-03` | `CHK-01` | `EVID-01` |
| `REQ-02` | `ASM-02`, `CON-01`, `CON-02`, `CTR-01` | `EC-01`, `SC-01` | `CHK-01` | `EVID-01` |
| `REQ-03` | `ASM-03`, `CON-01`, `CON-02`, `CTR-01` | `EC-01`, `SC-01` | `CHK-01` | `EVID-01` |
| `REQ-04` | `CON-02`, `CTR-01` | `EC-01`, `SC-01` | `CHK-01` | `EVID-01` |
| `REQ-05` | `FM-01` | `EC-02`, `SC-02` | `CHK-02` | `EVID-02` |

### Checks

| Check ID | Covers | How to check | Expected result | Evidence path |
| --- | --- | --- | --- | --- |
| `CHK-01` | `EC-01`, `SC-01`, `SC-03` | `bundle exec rspec spec/operations/dashboard/ spec/requests/dashboard_spec.rb` | Все тесты зелёные | `artifacts/ft-025/verify/chk-01/` |
| `CHK-02` | `EC-02`, `SC-02`, `NEG-01` | `bundle exec rspec` — zero-state сценарии | Все тесты зелёные | `artifacts/ft-025/verify/chk-02/` |

### Test matrix

| Check ID | Evidence IDs | Evidence path |
| --- | --- | --- |
| `CHK-01` | `EVID-01` | `artifacts/ft-025/verify/chk-01/` |
| `CHK-02` | `EVID-02` | `artifacts/ft-025/verify/chk-02/` |

### Evidence

- `EVID-01` RSpec output для happy path и streak reset сценариев.
- `EVID-02` RSpec output для zero-state и NEG-01 сценариев.

### Evidence contract

| Evidence ID | Artifact | Producer | Path contract | Reused by checks |
| --- | --- | --- | --- | --- |
| `EVID-01` | RSpec test output (happy path) | verify-runner | `artifacts/ft-025/verify/chk-01/` | `CHK-01` |
| `EVID-02` | RSpec test output (zero state) | verify-runner | `artifacts/ft-025/verify/chk-02/` | `CHK-02` |

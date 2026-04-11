---
title: "FT-025: Implementation Plan"
doc_kind: feature
doc_function: derived
purpose: "Execution-план реализации FT-025 (Dashboard MVP: progress cards). Фиксирует discovery context, шаги, риски и test strategy без переопределения canonical feature-фактов."
derived_from:
  - feature.md
status: archived
audience: humans_and_agents
must_not_define:
  - ft_025_scope
  - ft_025_architecture
  - ft_025_acceptance_criteria
  - ft_025_blocker_state
---

# План имплементации

## Цель текущего плана

Добавить три progress card (streak, words learned, daily goal) на dashboard. Пользователь видит обратную связь о прогрессе сразу после логина.

## Current State / Reference Points

| Path / module | Current role | Why relevant | Reuse / mirror |
| --- | --- | --- | --- |
| `app/controllers/dashboard_controller.rb` | Пустой контроллер с `require_login`, рендерит view без данных | Точка вызова операции | Добавить вызов `Dashboard::BuildProgress.call` |
| `app/views/dashboard/index.html.erb` | Приветствие + ссылка на reviews, старый стиль (gray/indigo) | Полная замена на design-system cards | Зеркалить паттерны из `_card_inner.html.erb`: `font-label`, `font-headline`, `surface-container-low`, `on-surface-variant` |
| `app/operations/reviews/build_session.rb` | Операция построения review-сессии | Паттерн операции: `def self.call(...) = new(...).call`, inject `user:`, `now:` | Повторить структуру для `Dashboard::BuildProgress` |
| `app/models/card.rb` | Модель карточки, `STATE_REVIEW = 2`, `mastered_at`, `belongs_to :user` | Источник `words_learned` (`state=2` OR `mastered_at IS NOT NULL`) | Query через `Card.where(user:)` |
| `app/models/review_log.rb` | Лог ревью, `reviewed_at` (NOT NULL), `belongs_to :card` | Источник streak и daily_reviews | Query через `ReviewLog.joins(:card).where(cards: { user_id: })` |
| `app/assets/tailwind/application.css` | Design tokens: `surface-container-low`, `on-surface`, `on-surface-variant`, `primary-fixed`, `tertiary`, `error-container`, `font-label`, `font-headline`, `rounded-xl` | Все CSS-переменные уже определены | Использовать напрямую, не добавлять новые токены |
| `app/views/review_sessions/_card_inner.html.erb` | Review card с progress/timer | Референс дизайн-паттернов: `font-label text-xs tracking-widest uppercase`, `font-headline text-2xl font-bold`, `surface-container-lowest rounded-xl` | Зеркалить типографику и spacing |
| `spec/requests/dashboard_spec.rb` | Auth + 200 тесты для dashboard | Расширить content-assertions | Добавить проверки наличия progress cards |
| `spec/factories/cards.rb`, `spec/factories/review_logs.rb` | Фабрики для тестов | Создание тестовых данных | Использовать as-is, дополнительные traits не нужны |

## Test Strategy

| Test surface | Canonical refs | Existing coverage | Planned automated coverage | Required local suites | Required CI suites | Manual-only gap | Approval ref |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `app/operations/dashboard/build_progress.rb` | `REQ-01..03`, `SC-01..03`, `NEG-01`, `CHK-01`, `CHK-02` | Отсутствует (новый файл) | `spec/operations/dashboard/build_progress_spec.rb` — unit tests: streak counting (consecutive days), words_learned (state=2 + mastered_at), daily_reviews count, zero-state, streak reset | `bundle exec rspec spec/operations/dashboard/` | `rspec` job | none | none |
| `app/controllers/dashboard_controller.rb` + view | `REQ-04`, `REQ-05`, `SC-01`, `SC-02`, `CHK-01`, `CHK-02` | Auth + 200 | Расширить `spec/requests/dashboard_spec.rb` — проверка отображения progress cards (happy path + zero state) | `bundle exec rspec spec/requests/dashboard_spec.rb` | `rspec` job | none | none |

## Open Questions / Ambiguities

| Open Question ID | Question                                                                                                   | Why unresolved                                            | Blocks              | Default action / escalation owner                                                                                  |
| ---------------- | ---------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- | ------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `OQ-01`          | ReviewLog не имеет прямого `user_id` — только через `card.user_id`. Достаточно ли JOIN для streak-запроса? | Нужно подтвердить производительность join + group by date | Ничего не блокирует | По умолчанию: JOIN. Индекс `[card_id, reviewed_at]` на review_logs + `user_id` на cards достаточен для MVP объёмов |

## Environment Contract

| Area | Contract | Used by | Failure symptom |
| --- | --- | --- | --- |
| setup | `bin/rails db:prepare` — БД с актуальной схемой | Все шаги | Миграция не нужна, таблицы уже есть |
| test | `bundle exec rspec spec/operations/dashboard/ spec/requests/dashboard_spec.rb` | `CHK-01`, `CHK-02` | Красные тесты |
| icons | Material Symbols Outlined уже подключены в layout | `STEP-03` | Иконки не рендерятся — проверить `<link>` в `application.html.erb` |

## Preconditions

| Precondition ID | Canonical ref | Required state | Used by steps | Blocks start |
| --- | --- | --- | --- | --- |
| `PRE-GIT` | `engineering/git-workflow.md` | Feature branch `feat/025-dashboard-progress` создана от `main` | Все шаги | yes — `git checkout -b feat/025-dashboard-progress` |
| `PRE-01` | `CON-01` | Таблицы `cards` и `review_logs` существуют с нужными колонками | Все шаги | yes |
| `PRE-02` | `CON-02` | Tailwind CSS tokens определены в `application.css` | `STEP-03` | no (уже выполнено) |

## Workstreams

| Workstream | Implements | Result | Owner | Dependencies |
| --- | --- | --- | --- | --- |
| `WS-1` Backend | `REQ-01..03`, `CTR-01` | `Dashboard::BuildProgress` операция + тесты | agent | `PRE-01` |
| `WS-2` Frontend | `REQ-04`, `REQ-05`, `CON-02` | Dashboard view с progress cards | agent | `WS-1` (нужен контракт операции) |

## Approval Gates

| Approval Gate ID | Trigger | Applies to | Why approval is required | Approver / evidence |
| --- | --- | --- | --- | --- |
| — | — | — | Нет рискованных или необратимых действий | — |

## Порядок работ

| Step ID | Actor | Implements | Goal | Touchpoints | Artifact | Verifies | Evidence IDs | Check command | Blocked by | Needs approval | Escalate if |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `STEP-01` | agent | `REQ-01..03`, `CTR-01` | Создать операцию `Dashboard::BuildProgress` с тремя метриками | `app/operations/dashboard/build_progress.rb` | Файл операции | — | — | `ruby -c app/operations/dashboard/build_progress.rb` | `PRE-01` | none | SQL-запросы возвращают некорректные результаты |
| `STEP-02` | agent | `SC-01..03`, `NEG-01`, `CHK-01`, `CHK-02` | Написать unit-тесты операции | `spec/operations/dashboard/build_progress_spec.rb` | Файл тестов | `CHK-01`, `CHK-02` | `EVID-01`, `EVID-02` | `bundle exec rspec spec/operations/dashboard/` | `STEP-01` | none | Тесты не покрывают streak reset / zero state |
| `STEP-03` | agent | `REQ-04`, `REQ-05`, `CON-02` | Обновить controller и view: вызов операции, разметка progress cards | `app/controllers/dashboard_controller.rb`, `app/views/dashboard/index.html.erb` | Обновлённые файлы | — | — | `bin/rails runner "puts 'ok'"` | `STEP-01` | none | Design tokens не применяются |
| `STEP-04` | agent | `SC-01`, `SC-02`, `CHK-01`, `CHK-02` | Расширить request spec: happy path + zero state через HTML assertions | `spec/requests/dashboard_spec.rb` | Обновлённый тест | `CHK-01`, `CHK-02` | `EVID-01`, `EVID-02` | `bundle exec rspec spec/requests/dashboard_spec.rb` | `STEP-03` | none | Assertions не находят cards в HTML |
| `STEP-05` | agent | — | Полный прогон тестов, сбор evidence | — | Лог тестов | `CHK-01`, `CHK-02` | `EVID-01`, `EVID-02` | `bundle exec rspec` | `STEP-04` | none | Регрессия в существующих тестах |

## Parallelizable Work

- `PAR-01` `STEP-01` и `STEP-02` можно писать параллельно (операция + тесты к ней), но запуск тестов требует готовой операции.
- `PAR-02` `STEP-03` и `STEP-04` нельзя параллелить — view нужен для request spec assertions.

## Checkpoints

| Checkpoint ID | Refs | Condition | Evidence IDs |
| --- | --- | --- | --- |
| `CP-01` | `STEP-02`, `CHK-01`, `CHK-02` | Unit-тесты операции зелёные: streak, words_learned, daily_reviews, zero-state, streak reset | `EVID-01`, `EVID-02` |
| `CP-02` | `STEP-05`, `CHK-01`, `CHK-02` | Полный suite зелёный, без регрессий | `EVID-01`, `EVID-02` |

## Execution Risks

| Risk ID | Risk | Impact | Mitigation | Trigger |
| --- | --- | --- | --- | --- |
| `ER-01` | Streak SQL-запрос сложнее ожидаемого (consecutive days через window functions) | Задержка `STEP-01` | Использовать Ruby-level итерацию по отсортированным датам вместо чистого SQL | Запрос не поддерживается SQLite |
| `ER-02` | Текущий dashboard view использует старые стили (gray/indigo), не design tokens | View выглядит inconsistent | Полная замена содержимого view, а не патч | — |

## Stop Conditions / Fallback

| Stop ID | Related refs | Trigger | Immediate action | Safe fallback state |
| --- | --- | --- | --- | --- |
| `STOP-01` | `CON-01` | Запросы к review_logs/cards таймаутят или возвращают некорректные данные | Проверить схему БД, индексы | Dashboard без progress cards (текущее состояние) |

## Готово для приемки

- [ ] `Dashboard::BuildProgress` возвращает корректные метрики для всех сценариев
- [ ] Unit-тесты операции зелёные (`CP-01`)
- [ ] Dashboard view отображает три progress card с design-system tokens
- [ ] Request spec подтверждает happy path и zero state
- [ ] Полный `bundle exec rspec` зелёный (`CP-02`)
- [ ] Simplify review пройден

# Layered Rails Review — FT-034

**Scope:** Review Pipeline v2 + Word Progress Dashboard
**Date:** 2026-04-16
**Reviewer:** layered-rails (automated)
**Round:** 1/2
**Severity verdict:** advisory (no blocking issues)

## Files Reviewed

| File | Layer | Status |
| --- | --- | --- |
| `app/models/review_log.rb` | Domain | OK |
| `app/models/lexeme_review_contribution.rb` (new) | Domain | OK |
| `app/operations/dashboard/build_progress.rb` | Application | OK |
| `app/operations/reviews/record_answer.rb` | Application | OK |
| `app/operations/word_mastery/record_coverage.rb` | Application | OK (with suggestions) |
| `app/views/dashboard/index.html.erb` | Presentation | OK (with one suggestion) |

## Layer Analysis

- **Files touched:** Domain (2), Application (3), Presentation (1). Миграция вне скоупа ревью.
- **Data flow:** Presentation → Application → Domain → Infrastructure. Нарушений направления нет.
- **Reverse dependencies:** отсутствуют. Модели не импортируют operations, operation-слои не зависят от controllers/views.
- **Current attributes в моделях:** отсутствуют. Единственное использование `current_user` — во views/controllers (presentation, write-site корректен).
- **Callbacks в моделях:** добавленных callbacks в `ReviewLog` и `LexemeReviewContribution` нет. Существующий `before_save` в `User` не затрагивается.

## The Specification Test

### `Reviews::RecordAnswer`
Ответственности:
1. Вычислить accuracy/recall/rating через `ReviewLog.*` class methods (domain delegation — OK).
2. Создать `ReviewLog` через ассоциацию `@card.review_logs.create!` (OK).
3. Вызвать `@card.schedule!` — domain method (OK).
4. Внутри той же transaction вызвать `WordMastery::RecordCoverage` только при `correct` (оркестрация — OK).

Все обязанности лежат в `Application`. Логика расчётов остаётся в моделях (`ReviewLog.compute_accuracy/classify_recall/compute_rating`, `Card#schedule!`). Anemic-model риска нет — operation оркеструет, модели хранят знание.

### `WordMastery::RecordCoverage`
Ответственности:
1. Идемпотентная ранняя выдача при `correct: false` и при существующем contribution.
2. Оркестрация: `InitializeState` → вычисление `contribution_type` → `LexemeReviewContribution.create!` → upsert двух coverage tables → пересчёт `UserLexemeState`.
3. Содержит чистую таблицу истинности `CONTRIBUTION_TYPE_BY_NEWNESS` (constants/data), которая концептуально принадлежит домену (ASM-03).

Все шаги — оркестрация и SQL-запись, это валидная Application-обязанность. `recalculate!` делает агрегатный пересчёт — в принципе может быть выделен как domain-метод (см. suggestion ниже), но текущая локализация оправдана, пока нет второго caller.

### `ReviewLog`
Class methods (`compute_accuracy`, `classify_recall`, `compute_rating`, `classify_speed`, `streak_for`, `distinct_review_dates_for`, `unique_cards_reviewed_on`) — доменные правила + query scopes. Constants (`RATING_*`, `RECALL_QUALITIES`, thresholds, `RECALL_TO_RATING`) корректно живут в модели. Это именно тот случай, когда **domain logic правильно остаётся в модели** и operation её потребляет. Anemic-model признаков нет.

### `LexemeReviewContribution`
17 строк: associations + validations + constants. Минималистичный value-record без лишних обязанностей. `CONTRIBUTION_TYPES` — константа enum-set на месте. Модель не анемична в плохом смысле: у неё нет callbacks/operations, потому что это audit/link-запись. В будущем при добавлении правил (например, weight-model по NS-01) логика должна идти сюда, а не в service.

### `Dashboard::BuildProgress`
Чисто read-model assembly (presenter-like operation). Struct `Progress` инкапсулирует output contract (CTR-03). Делегирует streak/reviews к `ReviewLog.*` class methods, и только «bucket-классификация» живёт в приватных методах operation. Это корректный Application-слой — composition без домен-логики.

### `app/views/dashboard/index.html.erb`
Рендерит `@progress.*` поля, нет SQL, нет бизнес-расчётов. Вычисление `daily_pct`/`dashoffset` — чисто геометрия SVG (presentation concern). Ветвление empty/encourage/progress — view-логика.

## Issues

### Advisory A-1: View содержит вычисление progress ratio
**Location:** `app/views/dashboard/index.html.erb:65-67`
```erb
<% daily_pct = (@progress.daily_reviews.to_f / @progress.daily_goal).clamp(0, 1) %>
<% circumference = 125.6 %>
<% dashoffset = (circumference * (1 - daily_pct)).round(1) %>
```
**Проблема:** `daily_pct` — по сути derived-метрика прогресса, которая имеет смысл не только для SVG (может пригодиться в a11y-атрибутах, копирайте). `circumference = 125.6` — магическая константа, без комментария (2π·20 для r=20). Presentation-concern в чистом виде — `dashoffset`; но `daily_pct` — derived-значение, которое лучше добавить в `Progress` struct или вынести в presenter/helper.
**Severity:** advisory (не блокирует).
**Рекомендация:**
- Вариант 1 (минимальный): добавить поле `daily_progress_ratio` в `Dashboard::BuildProgress::Progress` (уже есть `daily_reviews` и `daily_goal`, тут это просто удобный getter).
- Вариант 2: extract partial `_daily_goal_card.html.erb` с локальными переменными и комментарием про `2π·r`.

### Advisory A-2: Дублирование `unique_family_count` между двумя operations
**Location:**
- `app/operations/word_mastery/initialize_state.rb:20-26`
- `app/operations/word_mastery/record_coverage.rb:118-124`
```ruby
def unique_family_count(lexeme = @lexeme)
  SentenceOccurrence.where(lexeme: lexeme)
                    .select(:context_family_id)
                    .distinct
                    .where.not(context_family_id: nil)
                    .count
end
```
**Проблема:** Один и тот же query живёт в двух местах. По принципу «patterns before abstractions» — это уже паттерн (не первая копия). Логика «сколько уникальных families у lexeme» — доменное знание о lexeme, а не об operation.
**Severity:** advisory.
**Рекомендация:** Поднять как scope/method на `Lexeme` или `SentenceOccurrence`:
```ruby
# app/models/lexeme.rb
def unique_context_family_count
  sentence_occurrences.where.not(context_family_id: nil).distinct.count(:context_family_id)
end
```
Оба operations вызывают `lexeme.unique_context_family_count`. Это убирает дублирование и возвращает domain-knowledge в домен.

### Advisory A-3: `recalculate!` инкапсулирован в operation, но это aggregate-пересчёт над UserLexemeState
**Location:** `app/operations/word_mastery/record_coverage.rb:94-110`
```ruby
def recalculate!(state, user, lexeme)
  covered_senses = UserSenseCoverage.joins(:sense).where(user: user, senses: { lexeme_id: lexeme.id }).count
  total_senses = lexeme.senses.count
  covered_families = UserContextFamilyCoverage.where(user: user, lexeme: lexeme).count
  total_families = unique_family_count(lexeme)
  state.update!( ... )
end
```
**Проблема:** Логика «как посчитать и обновить свою собственную coverage» — это знание о `UserLexemeState` как aggregate root. Если появится второй caller (например, admin recalculate job, или manual data repair), её придётся переносить. Сейчас есть ровно один caller — держать в operation допустимо по принципу «favor extraction over complication, but not prematurely».
**Severity:** advisory (patterns-before-abstractions — пока один caller).
**Рекомендация (при появлении второго caller):** вынести в domain-метод `UserLexemeState#recalculate_from_coverages!` и operation станет:
```ruby
state.recalculate_from_coverages!(now: @now)
```
Не требует действий сейчас; отметить в TODO/backlog.

### Advisory A-4: CON-05 контракт «outer transaction обязателен» не enforced в коде
**Location:** `app/operations/word_mastery/record_coverage.rb` (отсутствие assertion), `lib/tasks/word_mastery.rake:14`
**Проблема:** CON-05 требует, чтобы caller обернул `RecordCoverage.call` в transaction (RecordAnswer — да; backfill — да, явно). Но контракт нигде не верифицируется: если появится третий caller (например, admin console, тест, новая операция), он легко забудет `ActiveRecord::Base.transaction do`, и частичный сбой оставит `LexemeReviewContribution` без coverage/state.
**Severity:** advisory (текущие два caller корректны).
**Рекомендации (выбрать одну):**
1. Документировать контракт в YARD-комментарии над `call`:
   ```ruby
   # @note Caller MUST wrap call in ActiveRecord::Base.transaction (see CON-05).
   ```
2. Runtime-assertion в начале `call`:
   ```ruby
   raise "RecordCoverage must run inside a transaction" unless ActiveRecord::Base.connection.transaction_open?
   ```
3. Оставить как есть — контракт зафиксирован в `feature.md`, покрытие тестами достаточно.

### Advisory A-5: Commented pragma-шум на границах метода
**Location:** `app/operations/reviews/record_answer.rb:5-7,18,43`
```ruby
# rubocop:disable Metrics/ParameterLists
def initialize(card:, correct:, answer_text: nil, ...)
  # rubocop:enable Metrics/ParameterLists
  ...
# rubocop:disable Metrics/MethodLength
def call
  ...
end
# rubocop:enable Metrics/MethodLength
```
**Проблема:** Методы действительно длинноваты. Длинный список параметров — сигнал к Parameter Object (например, `AnswerSubmission` value object: `answer_text/elapsed_ms/attempts/backspace_count`). Длина `call` — признак, что шаги (compute telemetry, persist review, schedule FSRS, record coverage) можно выделить в private методы.
**Severity:** advisory.
**Рекомендация:** оставить как есть для текущей итерации (patterns-before-abstractions — single caller, понятный сверху донизу). Зафиксировать в backlog: «когда появится второй caller (например, import-answer или offline-sync), извлечь `AnswerSubmission` value object».

## Callback Scoring

Новых callbacks в затронутых моделях не добавлено. В `ReviewLog` callbacks отсутствуют — вся логика вызывается явно через class methods, что соответствует CON-04.

| Model | Callback | Type | Score | Action |
| --- | --- | --- | --- | --- |
| `ReviewLog` | — | — | — | — |
| `LexemeReviewContribution` | — | — | — | — |

**Верификация CON-04:** `RecordCoverage` вызывается явно из `Reviews::RecordAnswer.call` — не через `after_create`/`after_commit` на `ReviewLog`. Это правильное решение: callback с операционной семантикой получил бы score 1/5 и рекомендацию к extraction, который уже сделан.

## Concern Health

- Изменённые файлы не используют concerns.
- Существующие concerns в проекте не тронуты.
- Code-slicing concerns (по типу артефакта) не обнаружены.

## God Object Check

| Model | LOC | Methods | Responsibilities | Verdict |
| --- | --- | --- | --- | --- |
| `ReviewLog` | 105 | 7 class + validations | Constants, classification, streak queries | OK (domain class-level methods оправданы) |
| `LexemeReviewContribution` | 17 | 0 (value record) | Associations + validations | OK |
| `Card` | 65 (неизменён) | 6 | FSRS delegation, scheduling, mastery | OK |

Никаких признаков god object (churn × complexity) нет. `ReviewLog` растёт классовыми domain-методами, но они однородны по concern (review/recall math) и тестируемы без HTTP-контекста.

## Data Flow Audit

**Presentation → Application → Domain:**
```
ReviewSessionsController#create
  → Reviews::RecordAnswer.call(card:, correct:, ...)
    → ReviewLog.compute_accuracy/classify_recall/compute_rating  (domain)
    → @card.review_logs.create!                                  (AR/infra)
    → @card.schedule!                                            (domain)
    → WordMastery::RecordCoverage.call(review_log:)              (application)
      → WordMastery::InitializeState.call                        (application)
      → LexemeReviewContribution.create!                         (domain/AR)
      → UserSenseCoverage.upsert                                 (domain/AR)
      → UserContextFamilyCoverage.upsert                         (domain/AR)
      → UserLexemeState#update!                                  (domain/AR)
```

```
DashboardController#index
  → Dashboard::BuildProgress.call(user:)
    → ReviewLog.streak_for(user)                                 (domain)
    → ReviewLog.unique_cards_reviewed_on(user, now)              (domain)
    → UserLexemeState.where(user:).pluck(:sense_coverage_pct)    (domain/AR)
  → @progress (Struct) → view (presentation)
```

Оба потока unidirectional, без reverse dependencies.

## Summary

**Verdict: advisory (no blocking).**

Интеграция `WordMastery::RecordCoverage` в `Reviews::RecordAnswer` выполнена корректно с точки зрения layered architecture:

- **CON-04 соблюдён:** RecordCoverage вызывается из operation, а не из ReviewLog callback. Это предотвращает model → operation reverse dependency.
- **CON-05 соблюдён по факту:** RecordCoverage не имеет inner transaction; outer transaction в RecordAnswer и явный wrapper в backfill rake — оба присутствуют. Контракт не enforced в коде (A-4), но зафиксирован в feature.md и покрыт тестами.
- **Domain logic правильно разложен:** математика recall/rating/accuracy — в `ReviewLog` class methods; FSRS scheduling — в `Card#schedule!`; truth table contribution_type — в константе operation (приемлемо для оркестрации).
- **Anemic model риск отсутствует:** модели несут поведение, operations — оркестрацию.
- **Dashboard operation** — классический read-model builder, соответствует Application-слою.
- **View** — без бизнес-логики, одно advisory по derived-метрике.

### Priorities (в порядке ценности)

1. **A-2** (низкая стоимость, высокая ценность): вынести `unique_family_count` в `Lexeme` или `SentenceOccurrence` — убирает дубль прямо сейчас. Рекомендуется к исполнению до merge либо в follow-up.
2. **A-4** (низкая стоимость): добавить YARD-комментарий к `RecordCoverage#call` о требовании outer transaction. Защищает от будущих регрессий без runtime-cost.
3. **A-1** (косметическое): `daily_progress_ratio` в Progress struct или extract partial.
4. **A-3**, **A-5** — отложить до появления второго caller/паттерна (patterns-before-abstractions).

Реализация готова к merge с точки зрения архитектуры. Рекомендуется решить A-2 и A-4 либо в этой итерации (малые фиксы), либо зафиксировать как follow-up в `memory-bank/features/FT-034/` с явной ссылкой в реестре.

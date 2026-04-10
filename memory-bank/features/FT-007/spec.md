# Spec: Сессия повторений со спейсед репетишн

**Brief:** [memory-bank/features/007/brief.md](brief.md)
**Issue:** trddddd/ai-eng#14
**Реализация:** последовательно — сначала Slice 1 (backend), затем Slice 2 (UI). Один PR.

---

## Цель

Пользователь проходит сессию повторений: видит cloze-карточку, вводит ответ, получает обратную связь. Система сохраняет сырые сигналы ответа, вычисляет дискретный FSRS-рейтинг и планирует следующее повторение.

## Scope

**Входит:**
- Модель `ReviewLog` для хранения ответов и рейтинга
- Rich Rating Pipeline: маппинг сырых сигналов → FSRS-рейтинг (5 классов recall quality)
- Планирование карточки через FSRS-алгоритм (`Card#schedule!`)
- Mark as Mastered: пользователь может пометить карточку как выученную навсегда
- Операции `Reviews::RecordAnswer`, `Reviews::BuildSession`, `Cards::Master`
- UI сессии: cloze-карточка, ввод с побуквенным фидбеком, ghost text, retry, audio, adaptive input
- Turbo Frame для смены карточек без перезагрузки страницы
- Stimulus-контроллер: таймер, backspace tracking, retry, audio playback, ghost text, real-time feedback

**НЕ входит:**
- Другие типы упражнений кроме cloze
- Аналитический дашборд
- Настройка параметров FSRS пользователем
- Композитный числовой score (взвешенная сумма сигналов) — нет данных для калибровки весов, FSRS принимает 4 дискретных значения
- Фоновые задачи / background jobs
- Модель `ReviewSession` (сессия эфемерна — набор due-карточек)
- Блокировка кнопки Submit на время запроса (двойной submit допустим для v1, см. сценарии ошибок)

---

## Инварианты

1. `correct` и `answer_text` фиксируются по **первой** попытке и не меняются при retry
2. `attempts` сохраняется в `review_logs`, но **НЕ** передаётся в `classify_recall` — retry педагогический, не FSRS-сигнал
3. `backspace_count` сохраняется, но **НЕ** участвует в rating v1 — сигнал шумный, нет данных для калибровки
4. Все сырые сигналы записываются в `review_logs` **ДО** необратимого маппинга в rating
5. Карточки с `mastered_at IS NOT NULL` исключены из `due_for_review` навсегда
6. `ReviewLog.create!` и `card.schedule!` выполняются атомарно в одной транзакции — либо оба, либо ни одного. Если `schedule!` выбрасывает исключение, `ReviewLog` не должен быть создан; если `create!` падает, карточка не перепланируется
7. `answer_text`, используемый для вычисления `correct` и `answer_accuracy`, должен быть одним и тем же входным текстом

---

## Декомпозиция на вертикальные слайсы

```
Slice 1: Review Cycle Backend        Slice 2: Review Session UI
┌──────────────────────────┐         ┌──────────────────────────┐
│  ReviewLog model         │         │  ReviewSessionsController│
│  Card: schedule!, master!│         │  CardsController#master  │
│  Rating Pipeline (5 cls) │         │  Turbo Stream views      │
│  Reviews::RecordAnswer   │         │  Stimulus: timer, retry, │
│  Reviews::BuildSession   │         │    audio, ghost, a11y    │
│  Migrations (2)          │         │  Routes, i18n (ru/en)    │
│  Model + Operation specs │         │  Request specs           │
└──────────────────────────┘         └──────────────────────────┘
      Backend + Tests                    GUI Presentation
```

**Порядок реализации:** Slice 1 → Slice 2 (GUI строится поверх проверенного backend).

---

# Slice 1: Review Cycle Backend

## Модель данных

### Таблица `review_logs`

| Колонка | Тип | Constraints | Описание |
|---------|-----|-------------|----------|
| `id` | `uuid` | PK, default `uuidv7()` | — |
| `card_id` | `uuid` | NOT NULL, FK → cards(id) | Карточка |
| `rating` | `integer` | NOT NULL | FSRS-рейтинг: 1=Again, 2=Hard, 3=Good, 4=Easy |
| `recall_quality` | `string` | NOT NULL | Классифицированное качество припоминания (enum, см. таксономию) |
| `correct` | `boolean` | NOT NULL | Правильность **первой** попытки (exact match, case-insensitive) |
| `answer_text` | `string` | NULL | Текст **первой** попытки (для accuracy) |
| `answer_accuracy` | `float` | NULL | Нормализованное сходство ответа с ожидаемым (0.0–1.0) |
| `elapsed_ms` | `integer` | NULL | Время от показа до финального submit (мс) |
| `attempts` | `integer` | NOT NULL, default `1` | Количество попыток (включая retry). Не участвует в рейтинге — педагогический сигнал |
| `backspace_count` | `integer` | NULL | Количество нажатий Backspace (сигнал неуверенности, не участвует в рейтинге v1) |
| `reviewed_at` | `datetime` | NOT NULL | Момент финального ответа |
| `created_at` | `datetime` | NOT NULL | — |
| `updated_at` | `datetime` | NOT NULL | — |

**Индексы:**
- `(card_id, reviewed_at)` — хронология ответов по карточке

**Foreign keys:**
- `card_id → cards(id)` ON DELETE CASCADE

### Модель `ReviewLog`

```ruby
# app/models/review_log.rb
class ReviewLog < ApplicationRecord
  belongs_to :card

  RATING_AGAIN = 1
  RATING_HARD  = 2
  RATING_GOOD  = 3
  RATING_EASY  = 4

  RATINGS = [RATING_AGAIN, RATING_HARD, RATING_GOOD, RATING_EASY].freeze

  RECALL_QUALITIES = %w[
    no_recall
    near_miss
    effortful_recall
    successful_recall
    automatic_recall
  ].freeze

  validates :rating, inclusion: { in: RATINGS }
  validates :recall_quality, inclusion: { in: RECALL_QUALITIES }
  validates :correct, inclusion: { in: [true, false] }
  validates :reviewed_at, presence: true
  validates :attempts, numericality: { greater_than: 0 }
  validates :answer_accuracy, numericality: { in: 0.0..1.0 }, allow_nil: true
end
```

### Миграция: `add_mastered_at_to_cards`

```ruby
add_column :cards, :mastered_at, :datetime, null: true
```

Отдельная миграция — одно изменение на миграцию (constraint проекта).

### Изменения в модели `Card`

```ruby
# app/models/card.rb — добавить:
has_many :review_logs, dependent: :destroy

scope :due_for_review, ->(user, now: Time.current) {
  where(user: user, mastered_at: nil).where(due: ..now)
}

def schedule!(rating:, now: Time.current)
  scheduler = Fsrs::Scheduler.new
  fsrs_card = to_fsrs_card
  results = scheduler.repeat(fsrs_card, now.utc)
  scheduled = results[rating]
  apply_fsrs_card!(scheduled.card)
end

def master!(now: Time.current)
  update!(mastered_at: now)
end

def mastered?
  mastered_at.present?
end
```

**Примечания:**
- `due_for_review` исключает mastered-карточки (`mastered_at: nil`)
- `schedule!` принимает дискретный FSRS-рейтинг (1–4) и текущее время
- `Fsrs::Scheduler#repeat` требует UTC — конвертируем `now.utc`
- Результат `repeat` — Hash с ключами `Fsrs::Rating::AGAIN/HARD/GOOD/EASY`
- `master!` — помечает карточку как выученную навсегда, исключает из review
- Из результата берём `.card` (обновлённое состояние) и применяем через `apply_fsrs_card!`

---

## Rich Rating Pipeline

### Проблема

FSRS принимает дискретный рейтинг (1–4). Реальное взаимодействие порождает несколько сигналов: правильность, время, попытки, близость ответа, паттерн набора. Маппинг этих сигналов в рейтинг **необратим** — потерянная информация не восстанавливается. Поэтому все сырые сигналы сохраняются в `review_logs` до маппинга.

### Pipeline-архитектура

```
answer_text, elapsed_ms, attempts, backspace_count
         │
         ▼
┌─────────────────────────┐
│  1. Store Raw Signals    │  → review_logs (все сигналы сохранены до маппинга)
└────────┬────────────────┘
         ▼
┌─────────────────────────┐
│  2. Compute Accuracy     │  answer_text + expected → answer_accuracy (0.0–1.0)
└────────┬────────────────┘
         ▼
┌─────────────────────────┐
│  3. Classify Recall      │  correct (first attempt) + accuracy → recall quality class
│     Classify Speed       │  elapsed_ms → speed class (only when correct)
└────────┬────────────────┘
         ▼
┌─────────────────────────┐
│  4. Resolve Rating       │  recall quality → FSRS rating (1–4)
└────────┬────────────────┘     ▲ LOSSY STEP (необратимый)
         ▼
┌─────────────────────────┐
│  5. Schedule Card        │  rating → Fsrs::Scheduler#repeat
└─────────────────────────┘
```

### Слой 1: Таксономия сырых сигналов

Всё, что система собирает и сохраняет **до** необратимого маппинга:

| Сигнал | Тип | Источник | Участвует в rating v1 | Описание |
|--------|-----|----------|----------------------|----------|
| `correct` | boolean | Server (exact match) | **Да** | Правильность **первой** попытки (case-insensitive, strip) |
| `answer_text` | string | Hidden field (Stimulus) | **Да** (через accuracy) | Текст **первой** попытки — фиксируется на первом Enter |
| `answer_accuracy` | float | Server (Levenshtein) | **Да** | Нормализованное сходство: `1 - (distance / max_len)` |
| `elapsed_ms` | integer | Stimulus timer | **Да** | Время от показа карточки до финального submit |
| `attempts` | integer | Stimulus counter | **Нет** (копим данные) | Сколько Enter до финального submit — педагогический, не FSRS сигнал |
| `backspace_count` | integer | Stimulus keydown | **Нет** (копим данные) | Количество нажатий Backspace — сигнал неуверенности |

**`backspace_count` не участвует в рейтинге v1:** сигнал шумный — бэкспейс из-за опечатки при наборе ≠ бэкспейс из-за неуверенности в слове. Без данных реальных сессий нечем калибровать. Собираем, анализируем позже.

### Слой 2: answer_accuracy — вычисление сходства

Сравнение ответа пользователя с ожидаемым словом. Позволяет отличить опечатку (знает слово, ошибся в наборе) от незнания (совсем другое слово).

**Формула:**

```
accuracy = 1.0 - (levenshtein(answer, expected) / max(len(answer), len(expected)))
```

**Реализация:** через `DidYouMean::Levenshtein.distance` из stdlib Ruby (не нужен новый гем).

```ruby
# app/models/review_log.rb
def self.compute_accuracy(answer_text, expected)
  return 0.0 if answer_text.blank?

  a = answer_text.strip.downcase
  e = expected.strip.downcase
  return 1.0 if a == e

  distance = DidYouMean::Levenshtein.distance(a, e)
  max_len = [a.length, e.length].max
  (1.0 - (distance.to_f / max_len)).clamp(0.0, 1.0)
end
```

**Примеры:**

| Ответ | Ожидание | Distance | max_len | Accuracy | Вердикт |
|-------|----------|----------|---------|----------|---------|
| `runnig` | `running` | 1 | 7 | 0.86 | near_miss (опечатка) |
| `runing` | `running` | 1 | 7 | 0.86 | near_miss (опечатка) |
| `ran` | `running` | 5 | 7 | 0.29 | no_recall (другое слово) |
| `walked` | `running` | 5 | 7 | 0.29 | no_recall (другое слово) |
| `` (пусто) | `running` | — | — | 0.00 | no_recall (не ответил) |
| `running` | `running` | 0 | 7 | 1.00 | correct=true |

**Порог near_miss:** `accuracy >= 0.7` (допускается до 30% отличающихся символов).

### Слой 3: Классификация — Recall Quality

Главная ось классификации. `correct` = результат **первой** попытки. `attempts` не участвует — retry-цикл педагогический, не сигнал для FSRS.

| Recall Quality | Условие | Когнитивный смысл |
|----------------|---------|-------------------|
| `:no_recall` | `!correct && accuracy < 0.7` | Слово не извлечено из памяти |
| `:near_miss` | `!correct && accuracy >= 0.7` | Слово в памяти, ошибка моторная/орфографическая |
| `:effortful_recall` | `correct && speed == :slow` | Извлечено, но с видимым усилием |
| `:successful_recall` | `correct && speed ∈ {:normal, :unknown}` | Штатное извлечение |
| `:automatic_recall` | `correct && speed == :fast` | Автоматизированное, без усилий |

5 классов. `assisted_recall` удалён: в текущем flow `correct` отражает первую попытку. Если первая попытка неправильная → `no_recall`/`near_miss` независимо от того, сколько retry было. Retry с ghost text — это не recall, а обучение.

### Слой 3b: Классификация — Speed Class

Вторичная ось, осмысленна только при `correct == true`:

| Speed Class | Порог | Обоснование |
|-------------|-------|-------------|
| `:fast` | < 3 000 мс | Чтение предложения ~1.5с + моторный ответ ~1с → если < 3с, слово автоматизировано |
| `:normal` | 3 000 – 9 999 мс | Типичное время на осознанное припоминание |
| `:slow` | >= 10 000 мс | Значительное усилие, возможно перебор вариантов |
| `:unknown` | nil | Таймер недоступен (JS отключён) → fallback к `:successful_recall` |

**Константы порогов:**

```ruby
FAST_THRESHOLD_MS = 3_000   # < 3 секунд → automatic recall
SLOW_THRESHOLD_MS = 10_000  # >= 10 секунд → effortful recall
NEAR_MISS_ACCURACY = 0.7    # accuracy >= 0.7 → near_miss (не no_recall)
```

### Слой 4: Маппинг Recall Quality → FSRS Rating

| Recall Quality | → Rating | Семантика FSRS |
|----------------|----------|----------------|
| `:no_recall` | **1 (Again)** | Полный провал извлечения → relearning |
| `:near_miss` | **2 (Hard)** | Слово в памяти, но моторная ошибка — не наказывать как провал |
| `:effortful_recall` | **2 (Hard)** | Извлёк, но с трудом — короткий интервал |
| `:successful_recall` | **3 (Good)** | Нормальное извлечение — стандартный интервал |
| `:automatic_recall` | **4 (Easy)** | Мгновенное — длинный интервал |

### Реализация pipeline

Чистые функции без побочных эффектов — class methods на `ReviewLog`:

```ruby
# app/models/review_log.rb

FAST_THRESHOLD_MS = 3_000
SLOW_THRESHOLD_MS = 10_000
NEAR_MISS_ACCURACY = 0.7

RECALL_TO_RATING = {
  "no_recall"         => RATING_AGAIN,
  "near_miss"         => RATING_HARD,
  "effortful_recall"  => RATING_HARD,
  "successful_recall" => RATING_GOOD,
  "automatic_recall"  => RATING_EASY
}.freeze

def self.classify_speed(elapsed_ms)
  return :unknown if elapsed_ms.nil?
  return :fast    if elapsed_ms < FAST_THRESHOLD_MS
  return :slow    if elapsed_ms >= SLOW_THRESHOLD_MS

  :normal
end

def self.classify_recall(correct:, elapsed_ms: nil, answer_accuracy: nil)
  unless correct
    return "near_miss" if answer_accuracy && answer_accuracy >= NEAR_MISS_ACCURACY
    return "no_recall"
  end

  case classify_speed(elapsed_ms)
  when :fast then "automatic_recall"
  when :slow then "effortful_recall"
  else            "successful_recall"  # :normal, :unknown
  end
end

def self.compute_rating(recall_quality)
  RECALL_TO_RATING.fetch(recall_quality)
end
```

**Двухшаговый pipeline:** `classify_recall` (correct + accuracy + speed → recall quality) + `compute_rating` (recall quality → FSRS integer). `attempts` не передаётся в pipeline — сохраняется только для аналитики.

**Почему class methods, а не отдельный класс:** это чистые функции от данных `ReviewLog`, без внешних зависимостей. Если появятся стратегии (по типу упражнения, по уровню) — тогда извлечь. Сейчас — YAGNI.

---

## Операции (Application Layer)

### `Reviews::RecordAnswer`

**Расположение:** `app/operations/reviews/record_answer.rb`

**Входные данные:**
- `card` — объект Card
- `correct` — boolean, правильность ответа
- `answer_text` — string, что ввёл пользователь (опционально)
- `elapsed_ms` — integer, время ответа в мс (опционально)
- `attempts` — integer, количество попыток (default: 1)
- `backspace_count` — integer, количество бэкспейсов (опционально)
- `now` — Time, текущий момент (default: Time.current)

**Алгоритм:**
1. Вычислить `answer_accuracy` через `ReviewLog.compute_accuracy(answer_text, card.form)`
2. Классифицировать `recall_quality` через `ReviewLog.classify_recall(correct:, attempts:, elapsed_ms:, answer_accuracy:)`
3. Вычислить `rating` через `ReviewLog.compute_rating(recall_quality)`
4. В транзакции:
   a. Создать `ReviewLog` со всеми сырыми сигналами + вычисленными `answer_accuracy`, `recall_quality`, `rating`
   b. Вызвать `card.schedule!(rating:, now:)`
5. Вернуть созданный `ReviewLog`

```ruby
module Reviews
  class RecordAnswer
    def self.call(...) = new(...).call

    def initialize(card:, correct:, answer_text: nil, elapsed_ms: nil,
                   attempts: 1, backspace_count: nil, now: Time.current)
      @card = card
      @correct = correct
      @answer_text = answer_text
      @elapsed_ms = elapsed_ms
      @attempts = attempts
      @backspace_count = backspace_count
      @now = now
    end

    def call
      accuracy = ReviewLog.compute_accuracy(@answer_text, @card.form)
      recall   = ReviewLog.classify_recall(
        correct: @correct, elapsed_ms: @elapsed_ms, answer_accuracy: accuracy
      )
      rating = ReviewLog.compute_rating(recall)

      ActiveRecord::Base.transaction do
        review_log = @card.review_logs.create!(
          rating: rating,
          recall_quality: recall,
          correct: @correct,
          answer_text: @answer_text,
          answer_accuracy: accuracy,
          elapsed_ms: @elapsed_ms,
          attempts: @attempts,
          backspace_count: @backspace_count,
          reviewed_at: @now
        )
        @card.schedule!(rating: rating, now: @now)
        review_log
      end
    end
  end
end
```

### `Reviews::BuildSession`

**Расположение:** `app/operations/reviews/build_session.rb`

**Входные данные:**
- `user` — объект User
- `limit` — integer, максимум карточек (default: 10)
- `now` — Time, текущий момент (default: Time.current)

**Алгоритм:**
1. Выбрать карточки пользователя с `due <= now`
2. Отсортировать по `due ASC` (самые просроченные — первыми)
3. Eager-load связи для отображения: `sentence_occurrence → sentence → sentence_translations`, `sentence_occurrence → lexeme → lexeme_glosses`
4. Ограничить `limit`

```ruby
module Reviews
  class BuildSession
    BATCH_SIZE = 10

    def self.call(...) = new(...).call

    def initialize(user:, limit: BATCH_SIZE, now: Time.current)
      @user = user
      @limit = limit
      @now = now
    end

    def call
      Card.due_for_review(@user, now: @now)
          .order(due: :asc)
          .limit(@limit)
          .includes(sentence_occurrence: [
            { sentence: :sentence_translations },
            { lexeme: :lexeme_glosses }
          ])
    end
  end
end
```

---

## Сценарии ошибок (Slice 1)

| Сценарий | Поведение |
|----------|-----------|
| Карточка не принадлежит пользователю | Controller проверяет `current_user.cards.find(id)` — 404 если не найдена |
| Нет due-карточек | `BuildSession` возвращает пустую коллекцию |
| `elapsed_ms` отрицательный или 0 | Трактуется как nil → speed = `:unknown` → `successful_recall` → Good |
| `answer_text` пустая строка | `correct=false`, `accuracy=0.0` → `no_recall` → Again |
| `answer_text` = почти правильно (опечатка) | `correct=false`, `accuracy >= 0.7` → `near_miss` → Hard (не Again) |
| `attempts` любое число | Допустимо — retry неограничен, pipeline игнорирует attempts |
| FSRS `repeat` выбрасывает `InvalidDateError` | Операция не ловит — ошибка пробрасывается, транзакция откатывается, controller показывает 500 |

---

## Acceptance Criteria — Slice 1

- [ ] Миграция 1: создаёт таблицу `review_logs` с описанными колонками (включая `recall_quality`, `answer_accuracy`, `backspace_count`), индексом и FK
- [ ] Миграция 2: добавляет `mastered_at` (datetime, nullable) к `cards`
- [ ] `ReviewLog` модель с валидациями `rating`, `recall_quality`, `correct`, `reviewed_at`, `attempts`, `answer_accuracy`
- [ ] `ReviewLog.compute_accuracy` вычисляет нормализованное сходство:
  - `"runnig"` vs `"running"` → 0.86
  - `"walked"` vs `"running"` → 0.29
  - `""` (пусто) → 0.0
  - `"running"` vs `"running"` → 1.0
- [ ] `ReviewLog.classify_recall` (correct = первая попытка, attempts не участвует):
  - incorrect + accuracy < 0.7 → `"no_recall"`
  - incorrect + accuracy >= 0.7 → `"near_miss"`
  - correct + elapsed >= 10000ms → `"effortful_recall"`
  - correct + elapsed 3000–9999ms → `"successful_recall"`
  - correct + elapsed nil → `"successful_recall"`
  - correct + elapsed < 3000ms → `"automatic_recall"`
- [ ] `ReviewLog.compute_rating` маппит recall quality → FSRS rating:
  - `no_recall` → 1, `near_miss` → 2, `effortful_recall` → 2, `successful_recall` → 3, `automatic_recall` → 4
- [ ] `Card#schedule!` обновляет FSRS-поля карточки (due, stability, difficulty, state, reps)
- [ ] `Card.due_for_review(user, now:)` возвращает только карточки с `due <= now` и `mastered_at IS NULL`
- [ ] `Card#master!` устанавливает `mastered_at`, карточка исчезает из `due_for_review`
- [ ] `Reviews::RecordAnswer.call` в одной транзакции: вычисляет accuracy → recall → rating, создаёт `ReviewLog` со всеми полями, обновляет карточку
- [ ] `Reviews::BuildSession.call` возвращает до 10 карточек, отсортированных по `due ASC`
- [ ] Повторный `RecordAnswer` для той же карточки создаёт второй `ReviewLog` (не обновляет)
- [ ] `bundle exec rspec` — все тесты проходят
- [ ] `bundle exec rubocop` — без нарушений

---

# Slice 2: Review Session UI

## User Flow

### Correct Answer Flow

```
1. Карточка отображается → preloadAudio() + warmUpAudio()
2. Пользователь печатает → побуквенный фидбек (зелёный/красный border)
3. Enter →  Stimulus валидирует клиентски
4. Правильно:
   ├── playAudio() — аудио предложения из Tatoeba
   ├── Записать answer_text (первая попытка) + elapsed_ms + attempts + backspace_count
   └── Submit формы → POST /review (Turbo Frame)
5. Сервер: RecordAnswer → pipeline → schedule
6. Turbo Stream → swap to next card → preloadAudio() для следующей
```

### Incorrect Answer Flow

```
1. Пользователь печатает → побуквенный фидбек (красный)
2. Enter → Stimulus валидирует → incorrect
3. Первая попытка:
   ├── Зафиксировать answer_text в hidden field (больше не меняется!)
   ├── attempts++
   └── resetUIForRetry():
       ├── clearInput() — очистить поле
       ├── showGhostText() — правильное слово серым поверх input
       ├── border → amber
       └── focusInput()
4. Пользователь печатает заново (ghost text исчезает при вводе)
5. Enter → Stimulus валидирует
   ├── Если опять неправильно → attempts++, снова resetUIForRetry()
   └── Если правильно → playAudio() + submit (correct=false, answer_text=первая попытка)
```

**Ключевое:** `correct` и `answer_text` фиксируются по **первой** попытке. Retry — педагогический, не меняет FSRS-рейтинг. Retry неограничен.

### Mark as Mastered Flow

```
1. На каждой карточке видна кнопка 🧠
2. Клик → POST /cards/:id/master (Turbo Frame)
3. Сервер: card.master! → mastered_at = now
4. Turbo Frame → swap to next card
```

---

## Маршруты

```ruby
# config/routes.rb — добавить:
resource :review, only: [:show, :create], controller: "review_sessions"
resources :cards, only: [] do
  member do
    post :master
  end
end
```

- `GET /review` — показать следующую карточку (или пустое состояние)
- `POST /review` — отправить ответ, Turbo Frame подменяет карточку на следующую
- `POST /cards/:id/master` — пометить карточку как выученную

## Контроллеры (Presentation Layer)

### `ReviewSessionsController`

```ruby
# app/controllers/review_sessions_controller.rb
class ReviewSessionsController < ApplicationController
  def show
    @cards = Reviews::BuildSession.call(user: current_user)
    @card = @cards.first
  end

  def create
    @card = current_user.cards.find(params[:card_id])
    answer_text = params[:answer_text].to_s.strip

    @review_log = Reviews::RecordAnswer.call(
      card: @card,
      correct: answer_correct?(answer_text, @card),
      answer_text: answer_text,
      elapsed_ms: positive_int(params[:elapsed_ms]),
      attempts: positive_int(params[:attempts]) || 1,
      backspace_count: positive_int(params[:backspace_count])
    )

    @next_cards = Reviews::BuildSession.call(user: current_user)
    @next_card = @next_cards.first
  end

  private

  def answer_correct?(answer_text, card)
    answer_text.downcase == card.form.downcase
  end

  def positive_int(value)
    v = value&.to_i
    v && v > 0 ? v : nil
  end
end
```

### `CardsController`

```ruby
# app/controllers/cards_controller.rb
class CardsController < ApplicationController
  def master
    card = current_user.cards.find(params[:id])
    card.master!

    @next_cards = Reviews::BuildSession.call(user: current_user)
    @next_card = @next_cards.first
    render "review_sessions/create"
  end
end
```

**Решения:**
- `answer_text` приходит из hidden field (первая попытка, зафиксированная Stimulus)
- `correct` определяется сервером по `answer_text` — exact match (case-insensitive, strip)
- `POST /review` возвращает Turbo Stream (не redirect) — подменяет карточку на следующую
- `POST /cards/:id/master` использует тот же Turbo Stream шаблон для подмены

## Turbo Stream архитектура

```
GET /review (full page load)
└── layout
    └── turbo_frame_tag "review_card"
        └── _card_form.html.erb (или _empty_state.html.erb)

POST /review (Turbo Stream response)
└── turbo_stream: replace "review_card"
    └── следующая _card_form.html.erb (или _empty_state.html.erb)

POST /cards/:id/master (Turbo Stream response)
└── turbo_stream: replace "review_card"
    └── следующая _card_form.html.erb (или _empty_state.html.erb)
```

**Принцип:** POST-ы возвращают `turbo_stream` с заменой фрейма на следующую карточку. Нет промежуточного feedback-экрана — audio играет клиентски, следующая карточка появляется сразу.

## Views

### `app/views/review_sessions/show.html.erb`

```erb
<div class="max-w-2xl mx-auto px-4 py-8">
  <h1 class="text-2xl font-bold text-gray-900 mb-6"><%= t("reviews.title") %></h1>

  <%= turbo_frame_tag "review_card" do %>
    <% if @card %>
      <%= render "card_form", card: @card %>
    <% else %>
      <%= render "empty_state" %>
    <% end %>
  <% end %>
</div>
```

### `app/views/review_sessions/create.turbo_stream.erb`

```erb
<%= turbo_stream.replace "review_card" do %>
  <% if @next_card %>
    <%= render "review_sessions/card_form", card: @next_card %>
  <% else %>
    <%= render "review_sessions/empty_state" %>
  <% end %>
<% end %>
```

### `app/views/review_sessions/_card_form.html.erb`

```erb
<%= turbo_frame_tag "review_card" do %>
<div class="bg-white rounded-lg shadow p-6"
     data-controller="review"
     data-review-answer-value="<%= card.form.downcase %>"
     data-review-audio-url-value="<%= card.sentence.audio_id ? "https://audio.tatoeba.org/sentences/eng/#{card.sentence.audio_id}.mp3" : "" %>">

  <%# Cloze-предложение с пропуском %>
  <p class="text-xl text-gray-800 mb-4 leading-relaxed">
    <%= card.cloze_text %>
  </p>

  <%# Перевод на русский %>
  <% translation = card.sentence.sentence_translations.find { |st| st.target_language.code == "ru" } %>
  <% if translation %>
    <p class="text-sm text-gray-500 mb-6 italic"><%= translation.text %></p>
  <% end %>

  <%# Глоссы %>
  <% glosses = card.lexeme.lexeme_glosses.select { |g| g.target_language.code == "ru" } %>
  <% if glosses.any? %>
    <p class="text-sm text-gray-400 mb-4"><%= glosses.map(&:gloss).join(", ") %></p>
  <% end %>

  <%# Форма ответа %>
  <%= form_with url: review_path, method: :post, data: { action: "submit->review#submit" } do |f| %>
    <%= f.hidden_field :card_id, value: card.id %>
    <%= f.hidden_field :answer_text, value: "", data: { review_target: "answerText" } %>
    <%= f.hidden_field :elapsed_ms, value: 0, data: { review_target: "elapsed" } %>
    <%= f.hidden_field :attempts, value: 1, data: { review_target: "attempts" } %>
    <%= f.hidden_field :backspace_count, value: 0, data: { review_target: "backspaces" } %>

    <div class="relative mb-4">
      <%# Ghost text overlay %>
      <div class="absolute inset-0 flex items-center px-3 pointer-events-none hidden"
           data-review-target="ghost">
        <span class="text-gray-300 text-lg"><%= card.form %></span>
      </div>

      <%# Input без name — не отправляется, данные идут через hidden fields %>
      <input type="text"
             autofocus
             autocomplete="off"
             placeholder="<%= t("reviews.placeholder") %>"
             class="w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-lg transition-colors"
             data-review-target="input"
             data-action="input->review#onInput keydown->review#trackKey" />
    </div>

    <div class="flex items-center justify-between">
      <%= f.submit t("reviews.submit"),
          class: "bg-indigo-600 text-white px-6 py-2 rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 cursor-pointer" %>

      <%# Mark as Mastered %>
      <%= button_to master_card_path(card), method: :post, class: "text-2xl opacity-50 hover:opacity-100 transition-opacity", title: t("reviews.master") do %>
        🧠
      <% end %>
    </div>
  <% end %>
</div>
<% end %>
```

### `app/views/review_sessions/_empty_state.html.erb`

```erb
<%= turbo_frame_tag "review_card" do %>
<div class="bg-white rounded-lg shadow p-8 text-center">
  <div class="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
    <svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
    </svg>
  </div>
  <h2 class="text-xl font-semibold text-gray-900 mb-2"><%= t("reviews.done_title") %></h2>
  <p class="text-gray-500 mb-6"><%= t("reviews.done_message") %></p>
  <%= link_to t("reviews.back_to_dashboard"), dashboard_path,
      class: "inline-block bg-indigo-600 text-white px-6 py-2 rounded-md hover:bg-indigo-700" %>
</div>
<% end %>
```

---

## Stimulus-контроллер

```javascript
// app/javascript/controllers/review_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "answerText", "elapsed", "attempts", "backspaces", "ghost"]
  static values = {
    answer: String,                          // ожидаемый ответ (lowercase)
    audioUrl: { type: String, default: "" }  // URL аудио Tatoeba
  }

  connect() {
    this.startedAt = Date.now()
    this.attemptCount = 0
    this.backspaceCount = 0
    this.firstAnswerRecorded = false
    this.audioBuffer = null
    this.audioContext = null

    this.inputTarget.focus()
    this.resizeInput()
    this.preloadAudio()
  }

  // --- Real-time feedback: побуквенное сравнение ---

  onInput() {
    const typed = this.inputTarget.value.toLowerCase()
    const expected = this.answerValue

    // Hide ghost text when user starts typing
    if (typed.length > 0) {
      this.ghostTarget.classList.add("hidden")
    }

    // Character-by-character feedback via border color
    if (typed.length === 0) {
      this.inputTarget.classList.remove("border-green-500", "border-red-500", "ring-green-500", "ring-red-500")
    } else if (expected.startsWith(typed)) {
      this.inputTarget.classList.remove("border-red-500", "ring-red-500")
      this.inputTarget.classList.add("border-green-500", "ring-green-500")
    } else {
      this.inputTarget.classList.remove("border-green-500", "ring-green-500")
      this.inputTarget.classList.add("border-red-500", "ring-red-500")
    }
  }

  // --- Backspace tracking ---

  trackKey(event) {
    if (event.key === "Backspace") {
      this.backspaceCount++
    }
  }

  // --- Submit: validation + retry + audio ---

  submit(event) {
    event.preventDefault()
    const userAnswer = this.inputTarget.value.trim()
    const isCorrect = userAnswer.toLowerCase() === this.answerValue

    // Capture first attempt (never overwrite)
    if (!this.firstAnswerRecorded) {
      this.answerTextTarget.value = userAnswer
      this.firstAnswerRecorded = true
    }

    this.attemptCount++

    if (isCorrect) {
      this.playAudio()
      this.finalSubmit()
    } else {
      this.resetUIForRetry()
    }
  }

  // --- Retry UI ---

  resetUIForRetry() {
    this.inputTarget.value = ""
    this.ghostTarget.classList.remove("hidden")       // show ghost text
    this.inputTarget.classList.remove("border-green-500", "ring-green-500", "border-red-500", "ring-red-500")
    this.inputTarget.classList.add("border-amber-500", "ring-amber-500")
    this.inputTarget.focus()
  }

  // --- Final submit to server ---

  finalSubmit() {
    this.elapsedTarget.value = Date.now() - this.startedAt
    this.attemptsTarget.value = this.attemptCount
    this.backspacesTarget.value = this.backspaceCount
    this.element.querySelector("form").requestSubmit()
  }

  // --- Audio: preload + warmup + play ---

  async preloadAudio() {
    if (!this.audioUrlValue) return

    try {
      this.audioContext = this.audioContext || new AudioContext()
      const response = await fetch(this.audioUrlValue)
      const arrayBuffer = await response.arrayBuffer()
      this.audioBuffer = await this.audioContext.decodeAudioData(arrayBuffer)
    } catch {
      // Audio unavailable — silent fallback
    }
  }

  playAudio() {
    if (!this.audioBuffer || !this.audioContext) return

    const source = this.audioContext.createBufferSource()
    source.buffer = this.audioBuffer
    source.connect(this.audioContext.destination)
    source.start(0)
  }

  // --- Adaptive input: ширина по длине слова ---

  resizeInput() {
    const canvas = document.createElement("canvas")
    const ctx = canvas.getContext("2d")
    const style = getComputedStyle(this.inputTarget)
    ctx.font = style.font
    const width = ctx.measureText(this.answerValue).width
    this.inputTarget.style.width = `${Math.max(width + 48, 120)}px`  // padding + minimum
  }
}
```

**Ответственность Stimulus-контроллера:**

| Функция | Что делает |
|---------|-----------|
| `connect` | Таймер, фокус, preload audio, adaptive input width |
| `onInput` | Побуквенный фидбек: `expected.startsWith(typed)` → зелёный/красный border |
| `trackKey` | Считает Backspace |
| `submit` | Фиксирует первый ответ → если правильно: audio + submit. Если нет: retry |
| `resetUIForRetry` | Очищает input, показывает ghost text, amber border, фокус |
| `finalSubmit` | Записывает elapsed_ms/attempts/backspaces → requestSubmit() |
| `preloadAudio` | Fetch + decode mp3 в AudioBuffer при показе карточки |
| `playAudio` | Мгновенное воспроизведение из буфера (без задержки) |
| `resizeInput` | Canvas measureText → input width по длине ожидаемого слова |

**Ghost text:** `position: absolute` overlay с правильным словом серым текстом. Показывается после неправильного ответа. Скрывается когда пользователь начинает печатать (`onInput`).

**Audio pipeline:** `connect → fetch(url) → decodeAudioData → audioBuffer`. При правильном ответе: `createBufferSource → start(0)`. Мгновенное воспроизведение без задержки первого play, т.к. AudioContext создан и аудио декодировано заранее. Если `audio_id = nil` → preload пропускается, playAudio — noop.

---

## i18n

```yaml
# config/locales/ru.yml — добавить:
ru:
  reviews:
    title: "Повторение"
    placeholder: "Введите слово..."
    submit: "Проверить"
    master: "Знаю это слово"
    done_title: "Все карточки повторены!"
    done_message: "Возвращайтесь позже для следующего повторения."
    back_to_dashboard: "На главную"
```

```yaml
# config/locales/en.yml — добавить:
en:
  reviews:
    title: "Review"
    placeholder: "Type the word..."
    submit: "Check"
    master: "I know this word"
    done_title: "All cards reviewed!"
    done_message: "Come back later for your next review."
    back_to_dashboard: "Dashboard"
```

## Навигация

Добавить ссылку на `/review` в `dashboard/index.html.erb`:

```erb
<%= link_to t("reviews.title"), review_path,
    class: "inline-block bg-indigo-600 text-white px-6 py-3 rounded-md hover:bg-indigo-700 text-lg" %>
```

---

## Сценарии ошибок (Slice 2)

| Сценарий | Поведение |
|----------|-----------|
| Пользователь не залогинен | Редирект на `/login` (существующий `require_login`) |
| `card_id` не принадлежит пользователю | `ActiveRecord::RecordNotFound` → 404 |
| `card_id` отсутствует в params | `ActiveRecord::RecordNotFound` → 404 |
| `answer_text` пустая (JS отключён или сломался) | `correct=false`, `accuracy=0.0` → `no_recall` → Again |
| JavaScript отключён | Hidden fields пусты → `elapsed_ms=nil`, `backspace_count=nil`. Visible input отправляется как fallback. Retry и audio не работают. |
| Audio недоступно (нет audio_id или сеть) | Silent fallback — preloadAudio ловит ошибку, playAudio — noop |
| Пользователь мастерит уже mastered карточку | `card.master!` — idempotent (mastered_at перезаписывается, без ошибки) |
| Двойной submit (race condition) | Первый submit обработается, второй создаст дубль `ReviewLog`. Допустимо для v1. |

---

## Acceptance Criteria — Slice 2

- [ ] `GET /review` показывает cloze-карточку с пропуском, переводом и глоссами
- [ ] `GET /review` без due-карточек показывает "Все карточки повторены!"
- [ ] Правильный ответ: audio играет, карточка заменяется на следующую (Turbo Stream)
- [ ] Неправильный ответ: ghost text появляется, input очищается, amber border, retry
- [ ] Retry неограничен — пользователь может пробовать пока не введёт правильно
- [ ] `answer_text` hidden field фиксируется на **первом** Enter, не перезаписывается при retry
- [ ] Побуквенный фидбек: зелёный border если `expected.startsWith(typed)`, красный если нет, neutral (сброс цвета) при пустом input
- [ ] Adaptive input: ширина поля подстраивается под длину ожидаемого слова
- [ ] Audio preload: mp3 загружается и декодируется при показе карточки
- [ ] Audio play: мгновенное воспроизведение при правильном ответе, silent fallback если нет audio_id
- [ ] `attempts` в hidden field корректно инкрементируется: после N попыток (включая первую) значение равно N
- [ ] Backspace tracking: считается и передаётся в hidden field
- [ ] Кнопка 🧠 на каждой карточке → `POST /cards/:id/master` → карточка mastered, следующая загружается
- [ ] Mastered карточки не появляются в `due_for_review`
- [ ] Поле ввода получает фокус автоматически при показе карточки
- [ ] Незалогиненный пользователь перенаправляется на `/login`
- [ ] i18n: все тексты через `t()`, наличие ru и en
- [ ] На dashboard есть ссылка "Повторение" → `/review`
- [ ] `bundle exec rspec` — все тесты проходят
- [ ] `bundle exec rubocop` — без нарушений

---

## Архитектурные слои (Layered Rails)

```
┌──────────────────────────────────────────────────────────────────┐
│  PRESENTATION                                                    │
│  ReviewSessionsController — HTTP: params, auth, turbo stream     │
│  CardsController#master — mark as mastered                       │
│  Views (ERB + Turbo Streams) — карточки, ghost text, empty state │
│  Stimulus review_controller — timer, retry, audio, ghost, a11y   │
│  i18n (ru.yml, en.yml) — тексты интерфейса                       │
└────────────────────────────┬─────────────────────────────────────┘
                             │ вызывает
┌────────────────────────────▼─────────────────────────────────────┐
│  APPLICATION (Operations)                                        │
│  Reviews::RecordAnswer — транзакция: лог + расписание            │
│  Reviews::BuildSession — выборка due-карточек с eager loading     │
│  Card#master! — пометить как выученную навсегда                  │
└────────────────────────────┬─────────────────────────────────────┘
                             │ использует
┌────────────────────────────▼─────────────────────────────────────┐
│  DOMAIN (Models)                                                 │
│  ReviewLog — валидации, classify_recall, compute_rating, accuracy │
│  Card — schedule!, master!, due_for_review, FSRS-конвертация     │
│  SentenceOccurrence — cloze_text, делегирование                  │
└────────────────────────────┬─────────────────────────────────────┘
                             │ обращается к
┌────────────────────────────▼─────────────────────────────────────┐
│  INFRASTRUCTURE                                                  │
│  ActiveRecord — PostgreSQL, UUID v7                              │
│  Fsrs gem — алгоритм спейсед репетишн (Fsrs::Scheduler#repeat)  │
└──────────────────────────────────────────────────────────────────┘
```

**Правила:**
- Нижние слои не зависят от верхних
- Models не обращаются к Current, контроллерам, операциям
- Operations не принимают request/params — только domain-объекты и скаляры
- Controller передаёт user явно (constructor injection через operations)

---

## Ограничения реализации

- Две миграции: создание таблицы `review_logs` + добавление `mastered_at` к `cards`
- Использовать паттерн Operation (как `Cards::BuildStarterDeck`) — `.call` / `new(...).call`
- Не добавлять новые гемы
- Не менять существующие миграции
- Файлы совместимы с Zeitwerk: `app/operations/reviews/record_answer.rb` → `Reviews::RecordAnswer`
- FSRS-рейтинги: использовать целочисленные константы (1–4), не зависеть от `Fsrs::Rating::*` вне domain layer
- Сравнение ответов для `correct`: exact match (case-insensitive, strip). `answer_accuracy` вычисляется отдельно для рейтинга, но не влияет на `correct`
- Levenshtein distance: использовать `DidYouMean::Levenshtein.distance` из stdlib Ruby (не новый гем)
- `backspace_count`: захватывать и сохранять, но **не использовать** в `classify_recall` v1
- `attempts`: захватывать и сохранять, но **не использовать** в `classify_recall` — retry педагогический
- Audio: URL строится из `sentences.audio_id` + Tatoeba CDN. Не кэшируется на сервере.
- Correct answer в HTML data-attribute: допустимый компромисс для обучающего приложения

---

## Тест-план

### Model specs

| Тест | Файл |
|------|------|
| `ReviewLog` валидации (rating, recall_quality, correct, reviewed_at, attempts, answer_accuracy) | `spec/models/review_log_spec.rb` |
| `.compute_accuracy` — Levenshtein: exact=1.0, typo≈0.86, wrong≈0.29, empty=0.0 | `spec/models/review_log_spec.rb` |
| `.classify_recall` — все 5 классов (no_recall, near_miss, effortful, successful, automatic) | `spec/models/review_log_spec.rb` |
| `.classify_recall` — `attempts` не влияет на результат | `spec/models/review_log_spec.rb` |
| `.compute_rating` — маппинг каждого recall quality → FSRS rating | `spec/models/review_log_spec.rb` |
| `Card#schedule!` — обновляет FSRS-поля | `spec/models/card_spec.rb` |
| `Card#master!` — устанавливает mastered_at | `spec/models/card_spec.rb` |
| `Card.due_for_review` — фильтрация по user + due + исключение mastered | `spec/models/card_spec.rb` |

### Operation specs

| Тест | Файл |
|------|------|
| `RecordAnswer` — full pipeline: accuracy → recall → rating → log + schedule | `spec/operations/reviews/record_answer_spec.rb` |
| `RecordAnswer` — near_miss: typo "runnig" → Hard(2), не Again(1) | `spec/operations/reviews/record_answer_spec.rb` |
| `RecordAnswer` — correct=false по первой попытке, attempts > 1 → всё равно no_recall/near_miss | `spec/operations/reviews/record_answer_spec.rb` |
| `RecordAnswer` — backspace_count и attempts сохраняются, но не влияют на rating | `spec/operations/reviews/record_answer_spec.rb` |
| `BuildSession` — возвращает due-карточки, сортировка, лимит | `spec/operations/reviews/build_session_spec.rb` |
| `BuildSession` — исключает mastered карточки | `spec/operations/reviews/build_session_spec.rb` |
| `BuildSession` — пустой результат без due-карточек | `spec/operations/reviews/build_session_spec.rb` |

### Request specs

| Тест | Файл |
|------|------|
| `GET /review` — показывает карточку залогиненному | `spec/requests/review_sessions_spec.rb` |
| `GET /review` — empty state без due-карточек | `spec/requests/review_sessions_spec.rb` |
| `GET /review` — редирект для незалогиненного | `spec/requests/review_sessions_spec.rb` |
| `POST /review` — правильный ответ: turbo stream с следующей карточкой | `spec/requests/review_sessions_spec.rb` |
| `POST /review` — неправильный ответ: turbo stream с следующей карточкой | `spec/requests/review_sessions_spec.rb` |
| `POST /review` — answer_text первой попытки используется для accuracy | `spec/requests/review_sessions_spec.rb` |
| `POST /review` — чужая карточка → 404 | `spec/requests/review_sessions_spec.rb` |
| `POST /cards/:id/master` — mastered_at, turbo stream с следующей карточкой | `spec/requests/cards_spec.rb` |
| `POST /cards/:id/master` — чужая карточка → 404 | `spec/requests/cards_spec.rb` |

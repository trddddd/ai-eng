# Spec: Персональная стартовая колода после регистрации

**Brief:** [memory-bank/features/006/brief.md](brief.md)
**Issue:** trddddd/ai-eng#10

## Цель

Сразу после регистрации пользователь получает персональный набор карточек из A1-лексем и может немедленно начать первую учебную сессию без дополнительных действий.

## Scope

**Входит:**
- Модель `Card` с персональным FSRS-состоянием
- Сервис формирования стартовой колоды
- Автоматический вызов при регистрации
- Идемпотентность: повторный вызов не дублирует карточки

**НЕ входит:**
- UI учебной сессии (review flow) — отдельная фича
- Выбор набора слов при регистрации (onboarding flow)
- Редактирование/удаление стартовой колоды пользователем
- Поддержка нескольких наборов одновременно
- Модель Deck / коллекции (все карточки пользователя = одна неявная колода)

---

## Модель данных

### Таблица `cards`

| Колонка | Тип | Constraints | Описание |
|---------|-----|-------------|----------|
| `id` | `uuid` | PK, default `uuidv7()` | — |
| `user_id` | `bigint` | NOT NULL, FK → users(id) | Владелец карточки |
| `sentence_occurrence_id` | `uuid` | NOT NULL, FK → sentence_occurrences(id) | Слово-в-контексте |
| `due` | `datetime` | NOT NULL | Когда показать следующий раз |
| `stability` | `float` | NOT NULL, default `0.0` | FSRS: стабильность памяти |
| `difficulty` | `float` | NOT NULL, default `0.0` | FSRS: сложность |
| `elapsed_days` | `integer` | NOT NULL, default `0` | FSRS: дней с последнего повтора |
| `scheduled_days` | `integer` | NOT NULL, default `0` | FSRS: запланированный интервал |
| `reps` | `integer` | NOT NULL, default `0` | FSRS: кол-во повторений |
| `lapses` | `integer` | NOT NULL, default `0` | FSRS: кол-во забываний |
| `state` | `integer` | NOT NULL, default `0` | FSRS: 0=new, 1=learning, 2=review, 3=relearning |
| `last_review` | `datetime` | NULL | FSRS: дата последнего повтора |
| `created_at` | `datetime` | NOT NULL | — |
| `updated_at` | `datetime` | NOT NULL | — |

**Индексы:**
- `(user_id, sentence_occurrence_id)` — UNIQUE (один пользователь не может иметь две карточки на одно и то же вхождение)
- `(user_id, due)` — для выборки "карточки к повторению" (будущий review flow)
- `(user_id, state)` — для фильтрации по состоянию

**Foreign keys:**
- `user_id → users(id)` ON DELETE CASCADE
- `sentence_occurrence_id → sentence_occurrences(id)` ON DELETE RESTRICT

### Модель `Card`

```ruby
class Card < ApplicationRecord
  belongs_to :user
  belongs_to :sentence_occurrence

  # Делегирование для удобства доступа
  delegate :lexeme, :sentence, :form, :cloze_text, to: :sentence_occurrence

  # FSRS states
  STATE_NEW        = 0
  STATE_LEARNING   = 1
  STATE_REVIEW     = 2
  STATE_RELEARNING = 3

  validates :user_id, uniqueness: { scope: :sentence_occurrence_id }
  validates :due, presence: true
  validates :state, inclusion: { in: [STATE_NEW, STATE_LEARNING, STATE_REVIEW, STATE_RELEARNING] }

  # Конвертация в/из Fsrs::Card для работы с алгоритмом
  def to_fsrs_card
    fsrs_card = Fsrs::Card.new
    fsrs_card.due = due
    fsrs_card.stability = stability
    fsrs_card.difficulty = difficulty
    fsrs_card.elapsed_days = elapsed_days
    fsrs_card.scheduled_days = scheduled_days
    fsrs_card.reps = reps
    fsrs_card.lapses = lapses
    fsrs_card.state = state
    fsrs_card.last_review = last_review
    fsrs_card
  end

  def apply_fsrs_card!(fsrs_card)
    update!(
      due: fsrs_card.due,
      stability: fsrs_card.stability,
      difficulty: fsrs_card.difficulty,
      elapsed_days: fsrs_card.elapsed_days,
      scheduled_days: fsrs_card.scheduled_days,
      reps: fsrs_card.reps,
      lapses: fsrs_card.lapses,
      state: fsrs_card.state,
      last_review: fsrs_card.last_review
    )
  end
end
```

---

## Логика формирования стартовой колоды

### Операция `Cards::BuildStarterDeck`

**Расположение:** `app/operations/cards/build_starter_deck.rb`

**Входные данные:**
- `user` — объект User (уже сохранён в БД)

**Алгоритм выбора карточек:**

1. Выбрать все лексемы с `cefr_level = "a1"` и `language.code = "en"`
2. Для каждой лексемы взять **одно** `SentenceOccurrence`, у которого:
   - У sentence есть `SentenceTranslation` на русский (`target_language.code = "ru"`)
   - Если несколько подходящих — выбрать первое по `sentence_occurrence.id` (детерминированный порядок)
3. Ограничить результат **50 карточками** (константа `STARTER_DECK_SIZE = 50`)
   - Если подходящих occurrence < 50 — взять сколько есть
4. Создать `Card` для каждого выбранного `SentenceOccurrence`:
   - `due = Time.current` (все карточки сразу доступны для изучения)
   - Все FSRS-поля = defaults (state: NEW)

**Идемпотентность:**
- Использовать `insert_all` с `unique_by: [:user_id, :sentence_occurrence_id]` — повторный вызов не создаёт дубликатов, не выбрасывает ошибку

**Производительность:**
- Один SQL-запрос для выборки occurrence IDs (через JOIN + WHERE + LIMIT)
- Один `insert_all` для массовой вставки карточек
- Не создаёт N+1 запросов

### Интеграция с регистрацией

В `RegistrationsController#create`, после успешного `@user.save`:

```ruby
def create
  @user = User.new(registration_params)
  if @user.save
    Cards::BuildStarterDeck.call(@user)
    session[:user_id] = @user.id
    redirect_to dashboard_path
  else
    render :new, status: :unprocessable_entity
  end
end
```

Вызов синхронный — `insert_all` для 50 строк занимает < 50ms.

---

## Ассоциации на существующих моделях

```ruby
# user.rb — добавить:
has_many :cards, dependent: :destroy

# sentence_occurrence.rb — добавить:
has_many :cards, dependent: :restrict_with_exception
```

---

## Сценарии ошибок

| Сценарий | Поведение |
|----------|-----------|
| Нет A1-лексем в БД (пустой каталог) | Пользователь создаётся, колода остаётся пустой (0 карточек). Регистрация не блокируется. |
| Нет sentence_occurrences с переводами | Аналогично — 0 карточек, регистрация успешна. |
| `BuildStarterDeck` выбрасывает исключение | Обернуть в `rescue` — залогировать ошибку через `Rails.logger.error`, не блокировать регистрацию. Пользователь получит пустую колоду. |
| Повторный вызов `BuildStarterDeck` для того же пользователя | Новые карточки не создаются (idempotent via `insert_all` + unique index). |

---

## Ограничения реализации

- Одна миграция: создание таблицы `cards`
- Использовать паттерн Operation (как `ContentBootstrap::*`) — класс с `.call`
- Не добавлять новые гемы
- Не менять существующие миграции
- Файлы совместимы с Zeitwerk: `app/operations/cards/build_starter_deck.rb` → `Cards::BuildStarterDeck`
- `user_id` — `bigint`, не UUID: таблица `users` использует legacy `bigint` PK, FK должен совпадать по типу

---

## Acceptance Criteria

- [ ] Миграция создаёт таблицу `cards` с описанными колонками, индексами и FK
- [ ] `Card` модель с валидациями, `to_fsrs_card`, `apply_fsrs_card!`
- [ ] `Cards::BuildStarterDeck.call(user)` создаёт ≤ 50 карточек для A1-лексем с переводами
- [ ] Каждая карточка ссылается на уникальный `SentenceOccurrence`; все FSRS-поля = defaults; `due = Time.current`; `state = 0` (NEW)
- [ ] Повторный вызов `BuildStarterDeck` для того же пользователя не создаёт дубликатов
- [ ] После `POST /register` у нового пользователя `user.cards.count` > 0 (при наличии контента в БД)
- [ ] Ошибка в `BuildStarterDeck` не блокирует регистрацию — пользователь создаётся, сессия устанавливается
- [ ] `bundle exec rspec` — все новые и существующие тесты проходят
- [ ] `bundle exec rubocop` — без нарушений

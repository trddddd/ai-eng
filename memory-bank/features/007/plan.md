# Plan: Сессия повторений со спейсед репетишн

**Spec:** [memory-bank/features/007/spec.md](spec.md)
**Issue:** trddddd/ai-eng#14

---

## Оркестрация

**Паттерн:** последовательный — Slice 1 (backend), затем Slice 2 (UI). Один PR.

**Обоснование:** UI строится поверх backend-операций. Внутри PR порядок важен — контроллеры и views вызывают операции, которых ещё нет.

---

## Grounding: привязка к текущей кодовой базе

### Что уже есть

| Артефакт | Статус | Путь |
|----------|--------|------|
| Card model с FSRS-полями (due, stability, difficulty, state, reps, lapses, elapsed_days, scheduled_days, last_review) | Есть | `app/models/card.rb` |
| `Card#to_fsrs_card` / `Card#apply_fsrs_card!` | Есть | `app/models/card.rb` |
| `Card` делегирует `form`, `cloze_text`, `lexeme`, `sentence` → `sentence_occurrence` | Есть | `app/models/card.rb` |
| `User has_many :cards` | Есть | `app/models/user.rb` |
| `Sentence#audio_id` (integer) | Есть | `db/schema.rb` |
| `SentenceOccurrence#cloze_text` | Есть | `app/models/sentence_occurrence.rb` |
| Operations pattern (`Cards::BuildStarterDeck`) | Есть | `app/operations/cards/build_starter_deck.rb` |
| Turbo + Stimulus + importmap | Настроено | `app/javascript/` |
| Аутентификация (`require_login`, `current_user`, session-based) | Есть | `app/controllers/application_controller.rb` |
| i18n (ru — полный, en — минимальный) | Есть | `config/locales/` |
| `params.expect()` паттерн | Есть | `app/controllers/registrations_controller.rb` |
| Dashboard с `GET /dashboard` | Есть | `app/controllers/dashboard_controller.rb` |

### Чего нет (нужно создать)

| Артефакт | Действие |
|----------|----------|
| `mastered_at` колонка на `cards` | Миграция |
| Таблица `review_logs` | Миграция |
| `ReviewLog` модель | Создать |
| `Card#schedule!`, `Card#master!`, `Card.due_for_review` | Добавить в существующий `card.rb` |
| `Reviews::RecordAnswer` операция | Создать |
| `Reviews::BuildSession` операция | Создать |
| `ReviewSessionsController` | Создать |
| `CardsController` (master action) | Создать |
| Views: card_form, empty_state, show, create.turbo_stream | Создать |
| Stimulus `review_controller.js` | Создать |
| Routes: `/review`, `/cards/:id/master` | Добавить в `routes.rb` |
| i18n ключи `reviews.*` | Добавить в ru.yml и en.yml |

### Feasibility-проверки

1. **`DidYouMean::Levenshtein.distance`** — часть stdlib Ruby, доступна без гемов. Проверить: `DidYouMean::Levenshtein.distance("a", "b")` в rails console.

2. **`Fsrs::Scheduler#repeat`** — gem fsrs 0.9.0 подключён с GitHub. Метод `repeat` принимает `(card, now)` и возвращает Hash. Ключи — целочисленные рейтинги (1–4). Нужно проверить точный API: `results[1].card` или `results[Fsrs::Rating::AGAIN].card`. Спека говорит использовать целочисленные ключи — верифицировать.

3. **`Card#schedule!`** — спека вызывает `scheduler.repeat(fsrs_card, now.utc)` и берёт `results[rating]`. Нужно убедиться, что `Fsrs::Scheduler.new` без параметров работает с дефолтными весами.

4. **Audio URL** — строится как `https://audio.tatoeba.org/sentences/eng/#{card.sentence.audio_id}.mp3`. `card.sentence` делегируется через `sentence_occurrence` → `sentence` — цепочка работает.

5. **`dashboard_path`** — маршрут `GET /dashboard` существует, helper `dashboard_path` доступен.

6. **User PK** — `users.id` это `bigint` (не UUID). `cards.user_id` — `bigint`. FK совместимы.

### Потенциальные конфликты

- **Нет конфликтов с текущим кодом.** Card model расширяется (scope, методы), не ломая существующее. Новые файлы не пересекаются с имеющимися.

---

## Slice 1: Review Cycle Backend

### Шаг 1.1 — Миграция `create_review_logs`

**Файл:** `db/migrate/TIMESTAMP_create_review_logs.rb`

- Создать таблицу `review_logs` (UUID PK, uuidv7)
- Колонки по спеке: card_id, rating, recall_quality, correct, answer_text, answer_accuracy, elapsed_ms, attempts, backspace_count, reviewed_at, timestamps
- Индекс: `(card_id, reviewed_at)`
- FK: `card_id → cards(id)` ON DELETE CASCADE

**Зависимости:** нет
**Проверка:** `bin/rails db:migrate` + проверить schema.rb

### Шаг 1.2 — Миграция `add_mastered_at_to_cards`

**Файл:** `db/migrate/TIMESTAMP_add_mastered_at_to_cards.rb`

- `add_column :cards, :mastered_at, :datetime, null: true`

**Зависимости:** нет (независима от 1.1)
**Проверка:** `bin/rails db:migrate` + проверить schema.rb

### Шаг 1.3 — Модель `ReviewLog`

**Файл:** `app/models/review_log.rb`

- `belongs_to :card`
- Константы: RATING_AGAIN/HARD/GOOD/EASY, RATINGS, RECALL_QUALITIES
- Константы порогов: FAST_THRESHOLD_MS, SLOW_THRESHOLD_MS, NEAR_MISS_ACCURACY
- RECALL_TO_RATING маппинг
- Валидации по спеке
- Class methods: `compute_accuracy`, `classify_speed`, `classify_recall`, `compute_rating`

**Зависимости:** шаг 1.1 (таблица должна существовать для тестов)
**Проверка:** model spec

### Шаг 1.4 — Расширение модели `Card`

**Файл:** `app/models/card.rb` (редактирование существующего)

Добавить:
- `has_many :review_logs, dependent: :destroy`
- `scope :due_for_review` — фильтр по user, due <= now, mastered_at IS NULL
- `schedule!(rating:, now:)` — вызов Fsrs::Scheduler, apply результат
- `master!(now:)` — установка mastered_at
- `mastered?` — предикат

**Зависимости:** шаг 1.1 (для `has_many`), шаг 1.2 (для `mastered_at`)
**Проверка:** model spec — расширить существующий `spec/models/card_spec.rb`

### Шаг 1.5 — Операция `Reviews::RecordAnswer`

**Файл:** `app/operations/reviews/record_answer.rb`

- Паттерн `.call` / `new(...).call` (как `Cards::BuildStarterDeck`)
- Pipeline: accuracy → recall → rating → транзакция (create log + schedule card)

**Зависимости:** шаги 1.3, 1.4
**Проверка:** operation spec

### Шаг 1.6 — Операция `Reviews::BuildSession`

**Файл:** `app/operations/reviews/build_session.rb`

- Выборка due-карточек с eager loading
- Сортировка по due ASC, лимит

**Зависимости:** шаг 1.4 (scope `due_for_review`)
**Проверка:** operation spec

### Шаг 1.7 — Тесты Slice 1

**Файлы:**
- `spec/models/review_log_spec.rb` — валидации, compute_accuracy, classify_recall, classify_speed, compute_rating
- `spec/models/card_spec.rb` — расширить: schedule!, master!, due_for_review
- `spec/operations/reviews/record_answer_spec.rb` — full pipeline, near_miss, backspace/attempts не влияют
- `spec/operations/reviews/build_session_spec.rb` — due-карточки, mastered исключены, пустой результат

**Зависимости:** шаги 1.3–1.6
**Проверка:** `bundle exec rspec` (все зелёные) + `bundle exec rubocop`

### Порядок выполнения Slice 1

```
1.1 create_review_logs ─┐
1.2 add_mastered_at ─────┤ (параллельно)
                         ▼
                    1.3 ReviewLog model
                    1.4 Card расширение
                         │
                    ┌────┴────┐
                    ▼         ▼
              1.5 RecordAnswer  1.6 BuildSession (параллельно)
                    └────┬────┘
                         ▼
                    1.7 Тесты + rubocop
```

---

## Slice 2: Review Session UI

### Шаг 2.1 — Routes

**Файл:** `config/routes.rb` (редактирование)

Добавить:
```ruby
resource :review, only: [:show, :create], controller: "review_sessions"
resources :cards, only: [] do
  member do
    post :master
  end
end
```

**Зависимости:** нет
**Проверка:** `bin/rails routes | grep review`

### Шаг 2.2 — `ReviewSessionsController`

**Файл:** `app/controllers/review_sessions_controller.rb`

- `before_action :require_login`
- `show` — BuildSession, первая карточка
- `create` — find card, RecordAnswer, Turbo Stream с следующей карточкой
- Private helpers: `answer_correct?`, `positive_int`

**Зависимости:** шаг 2.1

### Шаг 2.3 — `CardsController`

**Файл:** `app/controllers/cards_controller.rb`

- `before_action :require_login`
- `master` — find card, master!, Turbo Stream с следующей карточкой
- Рендерит `review_sessions/create` (тот же turbo stream шаблон)

**Зависимости:** шаг 2.1

### Шаг 2.4 — Views

**Файлы:**
- `app/views/review_sessions/show.html.erb` — страница с turbo_frame_tag
- `app/views/review_sessions/create.turbo_stream.erb` — turbo_stream.replace
- `app/views/review_sessions/_card_form.html.erb` — cloze-карточка, форма, hidden fields, ghost text, кнопка master
- `app/views/review_sessions/_empty_state.html.erb` — "все повторены"

**Зависимости:** шаги 2.2, 2.3

### Шаг 2.5 — Stimulus controller

**Файл:** `app/javascript/controllers/review_controller.js`

- Targets: input, answerText, elapsed, attempts, backspaces, ghost
- Values: answer (String), audioUrl (String)
- connect: таймер, фокус, preload audio, adaptive input
- onInput: побуквенный фидбек (зелёный/красный border)
- trackKey: backspace count
- submit: фиксация первого ответа, retry или audio + submit
- resetUIForRetry: ghost text, amber border
- finalSubmit: elapsed_ms, attempts, backspaces → requestSubmit
- preloadAudio / playAudio: Web Audio API
- resizeInput: canvas measureText

**Зависимости:** нет (но интегрируется с views)

### Шаг 2.6 — i18n

**Файлы:** `config/locales/ru.yml`, `config/locales/en.yml`

Добавить ключи `reviews.*` по спеке.

**Зависимости:** нет

### Шаг 2.7 — Навигация

**Файл:** `app/views/dashboard/index.html.erb` (редактирование)

Добавить ссылку на `/review`.

**Зависимости:** шаг 2.1 (route должен существовать)

### Шаг 2.8 — Тесты Slice 2

**Файлы:**
- `spec/requests/review_sessions_spec.rb` — GET/POST /review, auth, turbo stream, чужая карточка
- `spec/requests/cards_spec.rb` — POST /cards/:id/master, auth, чужая карточка

**Зависимости:** шаги 2.2–2.7
**Проверка:** `bundle exec rspec` + `bundle exec rubocop`

### Порядок выполнения Slice 2

```
2.1 Routes ──────────┐
2.5 Stimulus ────────┤
2.6 i18n ────────────┤ (параллельно)
                     ▼
               2.2 ReviewSessionsController
               2.3 CardsController
               2.4 Views
               2.7 Навигация (dashboard link)
                     │
                     ▼
               2.8 Тесты + rubocop
```

---

## Чеклист перед реализацией

- [ ] Верифицировать API fsrs gem: `Fsrs::Scheduler.new.repeat(card, time)` — формат ключей результата (integer vs Fsrs::Rating)
- [ ] Верифицировать `DidYouMean::Levenshtein.distance` доступен в runtime
- [ ] Проверить, что `card.sentence.audio_id` корректно резолвится через цепочку делегаций

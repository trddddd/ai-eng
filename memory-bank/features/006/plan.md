# Plan: Персональная стартовая колода после регистрации

**Spec:** [memory-bank/features/006/spec.md](spec.md)
**Issue:** trddddd/ai-eng#10

**Оркестрация:** один последовательный агент
**Файлы:** 6 new + 4 modified = 10

---

## Steps

### Step 1: Миграция `cards`

- **Action:** `create_table :cards, id: false` с UUID v7 PK, но `user_id: bigint` (legacy `users` PK). Три индекса, два FK.
- **Files:** `db/migrate/…_create_cards.rb` (NEW)
- **Depends on:** —
- **Grounding:** `users` — `bigint` PK (schema.rb:79), остальные таблицы — `id: :uuid, default: -> { "uuidv7()" }`. Генератор по умолчанию создаёт UUID-ссылки (`config/application.rb:52`), поэтому `t.references :user` требует явный `type: :bigint`.

```ruby
class CreateCards < ActiveRecord::Migration[8.1]
  def change
    create_table :cards, id: false do |t|
      t.column :id, :uuid, primary_key: true, default: -> { "uuidv7()" }
      t.references :user, type: :bigint, null: false,
                          foreign_key: { on_delete: :cascade }, index: false
      t.references :sentence_occurrence, type: :uuid, null: false,
                                         foreign_key: { on_delete: :restrict }, index: false
      t.datetime :due, null: false
      t.float :stability, null: false, default: 0.0
      t.float :difficulty, null: false, default: 0.0
      t.integer :elapsed_days, null: false, default: 0
      t.integer :scheduled_days, null: false, default: 0
      t.integer :reps, null: false, default: 0
      t.integer :lapses, null: false, default: 0
      t.integer :state, null: false, default: 0
      t.datetime :last_review
      t.timestamps null: false
    end

    add_index :cards, %i[user_id sentence_occurrence_id], unique: true
    add_index :cards, %i[user_id due]
    add_index :cards, %i[user_id state]
  end
end
```

### Step 2: Модель `Card`

- **Action:** `app/models/card.rb` — ассоциации, константы состояний, валидации, `to_fsrs_card`, `apply_fsrs_card!`
- **Files:** `app/models/card.rb` (NEW)
- **Depends on:** Step 1
- **Grounding:** `Fsrs::Card` имеет ровно те атрибуты, что в спеке. `SentenceOccurrence` имеет `form`, `cloze_text`, `belongs_to :lexeme/:sentence` — delegate корректен.

### Step 3: Ассоциации на `User` и `SentenceOccurrence`

- **Action:** Добавить `has_many :cards` с соответствующими `dependent:`
- **Files:** `app/models/user.rb` (MODIFIED), `app/models/sentence_occurrence.rb` (MODIFIED)
- **Depends on:** Step 2
- **Grounding:** Оба файла сейчас без `has_many`. `dependent: :destroy` / `:restrict_with_exception` совпадает с FK constraints в миграции.

### Step 4: Операция `Cards::BuildStarterDeck`

- **Action:** `app/operations/cards/build_starter_deck.rb` — запрос A1-лексем с ru-переводами, `DISTINCT ON (lexeme_id)`, `insert_all` с `unique_by`
- **Files:** `app/operations/cards/build_starter_deck.rb` (NEW)
- **Depends on:** Steps 1–3
- **Grounding:**
  - Паттерн — как `Sentences::ImportQuizword`, но с аргументом. Структура файла:
    ```ruby
    module Cards
      class BuildStarterDeck
        def self.call(user) = new(user).call

        def initialize(user)
          @user = user
        end

        def call
          # ...
        end
      end
    end
    ```
  - Директория `app/operations/cards/` не существует — создать
  - `insert_all` должен явно включать `created_at`/`updated_at` (как в `ImportNgslCoreLexemes`)
  - `DISTINCT ON (lexeme_id)` + `ORDER BY lexeme_id, id` + `LIMIT 50` — PostgreSQL применяет `DISTINCT ON` до `LIMIT`, корректно

### Step 5: Интеграция в `RegistrationsController#create`

- **Action:** Вызов `BuildStarterDeck` после `@user.save`, обёрнутый в `rescue StandardError`
- **Files:** `app/controllers/registrations_controller.rb` (MODIFIED)
- **Depends on:** Step 4
- **Grounding:** Текущий контроллер (строки 7–14) — чистая if/else структура, вставка между `save` и `session[:user_id]`.

### Step 6: Фабрика `Card`

- **Action:** `spec/factories/cards.rb` — ассоциация user + sentence_occurrence, due = Time.current, FSRS defaults
- **Files:** `spec/factories/cards.rb` (NEW)
- **Depends on:** Step 2

### Step 7: Спеки модели `Card`

- **Action:** Валидации, uniqueness, `to_fsrs_card` round-trip, `apply_fsrs_card!` persistence
- **Files:** `spec/models/card_spec.rb` (NEW)
- **Depends on:** Steps 1, 2, 6
- **Note:** Использовать `Timecop.freeze` для тестов, проверяющих `due` (требование `.claude/rules/rspec.md`)

### Step 8: Спеки `BuildStarterDeck`

- **Action:** Создаёт ≤50 карточек, 0 при пустом каталоге, идемпотентность, одна карточка на лексему
- **Files:** `spec/operations/cards/build_starter_deck_spec.rb` (NEW)
- **Depends on:** Steps 4, 6
- **Note:** Использовать `Timecop.freeze` для проверки `due` на созданных карточках

### Step 9: Обновление спеков регистрации

- **Action:** POST /register создаёт карточки; регистрация успешна даже при ошибке BuildStarterDeck
- **Files:** `spec/requests/registrations_spec.rb` (MODIFIED)
- **Depends on:** Steps 5, 8

### Step 10: Rubocop + RSpec

- **Action:** `bundle exec rubocop` + `bundle exec rspec` — зелёный прогон, фикс нарушений
- **Depends on:** All

---

## Risk areas

| # | Риск | Митигация |
|---|------|-----------|
| 1 | `t.references :user` создаст UUID вместо bigint | Явный `type: :bigint` |
| 2 | `insert_all` не ставит `created_at/updated_at` | Включить в row hashes явно |
| 3 | `DISTINCT ON` + `LIMIT` — порядок применения | PostgreSQL применяет `DISTINCT ON` до `LIMIT` — корректно |
| 4 | `insert_all` может не задействовать DB default для `id` | UUID v7 default на уровне БД сработает, если `id` не в hash |

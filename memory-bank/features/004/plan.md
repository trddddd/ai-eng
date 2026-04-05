# Plan: Sentence Domain & Quizword Import

**Spec:** `memory-bank/features/004/spec.md`
**Branch:** `feat/sentence-domain-and-import`

---

## Orchestration

Один агент, линейная последовательность. Шаги 1–3 — migrations/models/factories (не зависят от операции). Шаги 4–5 — операция и rake task (зависят от моделей). Шаг 6 — тесты (зависят от всего).

---

## Steps

### Step 1 — Migrations (3 файла, одна таблица каждый)

Паттерн: `id: false`, `t.column :id, :uuid, primary_key: true, default: -> { "uuidv7()" }`, FK через `t.references` с `type: :uuid`.

**`db/migrate/20260404000100_create_sentences.rb`**
- `create_table :sentences, id: false`
- колонки: `id uuid PK uuidv7`, `language_id uuid FK NOT NULL`, `text text NOT NULL`, `audio_id integer NULL`, `source string NOT NULL`
- `timestamps null: false`
- `add_index :sentences, [:language_id, :text], unique: true` (плюс автоиндекс от `t.references`)

**`db/migrate/20260404000200_create_sentence_translations.rb`**
- `create_table :sentence_translations, id: false`
- `t.references :sentence, ..., foreign_key: { on_delete: :restrict }, index: false`
- `t.references :target_language, ..., foreign_key: { to_table: :languages }, index: true`
- `add_index :sentence_translations, [:sentence_id, :target_language_id], unique: true`

**`db/migrate/20260404000300_create_sentence_occurrences.rb`**
- `create_table :sentence_occurrences, id: false`
- `t.references :sentence, ..., foreign_key: { on_delete: :restrict }, index: false`
- `t.references :lexeme, ..., foreign_key: { on_delete: :restrict }, index: true`
- `form string NOT NULL`, `hint string NULL`
- `add_index :sentence_occurrences, [:sentence_id, :lexeme_id], unique: true`

### Step 2 — Models (3 файла)

**`app/models/sentence.rb`**
```ruby
class Sentence < ApplicationRecord
  belongs_to :language
  has_many :sentence_translations, dependent: :restrict_with_exception
  has_many :sentence_occurrences, dependent: :restrict_with_exception

  validates :text, presence: true
  validates :source, presence: true
  validates :text, uniqueness: { scope: :language_id }
  validate :text_has_no_cloze_placeholder

  private

  def text_has_no_cloze_placeholder
    errors.add(:text, "must not contain ____") if text&.include?("____")
  end
end
```

**`app/models/sentence_translation.rb`**
```ruby
class SentenceTranslation < ApplicationRecord
  belongs_to :sentence
  belongs_to :target_language, class_name: "Language"

  validates :text, presence: true
  validates :sentence_id, uniqueness: { scope: :target_language_id }
end
```

**`app/models/sentence_occurrence.rb`**
```ruby
class SentenceOccurrence < ApplicationRecord
  belongs_to :sentence
  belongs_to :lexeme

  validates :form, presence: true
  validates :sentence_id, uniqueness: { scope: :lexeme_id }

  def cloze_text
    sentence.text.sub(form, "____")
  end
end
```
`String#sub` заменяет первое вхождение — это то, что нужно по спеке.

### Step 3 — Factories (3 файла)

**`spec/factories/sentences.rb`**, **`spec/factories/sentence_translations.rb`**, **`spec/factories/sentence_occurrences.rb`** — стандартный паттерн FactoryBot.

### Step 4 — Operation `Sentences::ImportQuizword`

Файл: `app/operations/sentences/import_quizword.rb`
Namespace: `Sentences` (новая директория `app/operations/sentences/`).
**Не наследовать** от `ContentBootstrap::BaseOperation`.

Ключевые особенности реализации:

1. **`end_page` autodiscovery** — если `END_PAGE` не задан в env, операция сама определяет последнюю непустую страницу через бинарный поиск (сначала удваивает номер страницы до первой пустой, затем бинарный поиск между `last_non_empty` и `page-1`).

2. **`find_lexeme`** — сортировка `min_by` с туплом `[-hw.length, idx, hw.downcase, id.to_s]`: длиннее → раньше в тексте → лексикографически → по id.

3. **`form`** сохраняется как точная подстрока из `text_eng` (не `headword`): `text_eng[text_eng.downcase.index(hw.downcase), hw.length]`.

4. **`insert_batch`** — одна транзакция на страницу:
   - Считывает уже существующие тексты для подсчёта `imported` (только новые)
   - `Sentence.insert_all(..., unique_by: :index_sentences_on_language_id_and_text)`
   - Перечитывает `text → id` map, строит строки translations/occurrences
   - `SentenceTranslation.insert_all(..., unique_by: %i[sentence_id target_language_id])`
   - `SentenceOccurrence.insert_all(..., unique_by: :index_sentence_occurrences_on_sentence_id_and_lexeme_id)`
   - Возвращает количество новых (не существовавших до вставки) sentences

5. **Progress output** — после каждой обработанной страницы выводит `Progress: X/Y pages. Current page: N. Imported: Z. Failed URLs: W. Skipped rows: S`.

6. **Summary** — по завершении: `Quizword done. Imported: X. Failed URLs: Y. Skipped rows: Z`.

7. **Retry** — 3 попытки с exponential backoff (1s/2s/4s) для `RETRYABLE` ошибок.

8. **Мьютекс** — только для счётчиков и `failed_urls`, не для парсинга/HTTP.

### Step 5 — Rake task (в `content_bootstrap.rake`)

Задача добавлена в существующий `lib/tasks/content_bootstrap.rake`:
- новый task `content_bootstrap:import_quizword` вызывает `Sentences::ImportQuizword.call`
- `content_bootstrap:import_all` расширен зависимостью `import_quizword`
- описание `import_all` обновлено: "Oxford → NGSL Core → NGSL Spoken → Poliglot → Quizword"

Zeitwerk: `app/operations/sentences/` находится внутри `app/operations/`, который уже в autoload путях Rails. `Sentences::ImportQuizword` загрузится автоматически.

### Step 6 — Schema refresh

- выполнить миграции и закоммитить обновлённый `db/schema.rb`
- проверить появление: `sentences`, `sentence_translations`, `sentence_occurrences` с нужными индексами

### Step 7 — Tests

**Model specs** (3 файла):
- `spec/models/sentence_spec.rb`
- `spec/models/sentence_translation_spec.rb`
- `spec/models/sentence_occurrence_spec.rb`

**Operation spec** (`spec/operations/sentences/import_quizword_spec.rb`):
- Fixture HTML: `spec/fixtures/files/quizword_page.html` — 3 блока (2 валидных, 1 пустой)
- HTTP мокинг через `allow(Net::HTTP).to receive(:get_response)` (WebMock не используется)
- Покрывает: happy path, blank skip, no-match skip, longest-match, tie-break, idempotency, HTTP 429, ReadTimeout retry, empty lexemes abort, invalid env abort, END_PAGE autodiscovery

---

## File Checklist

| Файл | Действие |
|------|----------|
| `db/migrate/20260404000100_create_sentences.rb` | новый |
| `db/migrate/20260404000200_create_sentence_translations.rb` | новый |
| `db/migrate/20260404000300_create_sentence_occurrences.rb` | новый |
| `app/models/sentence.rb` | новый |
| `app/models/sentence_translation.rb` | новый |
| `app/models/sentence_occurrence.rb` | новый |
| `app/operations/sentences/import_quizword.rb` | новый (новая директория) |
| `lib/tasks/content_bootstrap.rake` | изменён: добавлен `import_quizword` task и в `import_all` |
| `spec/factories/sentences.rb` | новый |
| `spec/factories/sentence_translations.rb` | новый |
| `spec/factories/sentence_occurrences.rb` | новый |
| `spec/fixtures/files/quizword_page.html` | новый |
| `spec/models/sentence_spec.rb` | новый |
| `spec/models/sentence_translation_spec.rb` | новый |
| `spec/models/sentence_occurrence_spec.rb` | новый |
| `spec/operations/sentences/import_quizword_spec.rb` | новый (новая директория) |
| `db/schema.rb` | обновлён после миграций |
| `bin/setup` | изменён: убран `db:seed` (вынесен или удалён) |

**Не затрагиваются:** существующие миграции, `Lexeme`, `Language`, `LexemeGloss`.

---

_Plan v2.0 | 2026-04-05_

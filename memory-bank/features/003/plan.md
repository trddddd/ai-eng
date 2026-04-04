# Plan: Test Coverage & CI Setup (Feature 003)

**Spec:** [spec.md](spec.md) | **Brief:** trddddd/ai-eng#4
**Branch:** `feat/test-coverage-and-ci`

---

## Grounding-находки

| Пункт | Факт | Влияние на план |
|-------|------|----------------|
| SimpleCov | отсутствует в Gemfile | добавить в `group :test` |
| `spec/spec_helper.rb` | существует, первая строка — комментарий | вставить SimpleCov до строки 1 |
| `spec/factories/` | существует, есть `users.rb` | добавить новые файлы рядом |
| `spec/models/` | существует, есть `user_spec.rb` | создать три новых файла |
| Модели | `Language`, `Lexeme`, `LexemeGloss` имеют `validates_uniqueness_of` | uniqueness-тесты — model-level (`not_to be_valid`) |
| `.github/workflows/` | существует, только `ci.yml` | создать `rails.yml` рядом, `ci.yml` не трогать |
| `.gitignore` | `coverage/` отсутствует | добавить |
| `README.md` | badge отсутствует, первая строка `# Lingvize` | вставить после строки 1 |
| `.ruby-version` | содержит `system` | **риск**: `ruby/setup-ruby@v1` не поймёт `system`; нужно выставить реальную версию |
| `mise.toml` | уже существует, `ruby = "4.0.2"` — источник истины | — |

---

## Паттерн оркестрации

Один агент, последовательно. Шаги 1–4 независимы между собой, но их удобнее делать последовательно в одном проходе чтобы не разбивать контекст.

---

## Шаги реализации

### Шаг 0 — Синхронизировать .ruby-version с mise.toml

**Проблема:** `.ruby-version` содержал `system` — `ruby/setup-ruby@v1` в GitHub Actions не умеет его читать.

**Источник истины:** `mise.toml` (уже существует в корне, `ruby = "4.0.2"`).

**Действие:** обновить `.ruby-version` → `4.0.2`. **Выполнено.**

**Результат:** GitHub Actions читает `.ruby-version` через `ruby/setup-ruby@v1` без хардкода версии в workflow.

**Зависимости:** блокирует Шаг 6 (workflow).

---

### Шаг 1 — Gemfile: добавить simplecov

**Файл:** `Gemfile`
**Действие:** в конец блока `group :test` добавить:
```ruby
gem "simplecov", require: false
```
Затем: `bundle install`

**Зависимости:** ничего не блокирует.

---

### Шаг 2 — .gitignore: добавить coverage/

**Файл:** `.gitignore`
**Действие:** добавить строку `/coverage/` в конец файла.

**Зависимости:** ничего не блокирует.

---

### Шаг 3 — SimpleCov в spec_helper.rb

**Файл:** `spec/spec_helper.rb`
**Действие:** вставить в самое начало файла (перед строкой 1, до любых `require`):

```ruby
require "simplecov"
SimpleCov.start "rails" do
  minimum_coverage 80
  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/db/"
  add_filter "/bin/"
end
```

Остальное содержимое файла не менять.

**Зависимости:** Шаг 1 (simplecov должен быть установлен).

---

### Шаг 4 — Factories

**Файлы:** создать три файла в `spec/factories/`:

`spec/factories/languages.rb`:
```ruby
FactoryBot.define do
  factory :language do
    sequence(:code) { |n| "lang#{n}" }
    sequence(:name) { |n| "Language #{n}" }
  end
end
```

`spec/factories/lexemes.rb`:
```ruby
FactoryBot.define do
  factory :lexeme do
    association :language
    sequence(:headword) { |n| "word#{n}" }
    pos { nil }
    cefr_level { nil }
  end
end
```

`spec/factories/lexeme_glosses.rb`:
```ruby
FactoryBot.define do
  factory :lexeme_gloss do
    association :lexeme
    association :target_language, factory: :language
    sequence(:gloss) { |n| "gloss #{n}" }
  end
end
```

**Зависимости:** ничего не блокирует.

---

### Шаг 5 — Model specs

**Файлы:** создать три файла в `spec/models/`.

#### `spec/models/language_spec.rb`

Покрыть:
- factory валидна (`.to be_valid`)
- `code: nil` → `not be_valid`
- `name: nil` → `not be_valid`
- дубликат `code` → `not be_valid` (model-level `validates :code, uniqueness: true`)

#### `spec/models/lexeme_spec.rb`

Покрыть:
- factory валидна
- `headword: nil` → `not be_valid`
- `language: nil` / `language_id: nil` → `not be_valid`
- дубликат `(language_id, headword)` → `not be_valid` (`validates :headword, uniqueness: { scope: :language_id }`)

#### `spec/models/lexeme_gloss_spec.rb`

Покрыть:
- factory валидна
- `gloss: nil` → `not be_valid`
- `lexeme: nil` → `not be_valid`
- `target_language: nil` → `not be_valid`
- дубликат `(lexeme_id, target_language_id, gloss)` → `not be_valid` (`validates :gloss, uniqueness: { scope: %i[lexeme_id target_language_id] }`)

**Зависимости:** Шаг 4 (factories).

---

### Шаг 6 — GitHub Actions workflow

**Файл:** `.github/workflows/rails.yml`

**Ключевые решения:**
- `runs-on: ubuntu-latest`
- Ruby: читается из `.ruby-version` автоматически (`ruby/setup-ruby@v1` без явного `ruby-version:` — action ищет `.ruby-version` в корне по умолчанию). После Шага 0 файл содержит `4.0.2`.
- `bundler-cache: true`
- PostgreSQL service: `postgres:18-alpine`, credentials `lingvize/lingvize`, db `lingvize_test`
- Concurrency: `ci-rails-${{ github.ref }}`, `cancel-in-progress: true`
- Триггеры: `pull_request`, `push` → `main`, `workflow_dispatch`
- Версии actions: `@v4`, `@v1` (не pinned SHA)

**Env vars для job `test`** (все обязательны — читаются из `database.yml`):

| Переменная | Значение |
|---|---|
| `RAILS_ENV` | `test` |
| `DB_HOST` | `localhost` |
| `DB_PORT` | `5432` (не 5433 — внутри Actions стандартный порт) |
| `DB_USER` | `lingvize` |
| `DB_PASSWORD` | `lingvize` |
| `SECRET_KEY_BASE` | `test-ci-secret-not-used-in-application` |

**Job `test` steps:**
1. `actions/checkout@v4`
2. `ruby/setup-ruby@v1` (bundler-cache: true)
3. `bin/rails db:test:prepare`
4. `bundle exec rspec`

**Job `lint` steps:**
1. `actions/checkout@v4`
2. `ruby/setup-ruby@v1` (bundler-cache: true)
3. `bundle exec rubocop --parallel`

`lint` и `test` параллельны (нет `needs:`).

**Зависимости:** Шаг 0 (выполнен — `.ruby-version` содержит `4.0.2`).

---

### Шаг 7 — CI badge в README.md

**Файл:** `README.md`
**Действие:** вставить сразу после первой строки `# Lingvize`:

```markdown
[![CI](https://github.com/trddddd/ai-eng/actions/workflows/rails.yml/badge.svg)](https://github.com/trddddd/ai-eng/actions/workflows/rails.yml)
```

Больше ничего в README не менять.

**Зависимости:** ничего не блокирует.

---

### Шаг 8 — Локальная проверка

1. `bundle exec rspec` — должен пройти, stdout содержит `/Coverage report generated for .+ \(\d+\.\d+%\)/`
2. `bundle exec rubocop` — без новых нарушений
3. Убедиться что `coverage/index.html` создан

### Шаг 9 — PR и проверка CI в GitHub

1. Запушить ветку `feat/test-coverage-and-ci`.
2. Создать PR через GitHub MCP (`gh pr create`).
3. Дождаться завершения CI-джобов через GitHub MCP (`gh pr checks <PR>`).
4. Убедиться что оба джоба — `test` и `lint` — имеют статус `success`.

**Зависимости:** все предыдущие шаги.

---

## Порядок выполнения

```
Шаг 0 (.ruby-version ← выполнен)
  └─► Шаг 6 (workflow)       ─┐
Шаг 1 (Gemfile + bundle)      │
  └─► Шаг 3 (spec_helper)     │
Шаг 2 (.gitignore)            ├─► Шаг 8 (локальная проверка)
Шаг 4 (factories)             │         └─► Шаг 9 (PR + CI)
  └─► Шаг 5 (model specs)    ─┘
Шаг 7 (README badge)         ─┘
```

---

## Файлы, затрагиваемые в этой задаче

| Файл | Действие |
|------|---------|
| `.ruby-version` | заменить `system` → `4.0.2` (из `mise.toml`) |
| `Gemfile` | добавить строку |
| `Gemfile.lock` | обновится автоматически |
| `.gitignore` | добавить строку |
| `spec/spec_helper.rb` | вставить в начало |
| `spec/factories/languages.rb` | создать |
| `spec/factories/lexemes.rb` | создать |
| `spec/factories/lexeme_glosses.rb` | создать |
| `spec/models/language_spec.rb` | создать |
| `spec/models/lexeme_spec.rb` | создать |
| `spec/models/lexeme_gloss_spec.rb` | создать |
| `.github/workflows/rails.yml` | создать |
| `README.md` | вставить badge |

**Не трогаем:** `ci.yml`, существующие миграции, модели, операции, `spec/operations/`, `spec/models/user_spec.rb`.

---

_Plan v1.3 | 2026-04-04_

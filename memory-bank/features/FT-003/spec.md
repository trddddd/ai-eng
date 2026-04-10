# Spec: Test Coverage & CI Setup

**Brief:** trddddd/ai-eng#4
**Branch:** `feat/test-coverage-and-ci`

---

## Цель

Выстроить safety net перед добавлением новой функциональности: автоматический прогон тестов и линтера в CI на каждый PR и push в main, покрытие кода ≥ 80%.

---

## Scope

**Входит:**
- Gem `simplecov` (coverage) — добавить в `group :test`
- GitHub Actions workflow `.github/workflows/rails.yml` — отдельный от `ci.yml`
- Model specs: `Language`, `Lexeme`, `LexemeGloss`
- Factories: `language`, `lexeme`, `lexeme_gloss`
- Настройка SimpleCov с порогом 80% в `spec/spec_helper.rb`
- Rubocop job в `rails.yml` (переиспользует уже установленные гемы)
- CI status badge в `README.md`

**НЕ входит:**
- System/request/e2e тесты
- Coverage-гейты на уровне отдельных файлов
- Внешние coverage-сервисы (Codecov, Coveralls и пр.)
- Настройка деплоя
- Нагрузочное тестирование

---

## Status Badge

Добавить в `README.md` сразу после заголовка `# Lingvize` (первая строка файла):

```markdown
[![CI](https://github.com/trddddd/ai-eng/actions/workflows/rails.yml/badge.svg)](https://github.com/trddddd/ai-eng/actions/workflows/rails.yml)
```

Больше ничего в README не изменять.

---

## Новые зависимости

| Gem | Группа | Назначение |
|-----|--------|-----------|
| `simplecov` | `:test` | измерение и enforcement покрытия |

Никаких других гемов не добавляется.

---

## Конфигурация SimpleCov

Вставить в начало существующего `spec/spec_helper.rb` (перед строкой 1, до любых `require`). Остальное содержимое файла не изменять.

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

- `SimpleCov.start "rails"` использует стандартный Rails-профиль (исключает `vendor/`, `test/`, `spec/` автоматически)
- `minimum_coverage 80` — если покрытие падает ниже 80%, процесс завершается с exit code ≠ 0 (RSpec suite считается упавшей)
- HTML-отчёт генерируется в `coverage/` (добавить в `.gitignore`)

---

## GitHub Actions Workflow

Файл: `.github/workflows/rails.yml`

**Триггеры:** `pull_request`, `push` на `main`, `workflow_dispatch`

**Версии Actions:** использовать теговые версии (`@v4`, `@v1`) — не pinned SHA. Паттерн pinned SHA применяется только в `ci.yml` (bootstrap-воркфлоу) и на `rails.yml` не распространяется.

**Concurrency:** `ci-rails-${{ github.ref }}`, cancel-in-progress: true

### Jobs

#### `test`

| Параметр | Значение |
|----------|---------|
| `runs-on` | `ubuntu-latest` |
| Ruby | из `.ruby-version` (через `ruby/setup-ruby@v1`, bundler-cache: true) |
| PostgreSQL service | `postgres:18-alpine`, credentials: `POSTGRES_USER=lingvize`, `POSTGRES_PASSWORD=lingvize`, `POSTGRES_DB=lingvize_test` |
| Healthcheck options | `--health-cmd 'pg_isready -U lingvize' --health-interval 10s --health-timeout 5s --health-retries 5` |
| `DB_HOST` | `localhost` |
| `DB_PORT` | `5432` (внутри Actions сервис доступен на стандартном порту, не 5433) |
| `DB_USER` | `lingvize` |
| `DB_PASSWORD` | `lingvize` |
| `RAILS_ENV` | `test` |
| `SECRET_KEY_BASE` | `test-ci-secret-not-used-in-application` (credentials в test-окружении не используются; значение произвольно) |

**Steps:**
1. `actions/checkout@v4`
2. `ruby/setup-ruby@v1` с `bundler-cache: true`
3. `bin/rails db:test:prepare`
4. `bundle exec rspec`

#### `lint`

| Параметр | Значение |
|----------|---------|
| `runs-on` | `ubuntu-latest` |
| Ruby | из `.ruby-version`, bundler-cache: true |

**Steps:**
1. `actions/checkout@v4`
2. `ruby/setup-ruby@v1` с `bundler-cache: true`
3. `bundle exec rubocop --parallel`

`lint` и `test` запускаются параллельно (не зависят друг от друга).

---

## Model Specs

Располагаются в `spec/models/`. Для всех трёх моделей покрываются:
- базовая валидность через factory (`.to be_valid`)
- обязательные поля: `NOT NULL` → невалидность при `nil` (model-level: `expect(record).not_to be_valid`)
- уникальные индексы — модели имеют `validates_uniqueness_of`, поэтому assertion на model-level: `expect(record).not_to be_valid`

### `Language`

```
spec/models/language_spec.rb
```
- `code` обязателен
- `name` обязателен
- `code` уникален (case-sensitive, по значению из БД)

### `Lexeme`

```
spec/models/lexeme_spec.rb
```
- `headword` обязателен
- `language` обязателен (presence через association)
- `(language_id, headword)` уникален

### `LexemeGloss`

```
spec/models/lexeme_gloss_spec.rb
```
- `gloss` обязателен
- `lexeme` обязателен
- `target_language` обязателен
- `(lexeme_id, target_language_id, gloss)` уникален

---

## Factories

Добавить в `spec/factories/`:

```ruby
# spec/factories/languages.rb
FactoryBot.define do
  factory :language do
    sequence(:code) { |n| "lang#{n}" }
    sequence(:name) { |n| "Language #{n}" }
  end
end

# spec/factories/lexemes.rb
FactoryBot.define do
  factory :lexeme do
    association :language
    sequence(:headword) { |n| "word#{n}" }
    pos { nil }
    cefr_level { nil }
  end
end

# spec/factories/lexeme_glosses.rb
FactoryBot.define do
  factory :lexeme_gloss do
    association :lexeme
    association :target_language, factory: :language
    sequence(:gloss) { |n| "gloss #{n}" }
  end
end
```

---

## Инварианты

- SimpleCov инициализируется **до** `require "rails_helper"` или любого app-кода — иначе покрытие считается неверно
- Порог 80% применяется к общему покрытию (`minimum_coverage`), не к отдельным файлам
- В CI порт БД — `5432` (не `5433`), так как `DB_PORT` задаётся через env; `5433` только для локальной разработки через docker compose
- `coverage/` не коммитится в git (добавить в `.gitignore`)
- Существующие тесты (`spec/operations/`, `spec/models/user_spec.rb`) не изменяются и не удаляются

---

## Сценарии ошибок

| Ситуация | Поведение |
|----------|----------|
| Покрытие ниже 80% | SimpleCov завершает процесс с exit code ≠ 0; CI job `test` падает |
| БД недоступна в CI | `db:test:prepare` упадёт с ошибкой подключения; явный healthcheck на postgres service предотвращает гонку |
| Rubocop-нарушение | job `lint` падает; `test` продолжается независимо |

---

## Acceptance Criteria

- [ ] `bundle exec rspec` проходит локально без ошибок
- [ ] После `bundle exec rspec` stdout содержит строку, соответствующую `/Coverage report generated for .+ \(\d+\.\d+%\)/`
- [ ] Файл `coverage/index.html` создаётся после прогона
- [ ] При покрытии ниже 80% `rspec` завершается с ненулевым кодом — проверяется вручную: временно закомментировать тело любого метода, прогнать `rspec`, убедиться в exit code ≠ 0
- [ ] Файл `.github/workflows/rails.yml` содержит jobs `test` и `lint` с триггером `pull_request` (статическая проверка содержимого файла)
- [ ] Создан PR в GitHub на ветке `feat/test-coverage-and-ci`; оба CI-джоба (`test`, `lint`) прошли зелёным — проверяется через GitHub MCP (`gh pr checks` или API): все checks имеют статус `success`
- [ ] Job `test` использует postgres service и переменные окружения `DB_*`
- [ ] `bin/rails db:test:prepare` в CI не требует ручных действий
- [ ] Factories для `Language`, `Lexeme`, `LexemeGloss` работают (`build/create` без ошибок)
- [ ] Model specs для `Language`, `Lexeme`, `LexemeGloss` проходят
- [ ] `coverage/` добавлен в `.gitignore`
- [ ] `bundle exec rubocop` проходит без новых нарушений
- [ ] В `README.md` после заголовка `# Lingvize` присутствует CI badge со ссылкой на `rails.yml`

---

## Ограничения на реализацию

- Не добавлять гемы кроме `simplecov` в `:test`
- Не изменять существующие миграции, модели и операции. Все необходимые валидации в моделях уже есть — ничего добавлять не нужно.
- Не создавать `spec/support/` в рамках этой задачи. Если понадобится shared helper — согласовать отдельно.
- `rails.yml` — отдельный файл, `ci.yml` не трогать

---

_Spec v1.4 | 2026-04-04_

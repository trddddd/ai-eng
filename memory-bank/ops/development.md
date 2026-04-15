---
title: Development Environment
doc_kind: engineering
doc_function: canonical
purpose: "Локальная разработка Lingvize: setup, команды, DB, сервисы."
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Development Environment

## Setup

```bash
# Первичная настройка (включая DB dump restore если доступен)
bin/setup

# Альтернатива без dump (полная миграция + seed)
bin/setup --reset

# Direnv для env vars
direnv allow

# Docker services (PostgreSQL на порту 5433)
docker compose up -d
```

**Зависимости:**
- Ruby 4.x (управление через **mise**, конфиг `mise.toml`). `.ruby-version` должен совпадать с `mise.toml` — он используется `ruby/setup-ruby@v1` в GitHub Actions.
- PostgreSQL 18 (через Docker Compose, порт **5433** — 5432 может быть занят другим проектом)
- Redis (стандартный порт 6379)
- **direnv** (загрузка `.env` и `.env.local`). При запуске через mise: `direnv exec /path/to/project <команда>`
- Node.js (для Tailwind CSS v4 build)

## Daily Commands

```bash
# Приложение с вотчерами фронтенда
bin/dev

# Только веб-сервер
bin/rails server

# Тесты
bundle exec rspec

# Линтер
bundle exec rubocop

# Миграции
bin/rails db:migrate

# Консоль
bin/rails console
```

## Browser Testing

- Default URL: `http://localhost:3000`
- Порт можно переопределить через `PORT` в `.env`
- Первый пользователь создаётся через `/register`

## Database And Services

### PostgreSQL

- **Доступ:** только через Docker Compose, не напрямую
- **Порт:** 5433 (не стандартный 5432)
- **Прямой psql:** `docker compose exec postgres psql -U lingvize -d lingvize_development`
- **Миграции:** `bin/rails db:migrate` (не менять существующие задним числом)

### Cold Start (DB Dump)

- `bin/setup` проверяет наличие dump в `db/dump/`, восстанавливает если найден
- Создание dump: `bin/rails db:dump:create`
- Восстановление: `bin/rails db:dump:restore`
- Время: ~5 мин с dump vs ~30 мин без

### Redis

- Используется для cache/queue
- Default: `redis://localhost:6379`

## Verification Commands

Не все изменения требуют одинаковой верификации. Выбирай команду по типу change surface:

| Change type | Verify command | Notes |
| --- | --- | --- |
| Ruby code (models, operations, controllers) | `bundle exec rspec` + `bundle exec rubocop` | Полный прогон |
| CSS / view templates | `bin/rails assets:precompile` или визуальная проверка | rspec irrelevant, rubocop не парсит ERB |
| Migration | `bin/rails db:migrate` + `bundle exec rspec` | Миграция на тестовой БД |
| Config / routes | `bin/rails routes` + `bundle exec rspec` | Проверка что приложение поднимается |
| Документация (memory-bank) | Нет автоматической проверки | Визуальный review |

**Важно:** `bin/setup` — деструктивная операция (dump restore). Запускать только на чистом окружении. Правило эскалации — см. `autonomy-boundaries.md`.

## Known Pitfalls

- PostgreSQL порт **5433**, не 5432 — проверь `DATABASE_URL` или `config/database.yml`
- `db:drop`, `db:reset` — **никогда** без явного подтверждения, даже для test env
- Новые гемы — только с явного запроса
- Миграции — одна таблица/аспект за миграцию
- **FSRS gem:** опубликованный `fsrs` (0.9.0) несовместим с Rails 8. Используется GitHub-источник: `gem "fsrs", github: "open-spaced-repetition/rb-fsrs"`
- **RuboCop:** используется `plugins:` (не `require:`) для rubocop-rails и rubocop-rspec — это новый API
- **При изменении данных (импорт, матчинг):** проверить, не стал ли cold-start dump (FT-005) устаревшим. Стейл-данные в dump'е молча распространяют баги на новые окружения

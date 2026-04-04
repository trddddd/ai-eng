# Lingvize

[![CI](https://github.com/trddddd/ai-eng/actions/workflows/rails.yml/badge.svg)](https://github.com/trddddd/ai-eng/actions/workflows/rails.yml)

Веб-платформа для изучения иностранных языков в контексте предложений (карточки, интервальное повторение). Подробное описание — в [PROJECT.md](PROJECT.md).

## Стек

- **Ruby** 4.0.2, **Rails** 8.1
- **PostgreSQL** 16 (Docker), **Redis** 7 (Docker)
- **Tailwind CSS** v4, **Hotwire** (Turbo + Stimulus)
- **FSRS** ([open-spaced-repetition/rb-fsrs](https://github.com/open-spaced-repetition/rb-fsrs))
- **RSpec** + FactoryBot, **RuboCop** (rubocop-rails, rubocop-rspec)
- **i18n**: русский по умолчанию, переводы через `rails-i18n`

## Быстрый старт

```bash
# 1. Установить инструменты (Ruby, Node, direnv и др.)
mise install

# 2. Запустить PostgreSQL и Redis
docker compose up -d

# 3. Установить зависимости и подготовить БД
bin/setup

# 4. Запустить сервер разработки
bin/dev
```

Приложение доступно на `http://localhost:3000`.

> **Примечание:** PostgreSQL проброшен на порт **5433** (5432 может быть занят другим проектом).
> Переменные подключения к БД задаются в `.env`: `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD` (см. `config/database.yml`).

## Команды

| Команда | Описание |
|---------|----------|
| `bin/dev` | Сервер + Tailwind watcher |
| `bin/rails server` | Только веб-сервер |
| `bundle exec rspec` | Тесты |
| `bundle exec rubocop` | Линтер |
| `bin/rails db:migrate` | Миграции БД |
| `docker compose up -d` | Запустить PostgreSQL и Redis |
| `docker compose down` | Остановить контейнеры |

## Структура аутентификации

Вход только по email + паролю (`has_secure_password`). Маршруты:

- `GET /login` — форма входа
- `POST /login` — аутентификация
- `DELETE /logout` — выход
- `GET /register` — форма регистрации
- `POST /register` — создание аккаунта
- `GET /dashboard` — личный кабинет (требует авторизации)

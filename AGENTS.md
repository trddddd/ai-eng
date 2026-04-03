See PROJECT.md for project description.

## Stack

- **Runtime:** Ruby 4.x, Rails 8
- **Data:** PostgreSQL, Redis
- **UI:** Tailwind CSS, Hotwire (Turbo, Stimulus; при необходимости Turbo Native)
- **Повторения:** алгоритм [FSRS](https://expertium.github.io/Algorithm.html);
- **Прочее:** i18n; сервисы озвучки (в т.ч. нейросинтез); корпуса и интеграции примеров (Tatoeba, OPUS, Reverso и др.)

## Key commands

- `bin/setup` — первичная настройка окружения и зависимостей
- `bin/dev` — приложение с вотчерами фронтенда (если используется)
- `bin/rails server` — только веб-сервер
- `bundle exec rspec` — тесты
- `bin/rails db:migrate` — миграции БД
- `docker compose exec postgres psql -U lingvize -d lingvize_development` — прямой доступ к БД (всегда через docker compose, не напрямую)
- `bundle exec rubocop` — линтер; запускать после каждого значимого изменения кода

## Constraints

- Не менять существующие миграции задним числом; новые изменения схемы — только новыми миграциями.
- Каждая миграция создаёт или изменяет одну таблицу или один аспект схемы.
- Никогда не запускать `db:drop`, `db:reset`, `db:drop db:create` без явного подтверждения пользователя — даже для `RAILS_ENV=test`.
- Не подключать новые гемы и не добавлять интеграции без явного запроса.
- Первичный ключ используем всегда UUID v7
- Новые классы, модули, пути и именование файлов должны быть совместимы с Zeitwerk; если добавляется новая директория с autoloadable-кодом, это нужно явно учесть в загрузке Rails.
- Acceptance Criteria проверяются через `bin/setup --skip-server` на чистой БД, а не через ручные команды.

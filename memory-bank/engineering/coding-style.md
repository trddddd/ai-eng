---
title: Coding Style
doc_kind: engineering
doc_function: convention
purpose: Coding conventions Lingvize: Ruby/Rails, Tailwind, SQL. Читать при написании или ревью кода.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Coding Style

## General Rules

- Имена файлов, модулей и каталогов совместимы с Zeitwerk autoloading.
- Комментарии только для WHY или boundary conditions.
- Минимальная локальная сложность вместо преждевременных абстракций.
- Generated code и миграции — отдельные правила (см. SQL/Migrations).

## Tooling Contract

- **Formatter/Linter:** RuboCop (`bundle exec rubocop`). Запускать после каждого значимого изменения.
- **Pre-commit hooks:** не используются; агент прогоняет lint вручную.

## Backend (Ruby/Rails)

- **Naming:** snake_case для методов и переменных, CamelCase для классов/модулей, SCREAMING_SNAKE для констант.
- **Module layout:** Operations в `app/operations/Namespace::OperationName` (`.call()` entry point). Модели — валидации, ассоциации, scopes, делегирование.
- **Error handling:** не rescue без причины; позволяй ошибкам подниматься, если нет явного recovery.
- **UUID v7:** все первичные ключи.
- **Autoloading:** новые директории с кодом должны быть совместимы с Zeitwerk; при необходимости — добавить в autoload paths.

## Frontend (Tailwind + Hotwire)

- **Styling:** Tailwind utility classes. Design tokens определены в `DESIGN.md`.
- **Components:** ERB partials. Stimulus controllers для интерактивности.
- **Turbo:** Turbo Streams для partial updates. Не смешивать Turbo и manual JS DOM manipulation.
- **Icons:** Material Symbols Outlined (Google Fonts).

## SQL / Migrations

- Каждая миграция создаёт или изменяет одну таблицу или один аспект схемы.
- Не менять существующие миграции задним числом.
- Новые таблицы: UUID v7 primary key (`id: :uuid`).
- Batch operations: `insert_all` с unique constraints для идемпотентности.

## Change Discipline

- Не переписывай несвязанный код ради единообразия.
- При touch-up следуй локальному стилю файла.
- Не добавляй docstrings, комментарии или type annotations к коду, который не менялся.

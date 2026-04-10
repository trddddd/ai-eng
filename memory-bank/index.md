# Project Index

## О проекте

**Lingvize** — веб-платформа для изучения иностранных языков через интервальное повторение (FSRS) и cloze-карточки.
Пользователи: самостоятельные изучающие иностранные языки.
Стек: Ruby 4 / Rails 8.1, PostgreSQL, Redis, Hotwire, Tailwind CSS.
MVP: контент-пайплайн (Oxford/NGSL/Quizword), стартовая колода, сессия повторения, дизайн-система.
Вне MVP: мобильное приложение, social features, UGC-контент.
Архитектура: Layered Rails (Dementyev), Operations pattern, UUID v7.

## Быстрый старт

- `bin/setup` — первичная настройка окружения и зависимостей
- `bin/dev` — приложение с вотчерами фронтенда
- `bin/rails server` — только веб-сервер
- `bundle exec rspec` — тесты
- `bin/rails db:migrate` — миграции БД
- `bundle exec rubocop` — линтер; запускать после каждого значимого изменения кода

## Критические ограничения

- Не менять существующие миграции задним числом; новые изменения схемы — только новыми миграциями.
- Каждая миграция создаёт или изменяет одну таблицу или один аспект схемы.
- Никогда не запускать `db:drop`, `db:reset`, `db:drop db:create` без явного подтверждения пользователя.
- Не подключать новые гемы и не добавлять интеграции без явного запроса.
- Первичный ключ — всегда UUID v7.
- Именование файлов совместимо с Zeitwerk.
- AC проверяются через `bin/setup --skip-server` на чистой БД.

## Документация

### Проект и продукт

- [project/overview.md](project/overview.md)
  **Что:** C4 Level 1 — компоненты, связи, файловая структура, деплой.
  **Читать, чтобы:** понять структуру перед работой с любым модулем.

- [domain/problem.md](domain/problem.md)
  **Что:** Продукт, workflows (WF-\*), outcomes (MET-\*), ограничения (PCON-\*).
  **Читать, чтобы:** понять «зачем» перед работой с фичами.

- [prd/README.md](prd/README.md)
  **Что:** Product Requirements Documents. PRD-001: Lingvize MVP.
  **Читать, чтобы:** понять продуктовую инициативу, из которой выросли фичи.

### Архитектура и домен

- [domain/architecture.md](domain/architecture.md)
  **Что:** Стек, module boundaries, operations pattern, domain models, concurrency, failure handling.
  **Читать, чтобы:** выбрать правильный слой/модуль для изменения.

- [domain/frontend.md](domain/frontend.md)
  **Что:** UI-поверхности, design system "The Editorial Scholar", i18n.
  **Читать, чтобы:** работать с интерфейсом.

- [glossary.md](glossary.md)
  **Что:** Доменные, governance и архитектурные термины.
  **Читать, чтобы:** не путать понятия в бизнес-логике.

### Инженерные стандарты

- [engineering/coding-style.md](engineering/coding-style.md)
  **Что:** Ruby/Rails конвенции, Zeitwerk, Tailwind, SQL/migrations.
  **Читать, чтобы:** писать код в стиле проекта.

- [engineering/testing-policy.md](engineering/testing-policy.md)
  **Что:** RSpec, SimpleCov 80%, FactoryBot, CI. Когда тесты обязательны.
  **Читать, чтобы:** знать какой уровень тестов нужен.

- [engineering/architecture-patterns.md](engineering/architecture-patterns.md)
  **Что:** Layered Rails (4 слоя), callback scoring, паттерны, `/layers:*` скилл.
  **Читать, чтобы:** не нарушить архитектурные границы.

- [engineering/autonomy-boundaries.md](engineering/autonomy-boundaries.md)
  **Что:** Границы автономии агента: автопилот, супервизия, эскалация.
  **Читать, чтобы:** знать что можно делать без подтверждения.

- [engineering/git-workflow.md](engineering/git-workflow.md)
  **Что:** Ветки, коммиты, PR, conventional commits.
  **Читать, чтобы:** правильно оформить изменения.

- [engineering/DESIGN.md](engineering/DESIGN.md)
  **Что:** Дизайн-система "The Editorial Scholar": цвета, типографика, компоненты, surface hierarchy.
  **Читать, чтобы:** работать с UI — верстать компоненты, применять токены, соблюдать визуальные правила.

### Операции

- [ops/README.md](ops/README.md)
  **Что:** Индекс операционной документации: dev-окружение, stages, релизы, конфигурация, runbooks.
  **Читать, чтобы:** найти нужный ops-документ — по разработке, деплою, конфигурации или инциденту.

### Процессы и шаблоны

- [flows/feature-flow.md](flows/feature-flow.md)
  **Что:** Lifecycle фичи: Draft → Design Ready → Plan Ready → Execution → Done.
  **Читать, чтобы:** создать или вести feature package.

- [flows/templates/](flows/templates/)
  **Что:** Шаблоны feature, ADR, PRD, use case.
  **Читать, чтобы:** инстанцировать новый governed-документ.

- [flows/workflows.md](flows/workflows.md)
  **Что:** Маршрутизация задач по типам, градиент автономии.
  **Читать, чтобы:** определить workflow для текущей задачи.

### Реестры

- [features/README.md](features/README.md)
  **Что:** Feature packages: FT-002—FT-008, FIX-001—FIX-002 (все done).
  **Читать, чтобы:** найти или создать feature package.

- [use-cases/README.md](use-cases/README.md)
  **Что:** Canonical user/operational scenarios.
  **Читать, чтобы:** найти или создать use case.

- [adr/README.md](adr/README.md)
  **Что:** Architecture Decision Records.
  **Читать, чтобы:** найти или создать ADR.

### Governance (DNA)

- [dna/README.md](dna/README.md)
  **Что:** Конституция документации: SSoT, frontmatter, lifecycle.
  **Читать, чтобы:** создавать или изменять governed-документы.

## Layered Rails Workflow

Проект следует подходу Layered Design (Vladimir Dementyev). Установлен скилл `layered-rails`:

| Когда | Команда |
| --- | --- |
| **Планирование фичи** | `/layers:spec-test` на затрагиваемых файлах |
| **Реализация / ревью** | `/layers:review` после написания кода |
| **Рефакторинг** | `/layers:analyze`, `/layers:analyze:callbacks`, `/layers:analyze:gods` |
| **Новый паттерн** | `/layers:gradual [цель]` |

## SDD Mapping

Memory Bank ложится на 6 шагов Spec-Driven Development:

| Шаг SDD | Как используется Memory Bank |
| --- | --- |
| **Brief** | Прогрев: агент читает `index.md` → набирает контекст проекта |
| **Spec** | Бриф → feature package; grounding через `domain/` и `prd/` |
| **Plan** | Декомпозиция фичи; `engineering/` определяет стиль и тестирование |
| **Implement** | Агент следует `engineering/` при написании кода |
| **Verify** | AC из `feature.md`; верификация против плана |
| **Ship** | Обновление реестров, frontmatter → `done` |

---
title: Architecture Patterns
doc_kind: domain
doc_function: canonical
purpose: Каноничное место для архитектурных границ проекта. Читать при изменениях, затрагивающих модули, фоновые процессы, интеграции или конфигурацию.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Architecture Patterns

## Stack

- **Runtime:** Ruby 4.x, Rails 8.1
- **Database:** PostgreSQL (Docker Compose, порт 5433), UUID v7 первичные ключи
- **Cache/Queue:** Redis
- **Frontend:** Tailwind CSS, Hotwire (Turbo + Stimulus), Propshaft, Importmap
- **Auth:** bcrypt (has_secure_password)
- **Spaced Repetition:** FSRS gem (rb-fsrs)
- **i18n:** rails-i18n, locale ru (primary), en (fallback)
- **Testing:** RSpec, FactoryBot, SimpleCov (80% минимум)
- **Linting:** RuboCop
- **Server:** Puma

## Module Boundaries

| Context | Owns | Must not depend on directly |
| --- | --- | --- |
| `Reviews` | Сессия повторения, оценка ответов, FSRS scheduling | Импорт контента, регистрация |
| `Cards` | Модель Card, формирование стартовой колоды | Детали FSRS-алгоритма (делегирует Card#schedule!) |
| `ContentBootstrap` | Импорт лексем (Oxford, NGSL), глоссов (Poliglot) | Пользовательские данные, карточки |
| `Sentences` | Импорт предложений (Quizword), матчинг к лексемам | Пользовательские данные |
| `Auth` | Регистрация, логин, сессии (SessionsController, RegistrationsController) | Бизнес-логика карточек |

## Operations Pattern

Бизнес-логика живёт в Operations (`app/operations/`), а не в моделях или контроллерах.

Конвенции:
- Namespace по domain context: `Reviews::RecordAnswer`, `Cards::BuildStarterDeck`
- Entry point: `.call()` class method с инициализацией через `new`
- Операция владеет одним use case; оркестрация нескольких операций — через контроллер или вышестоящую операцию
- Модели хранят валидации, ассоциации, scopes и делегирование к domain-библиотекам (FSRS)

## Domain Models

| Model | Purpose | Key relations |
| --- | --- | --- |
| `User` | Аутентификация, владелец карточек | has_many :cards |
| `Card` | Карточка с FSRS-состоянием | belongs_to :user, :sentence_occurrence |
| `Language` | Язык (en, ru) | has_many :lexemes |
| `Lexeme` | Слово с CEFR-уровнем | belongs_to :language, has_many :glosses, :sentence_occurrences |
| `LexemeGloss` | Перевод слова | belongs_to :lexeme, :target_language |
| `Sentence` | Предложение из корпуса | has_many :translations, :occurrences |
| `SentenceOccurrence` | Связь слово-предложение, cloze text | belongs_to :sentence, :lexeme |
| `SentenceTranslation` | Перевод предложения | belongs_to :sentence, :target_language |
| `ReviewLog` | Лог ответа в сессии | belongs_to :card |

## Concurrency And Critical Sections

- **Импорт контента:** идемпотентный batch insert через `insert_all` с unique constraints.
- **Quizword scraper:** многопоточный HTTP через Queue (10 concurrent по умолчанию).
- **FSRS scheduling:** атомарная операция на уровне одной Card, не требует locks.

## Failure Handling

- Ошибка при создании стартовой колоды при регистрации: не блокирует signup.
- HTTP-ошибки импорта (429, timeout): retry 3 раза с exponential backoff (1s/2s/4s).
- Невалидные данные при импорте: логируются, пропускаются, не прерывают batch.

## Configuration Ownership

1. Canonical schema: `.env` + `.envrc` (direnv).
2. Defaults: `config/application.rb`, `config/database.yml`.
3. Секреты: через Rails credentials или env vars.
4. Документация env contract: [`../ops/config.md`](../ops/config.md).

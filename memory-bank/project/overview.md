---
title: Project Overview
doc_kind: domain
doc_function: canonical
purpose: C4 Level 1 — компоненты, связи, файловая структура. Читать для понимания структуры системы перед работой с любым модулем.
derived_from:
  - ../dna/governance.md
  - ../domain/architecture.md
status: active
audience: humans_and_agents
---

# Project Overview

## System Context (C4 Level 0)

**Lingvize** — веб-платформа для изучения иностранных языков.

Actors:
- **Learner** — учит слова через cloze-карточки, проходит сессии повторения
- **Admin** — управляет контентом: лексемы, предложения, курсы, карточки

External systems:
- **Oxford / NGSL** — источники лексем с CEFR-уровнями
- **Quizword** — источник предложений с переводами
- **Tatoeba** — дополнительный корпус предложений

## Container Diagram (C4 Level 1)

```
┌─────────────────────────────────────────┐
│              Browser (Learner/Admin)     │
└──────────────────┬──────────────────────┘
                   │ HTTP (Turbo Streams)
┌──────────────────▼──────────────────────┐
│           Rails 8.1 (Puma)              │
│  ┌──────────┐ ┌───────────┐ ┌────────┐ │
│  │Controllers│ │Operations │ │ Models │ │
│  │(Presentat)│ │(Applicat.)│ │(Domain)│ │
│  └──────────┘ └───────────┘ └────────┘ │
│  ┌──────────────────────────────────┐   │
│  │  Infrastructure (importers, FSRS)│   │
│  └──────────────────────────────────┘   │
└────┬─────────────────────────┬──────────┘
     │                         │
┌────▼────┐              ┌─────▼────┐
│PostgreSQL│              │  Redis   │
│(Docker)  │              │(Cache/Q) │
└─────────┘              └──────────┘
```

## Layered Architecture

4 слоя по Dementyev (Layered Design for Ruby on Rails Applications):

| Layer | Responsibility | Examples |
| --- | --- | --- |
| Presentation | HTTP, rendering, Turbo | Controllers, views, Stimulus |
| Application | Use case orchestration | Operations (`app/operations/`) |
| Domain | Business rules, state | Models, валидации, scopes, FSRS |
| Infrastructure | External I/O | Importers, HTTP clients, DB |

Подробнее: [../engineering/architecture-patterns.md](../engineering/architecture-patterns.md)

## File Structure

```
app/
├── controllers/       # Presentation layer
├── models/            # Domain layer
├── operations/        # Application layer (Namespace::Operation)
├── views/             # ERB + Tailwind
├── javascript/        # Stimulus controllers (Importmap)
│   └── controllers/
├── assets/
│   └── stylesheets/   # Tailwind (Propshaft)
config/
├── database.yml       # PostgreSQL (port 5433, Docker)
├── routes.rb
db/
├── migrate/           # Миграции (UUID v7, одна таблица за раз)
├── schema.rb
├── seeds/             # pg_dump для cold start
spec/                  # RSpec + FactoryBot
├── models/
├── operations/
├── requests/
├── system/
memory-bank/           # Документация (этот каталог)
```

## Domain Models

Core entities и их связи:

```
User ──has_many──▶ Card ──belongs_to──▶ SentenceOccurrence
                    │                         │
                    │ has_many: ReviewLog      ├── belongs_to ──▶ Sentence
                    │                         │                    └── has_many: SentenceTranslation
                    │                         │
                    │                         └── belongs_to ──▶ Lexeme
                    │                                             ├── has_many: LexemeGloss
                    │                                             └── belongs_to: Language
```

| Model | Purpose |
| --- | --- |
| `User` | Аутентификация, владелец карточек |
| `Card` | Карточка с FSRS-состоянием |
| `Language` | Язык (en, ru) |
| `Lexeme` | Слово с CEFR-уровнем |
| `LexemeGloss` | Перевод слова |
| `Sentence` | Предложение из корпуса |
| `SentenceOccurrence` | Связь слово-предложение, cloze text |
| `SentenceTranslation` | Перевод предложения |
| `ReviewLog` | Лог ответа в сессии |

Полный справочник: [../domain/architecture.md](../domain/architecture.md)

## Key Integrations

| Integration | Purpose | Entry point |
| --- | --- | --- |
| FSRS (rb-fsrs) | Алгоритм интервального повторения | `Card#schedule!` |
| Oxford / NGSL import | Лексемы с CEFR | `ContentBootstrap` operations |
| Quizword scraper | Предложения + переводы | `Sentences` operations |
| bcrypt | Аутентификация | `has_secure_password` |

## Stack

- **Runtime:** Ruby 4.x, Rails 8.1
- **Database:** PostgreSQL (Docker Compose, порт 5433), UUID v7
- **Cache/Queue:** Redis
- **Frontend:** Tailwind CSS, Hotwire (Turbo + Stimulus), Propshaft, Importmap
- **Auth:** bcrypt (has_secure_password)
- **Spaced Repetition:** FSRS gem (rb-fsrs)
- **i18n:** rails-i18n, locale ru (primary), en (fallback)
- **Testing:** RSpec, FactoryBot, SimpleCov (80% минимум)
- **Linting:** RuboCop
- **Server:** Puma

## Development

- `bin/setup` → установка зависимостей, миграции, seed data
- `bin/dev` → Rails + Tailwind watcher
- Docker Compose → PostgreSQL (5433), Redis

Подробнее: [../ops/development.md](../ops/development.md)

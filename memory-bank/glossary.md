---
title: Glossary
doc_kind: project
doc_function: canonical
purpose: Словарь терминов проекта Lingvize — доменные и governance-термины.
derived_from:
  - dna/governance.md
  - domain/problem.md
status: active
audience: humans_and_agents
---

# Glossary

## Domain Terms (Lingvize)

### Lexeme

Словарная единица (слово) с headword, частью речи (POS) и CEFR-уровнем. Принадлежит языку. Пример: headword "abandon", POS "verb", level "b2".

### LexemeGloss

Перевод лексемы на целевой язык. Связывает Lexeme с Language (target). Пример: "abandon" → "покидать, отказываться".

### Sentence

Предложение из внешнего корпуса (Tatoeba, Quizword) с указанием source. Содержит текст на языке оригинала.

### SentenceOccurrence

Связь лексемы с предложением: фиксирует, какое слово (form) встречается в каком предложении. Генерирует cloze text (текст с пропущенным словом: `____`).

### Cloze Deletion

Учебный приём: пользователь видит предложение с пропущенным словом и вводит его по памяти. Основной формат карточки в Lingvize.

### Card

Учебная карточка пользователя. Привязана к SentenceOccurrence. Хранит FSRS-состояние: stability, difficulty, scheduled_days, reps, lapses, state, due.

### FSRS

Free Spaced Repetition Scheduler — алгоритм интервального повторения. Адаптирует интервалы между показами карточки по ответам пользователя. Состояния: NEW → LEARNING → REVIEW → RELEARNING.

### Recall Quality

Классификация качества вспоминания при ответе: `no_recall`, `near_miss` (≥70% Levenshtein), `effortful_recall` (≥10s), `successful_recall`, `automatic_recall` (<3s + 100% точность).

### Rating

FSRS-оценка ответа: AGAIN (1), HARD (2), GOOD (3), EASY (4). Определяется автоматически на основе recall quality.

### ReviewLog

Запись ответа в сессии повторения: rating, recall quality, accuracy, время ответа, количество попыток, backspace count.

### Starter Deck

Стартовая колода: 50 карточек уровня A1 с русскими переводами. Создаётся автоматически при регистрации (`Cards::BuildStarterDeck`).

### CEFR

Common European Framework of Reference for Languages — шкала владения языком: A1 (начальный) → C2 (свободный). Используется для маркировки lexemes.

### Content Bootstrap

Процесс наполнения базы данных контентом: импорт лексем (Oxford 5000, NGSL), глоссов (Poliglot), предложений (Quizword).

### Cold Start

Быстрый запуск на чистом окружении через pg_dump/pg_restore вместо полного прогона миграций и seed'ов (FT-005).

## Governance Terms (Memory Bank)

### SSoT (Single Source of Truth)

Каждый факт имеет одного canonical owner. Дублирование — дефект.

### Canonical Owner

Документ, который владеет фактом и имеет приоритет над downstream-описаниями.

### Governed Document

Markdown-файл с YAML frontmatter, подчиняющийся governance-правилам memory-bank.

### Dependency Tree

DAG зависимостей между документами через `derived_from`. Authority течёт upstream → downstream.

### Feature Package

Каталог `FT-XXX/` с документами одной delivery-единицы: brief, feature.md (spec), implementation-plan.md (plan).

### PRD (Product Requirements Document)

Документ уровня продуктовой инициативы. Стоит между domain/problem.md и downstream feature packages.

### ADR (Architecture Decision Record)

Фиксация архитектурного решения: контекст, альтернативы, rationale, последствия.

### Status (Publication)

`draft` → `active` → `archived`. Отвечает за то, является ли документ действующим источником истины.

### Delivery Status

`planned` → `in_progress` → `done` / `cancelled`. Lifecycle feature-документа.

### Progressive Disclosure

Принцип: обзор сначала, детали по ссылкам. Верхний уровень остаётся читаемым.

## Architecture Terms

### Operation

Класс бизнес-логики в `app/operations/`. Entry point: `.call()`. Один use case = одна операция. Пример: `Reviews::RecordAnswer`.

### Layered Rails

Подход к организации Rails-кода из книги "Layered Design for Ruby on Rails Applications" (Vladimir Dementyev). Четыре слоя с однонаправленным потоком данных: Presentation → Application → Domain → Infrastructure. Нижние слои не зависят от верхних. Domain logic живёт в моделях (не в сервисах). Services — "waiting room" для кода до появления правильной абстракции. Скилл `layered-rails` с командами `/layers:*`. См. `engineering/architecture-patterns.md`.

### Specification Test

Ключевой принцип Layered Rails: если спецификация объекта описывает возможности за пределами основной ответственности его архитектурного слоя, эти возможности должны быть вынесены в нижние слои. Проверяется через `/layers:spec-test`.

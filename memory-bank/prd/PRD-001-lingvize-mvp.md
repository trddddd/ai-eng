---
title: "PRD-001: Lingvize MVP — Изучение английских слов через интервальное повторение"
doc_kind: prd
doc_function: canonical
purpose: Фиксирует продуктовую проблему, целевых пользователей, goals, scope и success metrics MVP Lingvize.
derived_from:
  - ../domain/problem.md
status: active
audience: humans_and_agents
must_not_define:
  - implementation_sequence
  - architecture_decision
  - feature_level_verify_contract
---

# PRD-001: Lingvize MVP — Изучение английских слов через интервальное повторение

## Problem

Существующие решения для изучения слов (Anki, Quizlet, Memrise) имеют один из двух недостатков: либо требуют от пользователя самостоятельно создавать учебный контент (создание колод — отдельная работа, не обучение), либо предлагают контент без привязки к стандартам владения языком (CEFR) и без адаптивного алгоритма повторения.

Lingvize MVP решает эту проблему: готовый, курируемый контент с привязкой к CEFR-уровням + адаптивное повторение по FSRS + cloze deletion в контексте предложений.

Подробный project-wide контекст: [`../domain/problem.md`](../domain/problem.md).

## Users And Jobs

| User / Segment | Job To Be Done | Current Pain |
| --- | --- | --- |
| Изучающий английский (начальный уровень, A1-B1) | Выучить базовую лексику в контексте | Нет готового контента по CEFR; создание карточек отнимает время; повторение не адаптивное |
| Контент-менеджер (внутренний) | Наполнить базу качественным контентом | Ручной ввод слов и предложений; нет автоматизации импорта |

## Goals

- `G-01` Пользователь начинает учить слова сразу после регистрации (стартовая колода 50 карточек A1).
- `G-02` Каждая карточка содержит слово в контексте предложения с переводом.
- `G-03` Повторение адаптируется под пользователя через FSRS (сложные слова чаще, лёгкие — реже).
- `G-04` Контент-пайплайн автоматизирован: импорт лексем, предложений, переводов из внешних корпусов.

## Non-Goals

- `NG-01` Мобильное приложение (только web).
- `NG-02` Социальные функции (лидерборды, друзья, группы).
- `NG-03` Создание контента пользователями (UGC).
- `NG-04` Поддержка языков кроме английского (как целевого).
- `NG-05` Платная подписка или монетизация.

## Product Scope

### In Scope

- Регистрация и аутентификация (email/password)
- Автоматическая стартовая колода при регистрации
- Сессия повторения с cloze deletion
- Оценка ответа по точности (Levenshtein) + recall quality classification
- FSRS scheduling (stability, difficulty, intervals)
- Аудио для предложений (Tatoeba через серверный proxy)
- Контент-пайплайн: импорт Oxford 5000, NGSL, Quizword sentences
- Дизайн-система "The Editorial Scholar"
- i18n (ru primary, en fallback)

### Out Of Scope

- Админка (пока только rake tasks для контента)
- Аналитика обучения и статистика для пользователя
- Множественные колоды и курсы
- Грамматика и аудирование как отдельные модули
- Production deployment

## UX / Business Rules

- `BR-01` Пользователь видит cloze-карточку: предложение с пропущенным словом, перевод предложения, глоссы слова. Вводит ответ.
- `BR-02` Ответ оценивается автоматически (Levenshtein distance ≥ 70% = near miss, 100% = correct).
- `BR-03` Recall quality классифицируется по точности + скорости (< 3s = automatic, ≥ 10s = effortful).
- `BR-04` Кнопка "Знаю это слово" — mastering, карточка больше не показывается.
- `BR-05` Стартовая колода = 50 A1-лексем с русским переводом и хотя бы одним предложением.
- `BR-06` Ошибка при создании колоды не блокирует регистрацию.

## Success Metrics

| Metric ID | Metric | Baseline | Target | Measurement method |
| --- | --- | --- | --- | --- |
| `MET-01` | Каталог лексем | 0 | 9500+ | `Lexeme.count` |
| `MET-02` | Предложения с привязкой | 0 | 10000+ | `SentenceOccurrence.count` |
| `MET-03` | Стартовая колода | 0 | 50 карточек | Post-registration check |
| `MET-04` | FSRS scheduling работает | Нет | End-to-end flow | RSpec + manual |
| `MET-05` | Cold start | ~30 мин | ≤5 мин | Timing с pg_dump |

## Risks And Open Questions

- `RISK-01` Quizword может изменить структуру HTML → сломает импорт предложений.
- `RISK-02` Tatoeba CDN может заблокировать CORS → требуется серверный proxy (уже решено).
- `OQ-01` Нужна ли админка в MVP или достаточно rake tasks?
- `OQ-02` Какой порог coverage считать production-ready?

## Downstream Features

| Feature | Why it exists | Status |
| --- | --- | --- |
| `FT-002` | Content Bootstrap: импорт лексем и глоссов | done |
| `FT-003` | Test Coverage & CI | done |
| `FT-004` | Sentence Domain & Quizword Import | done |
| `FT-005` | Cold Start via DB Dump | done |
| `FT-006` | Personal Starter Deck | done |
| `FT-007` | Spaced Repetition Review Session | done |
| `FT-008` | Design System & UI Redesign | done |
| `FIX-001` | Word Matching Fix | done |
| `FIX-002` | CI Cleanup | done |

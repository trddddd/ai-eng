---
title: "ADR-001: Источник sense-данных для лексем"
doc_kind: adr
doc_function: canonical
purpose: "Фиксирует выбор внешнего источника sense-данных (значений слов) для импорта в контент-пайплайн Lingvize. Разрешает DEC-01 из FT-029."
derived_from:
  - ../features/FT-029/feature.md
related_tasks:
  - "#29"
comment:
status: active
decision_status: accepted
date: 2026-04-13
date_accepted: 2026-04-13
audience: humans_and_agents
must_not_define:
  - current_system_state
  - implementation_plan
---

# ADR-001: Источник sense-данных для лексем

**Related tasks:** GitHub Issue #29

## Контекст

FT-029 (Lexeme Sense & Context Families) вводит доменную сущность `Sense` — отдельное значение лексемы. Для автоматической разметки значений при сборке контента нужен внешний словарный источник с sense-данными (`REQ-05`).

Без выбора источника невозможно спроектировать `ImportSenses` operation, определить формат `external_id` в контракте `CTR-01`, и начать реализацию `REQ-01` (сущность Sense) и `REQ-03` (привязка SentenceOccurrence к Sense).

Это решение — `DEC-01` из `feature.md` FT-029. Discovery проведён в [research-sense-sources.md](../features/FT-029/research-sense-sources.md).

## Драйверы решения

- `REQ-05` — импорт sense-данных из минимум одного утверждённого внешнего источника.
- `CON-03` — новые гемы требуют явного approval.
- `ASM-01` — для monosemous лексем `lexeme == sense` (fallback). Источник не обязан покрывать 100% лексем.
- `ASM-03` — масштаб: 9500+ лексем в целевом каталоге (Oxford 5000 + NGSL), из них Oxford 5000 содержит ~5949 word/POS записей, а часть NGSL-лексем не имеет POS. Импорт однократный (content pipeline), не рантайм.
- Лицензия: источник должен допускать коммерческое использование без платной подписки (нулевая стоимость лицензии — проект не имеет бюджета на подписки сторонних API).
- Покрытие: источник должен покрывать основную массу Oxford 5000 (content words).
- Структурированность: нужны definition, POS, sense rank (для MFS baseline), желательно — examples, hypernyms, lexical domain.

## Рассмотренные варианты

| Вариант | Плюсы | Минусы | Почему основной / не основной кандидат |
| --- | --- | --- | --- |
| **WordNet 3.1 via ruby-wordnet** | Свободная лицензия (BSD-подобная). Покрытие Oxford 5000: 5653 из 5949 лексем (95%) имеют POS с прямым аналогом в WordNet (noun/verb/adjective/adverb). Остальные 296 (5%) — function words с POS без аналога (см. риск POS mismatch). Точное покрытие synsets верифицируется при acceptance gate. Структурированные данные: definition (отдельно от examples), POS, sense rank, hypernyms, lexical domain в читаемом формате. Graph traversal с depth. Ruby-гем с SQLite-бэкендом — естественная интеграция с Rails content pipeline. Нужен только при импорте, не в рантайме. | 4 runtime-зависимости (sequel, sqlite3, loggability, hoe) — требует approval по `CON-03`. БД ~34 MB + гемы (суммарно ~40 MB). Определения академические, не адаптированы для learners. WordNet не обновлялся с 2011 — новая лексика (post-2011 neologisms) может отсутствовать, хотя для Oxford 5000 (устоявшаяся лексика) это маловероятно. Часть function words (articles, prepositions) может не иметь synsets. ruby-wordnet v1.2.0 (май 2023) требует Ruby ~> 3.0 — совместимость с текущим Ruby проекта нужно проверить при добавлении гема. | **Основной кандидат.** Драйверы «нулевая стоимость лицензии» и «покрытие Oxford 5000» закрыты. Драйвер «структурированность» (definition, sense rank, lexical domain) — лучший среди вариантов. Зависимости (`CON-03`) — разумный trade-off: гемы нужны только при импорте и естественны для Rails (sequel, sqlite3). |
| **WordNet 3.0 via rwordnet** | Нет зависимостей (чистый Ruby) — преимущество по `CON-03`: не нужен approval на новые гемы. Маленькая БД (~8 MB). | WordNet 3.0 (старая версия). `gloss` смешивает definition и examples — нужен ручной парсинг. Нет graph traversal. Неактивен с 2019 (6+ лет без коммитов). Нет lexical domain в читаемом формате. | **Не основной.** Преимущество по `CON-03` (нулевые зависимости) не компенсирует потерю по драйверу «структурированность»: смешанный gloss, отсутствие graph traversal и lexical domain в читаемом формате увеличивают объём кода импорта. Неактивность 6+ лет — риск при совместимости с Ruby 3.x. |
| **Oxford API (Oxford Learners Dictionary)** | Определения адаптированы для learners (A1-C1) — единственный вариант, не требующий упрощения определений для пользовательского UI. CEFR-разметка на уровне sense. Примеры высокого качества. | Платная подписка (free tier отсутствует). Нет готового Ruby-гема. REST API — сетевые запросы при импорте (хрупкость). Формат данных привязан к Oxford, не к стандартному sense ID (нет inter-operability). | **Не основной.** Драйвер «нулевая стоимость лицензии» не закрыт: Oxford API требует платной подписки (free tier отсутствует), проект не имеет бюджета на подписки. Learner-friendly определения — существенный плюс, но `NG-05` из PRD-002 выводит UI управления значениями из scope, а для внутренних нужд content pipeline академические определения WordNet достаточны. При появлении UI определений в будущем — возможен гибрид (WordNet для импорта + Oxford для display text). |

## Решение

Принято решение использовать **WordNet 3.1** через Ruby-гем **ruby-wordnet** (`ged/ruby-wordnet`, v1.2.0) как источник sense-данных для контент-пайплайна.

**Границы решения:**

- ruby-wordnet используется **только в content pipeline** (rake tasks / operations при сборке контента). В рантайме приложения гем не нужен — все sense-данные после импорта живут в PostgreSQL.
- Гем добавляется вместе с companion-гемом `wordnet-defaultdb` (SQLite-база WordNet 3.1, ~34 MB).
- `external_id` в `CTR-01` будет содержать идентификатор из WordNet (synset offset). Конкретный формат фиксируется в implementation plan.
- Для лексем без match в WordNet — fallback sense (`ASM-01`). Лексемы без match логируются (`FM-01`).
- WSD-стратегия (привязка occurrence к sense) не является предметом этого ADR. Фиксируется в implementation plan FT-029 как отдельное проектное решение (не требует ADR — research уже содержит рекомендацию MFS + POS filter, альтернативы с существенными trade-offs отсутствуют).

## Последствия

### Положительные

- Sense-данные доступны для всех content words из Oxford 5000 без лицензионных ограничений.
- `definition` отделён от `examples` в API — не нужен ручной парсинг gloss.
- `sense_rank` (Most Frequent Sense) из WordNet даёт готовый MFS baseline для WSD без дополнительных данных.
- Lexical domain (`noun.motion`, `verb.cognition` и т.д.) — может рассматриваться как входные данные для DEC-02 (таксономия context families), но не предопределяет выбор таксономии.
- Graph traversal (hypernyms с depth) — возможность будущего обогащения sense-данных (не в scope FT-029).

### Отрицательные

- Добавляются 2 новых гема (`ruby-wordnet`, `wordnet-defaultdb`) и их транзитивные зависимости (sequel, sqlite3, loggability) в Gemfile group `:development` (не в production). Увеличение dev bundle size (~40 MB, из которых ~34 MB — SQLite-база WordNet). Production deploy не затрагивается.
- Определения WordNet академические. Пользовательский UI для значений выведен из scope (`NG-05` PRD-002). Если в будущем появится UI отображения определений — потребуется отдельная задача по адаптации текстов (не в scope FT-029).
- POS-маппинг между Oxford CSV и WordNet не 1:1 (Oxford: "indefinite article", WordNet: не знает articles). Нужна таблица маппинга в ImportSenses.

### Нейтральные / организационные

- `CON-03` — approval на добавление ruby-wordnet и wordnet-defaultdb считается полученным при переводе этого ADR в `accepted`.
- Обновить `memory-bank/project/overview.md` — добавить WordNet как источник данных.
- Обновить `memory-bank/glossary.md` — добавить термины: Sense, Synset, WordNet.
- Обновить `FT-029/feature.md`: `DEC-01` ссылка на ADR-001, секция `ADR Dependencies` — статус.

## Риски и mitigation

| Риск | Вероятность | Последствие | Mitigation |
| --- | --- | --- | --- |
| WordNet не покрывает часть function words (a, the, about как preposition) | Средняя | Лексемы без synset получают fallback sense — функциональность не страдает, но sense-разметка неполная | Fallback sense (`ASM-01`). Логирование непокрытых лексем для ручной разметки. |
| ruby-wordnet перестанет поддерживаться или несовместим с Ruby проекта | Средняя (последний релиз v1.2.0 — май 2023; активность репо умеренная) | Гем нужен только при импорте, не в рантайме. Даже без обновлений SQLite-база работает. | WordNet-данные статичны (последнее обновление 2011). ruby-wordnet требует Ruby ~> 3.0 — совместимость проверяется в acceptance gate. При несовместимости или abandonment — fork или прямой SQL к SQLite через sequel (данные в стандартном формате). |
| POS mismatch Oxford/NGSL ↔ WordNet | Высокая (подтверждено) | Oxford CSV содержит 296 лексем (5%) с POS без прямого аналога в WordNet; NGSL-импорты могут создавать `lexeme.pos = NULL`. | Двухуровневый fallback: (1) маппинг Oxford POS → ближайший WordNet POS (modal verb → verb, number → noun, determiner → adjective); (2) если POS присутствует, но маппинг не даёт match — fallback sense (`ASM-01`); (3) если `lexeme.pos` отсутствует, lookup без POS-filter и сохранение POS из synset, при отсутствии match — fallback sense с `pos = "unknown"`. Полная таблица и алгоритм — в implementation plan. |

## Follow-up

**Acceptance gate для реализации:** при `STEP-01` выполнить smoke-тест: `bundle add ruby-wordnet wordnet-defaultdb` + lookup текущего каталога лексем (Oxford + NGSL; для nullable POS использовать алгоритм из FT-029 implementation plan). Подтвердить: (a) гем совместим с Ruby проекта, (b) покрытие content words >= 90% среди лексем с WordNet-compatible POS; лексемы без match получают fallback sense.

1. **При реализации:**
   - Добавить ruby-wordnet и wordnet-defaultdb в Gemfile (group :development). Approval по `CON-03` считается полученным.
   - Обновить `memory-bank/project/overview.md` — добавить WordNet как источник данных.
   - Убедиться, что `memory-bank/glossary.md` содержит термины: Sense, Synset, WordNet.

2. **Уже связано:**
   - `FT-029/feature.md` ссылается на ADR-001 как accepted decision для `DEC-01`.
   - `memory-bank/adr/README.md` содержит ADR-001.
   - ADR-002 уже создан и принят для `DEC-02`.
   - Implementation plan FT-029 фиксирует WSD-стратегию (MFS + POS filter), nullable POS handling, формат `external_id`, batch processing.

## Связанные ссылки

- [FT-029: Lexeme Sense & Context Families](../features/FT-029/feature.md)
- [FT-029 Research: Sense Data Sources](../features/FT-029/research-sense-sources.md)
- [PRD-002: Word Mastery](../prd/PRD-002-word-mastery.md)
- [ruby-wordnet GitHub](https://github.com/ged/ruby-wordnet)

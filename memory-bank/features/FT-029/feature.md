---
title: "FT-029: Lexeme Sense & Context Families"
doc_kind: feature
doc_function: canonical
purpose: "Foundation-слой для PRD-002: доменные сущности sense и context family, импорт sense-данных, группировка предложений по контексту. Блокирует Word Mastery State, Review Pipeline v2, Session Builder v2."
derived_from:
  - ../../domain/problem.md
  - ../../prd/PRD-002-word-mastery.md
status: active
delivery_status: done
audience: humans_and_agents
must_not_define:
  - implementation_sequence
---

# FT-029: Lexeme Sense & Context Families

> GitHub Issue: [xtrmdk/ai-eng#29](https://github.com/xtrmdk/ai-eng/issues/29)

## What

### Problem

Lingvize не различает значения полисемичных слов. `run` как "бежать" и `run` как "работать (о моторе)" --- разные знания, но система склеивает их в один `Lexeme`. Успех в одном значении ложно засчитывается другому --- пользователь получает завышенный интервал повторения по значениям, которые на самом деле не освоил.

Вторая часть проблемы: предложения не сгруппированы по контексту употребления. Система не различает "пользователь уже встречал слово в этой ситуации" от "это новый контекст". Без этого различения невозможно оценить ширину знания слова.

Feature-specific delta относительно PRD-002: эта фича создаёт foundation-слой --- доменные сущности и данные. Downstream features (Word Mastery State, Review Pipeline v2, Session Builder v2) зависят от этого слоя, но не входят в scope.

### Outcome

| Metric ID | Metric | Baseline | Target | Measurement method |
| --- | --- | --- | --- | --- |
| `MET-01` | Polysemous lexemes имеют >= 2 senses | 0 | 100% из configured top-100 полисемичных лексем (aligned с PRD-002 MET-06) | `Lexeme.where(id: CONFIGURED_TOP_100_POLYSEMOUS_IDS).all? { _1.senses.count >= 2 }` |
| `MET-02` | Monosemous lexemes имеют ровно 1 sense (fallback) | 0 | 100% lexemes имеют >= 1 sense | `Lexeme.left_joins(:senses).where(senses: { id: nil }).count == 0` |
| `MET-03` | SentenceOccurrences привязаны к context family | 0 | 100% occurrences имеют context_family | `SentenceOccurrence.where(context_family: nil).count == 0` |
| `MET-04` | SentenceOccurrences привязаны к sense | 0 | 100% occurrences mapped к sense | `SentenceOccurrence.where(sense: nil).count == 0` |

### Scope

- `REQ-01` Доменная сущность `Sense` --- отдельное значение лексемы (lemma + sense definition). Связь: `Lexeme has_many :senses`. Для monosemous лексем создаётся fallback sense (1:1 с lexeme).
- `REQ-02` Доменная сущность `ContextFamily` --- именованная группа контекстов употребления (curated string label из контролируемого словаря). Связь: принадлежность на уровне `SentenceOccurrence`.
- `REQ-03` `SentenceOccurrence` получает FK на `Sense` --- каждое вхождение слова привязано к конкретному значению.
- `REQ-04` `SentenceOccurrence` получает FK на `ContextFamily` --- каждое вхождение слова привязано к контекстной семье.
- `REQ-05` Импорт sense-данных из минимум одного утверждённого внешнего источника (WordNet или Oxford) для автоматической разметки значений при сборке контента. Выбор источника и формат --- вопрос `DEC-01`.
- `REQ-06` Backfill task: все существующие `SentenceOccurrence` получают best-available `sense_id` и `context_family_id`: imported WordNet sense через MFS baseline + POS filter, fallback sense если sense-данных нет, context family через lexical domain mapping, fallback family `unknown` если классификация невозможна. Миграция не-деструктивна (BR-08 из PRD-002).
- `REQ-07` Существующие карточки и review logs не теряются и не меняются. Новые сущности дополняют текущую схему.
- `REQ-08` Импорт предложений из Tatoeba CSV: чтение локальных TSV-файлов (`sentences.tar.bz2`, `links.tar.bz2`), создание `Sentence` + `SentenceTranslation` + `SentenceOccurrence` для eng-rus пар. Замена `ImportQuizword` как основного источника предложений (обоснование: `ASM-04`). Существующие записи `source: "quizword"` остаются в БД, новые --- `source: "tatoeba"`. Если Tatoeba files недоступны, FT-029 не считается завершённой; допускается только явное rescope-решение с переносом `REQ-08` в отдельную feature.

### Non-Scope

- `NS-01` Word Mastery State (персональное состояние знания слова) --- отдельная feature downstream.
- `NS-02` Review Pipeline v2 (contribution card -> word mastery) --- отдельная feature downstream.
- `NS-03` Session Builder v2 (dual-level scheduling) --- отдельная feature downstream.
- `NS-04` Автоматическая WSD (word sense disambiguation) в рантайме (NG-03 из PRD-002).
- `NS-05` Пользовательский UI для управления значениями и контекстными семьями (NG-05 из PRD-002).
- `NS-06` Dashboard прогресса по словам --- отдельная feature downstream.
- `NS-07` Алгоритмическая таксономия context families --- v1 = curated labels.
- `NS-08` Делать `lexeme.pos` обязательным (`NOT NULL`) --- вне scope. Текущая схема допускает `lexeme.pos = NULL` для части NGSL-лексем; FT-029 должна корректно обрабатывать такие лексемы без POS.

### Constraints / Assumptions

- `ASM-01` Для monosemous лексем `lexeme == sense` (fallback). Система работает с первого дня без полной sense-разметки (OQ-03 из PRD-002, resolved).
- `ASM-02` Context family v1 = curated string labels из контролируемого словаря; fallback для неклассифицированных = `unknown` (RISK-02 из PRD-002).
- `ASM-03` Масштаб: 9500+ lexemes в базе. Точный процент полисемичных неизвестен до подключения словарного источника.
- `ASM-04` Прямой импорт Tatoeba CSV заменяет скрейпинг Quizword как основной источник предложений. `ImportQuizword` → deprecated (оставить для совместимости, не удалять). Новый `Sentences::ImportTatoeba` работает с локальными TSV-файлами (`sentences.tar.bz2`, `links.tar.bz2`). Обоснование: research (секция 9) --- Quizword хрупкий (HTML-скрейпинг, timeouts), ограниченное покрытие, нестабильная доступность. Tatoeba direct --- локальные файлы, 100% надёжность, полное покрытие eng-rus пар (~150K+). Существующие записи `source: "quizword"` остаются в БД, новые --- `source: "tatoeba"`. Это scope FT-029, а не optional expansion; если файлы недоступны, требуется rescope decision.
- `CON-01` Первичные ключи --- UUID v7 (PCON-01).
- `CON-02` Не менять существующие миграции (PCON-02). Новые сущности --- только новыми миграциями.
- `CON-03` Не подключать новые гемы без явного запроса (PCON-04). Если для импорта WordNet нужен gem --- approval gate.
- `DEC-01` Выбор источника sense-данных: WordNet vs Oxford vs другой. Критерии: лицензия, покрытие лексем, формат, сложность импорта. Решение блокирует `REQ-05`. → [ADR-001](../../adr/ADR-001-sense-data-source.md) (`accepted`).
- `DEC-02` Таксономия context families v1: какие labels, иерархия или flat list, гранулярность. Решение блокирует `REQ-02` и `REQ-04`. → [ADR-002](../../adr/ADR-002-context-family-taxonomy.md) (`accepted`).
- `ASM-05` `sense.pos` = POS из WordNet synset, validated against `lexeme.pos` через POS mapping table когда `lexeme.pos` присутствует. Если `lexeme.pos` отсутствует, ImportSenses ищет WordNet senses без POS-filter и сохраняет POS из synset; если match нет, fallback sense получает `pos = "unknown"`. В scope FT-029: `lexeme.pos` остаётся nullable, `sense.pos` остаётся NOT NULL.
- `ASM-06` Context family таксономия глобальная (одна на все языки, не per-language). Обоснование: v1 = consolidated flat list (~17 семей) из WordNet lexical domains (ADR-002) --- язык-независимая онтология. Future: per-language расширение через additive migration.
- `ASM-07` Backfill выполняется через rake task, не через db:migrate. Причины: контроль над batch processing, resume capability, отдельный lifecycle от schema migrations.
- `ASM-08` "Configured top-100 полисемичных лексем" (MET-01, EC-04) хранится как curated/configured список, aligned с PRD-002 MET-06. Начальный список может быть сгенерирован из WordNet top lexemes по `senses.count`, но после генерации фиксируется как конфигурация/seed и используется как стабильный verification set.

### User Stories

- `US-01` Как контент-менеджер, я хочу импортировать sense-данные из WordNet (rake task), чтобы система различала значения полисемичных слов. → `REQ-05`, `DEC-01`
- `US-02` Как контент-менеджер, я хочу видеть все lexemes привязанными к sense (rake task backfill), чтобы данные были полными и downstream features могли работать. → `REQ-01`, `REQ-06`
- `US-03` Как контент-менеджер, я хочу видеть все occurrences классифицированными по контекстным семьям (rake task), чтобы система могла различать контексты употребления слова. → `REQ-02`, `REQ-04`
- `US-04` Как разработчик downstream feature, я хочу чтобы миграция была non-destructive, чтобы существующие карточки и review logs не пострадали. → `REQ-07`
- `US-05` Как контент-менеджер, я хочу импортировать предложения из Tatoeba CSV, чтобы заменить хрупкий HTML-скрейпинг надёжным локальным источником данных. → `REQ-08`

Operations запускаются через rake tasks, доступны администраторам. Не UI, не auto-deploy.

## How

### Solution

Добавить две новые доменные сущности (`Sense`, `ContextFamily`) и связать их с существующей моделью через FK на `SentenceOccurrence`. Импорт sense-данных из внешнего словарного источника автоматизировать через operation в content pipeline. Для monosemous слов --- fallback sense. Для неклассифицированных контекстов --- `unknown` family.

### Change Surface

| Surface | Type | Why it changes |
| --- | --- | --- |
| `app/models/sense.rb` | code (new) | Новая доменная сущность: значение лексемы |
| `app/models/context_family.rb` | code (new) | Новая доменная сущность: контекстная семья |
| `app/models/lexeme.rb` | code | Добавление `has_many :senses` |
| `app/models/sentence_occurrence.rb` | code | Добавление `belongs_to :sense`, `belongs_to :context_family` |
| `app/models/card.rb` | code | Добавление `delegate :sense, :context_family, to: :sentence_occurrence`. Проверить все места где используется `card.lexeme` |
| `db/migrate/*_create_senses.rb` | code (new) | Миграция: таблица senses |
| `db/migrate/*_create_context_families.rb` | code (new) | Миграция: таблица context_families |
| `db/migrate/*_add_sense_and_context_family_to_sentence_occurrences.rb` | code (new) | Миграция: FK на sentence_occurrences |
| `app/operations/content_bootstrap/import_senses.rb` | code (new) | Operation: импорт sense-данных из внешнего источника |
| `app/operations/content_bootstrap/assign_fallback_senses.rb` | code (new) | Operation: создание fallback senses для лексем без imported senses |
| `app/operations/content_bootstrap/assign_context_families.rb` | code (new) | Operation: классификация occurrences по контекстным семьям |
| `app/operations/sentences/import_tatoeba.rb` | code (new) | Operation: импорт предложений из Tatoeba CSV (замена ImportQuizword) |
| `spec/` | code (new/update) | Тесты для новых моделей и операций |

### Flow

1. Импорт sense-данных из WordNet 3.1 (`ImportSenses`, ADR-001): парсинг synsets, создание `Sense` записей, привязка к `Lexeme` через POS filter.
2. Для лексем без sense-данных --- создание fallback sense (`AssignFallbackSenses`).
3. Импорт предложений из Tatoeba CSV (`Sentences::ImportTatoeba`): чтение локальных TSV-файлов, создание `Sentence` + `SentenceTranslation` + `SentenceOccurrence` для eng-rus пар. Замена `ImportQuizword` (см. `ASM-04`).
4. Привязка существующих `SentenceOccurrence` к sense: через lexeme → sense mapping (алгоритм MFS baseline, см. ниже).
5. Создание `ContextFamily` записей из curated mapping (ADR-002).
6. Классификация `SentenceOccurrence` по контекстным семьям (`AssignContextFamilies`): транзитивная цепочка occurrence → sense → synset (lexical domain) → context family mapping.
7. Валидация: все occurrences имеют sense и context_family.

### Occurrence → Sense Algorithm (MFS Baseline)

Для каждого `SentenceOccurrence` без `sense_id`:

1. Найти все `Sense` через `occurrence.lexeme.senses`.
2. Если lexeme имеет 1 sense (monosemous) → привязать к нему.
3. Если lexeme имеет >1 sense (polysemous) и `lexeme.pos` присутствует → привязать к primary sense среди POS-compatible senses (lowest `sense_rank` из WordNet = Most Frequent Sense).
4. Если `lexeme.pos` отсутствует или POS-compatible senses нет → привязать к sense с lowest `sense_rank` среди всех senses этой lexeme, логировать warning для POS-mismatch.

Ограничения: автоматическая привязка для polysemous uses не-первое значение (non-MFS). Ручная курация и WSD — post-v1 (`NS-04`).

### Migration Strategy (Safe 3-Phase)

| Фаза | Действие | Rollback |
| --- | --- | --- |
| Phase 1 | Add nullable FK columns (`sense_id`, `context_family_id`) to `sentence_occurrences` | Drop columns |
| Phase 2 | Backfill via rake task: batch size=500, transaction per batch, resume from last processed ID (`ASM-07`) | Clear columns: `UPDATE sentence_occurrences SET sense_id = NULL, context_family_id = NULL` |
| Phase 3 | SET NOT NULL constraint via separate migration | Drop NOT NULL constraint |

### Contracts

| Contract ID | Input / Output | Producer / Consumer | Notes |
| --- | --- | --- | --- |
| `CTR-01` | `Sense`: `id`, `lexeme_id`, `external_id`, `definition`, `pos`, `examples`, `source` | ImportSenses / SentenceOccurrence, downstream features | `external_id` --- WordNet synset offset (integer). `source` --- string, default `'wordnet'`. |
| `CTR-02` | `ContextFamily`: `id`, `name`, `description` | Seed / SentenceOccurrence, downstream features | `name` --- curated label из контролируемого словаря (ADR-002) |
| `CTR-03` | `SentenceOccurrence.sense_id` FK | Migrations / Card (через delegation), downstream features | NOT NULL после Phase 3 migration. `on_delete: :restrict`. |
| `CTR-04` | `SentenceOccurrence.context_family_id` FK | Migrations / Card (через delegation), downstream features | NOT NULL после Phase 3 migration. `on_delete: :restrict`; переназначение в `unknown` выполняется явной maintenance operation до удаления/объединения family. |

### Schema Constraints

**Sense:**
- `lexeme_id` NOT NULL, FK → `lexemes`, `on_delete: :cascade` (`dependent: :destroy` --- sense не существует без lexeme)
- `definition` NOT NULL (text)
- `external_id` integer, nullable (NULL для fallback senses)
- `pos` NOT NULL (string) --- POS из WordNet synset; для fallback без POS = `"unknown"`. Validated: совместим с `lexeme.pos` через POS mapping table когда `lexeme.pos` присутствует (`ASM-05`)
- `examples` jsonb (array of strings), nullable
- `source` string, NOT NULL, default `'wordnet'`
- Unique index: `(lexeme_id, external_id)` WHERE `external_id IS NOT NULL`
- Index: `external_id` для lookup

**ContextFamily:**
- `name` NOT NULL, unique constraint
- `description` text, nullable

**SentenceOccurrence FKs:**
- `sense_id` --- nullable (Phase 1-2), NOT NULL (Phase 3). FK → `senses`, `on_delete: :restrict` (нельзя удалить sense с привязанными occurrences)
- `context_family_id` --- nullable (Phase 1-2), NOT NULL (Phase 3). FK → `context_families`, `on_delete: :restrict` (family нельзя удалить, пока есть occurrences; для merge/delete сначала переназначить affected occurrences в replacement или `unknown`)

### Result Contracts (Operations)

Каждая operation возвращает структуру:

```
{ success: boolean, created: integer, skipped: integer, errors: Array<ErrorDetail> }
```

| Operation | Успех | Частичный успех | Ошибка |
| --- | --- | --- | --- |
| `ImportSenses` | `success: true, created: N, skipped: M` | `success: true, created: N, errors: [...]` | `success: false, errors: [...]` |
| `AssignFallbackSenses` | `success: true, created: N` | — | `success: false, errors: [...]` |
| `AssignContextFamilies` | `success: true, created: N, skipped: M` | `success: true, errors: [...]` | `success: false, errors: [...]` |
| `Sentences::ImportTatoeba` | `success: true, created: N, skipped: M` | `success: true, created: N, errors: [...]` | `success: false, errors: [...]` |

### Failure Modes

- `FM-01` Внешний словарный источник не покрывает часть лексем --- fallback sense (ASM-01). Лексемы без match логируются для ручной разметки.
- `FM-02` Несколько senses из источника --- все создаются. Привязка occurrence к конкретному sense: MFS baseline (primary sense, см. алгоритм выше). Non-MFS привязка требует ручной курации (post-v1).
- `FM-03` Context family классификация неоднозначна --- fallback `unknown`. Итеративное уточнение допустимо post-launch.
- `FM-04` Backfill миграция на 9500+ lexemes и связанных occurrences --- потенциально долгая операция. Batched processing обязателен. Выполняется через rake task (ASM-07), batch size=500, transaction per batch, resume from last processed ID.
- `FM-05` Невалидный формат данных при импорте: skip record + log warning. Batch failure: per-batch transaction, skip failed batch + continue. Result object содержит errors list для post-mortem.
- `FM-06` Повторный запуск operations --- идемпотентный (не создаёт дубли). External_id unique constraint предотвращает дублирование senses.

### ADR Dependencies

| ADR | Current `decision_status` | Used for | Execution rule |
| --- | --- | --- | --- |
| [ADR-001](../../adr/ADR-001-sense-data-source.md) | `accepted` | Выбор внешнего источника sense-данных: WordNet 3.1 via ruby-wordnet | Canonical input для implementation. Принято 2026-04-13. |
| [ADR-002](../../adr/ADR-002-context-family-taxonomy.md) | `accepted` | Таксономия контекстных семей v1: consolidated flat list (~17 семей), маппинг из WordNet lexical domains | Canonical input для `REQ-02`, `REQ-04`. Принято 2026-04-14. |

## Verify

### Exit Criteria

- `EC-01` Все lexemes имеют >= 1 sense (monosemous = fallback, polysemous = imported).
- `EC-02` Все sentence_occurrences привязаны к sense и context_family (no NULLs).
- `EC-03` Существующие карточки и review logs не изменены (non-destructive migration).
- `EC-04` Полисемичные лексемы из configured top-100 списка имеют >= 2 senses с independent tracking.

### Traceability matrix

| Requirement ID | Design refs | Acceptance refs | Checks | Evidence IDs |
| --- | --- | --- | --- | --- |
| `REQ-01` | `ASM-01`, `CON-01`, `CTR-01` | `EC-01`, `EC-04`, `SC-01`, `SC-02` | `CHK-01`, `CHK-04` | `EVID-01`, `EVID-04` |
| `REQ-02` | `ASM-02`, `CON-01`, `DEC-02`, `CTR-02` | `EC-02`, `SC-03` | `CHK-02` | `EVID-02` |
| `REQ-03` | `CTR-03`, `FM-02` | `EC-02`, `SC-01`, `SC-02` | `CHK-02` | `EVID-02` |
| `REQ-04` | `CTR-04`, `FM-03` | `EC-02`, `SC-03` | `CHK-02` | `EVID-02` |
| `REQ-05` | `DEC-01`, `CON-03`, `FM-01` | `EC-01`, `SC-04` | `CHK-03` | `EVID-03` |
| `REQ-06` | `ASM-01`, `ASM-02`, `ASM-05`, `FM-02`, `FM-03`, `FM-04` | `EC-02`, `SC-05` | `CHK-02` | `EVID-02` |
| `REQ-07` | `CON-02` | `EC-03`, `SC-06` | `CHK-05` | `EVID-05` |
| `REQ-08` | `ASM-04` | `SC-07` | `CHK-06` | `EVID-06` |

### Acceptance Scenarios

- `SC-01` Polysemous lexeme (например `run`) имеет >= 2 senses после импорта. Каждый sense имеет definition и external_id. SentenceOccurrences для `run` привязаны к конкретным senses.
- `SC-02` Monosemous lexeme (например `cat`) имеет ровно 1 fallback sense. Все его occurrences привязаны к этому sense.
- `SC-03` SentenceOccurrence привязан к context_family. Два occurrence одного lexeme могут принадлежать разным context families (например `run` в спорте vs `run` в бизнесе).
- `SC-04` Импорт sense-данных из внешнего источника: парсинг файла, создание Sense записей, привязка к Lexeme. Лексемы без match в источнике получают fallback sense.
- `SC-05` Backfill: после миграции все существующие SentenceOccurrences имеют sense_id и context_family_id (no NULLs). Для polysemous occurrences привязка к primary sense через MFS baseline — приемлемый fallback, не требующий WSD (см. FM-02). Ручная курация — post-v1.
- `SC-06` После миграции: `Card.count`, `ReviewLog.count`, `SentenceOccurrence.count` не изменились. Существующие FK не сломаны.
- `SC-07` Импорт предложений из Tatoeba CSV: чтение локальных TSV-файлов, создание Sentence + SentenceTranslation + SentenceOccurrence для eng-rus пар. Повторный запуск --- идемпотентный (не создаёт дубли по `source: "tatoeba"` + sentence text uniqueness). Существующие записи `source: "quizword"` не затронуты.

### Negative / Edge Cases

- `NEG-01` Lexeme без match в словарном источнике --- получает fallback sense, не остаётся без sense.
- `NEG-02` SentenceOccurrence без классифицируемого контекста --- получает `unknown` context_family, не остаётся без family.
- `NEG-03` Повторный запуск импорта sense-данных --- идемпотентный (не создаёт дубли).
- `NEG-04` Lexeme с единственным occurrence --- корректно работает с одним sense и одной context_family.

### Checks

| Check ID | Covers | How to check | Expected result | Evidence path |
| --- | --- | --- | --- | --- |
| `CHK-01` | `EC-01`, `SC-01`, `SC-02` | `bundle exec rspec spec/models/sense_spec.rb` | Все тесты зелёные: создание, ассоциации, fallback | `artifacts/ft-029/verify/chk-01/` |
| `CHK-02` | `EC-02`, `SC-03`, `SC-05` | `bundle exec rspec spec/models/sentence_occurrence_spec.rb` + DB query: `SentenceOccurrence.where(sense: nil).or(SentenceOccurrence.where(context_family: nil)).count == 0` | Все occurrences mapped | `artifacts/ft-029/verify/chk-02/` |
| `CHK-03` | `SC-04`, `NEG-01`, `NEG-03` | `bundle exec rspec spec/operations/content_bootstrap/import_senses_spec.rb` | Импорт корректен, идемпотентен, fallback работает | `artifacts/ft-029/verify/chk-03/` |
| `CHK-04` | `EC-04`, `SC-01` | DB query по configured verification set: `Lexeme.where(id: CONFIGURED_TOP_100_POLYSEMOUS_IDS).joins(:senses).group(:id).having('COUNT(senses.id) >= 2').count.size == CONFIGURED_TOP_100_POLYSEMOUS_IDS.size` | Все configured top-100 covered | `artifacts/ft-029/verify/chk-04/` |
| `CHK-05` | `EC-03`, `SC-06` | `bundle exec rspec` (full suite green) + DB counts unchanged | Non-destructive migration confirmed | `artifacts/ft-029/verify/chk-05/` |
| `CHK-06` | `SC-07`, `NEG-03` | `bundle exec rspec spec/operations/sentences/import_tatoeba_spec.rb` | Импорт корректен, идемпотентен, quizword records не затронуты | `artifacts/ft-029/verify/chk-06/` |

### Test matrix

| Check ID | Evidence IDs | Evidence path |
| --- | --- | --- |
| `CHK-01` | `EVID-01` | `artifacts/ft-029/verify/chk-01/` |
| `CHK-02` | `EVID-02` | `artifacts/ft-029/verify/chk-02/` |
| `CHK-03` | `EVID-03` | `artifacts/ft-029/verify/chk-03/` |
| `CHK-04` | `EVID-04` | `artifacts/ft-029/verify/chk-04/` |
| `CHK-05` | `EVID-05` | `artifacts/ft-029/verify/chk-05/` |
| `CHK-06` | `EVID-06` | `artifacts/ft-029/verify/chk-06/` |

### Evidence

- `EVID-01` RSpec output: Sense model specs green.
- `EVID-02` RSpec output + DB query: all occurrences have sense and context_family.
- `EVID-03` RSpec output: ImportSenses operation specs green (import, fallback, idempotency).
- `EVID-04` DB query output: configured top-100 polysemous lexemes verification.
- `EVID-05` RSpec full suite output + DB count comparison before/after migration.
- `EVID-06` RSpec output: Sentences::ImportTatoeba operation specs green (import, idempotency, quizword isolation).

### Evidence contract

| Evidence ID | Artifact | Producer | Path contract | Reused by checks |
| --- | --- | --- | --- | --- |
| `EVID-01` | RSpec output log | verify-runner | `artifacts/ft-029/verify/chk-01/` | `CHK-01` |
| `EVID-02` | RSpec output + DB query log | verify-runner | `artifacts/ft-029/verify/chk-02/` | `CHK-02` |
| `EVID-03` | RSpec output log | verify-runner | `artifacts/ft-029/verify/chk-03/` | `CHK-03` |
| `EVID-04` | DB query output | verify-runner | `artifacts/ft-029/verify/chk-04/` | `CHK-04` |
| `EVID-05` | RSpec full suite + DB counts | verify-runner | `artifacts/ft-029/verify/chk-05/` | `CHK-05` |
| `EVID-06` | RSpec output log | verify-runner | `artifacts/ft-029/verify/chk-06/` | `CHK-06` |

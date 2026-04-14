---
title: "ADR-002: Таксономия context families v1"
doc_kind: adr
doc_function: canonical
purpose: "Фиксирует выбор таксономии контекстных семей v1 для FT-029: структуру (flat vs иерархия), источник labels, гранулярность и маппинг WordNet domains → context families. Разрешает DEC-02 из FT-029."
derived_from:
  - ../features/FT-029/feature.md
related_tasks:
  - "#29"
comment:
status: active
decision_status: accepted
date: 2026-04-14
date_accepted: 2026-04-14
audience: humans_and_agents
must_not_define:
  - current_system_state
  - implementation_plan
---

# ADR-002: Таксономия context families v1

**Related tasks:** GitHub Issue #29

## Контекст

FT-029 вводит доменную сущность `ContextFamily` — именованную группу контекстов употребления слова. Контекстная семья группирует предложения, использующие слово в схожей ситуации или домене: `run` в спорте vs `run` в бизнесе (`REQ-02`). Каждое `SentenceOccurrence` привязывается к `ContextFamily` через FK (`REQ-04`).

Без определения таксономии невозможно:
- Спроектировать таблицу `context_families` и её схему (структура: flat list или hierarchy — определяет наличие `parent_id`)
- Реализовать `AssignContextFamilies` operation (нужен маппинг source → family)
- Обеспечить fallback для неклассифицированных контекстов (`ASM-02`)

Это решение — `DEC-02` из `feature.md` FT-029.

ADR-001 (принят) выбирает WordNet 3.1 как источник sense-данных. WordNet содержит ~45 lexical domains (`noun.artifact`, `verb.motion`, `adj.all` и т.д.) — готовую coarse-grained классификацию, которая может служить входными данными для таксономии context families. Discovery проведён в [research-sense-sources.md](../features/FT-029/research-sense-sources.md), секция 8.

## Драйверы решения

- `REQ-02` — сущность `ContextFamily`: именованная группа контекстов, curated string label из контролируемого словаря.
- `REQ-04` — `SentenceOccurrence` получает FK на `ContextFamily`.
- `ASM-02` — v1 = curated string labels из контролируемого словаря; fallback для неклассифицированных = `unknown`.
- `NS-07` — алгоритмическая таксономия context families вне scope; v1 = curated labels.
- `FM-03` — context family классификация неоднозначна → fallback `unknown`.
- G-03 (PRD-002) — контекстное покрытие: для каждого слова/значения нужны примеры из разных контекстных семей.
- `MET-02` (PRD-002, не feature.md — в feature.md MET-02 = другой metric) — target: среднее >= 2 контекстных семьи на освоенное слово (среди слов с 2+ доступными семьями).
- Масштаб: 5949 лексем, ~60K+ `SentenceOccurrence` записей.

## Рассмотренные варианты

| Вариант | Плюсы | Минусы | Почему основной / не основной кандидат |
| --- | --- | --- | --- |
| **A. Consolidated flat list (~15-20 семей)** — маппинг WordNet domains в сокращённый curated список | Правильная гранулярность для learner context: достаточно широкий для различения контекстов (спорт vs бизнес), но не чрезмерно дробный. Human-readable labels ("food & drink" вместо "noun.food"). Simple DB schema: `name` (unique string) + `description`. Простые запросы без tree traversal. Легко итерировать: добавить/объединить семьи — тривиальная миграция. | Требует curated маппинг WordNet lexical domain → context family (~45 → ~16 строк). Некоторая потеря детальности: verb.motion и verb.competition → одна семья "movement & sports". | **Основной кандидат.** G-03 (разные контексты) и MET-02 (>= 2 семьи) требуют таксономии, которая различает основные ситуации. ~16 семей — достаточно для различения, но не создаёт шум. Flat list — минимальная сложность DB и queries для v1. Принцип 5 (design principles): минимальные затраты для проверки гипотезы. |
| **B. WordNet lexical domains как-is (~45 семей)** | Нулевая curation — каждый synset уже имеет lexical domain. Автоматическое назначение при импорте. Стандартная таксономия (Princeton WordNet). | Избыточная гранулярность: `noun.Tops` vs `noun.object` — learner не различает как разные контексты употребления. Технические labels (`noun.act`, `verb.stative`) — нужны display names. adj.all, adv.all — catch-all категории, не представляющие контекст. 45 семей → многие содержат <50 occurrences — недостаточно для meaningful grouping при ~60K occurrences. | **Не основной.** Гранулярность не соотносится с learner experience: learner видит "noun.Tops" vs "noun.object" как разные контексты — это не отражает ситуации употребления. Но lexical domains — ценный входной источник для Option A через consolidation mapping. Реальный плюс: нулевая curation. Но минус (избыточность) перевешивает для learner-focused таксономии. |
| **C. Two-level hierarchy (5-8 верхних доменов + 15-30 leaf-семей)** | Позволяет drill-down: "physical" → "sports", "health", "food". Гибкость: можно показывать сводную или детальную группировку в downstream features. | Сложнее DB schema: `parent_id`, tree queries (recursive CTE или closure tree). Преждевременная оптимизация для v1: ASM-02 говорит "curated string labels", не "hierarchy". UI для иерархии вне scope (NG-05). Нет downstream-потребителя иерархии в текущем scope — Session Builder v2 работает с flat families. | **Не основной.** Принцип 3 (design principles): следи за scope. Иерархия добавляет complexity без текущего потребителя. ASM-02 и NS-07 явно ограничивают v1 до curated labels. Если downstream features (Dashboard, Session Builder v2) потребуют drill-down — flat list можно обогатить до иерархии через additive migration (добавить `parent_id`), без breaking change. |

## Решение

Предлагается **consolidated flat list (~16 context families)** с маппингом из WordNet lexical domains.

**Границы решения:**

1. **Структура:** Flat list. Каждая `ContextFamily` = `name` (unique, human-readable string) + `description` (опционально). Нет `parent_id`, нет иерархии.

2. **Источник:** WordNet lexical domains (~45) консолидируются в ~16 context families через curated mapping. Маппинг живёт в коде `AssignContextFamilies` operation (не в DB).

3. **Fallback:** Occurrences без WordNet match (function words) и occurrences с adj.all/adv.all lexical domain получают context family `unknown`.

4. **Назначение:** `SentenceOccurrence` → `ContextFamily` через транзитивную цепочку: occurrence → sense → synset (lexical domain) → context family mapping.

5. **Итеративность:** Flat list позволяет добавлять/объединять семьи через миграции без изменения структуры данных. Переход к иерархии в будущем — additive change (добавить `parent_id`).

**Предварительный маппинг WordNet lexical domains → context families:**

| Context Family | WordNet Lexical Domains | Rationale |
| --- | --- | --- |
| people & relationships | noun.person, noun.group, verb.social | Люди, группы, социальные взаимодействия |
| communication | noun.communication, verb.communication | Речь, язык, передача информации |
| body & health | noun.body, verb.body | Тело, здоровье, физические функции |
| food & drink | noun.food, verb.consumption | Еда, питьё, потребление |
| movement & sports | verb.motion, verb.competition | Движение, спорт, соревнования |
| thinking & knowledge | noun.cognition, verb.cognition | Мышление, знание, обучение |
| emotions & feelings | noun.feeling, verb.emotion, noun.motive | Чувства, эмоции, мотивация |
| objects & tools | noun.artifact | Предметы, инструменты, технологии |
| nature & environment | noun.animal, noun.plant, noun.substance, noun.object, noun.phenomenon | Природа, животные, растения |
| places & travel | noun.location | Места, география, путешествия |
| time & events | noun.time, noun.event, verb.change | Время, события, изменения |
| actions & activities | noun.act, verb.creation | Действия, создание, активности |
| possession & commerce | noun.possession, verb.possession | Владение, торговля, финансы |
| physical interaction | verb.contact, verb.perception | Физический контакт, восприятие |
| weather | verb.weather | Погода, климатические явления |
| qualities & states | noun.attribute, noun.state, noun.process, noun.shape, noun.quantity, noun.Tops, noun.relation | Абстрактные качества, состояния, формы |
| unknown | adj.all, adj.ppl, adv.all, (no WordNet match) | Fallback: прилагательные/наречия без контекста, function words |

Итого: **17 context families** (16 тематических + 1 fallback `unknown`).

Точный маппинг верифицируется при реализации: прогнать все Oxford 5000 через WordNet, построить распределение occurrences по семьям. Если одна семья содержит >30% всех occurrences — кандидат на разделение. Предварительный маппинг может быть скорректирован до seeding.

## Последствия

### Положительные

- Context families автоматически назначаются через WordNet lexical domains — не нужен дополнительный внешний источник или ручная разметка каждого occurrence.
- Flat list — минимальная DB schema, простые queries, нет tree complexity.
- 17 семей — достаточно для различения контекстов (MET-02: >= 2 семьи на слово) без избыточной фрагментации.
- Human-readable labels — осмысленные для future UI (NG-05 out of scope, но labels готовы).
- Итеративность: семьи можно добавлять, объединять, разделять через миграции без architectural changes.

### Отрицательные

- Консолидация ~45 domains → ~17 семей теряет детальность. `verb.motion` (движение) и `verb.competition` (соревнования) попадают в одну семью "movement & sports" — хотя "run a race" и "run a business" — разные контексты. Mitigation: если распределение покажет скошенность, "movement & sports" можно разделить на две семьи — trivial migration.
- WordNet lexical domains — онтологическая (по типу понятия), а не ситуативная (по контексту употребления) классификация. "Run a meeting" → `verb.social` ("people & relationships"), но learner может ожидать "work & business". Для v1 это допустимый compromise (ASM-02: curated, не algorithmic).
- adj.all, adv.all (большинство прилагательных и наречий) → `unknown`. Существенная доля occurrences получит fallback. Mitigation: прилагательные и наречия часто модификаторы, а не носители контекста; downstream features могут weighted discount `unknown` при оценке context coverage.

### Нейтральные / организационные

- Mapping table (WordNet domain → context family) живёт в коде `AssignContextFamilies` operation — не в DB. Изменение маппинга = deploy, не миграция данных (семьи переименуются/добавляются через seed).
- `CTR-02` (контракт ContextFamily) остаётся: `id`, `name`, `description`. `name` = human-readable label из mapping.
- Обновить `FT-029/feature.md`: `DEC-02` → ссылка на ADR-002.
- Обновить `memory-bank/adr/README.md`: добавить ADR-002.

## Риски и mitigation

| Риск | Вероятность | Последствие | Mitigation |
| --- | --- | --- | --- |
| Слишком много occurrences в `unknown` (adj/adv/function words) | Высокая | MET-02 (>= 2 семьи) не достигается для слов с преимущественно adj/adv occurrences | (1) adj/adv occurrences часто не являются primary word в предложении — context coverage можно считать только по content word occurrences в downstream features. (2) Post-launch: добавить контекстные семьи для прилагательных (например, "appearance", "evaluation") — additive change, не breaking. (3) `unknown` — валидная семья, не ошибка. |
| Консолидация слишком агрессивна — разные контексты попадают в одну семью | Средняя | G-03 (разные контексты) частично не достигается: learner видит два предложения как "один контекст", хотя ситуации разные | (1) "movement & sports" можно разделить на "movement" и "competition" — trivial migration. (2) Критерий разделения: если семья содержит >30% всех occurrences — кандидат на разделение. (3) Flat list = легко refine без architectural changes. |
| WordNet lexical domain не отражает ситуативный контекст для части слов | Средняя | "Run a meeting" → "people & relationships" (verb.social), learner ожидает "work & business" | (1) Для v1 — допустимо (ASM-02: curated, итеративно). (2) Fallback `unknown` покрывает неклассифицируемые случаи. (3) Future: manual curation для high-frequency polysemous words, topic modeling. |

## Follow-up

1. **При реализации `AssignContextFamilies`:**
   - Верифицировать маппинг на реальных данных: прогнать текущий каталог лексем (Oxford + NGSL, с учётом nullable POS) через WordNet, построить распределение по lexical domains → context families. Если распределение сильно скошено (одна семья >30%) — скорректировать маппинг до seeding.
   - Seed `context_families` таблицу из mapping table.

2. **Уже связано:**
   - `FT-029/feature.md` ссылается на ADR-002 как accepted decision для `DEC-02`.
   - `memory-bank/adr/README.md` содержит ADR-002.
   - `REQ-02` (сущность ContextFamily) и `REQ-04` (FK SentenceOccurrence → ContextFamily) разблокированы.

3. **Downstream (post-FT-029):**
   - Session Builder v2 — учитывать распределение по context families при выборе best occurrence (G-03, BR-06).
   - Dashboard — human-readable labels готовы (`name` в `CTR-02`).
   - Если downstream features потребуют иерархию — flat list обогащается до hierarchy через additive migration (`parent_id`), без breaking change.

## Связанные ссылки

- [FT-029: Lexeme Sense & Context Families](../features/FT-029/feature.md)
- [FT-029 Research: Sense Data Sources](../features/FT-029/research-sense-sources.md)
- [ADR-001: Источник sense-данных для лексем](ADR-001-sense-data-source.md)
- [PRD-002: Word Mastery](../prd/PRD-002-word-mastery.md)

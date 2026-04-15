---
title: "FT-029: Spec Review Results"
doc_kind: review
doc_function: derived
purpose: "Результаты ревью спецификации FT-029: критичные и высокие замечания от 5 субагентов. Итерация 1."
derived_from:
  - feature.md
status: active
review_date: 2026-04-13
review_depth: standard
review_iteration: 1
audience: humans_and_agents
---

# FT-029: Spec Review Results

**Документ:** FT-029: Lexeme Sense & Context Families
**Дата ревью:** 2026-04-13
**Уровень:** Standard
**Показаны проблемы:** severity >= high
**Итерация:** 1 из 2
**Агентов запущено:** 5 из 10 (analyst, test, data, risk, axes)
**Статус:** Требует доработки

---

## Оценка объёма

| Verdict | Complexity | Модели | Endpoints | Операции |
|---------|------------|--------|-----------|----------|
| Влезает | M | 4 (2 new + 2 mod) | 0 | 3 |

---

## Покрытие по трём осям

| Фича | Что (PRD/US/AC) | Как (ERD/схема) | Проверка (Tests) |
|------|-----------------|-----------------|-------------------|
| F1: Sense Entity | [OK] REQ-01, MET-01/02, ASM-01 | [!] CTR-01, но нет constraints | [OK] SC-01/02, CHK-01 |
| F2: ContextFamily | [!] DEC-02 unresolved | [!] CTR-02, нет seed spec | [!] Только fallback 'unknown' |
| F3: Occ→Sense FK | [OK] REQ-03, MET-04 | [!] FM-02, нет алгоритма | [OK] SC-01/02, CHK-02 |
| F4: Occ→ContextFamily FK | [OK] REQ-04, MET-03 | [!] Нет алгоритма классификации | [OK] SC-03, CHK-02 |
| F5: Sense Import | [!] DEC-01 unresolved | [!] ImportSenses — stub | [OK] SC-04, NEG-01/03 |
| F6: Backfill Migration | [OK] REQ-06, FM-04 | [!] Нет migration strategy | [OK] SC-05, CHK-02 |
| F7: Non-Destructive | [OK] REQ-07, BR-08 | [OK] Change Surface | [OK] SC-06, CHK-05 |

**Полностью покрыты:** 4/7 | **Частично:** 3/7 (F2, F5, F6)

---

## Качество спецификации

| Источник | Крит. | Выс. | Сред. | Низ. |
|----------|-------|------|-------|------|
| Analyst (BIZ-*) | 3 | 7 | 7 | 3 |
| Test (TST-*) | 2 | 9 | 11 | 2 |
| Data (DAT-*) | 3 | 9 | 6 | 4 |
| Risk (RSK-*) | 3 | 5 | 9 | 0 |
| Axes (AXS-*) | 1 | 3 | 2 | 0 |
| **Итого** | **12** | **33** | **35** | **9** |
| **Уникальных тем (дедуп)** | **5** | **13** | — | — |

---

## Критичные проблемы (5 уникальных)

### CRIT-1. DEC-01 не принят — блокирует REQ-05, схему Sense и тесты

**ID:** `BIZ-GAP-001` `TST-UNT-001` `RSK-TEC-001` `AXS-HOW-001` `DAT-FEA-002`

Без решения о выборе источника (WordNet/Oxford) невозможно: определить формат `external_id`, тип `examples`, написать тесты на ImportSenses, спроектировать контракт. ADR не создан.

**Рекомендация:** Провести discovery: сравнить WordNet (Princeton, open license, synset-based) vs Oxford API (commercial, structured). Создать ADR для DEC-01 с критериями: лицензия, покрытие лексем, формат, сложность импорта.

### CRIT-2. DEC-02 не принят — блокирует REQ-02, REQ-04 и тесты ContextFamily

**ID:** `BIZ-GAP-002` `TST-UNT-002` `RSK-TEC-002` `AXS-WHAT-001`

Без таксономии context families невозможно: создать seed data, написать тесты, реализовать AssignContextFamilies. ADR не создан.

**Рекомендация:** Определить начальный список context family labels (например: sports, technology, business, daily_life, academic, literary, unknown). Зафиксировать в ADR с примерами и критериями классификации.

### CRIT-3. Не определено 'configured top-N' из MET-01 / EC-04

**ID:** `BIZ-GAP-003` `TST-AMB-001` `DAT-AMB-001`

N не указано, критерий отбора неизвестен (частотность? curated список?), источник конфигурации не определён. Exit criteria EC-04 непроверяемо.

**Рекомендация:** Зафиксировать N=100 (согласовать с PRD-002 MET-06). Определить: источник списка (curated seed file с headword-списком top-100 полисемичных слов), алгоритм выбора, где хранится конфигурация.

### CRIT-4. Схема Sense не имеет constraints: NOT NULL, unique, indexes

**ID:** `DAT-GAP-001` `DAT-GAP-002` `DAT-GAP-003`

Не определены: тип `examples` (jsonb? string? array?), обязательность полей, unique constraint на `(lexeme_id, external_id)`, индексы, `ContextFamily.name` уникальность.

**Рекомендация:**
- Sense: `lexeme_id` NOT NULL, `definition` NOT NULL, unique index на `(lexeme_id, external_id)`, index на `external_id` для lookup
- ContextFamily: `name` NOT NULL, unique constraint на `name`
- `examples`: определить тип (рекомендуется jsonb)
- Добавить `source` поле в Sense для мультиисточности

### CRIT-5. Два нерешённых решения блокируют 4 из 7 requirements

**ID:** `RSK-SCH-001` `RSK-SCH-002`

DEC-01 + DEC-02 вместе парализуют реализацию. Можно реализовать только REQ-01 (Sense entity), REQ-07 (non-destructive check). Downstream features (3 штуки) ждут.

**Рекомендация:** Принять решения по DEC-01 и DEC-02 как gate items. Параллельно вести discovery по обоим. Если решения затягивают — реализовать partial feature: Sense entity + fallback sense для всех lexemes. Context families отложить.

---

## Высокие проблемы (13 уникальных)

### HIGH-1. Нет алгоритма привязки Occurrence → Sense для полисемичных слов

**ID:** `TST-GAP-002` `DAT-GAP-006` `DAT-FEA-001` `AXS-HOW-002` `RSK-TEC-005`

FM-02 признаёт что привязка может требовать ручной разметки, но алгоритм не описан. Противоречит SC-05 (100% occurrences mapped). WSD вне scope (NS-04).

**Рекомендация:** Для v1: polysemous occurrences привязываются к primary sense (первому) с пометкой `needs_disambiguation: true`. SC-05 уточнить: "все occurrences имеют sense_id, возможно fallback для polysemous". Ручная курация — post-v1.

### HIGH-2. Migration strategy: NULL → backfill → NOT NULL не формализована

**ID:** `BIZ-INC-001` `TST-AMB-003` `DAT-GAP-004` `AXS-HOW-003` `RSK-TEC-007`

Стандартный Rails safe migration pattern (add nullable → backfill → SET NOT NULL) не зафиксирован. Нет batch size, timeout, resume strategy.

**Рекомендация:** 3 фазы: (1) add nullable FK, (2) backfill via rake task, batch size=500, transaction per batch, (3) SET NOT NULL отдельной миграцией. Описать rollback для каждой фазы.

### HIGH-3. Sense.pos конфликтует или дублирует Lexeme.pos

**ID:** `BIZ-AMB-003` `TST-EDG-001` `DAT-GAP-005`

Оба имеют поле `pos`. Неясно: может ли sense.pos отличаться от lexeme.pos?

**Рекомендация:** Вариант (b): `lexeme.pos` может быть nullable для полисемичных с разными POS, а `sense.pos` NOT NULL указывает конкретный POS каждого sense. Зафиксировать в ADR/контракте.

### HIGH-4. Нет on_delete стратегии для новых FK

**ID:** `DAT-GAP-007`

`sentence_occurrences → senses` и `→ context_families` — restrict, nullify или cascade?

**Рекомендация:**
- `senses → lexemes`: `dependent: :destroy` (sense не существует без lexeme)
- `sentence_occurrences → senses`: `on_delete: :restrict` (нельзя удалить sense с привязанными occurrences)
- `sentence_occurrences → context_families`: `on_delete: :nullify` (если family удалена, occurrence теряет классификацию)

### HIGH-5. Нет result contract для Operations

**ID:** `TST-GAP-004`

ImportSenses, AssignFallbackSenses, AssignContextFamilies — что возвращают при успехе, частичном успехе, ошибке?

**Рекомендация:** Определить result pattern: `{ success: true, created: N, skipped: N, errors: [] }`. Проверить конвенцию в domain/architecture.md.

### HIGH-6. Нет error handling для ImportSenses и backfill

**ID:** `TST-ERR-001` `TST-ERR-002`

Невалидный формат файла, битые записи, сбой в середине batch — поведение не специфицировано.

**Рекомендация:** (1) Ожидаемые ошибки парсинга: skip record + log warning. (2) Batch failure: per-batch transaction, skip failed batch + continue. (3) Result object с errors list. (4) Тестовые примеры невалидных входных данных.

### HIGH-7. Backfill на 9500+ lexemes — риск long-running migration

**ID:** `RSK-TEC-003` `RSK-OPS-001`

`sentence_occurrences` имеет `restrict_with_exception` на cards. Data migration потенциально долгая, нет rollback strategy.

**Рекомендация:** Data migration через отдельный rake task, не через db:migrate. Тестировать на production-подобном объёме. Rollback: очистить sense_id/context_family_id колонки.

### HIGH-8. Card не учитывает Sense в delegation

**ID:** `DAT-INC-002`

Card делегирует `:lexeme` через `sentence_occurrence`. После добавления Sense нужен ли `delegate :sense`?

**Рекомендация:** Уточнить в Change Surface: `card.rb` — добавление `delegate :sense, :context_family, to: :sentence_occurrence`. Проверить все места где используется `card.lexeme`.

### HIGH-9. ContextFamily не связана с Language

**ID:** `DAT-GAP-008`

Таксономия глобальная (одна на все языки) или per-language?

**Рекомендация:** Для v1: глобальная таксономия (одна на все языки). Зафиксировать решение явно. В future — per-language расширение.

### HIGH-10. Классификация occurrences по ContextFamily — нет алгоритма

**ID:** `BIZ-GAP-004` `TST-GAP-003` `AXS-HOW-005`

AssignContextFamilies описана как operation, но без внутренней логики.

**Рекомендация:** Для v1: все существующие occurrences получают context_family = 'unknown' (initial backfill). Классификация добавляется итеративно через seed data updates.

### HIGH-11. Нет user stories и ролей

**ID:** `BIZ-GAP-005` `BIZ-GAP-007`

Нет ни одной user story. Не определено кто запускает operations (admin? rake task? auto-deploy?).

**Рекомендация:** Добавить user stories: "Как контент-менеджер, я хочу импортировать sense-данные, чтобы система различала значения полисемичных слов". Operations запускаются через rake tasks, доступны администраторам.

### HIGH-12. External source licensing и gem dependency risk

**ID:** `RSK-TEC-004` `RSK-BIZ-001`

CON-03 требует approval для новых гемов. Лицензия WordNet vs коммерческий Oxford — не оценена.

**Рекомендация:** При DEC-01 предпочесть open-source (WordNet). Абстрагировать source через интерфейс ImportSenses. Оценить stdlib-only реализацию как fallback.

### HIGH-13. SC-05 (100% mapped) противоречит FM-02 (manual binding needed)

**ID:** `DAT-INC-001`

Для полисемичных: backfill не может автоматически привязать correct sense без WSD.

**Рекомендация:** Ввести промежуточный status: sense может быть `auto`, `fallback` (monosemous), `undetermined` (polysemous без WSD). SC-05 уточнить: "все occurrences имеют sense_id, включая undetermined fallback sense".

---

## Ключевые рекомендации (итог)

1. **Принять DEC-01 и DEC-02 как gate items** — создать ADR для обоих до начала реализации. Это разблокирует 4/7 requirements.

2. **Определить алгоритм occurrence→sense mapping** — для v1: все polysemous occurrences привязываются к первому/primary sense с пометкой `needs_disambiguation: true`. Это снимает противоречие SC-05 vs FM-02.

3. **Формализовать safe migration pattern** — 3 фазы: (1) add nullable FK, (2) backfill via rake task, (3) SET NOT NULL. Указать batch size = 500, transaction per batch.

4. **Дополнить схему Sense constraints** — NOT NULL, unique indexes, тип examples, on_delete стратегии.

5. **Рассмотреть split FT-029 → FT-029a + FT-029b** — FT-029a: Sense entity + fallback + nullable FK. FT-029b: Context families + import + NOT NULL. Это разблокирует downstream features раньше.

---

_Spec Review v1.11.0 | 2026-04-13_

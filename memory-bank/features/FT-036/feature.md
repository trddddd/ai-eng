---
title: "FT-036: Session Builder v2 — Dual-Level Scheduling"
doc_kind: feature
doc_function: canonical
purpose: "Расширяет session builder двухуровневым планированием: card debt (просроченные карточки по FSRS) + word debt (слова с низким контекстным покрытием). Пользователь получает в сессии не только повторение знакомых предложений, но и новые контексты для слабо покрытых слов."
derived_from:
  - ../../domain/problem.md
  - ../../prd/PRD-002-word-mastery.md
  - ../FT-031/feature.md
  - ../FT-034/feature.md
status: active
delivery_status: done
audience: humans_and_agents
must_not_define:
  - implementation_sequence
  - weight_model_for_contribution
  - fsrs_parameter_tuning
---

# FT-036: Session Builder v2 — Dual-Level Scheduling

> GitHub Issue: [xtrmdk/ai-eng#36](https://github.com/xtrmdk/ai-eng/issues/36)

## What

### Problem

`Reviews::BuildSession` строит сессию исключительно по card-level FSRS due date: `WHERE due <= now ORDER BY due ASC LIMIT 10`. После FT-031 и FT-034 система знает, какие слова имеют низкое контекстное покрытие (`sense_coverage_pct`, `family_coverage_pct` в `UserLexemeState`), но не использует эту информацию при формировании сессии. В результате пользователь повторяет одни и те же заученные предложения, а слова с полисемией или слабым покрытием не получают новых контекстов.

Feature-specific delta относительно PRD-002: эта фича реализует BR-06 (планировщик сессии учитывает card debt и word debt), G-02 (dual-level scheduling) и G-03 (контекстное покрытие через выбор unseen context families).

### Outcome

| Metric ID | Metric | Baseline | Target | Measurement method |
| --- | --- | --- | --- | --- |
| `MET-01` | При наличии word-debt candidates и отсутствии higher-priority due cards, сессия включает word-debt карточки | 0 word-debt cards | >= 1 word-debt card в сессии (PRD-002 MET-03) | RSpec: synthetic pool с word_debt candidates и пустой card debt |
| `MET-02` | Card debt приоритетнее word debt: при достаточном количестве due cards word-debt slots не вытесняют card debt | N/A | 100% due cards попадают в сессию до word-debt | RSpec: full card debt pool vs word debt |
| `MET-03` | Word debt occurrence selection предпочитает unseen context families | Random selection | Occurrence из невиденной context family выбирается первой | RSpec: lexeme с 3 occurrences, 1 family covered → выбирается occurrence из uncovered family |

### Scope

- `REQ-01` `Reviews::BuildSession` расширен двухуровневым алгоритмом: сначала card debt (due cards по FSRS), затем word debt (слова с низким покрытием) заполняет оставшиеся слоты до `limit`.
- `REQ-02` Card debt: карточки с `due <= now` и `mastered_at IS NULL`, сортировка `due ASC` — текущее поведение v1, без изменений.
- `REQ-03` Word debt: для каждого `UserLexemeState` с `family_coverage_pct < 100.0` найти occurrence с unseen context family, для которого у пользователя ещё нет card. Создать card для выбранного occurrence.
- `REQ-04` Occurrence selection при word debt: предпочтение occurrence из context family, не покрытой в `UserContextFamilyCoverage` для данного (user, lexeme). Если все families покрыты, но `sense_coverage_pct < 100.0` — предпочтение occurrence с unseen sense. Если ни sense, ни family unseen — skip этот lexeme.
- `REQ-05` Сессия возвращает единообразную коллекцию Card objects (card debt + word debt cards) — интерфейс для view не меняется. Новые card debt cards уже существуют в БД; word debt cards создаются on-demand.
- `REQ-06` Word debt candidate ranking: lexemes с наименьшим `family_coverage_pct` приоритетнее (самые слабо покрытые слова — первые в очереди). При равном `family_coverage_pct` — lexeme с более ранним `last_covered_at` (давно не видели).

### Non-Scope

- `NS-01` Весовая модель contribution (конкретные коэффициенты new_family vs reinforcement) — отдельная feature (PRD-002 BR-04 ADR).
- `NS-02` Word-level FSRS scheduling — word mastery state не является FSRS-картой, word debt определяется coverage, не FSRS due.
- `NS-03` Пользовательская настройка пропорций card debt / word debt — v1 использует фиксированную стратегию.
- `NS-04` Генерация новых предложений или контента — word debt работает только с существующими `SentenceOccurrence`.
- `NS-05` Dashboard изменения — dashboard уже показывает word progress (FT-034).
- `NS-06` Curriculum (рекомендация новых слов для изучения) — word debt работает только со словами, для которых у пользователя уже есть `UserLexemeState`.

### Constraints / Assumptions

- `ASM-01` FT-031 и FT-034 завершены: `UserLexemeState`, `UserSenseCoverage`, `UserContextFamilyCoverage`, `LexemeReviewContribution` существуют и обновляются в runtime.
- `ASM-02` `SentenceOccurrence` имеет nullable `sense_id` и `context_family_id`. Occurrences с `context_family_id IS NULL` исключаются из word debt candidate pool (нельзя определить, виденная ли family).
- `ASM-03` Card debt всегда приоритетнее word debt (PRD-002 BR-06). Если due cards >= limit — word debt не добавляется.
- `ASM-04` Word debt card creation: для выбранного occurrence создаётся Card с `due: now` (немедленно показать в сессии). FSRS state: `STATE_NEW` (0), все FSRS-параметры по умолчанию. Первый ответ пользователя запустит стандартный FSRS scheduling.
- `ASM-05` Один lexeme — максимум один word debt slot на сессию. Это предотвращает заполнение сессии карточками одного слова.
- `CON-01` Интерфейс `BuildSession.call(user:, limit:, now:)` сохраняется. Output — коллекция Card objects. View layer не меняется.
- `CON-02` Первичные ключи — UUID v7.
- `CON-03` Не подключать новые гемы.
- `CON-04` Не менять существующие миграции.
- `ASM-06` `limit` всегда > 0 при нормальном использовании. `limit: 0` → пустая коллекция без side effects (NEG-07).
- `CON-05` Performance: word debt query должен быть эффективным. Для v1 допус��им N+1 при маленьком pool (< 100 lexemes), но основные queries должны использовать существующие индексы.

## How

### Solution

`BuildSession` разделяется на два этапа: (1) card debt — текущий FIFO по due date, (2) word debt — fill remaining slots. Для word debt operation `BuildSession` находит lexemes с `family_coverage_pct < 100.0`, для каждого выбирает лучший unseen occurrence, создаёт Card и добавляет в сессию.

Главный trade-off: создание Card on-demand в BuildSession — побочный эффект в read operation. Альтернатива — pre-create cards для всех occurrences — создаёт тысячи лишних Card records. On-demand creation точнее и экономнее; card создаётся только когда word debt реально попадает в сессию.

### Change Surface

| Surface | Type | Why it changes |
| --- | --- | --- |
| `app/operations/reviews/build_session.rb` | code | Dual-level алгоритм: card debt + word debt |
| `spec/operations/reviews/build_session_spec.rb` | code (update) | Тесты для dual-level scheduling |

### Flow

1. `BuildSession.call(user:, limit:, now:)` вызывается.
2. **Card debt phase:** Query `Card.where(user:, mastered_at: nil).where("due <= ?", now).order(due: :asc).limit(limit)` — текущее поведение v1.
3. Вычислить `remaining_slots = limit - card_debt_count`.
4. Если `remaining_slots <= 0` — вернуть card debt cards (word debt не нужен).
5. **Word debt phase:**
   a. Query `UserLexemeState.where(user:).where("family_coverage_pct < 100.0").order(family_coverage_pct: :asc, last_covered_at: :asc)`.
   b. Для каждого candidate lexeme (до `remaining_slots`):
      - Найти uncovered context families: `SentenceOccurrence` с `context_family_id NOT IN (covered families)` для данного lexeme.
      - Если есть uncovered family occurrence и у user нет Card для этого occurrence — выбрать его.
      - Если все families покрыты, найти occurrence с uncovered sense.
      - Если подходящий occurrence найден — `Card.create!(user:, sentence_occurrence:, due: now)`.
   c. Добавить созданные word debt cards к результату.
6. Вернуть объединённую коллекцию: card debt cards + word debt cards (все — Card objects).

### Contracts

| Contract ID | Input / Output | Producer / Consumer | Notes |
| --- | --- | --- | --- |
| `CTR-01` | `BuildSession.call(user:, limit:, now:)` → Array/Relation of Card | `ReviewSessionsController` | Interface не меняется. Output содержит mix card debt + word debt cards. Word debt cards имеют `state: STATE_NEW`, `due: now`. |
| `CTR-02` | Word debt Card creation: `Card.create!(user:, sentence_occurrence:, due: now)` | `BuildSession` / FSRS scheduling | Card создаётся с default FSRS params (state=0, stability=0, difficulty=0). Первый ответ пользователя запускает стандартный FSRS flow. Unique constraint `(user_id, sentence_occurrence_id)` предотвращает дубли. |

### Failure Modes

- `FM-01` Нет word debt candidates (все lexemes имеют `family_coverage_pct = 100.0` или нет `UserLexemeState`): word debt phase возвращает пустой результат — сессия состоит только из card debt. Это нормальное поведение.
- `FM-02` Для word debt lexeme нет подходящего occurrence (все occurrences с `context_family_id IS NULL` или у user уже есть Card для каждого): skip lexeme, перейти к следующему candidate.
- `FM-03` Card creation fails (unique constraint violation — card для occurrence уже существует): skip этот occurrence, продолжить поиск. Race condition маловероятен (single-user sessions), но idempotent skip безопасен. Повторный вызов BuildSession для того же пользователя (например, double-click) — unique constraint `(user_id, sentence_occurrence_id)` предотвращает дубли word debt cards; skip + continue.
- `FM-04` Пустая сессия (ни card debt, ни word debt): BuildSession возвращает пустую коллекцию — существующий empty state в view обрабатывает это.

## Verify

### Exit Criteria

- `EC-01` При наличии due cards — они включены в сессию с приоритетом (card debt first).
- `EC-02` При наличии remaining slots и word debt candidates — сессия заполняется word debt cards.
- `EC-03` Word debt occurrence selection предпочитает unseen context family.
- `EC-04` Word debt card создаётся с корректными FSRS defaults и `due: now`.
- `EC-05` Один lexeme — максимум один word debt slot на сессию.
- `EC-06` Интерфейс `BuildSession.call(user:, limit:, now:)` не сломан — view продолжает работать.
- `EC-07` Существующие card debt tests не регрессируют.

### Traceability matrix

| Requirement ID | Design refs | Acceptance refs | Checks | Evidence IDs |
| --- | --- | --- | --- | --- |
| `REQ-01` | `ASM-03`, `CON-01`, `CTR-01` | `EC-01`, `EC-02`, `EC-06`, `SC-01`, `SC-02` | `CHK-01`, `CHK-02` | `EVID-01`, `EVID-02` |
| `REQ-02` | `ASM-03` | `EC-01`, `EC-07`, `SC-01` | `CHK-01` | `EVID-01` |
| `REQ-03` | `ASM-02`, `ASM-04`, `CTR-02`, `FM-02` | `EC-02`, `EC-04`, `SC-02`, `SC-03` | `CHK-02` | `EVID-02` |
| `REQ-04` | `ASM-02`, `FM-02` | `EC-03`, `SC-03`, `SC-05` | `CHK-02` | `EVID-02` |
| `REQ-05` | `CON-01`, `CTR-01` | `EC-06`, `SC-01`, `SC-02` | `CHK-01`, `CHK-03` | `EVID-01`, `EVID-03` |
| `REQ-06` | `FM-01` | `EC-02`, `SC-02` | `CHK-02` | `EVID-02` |

### Acceptance Scenarios

- `SC-01` **Card debt only:** Пользователь имеет 10 due cards. `BuildSession.call(limit: 10)` возвращает 10 card debt cards, отсортированных по `due ASC`. Word debt не добавляется.
- `SC-02` **Mixed session:** Пользователь имеет 3 due cards и 2 lexemes с `family_coverage_pct < 100.0`, для каждого есть occurrence с unseen family. `BuildSession.call(limit: 10)` возвращает 5 cards: 3 card debt + 2 word debt.
- `SC-03` **Unseen family preference:** Lexeme `run` имеет 3 occurrences: family `sports` (covered), family `business` (uncovered), family `cooking` (uncovered). Word debt выбирает occurrence из `business` или `cooking` (uncovered), не из `sports`.
- `SC-04` **No word debt candidates:** Все lexemes имеют `family_coverage_pct = 100.0`. `BuildSession.call(limit: 10)` возвращает только card debt cards (0–10), без word debt.
- `SC-05` **Sense fallback:** Lexeme `set` имеет 2 context families (обе covered в `UserContextFamilyCoverage`), но 1 sense uncovered в `UserSenseCoverage`. Word debt выбирает occurrence с uncovered sense, а не с uncovered family.

### Negative / Edge Cases

- `NEG-01` Пользователь без `UserLexemeState` записей (новый пользователь, ещё не ответил правильно): word debt phase не находит candidates — сессия только из card debt.
- `NEG-02` Lexeme с единственным occurrence, для которого Card уже существует: skip (нечего создавать).
- `NEG-03` Все occurrences word debt lexeme имеют `context_family_id IS NULL`: skip lexeme (ASM-02).
- `NEG-04` Word debt card creation race condition (Card для occurrence создан другим процессом): unique constraint → skip, продолжить (FM-03).
- `NEG-05` `remaining_slots = 0` (card debt заполнил всю сессию): word debt phase не запускается.
- `NEG-06` Lexeme с 3 uncovered occurrences из разных families — в сессию попадает ровно 1 word debt card от этого lexeme (ASM-05), остальные occurrences пропускаются.
- `NEG-07` `limit: 0` → пустая коллекция, без side effects (card creation не запускается).

### Checks

| Check ID | Covers | How to check | Expected result | Evidence path |
| --- | --- | --- | --- | --- |
| `CHK-01` | `EC-01`, `EC-06`, `EC-07`, `SC-01`, `SC-04`, `NEG-05` | `bundle exec rspec spec/operations/reviews/build_session_spec.rb` (card debt path) | Card debt cards returned correctly, sorted by due ASC, existing tests green | `artifacts/ft-036/verify/chk-01/` |
| `CHK-02` | `EC-02`, `EC-03`, `EC-04`, `EC-05`, `SC-02`, `SC-03`, `SC-05`, `NEG-01`, `NEG-02`, `NEG-03`, `NEG-06`, `NEG-07` | `bundle exec rspec spec/operations/reviews/build_session_spec.rb` (word debt path) | Word debt cards created for uncovered families, one per lexeme, correct FSRS defaults | `artifacts/ft-036/verify/chk-02/` |
| `CHK-03` | `EC-06`, All | `bundle exec rspec` (full suite green) | No regressions | `artifacts/ft-036/verify/chk-03/` |

### Test matrix

| Check ID | Evidence IDs | Evidence path |
| --- | --- | --- |
| `CHK-01` | `EVID-01` | `artifacts/ft-036/verify/chk-01/` |
| `CHK-02` | `EVID-02` | `artifacts/ft-036/verify/chk-02/` |
| `CHK-03` | `EVID-03` | `artifacts/ft-036/verify/chk-03/` |

### Evidence

- `EVID-01` RSpec output: BuildSession card debt path specs green (priority, sorting, limit).
- `EVID-02` RSpec output: BuildSession word debt path specs green (candidate selection, unseen family preference, card creation, one-per-lexeme).
- `EVID-03` RSpec full suite output: all green, no regressions.

### Evidence contract

| Evidence ID | Artifact | Producer | Path contract | Reused by checks |
| --- | --- | --- | --- | --- |
| `EVID-01` | RSpec output log | verify-runner | `artifacts/ft-036/verify/chk-01/` | `CHK-01` |
| `EVID-02` | RSpec output log | verify-runner | `artifacts/ft-036/verify/chk-02/` | `CHK-02` |
| `EVID-03` | RSpec full suite | verify-runner | `artifacts/ft-036/verify/chk-03/` | `CHK-03` |

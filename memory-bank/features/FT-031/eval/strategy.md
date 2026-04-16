# FT-031: Eval Strategy

## Eval Layers

### 1. Гигиена

Проверяет: синтаксис, стиль

| Check | Command | Evidence |
|-------|---------|----------|
| Lint pass? | `bundle exec rubocop` на новых/изменённых файлах | 0 offenses |
| Suite green? | `bundle exec rspec` | 0 failures |

### 2. Plan Coverage

Проверяет: все REQ-* прослеживаются к STEP-* и CHK-*

| REQ | STEP | CHK | Status |
|-----|------|-----|--------|
| REQ-01 UserLexemeState | STEP-01, STEP-02 | CHK-01 | ✅ |
| REQ-02 UserSenseCoverage | STEP-01, STEP-02 | CHK-02 | ✅ |
| REQ-03 UserContextFamilyCoverage | STEP-01, STEP-02 | CHK-02 | ✅ |
| REQ-04 RecordCoverage | STEP-05 | CHK-03, CHK-04 | ✅ |
| REQ-05 InitializeState | STEP-05 | CHK-01 | ✅ |
| REQ-06 Backfill rake task | STEP-06 | CHK-05 | ✅ |
| REQ-07 Card association | STEP-03 | CHK-01 | ✅ |

### 3. Acceptance

Проверяет: CHK-* имеют EVID-* и реальные результаты

| CHK | Evidence | Status |
|-----|----------|--------|
| CHK-01 UserLexemeState model | RSpec green | ✅ pass |
| CHK-02 Coverage models | RSpec green | ✅ pass |
| CHK-03 Coverage creation | RSpec green | ✅ pass |
| CHK-04 Idempotency + edges | RSpec green | ✅ pass |
| CHK-05 Backfill rake | RSpec green | ✅ pass |
| CHK-06 Full suite regression | 306 examples, 0 failures | ✅ pass |

### 4. Workflow

Проверяет: trajectory выполнения соответствует плану

| Проверка | Result |
|---------|--------|
| Пропущены шаги? | Eval suite создан пост-фактум (gap исправлен) |
| Правильный порядок? | STEP-01→08 sequential, корректный |
| Layered Rails review? | Выполнен, 0 critical violations |

### 5. Data Integrity

Проверяет: существующие данные не сломаны

| Проверка | Result |
|---------|--------|
| Cards сохранены? | Да — Card.count unchanged |
| ReviewLogs сохранены? | Да — ReviewLog.count unchanged |
| Миграции добавили только новые таблицы? | Да — 3 новых таблицы, 0 изменённых колонок |

## Decision Rules

- **Accept:** Все критические eval cases passed, evidence собран
- **Revise:** Есть failed eval cases, но исправления очевидны (1-2 итерации)
- **Escalate:** После 3 неудачных attempts или critical regression

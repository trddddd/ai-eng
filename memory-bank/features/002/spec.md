# [CLOSED] Content Bootstrap for Study MVP

> **[Approved by @trddddd 2026-04-03 | Closed 2026-04-03]**
> Спецификация прошла архитектурное и бизнес-ревью. Реализация завершена.
> Итераций: 1. Исправлено проблем: 10 (3 critical, 8 high → 0).

**Brief:** trddddd/ai-eng#2

## Цель

Создать языконезависимую доменную основу контента и наполнить её лексическими данными, чтобы следующая фича могла создавать пользовательские карточки поверх каталога.

## Scope

- **Входит:**
  - Доменные модели: `Language`, `Lexeme`, `LexemeGloss`
  - Миграции для всех новых моделей
  - Rake tasks для импорта лексем из `db/data`
  - `db/seeds.rb` как оркестратор rake tasks
  - Данные: Oxford 5000, NGSL Core, NGSL Spoken, Poliglot (переводы)

- **НЕ входит:** `Sentence`, `SentenceLink`, `SentenceOccurrence` (следующие задачи), пользовательские карточки, study flow, аудио, UI, cloze-рендеринг

## Схема моделей

### Language

| Поле | Тип | Constraints |
|------|-----|-------------|
| id | UUID v7 | PK |
| code | string | NOT NULL, UNIQUE (BCP-47: `en`, `ru`) |
| name | string | NOT NULL |
| created_at | timestamp | NOT NULL |
| updated_at | timestamp | NOT NULL |

### Lexeme

| Поле | Тип | Constraints |
|------|-----|-------------|
| id | UUID v7 | PK |
| language_id | UUID | FK → Language, NOT NULL |
| headword | string | NOT NULL |
| pos | string | nullable |
| cefr_level | enum | nullable: `a1`, `a2`, `b1`, `b2`, `c1` |
| created_at | timestamp | NOT NULL |
| updated_at | timestamp | NOT NULL |

**Unique index:** `(language_id, headword)`

### LexemeGloss

| Поле | Тип | Constraints |
|------|-----|-------------|
| id | UUID v7 | PK |
| lexeme_id | UUID | FK → Lexeme, NOT NULL |
| target_language_id | UUID | FK → Language, NOT NULL |
| gloss | text | NOT NULL |
| created_at | timestamp | NOT NULL |
| updated_at | timestamp | NOT NULL |

**Unique index:** `(lexeme_id, target_language_id, gloss)`

## Формат входных данных

### `db/data/oxford-5000.csv`
Заголовок: `word, level, pos, definition_url, voice_url`
- `word` — headword лексемы
- `level` — CEFR-уровень: `a1`, `a2`, `b1`, `b2`, `c1`
- `pos` — часть речи (noun, verb, adjective, …)
- `definition_url`, `voice_url` — игнорируются

### `db/data/ngsl-1-2.csv`
Без заголовка. Строки начинающиеся с `##` — комментарии, пропускаются.
Формат строки: `headword[, форма1, форма2, ...]`
- первый элемент — headword лексемы, остальные игнорируются
- `pos` и `cefr_level` — отсутствуют, сохраняются как `null`

### `db/data/ngsl-spoken-1-2.csv`
Заголовок: `Lemma, Rank, SFI, U`
- `Lemma` — headword лексемы
- `Rank`, `SFI`, `U` — игнорируются
- `pos` и `cefr_level` — отсутствуют, сохраняются как `null`

### `db/data/poliglot-translations.json`
JSON-объект с ключом `"data"` — массив объектов.
Каждый объект содержит:
- `"1"` — английское слово
- `"2"` — транскрипция (игнорируется)
- `"3"` — русские значения через `; ` (split → отдельный LexemeGloss на каждое)

Не все лексемы из вордлистов имеют перевод в этом файле — это допустимо.

## Требования

1. Все лексемы из Oxford 5000, NGSL Core и NGSL Spoken загружены в `Lexeme`
2. Импорт запускается в порядке: Oxford 5000 → NGSL Core → NGSL Spoken. Если headword уже существует (UNIQUE conflict) — пропускается (`on_conflict: :skip`). Таким образом Oxford имеет приоритет над NGSL.
3. При запуске импорта создаются Language-записи через `find_or_create_by`:
   - `Language.find_or_create_by(code: "en", name: "English")` — для лексем
   - `Language.find_or_create_by(code: "ru", name: "Russian")` — для глоссов
4. Для каждой лексемы с совпадением по headword в `poliglot-translations.json` (case-insensitive, downcase + strip) создаются `LexemeGloss`-записи: поле `"3"` разбивается по `"; "`, каждое значение — отдельная запись с `target_language_id = Language("ru").id`. Если в poliglot несколько строк для одного слова — значения объединяются.
5. Лексемы без совпадения импортируются без `LexemeGloss` — это допустимое состояние
6. Схема языконезависима: `Language` — отдельная сущность, добавление нового языка перевода не требует изменений схемы (только новые LexemeGloss с другим `target_language_id`)
7. Импорт идемпотентен — повторный запуск `db:seed` не дублирует данные
8. Импорт лексем и глоссов использует batch insert (`insert_all`) — единичные INSERT недопустимы
9. Полный холодный импорт завершается менее чем за 60 секунд на локальной машине (проверяется вручную: `time bin/rails db:seed` на пустой БД)

## Инварианты

- Все первичные ключи — UUID v7
- Каждый `Lexeme` принадлежит ровно одному `Language`
- `LexemeGloss` без привязанного `Lexeme` не существует
- `LexemeGloss` всегда имеет `target_language_id`

## Сценарии ошибок

- Файл отсутствует в `db/data` → rake task завершается с `raise "File not found: #{path}"` (exit code ≠ 0, имя файла в сообщении)
- Строка CSV невалидна (пустой или blank headword) → строка пропускается, `Rails.logger.warn("Skipping blank headword in #{file}")`
- Дубликат headword внутри одного вордлиста → `insert_all` с `on_conflict: :skip`, дубль молча игнорируется
- `poliglot-translations.json` не содержит ключ `"data"` → `raise "Invalid poliglot format: missing 'data' key"`

## Acceptance Criteria

- [ ] После `db:setup` в таблице `lexemes` есть записи из всех трёх вордлистов
- [ ] Лексемы из Oxford 5000 имеют заполненные `pos` и `cefr_level`
- [ ] Для лексем с совпадением в poliglot созданы `lexeme_glosses` с `target_language.code = "ru"`
- [ ] Слово с несколькими значениями в poliglot имеет несколько `lexeme_glosses`
- [ ] Лексемы без совпадения существуют без `lexeme_glosses` — без ошибок
- [ ] Повторный запуск `db:seed` не создаёт дубликатов
- [ ] Добавление `Language.create!(code: "fr", name: "French")` возможно без изменений схемы
- [ ] Полный холодный импорт завершается менее чем за 60 секунд (проверяется вручную)
- [ ] Все существующие тесты проходят
- [ ] Инварианты не нарушены

## Test Plan

Тесты пишутся по правилам проекта (RSpec).

**Unit-тесты для каждого Operation-класса** (`app/operations/`):
- happy path с fixture-файлом из `spec/fixtures/files/`
- сценарий: отсутствующий файл → `raise` с именем файла
- сценарий: строка с пустым headword → запись пропускается, gloss не создаётся
- сценарий: дубликат headword → count не изменяется при повторном вызове

**Fixture-файлы** (`spec/fixtures/files/`):
- минимальный CSV Oxford: 2 валидных строки + 1 с пустым headword
- минимальный CSV NGSL: 2 строки + комментарии `##`
- минимальный JSON poliglot: 2 слова, одно с несколькими значениями через `; `

**Assertions для ошибок:**
- `expect { operation.call }.to raise_error(RuntimeError, /oxford-5000.csv/)`
- `expect(Rails.logger).to receive(:warn).with(/Skipping/)`

## Ограничения

- Логика импорта — в Operation (`app/operations/`), не в модели и не в rake task напрямую
- Не подключать новые гемы без явного запроса
- Не модифицировать существующие миграции — только новые
- Первичные ключи — UUID v7 (без исключений)
- `db/seeds.rb` только вызывает rake tasks, сам контент в коде не хранится
- Контентные файлы — в `db/data`

---

_Spec Review v1.11.0 | 2026-04-03_

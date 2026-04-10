# Spec: Sentence Domain & Quizword Import

**Brief:** `memory-bank/features/004/brief.md`  
**Issue:** `trddddd/ai-eng#6`  
**Branch:** `feat/sentence-domain-and-import`

## Цель

Сохранить в БД английские предложения из Quizword, их русский перевод и одну найденную лексему для каждого импортированного предложения.

## Scope

**Implementation modules (max 3):**
1. Sentence Catalog: миграции и модели `Sentence`, `SentenceTranslation`, `SentenceOccurrence`
2. Quizword Import: `Sentences::ImportQuizword`
3. CLI entrypoint: `sentences:import_quizword`

**Входит:**
- три новые таблицы: `sentences`, `sentence_translations`, `sentence_occurrences`
- модели ActiveRecord для этих таблиц
- импорт страниц Quizword через `Net::HTTP`, `Thread`, `Queue`, `Nokogiri`
- идемпотентная пакетная вставка
- один rake task, который только вызывает операцию

**НЕ входит:**
- более одной лексемы на предложение
- другие источники данных
- UI, study flow, карточки, аудио-проигрывание
- переводы не на русский язык
- изменение существующих моделей `Lexeme`, `Language`, `LexemeGloss`, кроме чтения их данных

## Схема данных

### `sentences`

| Поле | Тип | Constraints |
|------|-----|-------------|
| id | UUID v7 | PK, `DEFAULT uuidv7()` |
| language_id | UUID | FK -> `languages.id`, NOT NULL |
| text | text | NOT NULL, без `____` |
| audio_id | integer | NULL |
| source | string | NOT NULL, значение `"quizword"` |
| created_at / updated_at | timestamp | NOT NULL |

Unique index: `(language_id, text)`

Index: `language_id`

### `sentence_translations`

| Поле | Тип | Constraints |
|------|-----|-------------|
| id | UUID v7 | PK, `DEFAULT uuidv7()` |
| sentence_id | UUID | FK -> `sentences.id`, NOT NULL |
| target_language_id | UUID | FK -> `languages.id`, NOT NULL |
| text | text | NOT NULL |
| created_at / updated_at | timestamp | NOT NULL |

Unique index: `(sentence_id, target_language_id)` (покрывает индекс на `sentence_id`)

FK `sentence_id` → `sentences.id` с `ON DELETE RESTRICT` (удаление `Sentence` не предусмотрено этой фичей).

### `sentence_occurrences`

| Поле | Тип | Constraints |
|------|-----|-------------|
| id | UUID v7 | PK, `DEFAULT uuidv7()` |
| sentence_id | UUID | FK -> `sentences.id`, NOT NULL |
| lexeme_id | UUID | FK -> `lexemes.id`, NOT NULL |
| form | string | NOT NULL |
| hint | string | NULL |
| created_at / updated_at | timestamp | NOT NULL |

Unique index: `(sentence_id, lexeme_id)` (покрывает индекс на `sentence_id`)

Index: `lexeme_id`

FK `sentence_id` → `sentences.id` с `ON DELETE RESTRICT`. FK `lexeme_id` → `lexemes.id` с `ON DELETE RESTRICT`.

`SentenceOccurrence#cloze_text` возвращает `sentence.text`, где **первое** вхождение `form` (точное совпадение с учётом регистра) заменено на `"____"`. Если `form` встречается несколько раз — заменяется только первое.

## Источник и парсинг

Источник: `https://quizword.net/ru-en/sentences/?page=N`

Для каждой страницы:
- HTML парсится через `Nokogiri::HTML`
- корневой набор узлов: `doc.xpath('//*[@id="main"]/div/div[*]')[1..-2] || []`
- `text_eng = node.search("div")[1]&.text&.strip`
- `text_rus = node.search("div")[4]&.text&.strip&.split("  ")&.first&.strip`
- `audio_source_html = node.search("div")[3]&.to_html.to_s`
- `audio_id = audio_source_html[/\b(\d{1,10})\b/, 1]&.to_i`

Если `text_eng.blank?` или `text_rus.blank?`, строка пропускается.

## Алгоритм выбора лексемы

Перед стартом пула потоков операция **один раз** загружает все `Lexeme.pluck(:id, :headword)` в память и передаёт как immutable структуру потокам. Для каждого `text_eng` кандидаты ищутся в этой структуре.

Кандидат подходит, если `text_eng.downcase.include?(headword.downcase)`.

Выбор кандидата детерминирован:
1. максимальная длина `headword`
2. при равной длине: минимальный индекс первого вхождения в `text_eng.downcase`
3. при равенстве индекса: лексема с лексикографически минимальным `headword.downcase`
4. при полном равенстве `headword.downcase`: запись с минимальным `lexemes.id`

`form` сохраняется как точная подстрока из `text_eng` по выбранному диапазону, с сохранением регистра. Если кандидатов нет, строка пропускается.

## Поведение операции

- Операция находит или создаёт `Language(code: "en", name: "English")` и `Language(code: "ru", name: "Russian")` **до старта пула потоков** (в главном треде); при `ActiveRecord::RecordNotUnique` — retry find. Предполагается наличие unique index на `languages.code`
- Значения env:
  - `START_PAGE`, `END_PAGE`, `CONCURRENCY`
  - default: `1`, `50`, `10`
  - все три значения должны быть целыми числами `>= 1`
  - `START_PAGE <= END_PAGE`
- При невалидном env операция завершаетcя с `abort "Invalid page range or concurrency"`
- Параллелизм реализован фиксированным пулом из `CONCURRENCY` потоков и `Queue`
- Батч вставки: `1000` строк
- Для каждой страницы вставки `sentences`, `sentence_translations`, `sentence_occurrences` оборачиваются в одну транзакцию; при DB-ошибке выполняется rollback и операция завершается через `abort` (fatal_error)
- Дубликаты пропускаются через bulk insert со skip-on-conflict (`ON CONFLICT DO NOTHING`) семантикой по unique index таблиц; поля `audio_id` и `hint` при повторном импорте не обновляются
- Rake task `sentences:import_quizword` не содержит бизнес-логики и только вызывает `Sentences::ImportQuizword.call`

## Состояния и ошибки

Для этой фичи состояние `loading/in_progress` как пользовательское состояние отсутствует: импорт запускается как CLI-операция без интерактивного UI. Во время выполнения допускается только финальный summary stdout после завершения операции или `abort` при `fatal_error`.

| Состояние | Условие | Exit code | Наблюдаемое поведение |
|----------|---------|-----------|------------------------|
| `success` | есть хотя бы 1 импортированное предложение и `failed_urls.empty?` | `0` | stdout: `Quizword done. Imported: X. Failed URLs: 0. Skipped rows: Y` |
| `partial_success` | `failed_urls.any?`, независимо от числа импортированных предложений | `0` | stdout в том же формате, `Failed URLs > 0` |
| `empty` | `Imported: 0` и `failed_urls.empty?` | `0` | stdout в том же формате, `Imported: 0` |
| `fatal_error` | невалидный env, пустая таблица `lexemes`, или исключение БД | `1` | операция завершается через `abort` и ничего не пишет в summary stdout |

| Ситуация | Поведение |
|----------|----------|
| Пустой `text_eng` или `text_rus` | строка пропускается, `skipped_rows += 1` |
| Нет matching лексемы | строка пропускается, `skipped_rows += 1` |
| HTTP `429` | URL добавляется в `failed_urls`, обработка продолжается |
| HTTP status, отличный от `200` и `429` | URL добавляется в `failed_urls`, обработка продолжается |
| `Net::OpenTimeout`, `Net::ReadTimeout`, `SocketError`, `EOFError`, `Errno::ECONNRESET` | 3 попытки с exponential backoff (1s / 2s / 4s); если все 3 упали — URL добавляется в `failed_urls`, обработка продолжается |
| `Lexeme.count == 0` до старта импорта | `abort "No lexemes in DB. Run content_bootstrap:import_all first"` |

## Инварианты

- каждый `SentenceOccurrence` ссылается на существующий `Sentence` и существующий `Lexeme`
- `Sentence.text` не содержит `____`
- `Sentence.source == "quizword"` для всех записей, созданных этой фичей
- `SentenceOccurrence.form` непустой и совпадает с подстрокой в `Sentence.text`
- `SentenceOccurrence#cloze_text` содержит ровно одно `____`
- для каждого импортированного `Sentence` существует ровно один `SentenceTranslation` с `target_language_id = ru`
- все PK новых таблиц используют UUID v7

## Acceptance Criteria

- [ ] На чистой БД `bin/setup --skip-server` поднимает схему без ручных шагов для этой фичи
- [ ] Operation spec с fixture-страницей из 3 блоков (`2` валидных, `1` пустой) создаёт ровно `2` `sentences`, `2` `sentence_translations`, `2` `sentence_occurrences`
- [ ] Для fixture, где в предложении встречаются `run` и `running`, выбирается `running`
- [ ] Для fixture с одинаковой длиной headword выбирается кандидат по правилам: earliest index, затем лексикографический `headword`, затем минимальный `lexeme.id`
- [ ] `SentenceOccurrence#cloze_text` заменяет **первое** вхождение `form` на `"____"` (`text = "Run and run"`, `form = "run"` → `"Run and ____"`)
- [ ] Повторный запуск импорта с тем же fixture не меняет counts трёх таблиц
- [ ] При HTTP `429` или `Net::ReadTimeout` URL попадает в `failed_urls`, операция завершается с exit code `0`, если хотя бы одна страница импортировалась
- [ ] При `Lexeme.count == 0` операция завершается с `abort "No lexemes in DB. Run content_bootstrap:import_all first"` и не создаёт записей
- [ ] При `START_PAGE=3 END_PAGE=1` операция завершается с `abort "Invalid page range or concurrency"` и не создаёт записей

## Test Plan

**Preconditions:** каждый test case создаёт нужные данные через FactoryBot: `Language(code: 'en')`, `Language(code: 'ru')`, и `Lexeme` с headword, совпадающими с fixture HTML. Реальные HTTP-запросы к quizword.net в тестах подменяются через `allow(Net::HTTP).to receive(:get_response)`; новые библиотеки для HTTP-mocking не добавляются.

- `spec/models/sentence_spec.rb`: обязательность полей, уникальность `(language_id, text)`, запрет `____` в `text`
- `spec/models/sentence_translation_spec.rb`: обязательность полей, уникальность `(sentence_id, target_language_id)`
- `spec/models/sentence_occurrence_spec.rb`: обязательность полей, уникальность `(sentence_id, lexeme_id)`, `#cloze_text`
- `spec/operations/sentences/import_quizword_spec.rb`:
  - happy path на локальном fixture HTML
  - blank row skip
  - no-match skip
  - longest-match
  - tie-break rules
  - idempotency on rerun
  - `429` and timeout handling
  - abort on empty lexemes
  - abort on invalid env
- `bundle exec rubocop` не добавляет новых нарушений

## Ограничения на реализацию

- не изменять существующие миграции задним числом
- каждая новая миграция изменяет только одну таблицу
- не добавлять новые gem-зависимости
- не использовать `ContentBootstrap::BaseOperation`
- не переносить бизнес-логику в rake task

_Spec v2.2 | 2026-04-04_

---

> **[Approved by @trddddd 2026-04-04]**
> Спецификация прошла архитектурное и бизнес-ревью.
> Итераций: 1. Исправлено проблем: 10.

---

_Spec Review v1.11.0 | 2026-04-04_

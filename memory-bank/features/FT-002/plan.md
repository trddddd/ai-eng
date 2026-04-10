# Plan: Content Bootstrap for Study MVP

**Feature:** 002  
**Inputs:** `memory-bank/features/002/brief.md`, `memory-bank/features/002/spec.md`

## Что это за plan

Этот документ описывает не только "что сделать", но и "в каком порядке это делать именно в этом репозитории", с учётом текущего Rails skeleton, существующих данных в `db/data`, ограничений по UUID v7 и требований к идемпотентному импорту.

Если между планированием и реализацией кодовая база изменится, grounding нужно прогнать заново.

## Оркестрация

**Паттерн:** один агент, преимущественно последовательная реализация.

Почему не параллельно:
- в проекте пока нет существующего content-domain слоя;
- шаги сильно завязаны на схему и контракт Operation-классов;
- ранний параллелизм создаст лишние конфликты в миграциях, моделях и тестовых фикстурах.

Где допустим локальный параллелизм:
- после стабилизации схемы можно независимо писать unit-спеки для отдельных import-операций;
- фикстуры можно готовить параллельно с тестами, но не раньше, чем зафиксирован формат входа/выхода операций.

## Preconditions

1. Поднять baseline до `PostgreSQL 18+` во всех dev-docs и локальном окружении.
2. Привести Bundler-окружение в рабочее состояние через `bundle install` или `bin/setup`.
3. Только после этого запускать `bin/rails` и `bundle exec rspec`.
4. Перед стартом реализации заново проверить grounding, если появились новые коммиты или незнакомые изменения в дереве.

Причина: сейчас приложение не бутится, потому что git-зависимость `rb-fsrs` ещё не checkout'нута Bundler.

## Пошаговая реализация

### 1. Зафиксировать database baseline: PostgreSQL 18+ и DB-generated UUID v7

**Что делаем**
- Обновляем project baseline до `PostgreSQL 18+`.
- Фиксируем правило: новые UUID генерируются только в БД через `DEFAULT uuidv7()`.
- В рамках реализации фичи 2 не добавляем Ruby-side UUID generation и не делаем fallback через `SecureRandom.uuid_v7`.
- Оставляем текущий контракт подключения через env как источник правды:
  - `config/database.yml` не переписываем;
  - используем уже существующие `.env` и `.envrc`, где заданы `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`;
  - baseline-шаг не меняет способ подключения, а только обновляет версию PostgreSQL и документацию.
- Одновременно планируем обновление repo-артефактов, которые уже зашиты на PostgreSQL 16:
  - `docker-compose.yml`
  - `README.md`
- Добавляем project-level guardrail в `config/application.rb`, чтобы новые генераторы Rails по умолчанию создавали `uuid` primary keys, а не bigint.
  - В файле уже есть блок `config.generators do |g| ... end` — добавляем строку внутрь него:
    ```ruby
    g.orm :active_record, primary_key_type: :uuid
    ```
  - Не добавлять как отдельный `config.generators.orm` снаружи блока — это создаст два разрозненных блока настройки.
- Явно фиксируем шаблон для новых миграций с `DEFAULT uuidv7()`:
  ```ruby
  create_table :languages, id: false do |t|
    t.column :id, :uuid, primary_key: true, default: -> { "uuidv7()" }
    # остальные колонки...
  end
  ```
  **Важно:** `id: :uuid` без явного `default` создаст `DEFAULT gen_random_uuid()` (UUID v4), что нарушит инвариант. Нужен именно `id: false` + явное определение колонки.

**Почему так**
- Это делает БД единым источником правды для генерации идентификаторов.
- Это убирает дублирование правил между Rails и PostgreSQL.
- Это лучше согласуется с требованием "UUID v7 без исключений" для новых таблиц.
- В текущем репозитории уже зашит `postgres:16-alpine`, так что смена baseline должна быть отражена явно, а не подразумеваться.
- Без project-level guardrail следующий `rails generate model` снова может вернуть проект к bigint PK.
- `config/database.yml` уже совместим с текущим Docker-контрактом через env, поэтому менять его не требуется.

**Зависимости**
- Нет.

### 2. Добавить preflight-check на PostgreSQL 18+

**Что делаем**
- Добавляем раннюю проверку версии PostgreSQL в setup/bootstrap path проекта.
- Точка интеграции: `bin/setup`.
- Проверка выполняется до `db:prepare`.
- Проверка должна падать с понятным сообщением, если `server_version_num < 180000`.

**Почему так**
- Переход на `uuidv7()` зависит от версии PostgreSQL и должен проверяться отдельно, до запуска миграций.
- Это делает шаг атомарным: его можно проверить независимо от content-domain изменений.

**Зависимости**
- Шаг 1.

### 3. Добавить схему content-domain

**Что делаем**
- Создаём новую миграцию для таблиц `languages`, `lexemes`, `lexeme_glosses`.
- Все новые PK — через шаблон из шага 1: `id: false` + `t.column :id, :uuid, primary_key: true, default: -> { "uuidv7()" }`.
- Все FK — тип `:uuid`, без дефолта (значение приходит из PK связанной записи).
- Не использовать `id: :uuid` без явного `default` — это даст UUID v4.
- Добавляем уникальные индексы:
  - `languages(code)`
  - `lexemes(language_id, headword)`
  - `lexeme_glosses(lexeme_id, target_language_id, gloss)`
- Для `lexemes.cefr_level` используем string-колонку без DB enum и без DB `CHECK`; допустимые значения фиксируем в модели через Rails enum/validation.

**Почему так**
- Это минимально инвазивно для текущего skeleton'а.
- Не затрагивает старую миграцию `users`, что соответствует constraint "existing migrations не менять".
- Генерация UUID остаётся на стороне БД, а не размазывается между schema и application code.

**Зависимости**
- Шаг 2.

### 4. Создать доменные модели и их инварианты

**Что делаем**
- Добавляем:
  - `app/models/language.rb`
  - `app/models/lexeme.rb`
  - `app/models/lexeme_gloss.rb`
- Описываем ассоциации:
  - `Language has_many :lexemes`
  - `Language has_many :targeted_lexeme_glosses, class_name: "LexemeGloss", foreign_key: :target_language_id, inverse_of: :target_language`
  - `Lexeme belongs_to :language`
  - `Lexeme has_many :lexeme_glosses`
  - `LexemeGloss belongs_to :lexeme`
  - `LexemeGloss belongs_to :target_language, class_name: "Language"`
- Добавляем валидации присутствия и enum/validation для `cefr_level`.

**Почему так**
- Следующие шаги импорта должны опираться на явную доменную модель, а не на raw SQL по таблицам без контрактов.
- Для Rails-проекта с multilingual content-domain явная target-side association на `Language` делает модель навигационно полной и упрощает дальнейшие запросы и тесты без лишних ad hoc joins.

**Зависимости**
- Шаг 3.

### 5. Завести слой операций импорта

**Что делаем**
- Создаём `app/operations/content_bootstrap/`.
- Вводим базовый application-layer service object:
  - `app/operations/content_bootstrap/base_operation.rb`
- Все конкретные import-операции наследуются от него.
- `BaseOperation` отвечает за общий контракт операций, например:
  - проверка существования файла;
  - общий `timestamp`;
  - нормализация headword;
  - batched `insert_all`.
- Каждая операция получает путь к файлу и, при необходимости, зависимости вроде `source_language`/`target_language`.

**Почему так**
- Спека явно требует вынести логику в `app/operations/`, а не в модели и не в rake task.
- В проекте такого слоя ещё нет, поэтому его лучше сразу оформить единообразно.
- При DB-generated UUID операции становятся проще: они готовят только доменные данные, не отвечая за идентификаторы.
- Это соответствует layered-rails подходу: orchestration живёт в application layer, а не размазывается по моделям; service objects используются как управляемый application-layer boundary, а не как случайный `app/services` bag.

**Зависимости**
- Шаг 4.

### 6. Реализовать три независимые операции импорта лексем

**Что делаем**
- Добавляем отдельные operation-файлы и классы:
  - `app/operations/content_bootstrap/import_oxford_lexemes.rb` -> `ContentBootstrap::ImportOxfordLexemes`
  - `app/operations/content_bootstrap/import_ngsl_core_lexemes.rb` -> `ContentBootstrap::ImportNgslCoreLexemes`
  - `app/operations/content_bootstrap/import_ngsl_spoken_lexemes.rb` -> `ContentBootstrap::ImportNgslSpokenLexemes`
- Поведение операций:
  - находят или создают `Language(code: "en", name: "English")`;
  - читают свой формат файла;
  - пропускают blank headword с `Rails.logger.warn`;
  - подготавливают массив row hash для `Lexeme.insert_all`;
  - используют `unique_by` по индексу `(language_id, headword)` и режим skip;
  - сохраняют `pos`/`cefr_level` только там, где они есть по спецификации.

**Важно по данным**
- Порядок вызова в оркестраторе жёсткий: Oxford -> NGSL Core -> NGSL Spoken.
- Приоритет Oxford обеспечивается именно этим порядком плюс `on_conflict: :skip`.
- `headword` нужно как минимум `strip`; downcase для хранения делать не нужно без отдельного требования, чтобы не искажать исходный контент.

**Зависимости**
- Шаг 5.

### 7. Реализовать операцию импорта переводов Poliglot

**Что делаем**
- Добавляем operation-файл и класс:
  - `app/operations/content_bootstrap/import_poliglot_glosses.rb` -> `ContentBootstrap::ImportPoliglotGlosses`
- Операция работает с `poliglot-translations.json`.
- Операция:
  - находит или создаёт `Language(code: "ru", name: "Russian")`;
  - читает JSON из `db/data`;
  - валидирует наличие ключа `"data"`;
  - строит in-memory map: `normalized_headword -> [gloss1, gloss2, ...]`;
  - объединяет несколько записей одного слова;
  - делит поле `"3"` по `"; "`;
  - убирает пустые и дублирующиеся gloss values;
  - одним запросом поднимает английские `Lexeme`;
  - матчится case-insensitive через `downcase + strip`;
  - делает batched `insert_all` в `lexeme_glosses`.

**Критичный grounding-факт**
- Файл содержит битые байты в игнорируемом поле транскрипции `"2"`.
- Прямой `JSON.parse(File.read(...))` падает по encoding.
- Значит чтение должно быть tolerant: `File.binread(...).force_encoding("UTF-8").scrub`, и только потом `JSON.parse`.

**Зависимости**
- Шаг 6, потому что glosses зависят от уже импортированных lexeme.

### 8. Собрать rake orchestration и `db/seeds.rb`

**Что делаем**
- Добавляем `lib/tasks/content_bootstrap.rake`.
- Делаем granular tasks для отдельных операций:
  - `content_bootstrap:import_oxford_lexemes`
  - `content_bootstrap:import_ngsl_core_lexemes`
  - `content_bootstrap:import_ngsl_spoken_lexemes`
  - `content_bootstrap:import_poliglot_glosses`
- Добавляем aggregate task:
  - `content_bootstrap:import_all`
- В `db/seeds.rb` оставляем только orchestration-вызов `content_bootstrap:import_all`, без бизнес-логики импорта.

**Рекомендуемый порядок orchestration**
1. Oxford
2. NGSL Core
3. NGSL Spoken
4. Poliglot glosses

**Почему так**
- Это соответствует приоритету источников из спеки.
- Сохраняет `db/seeds.rb` тонким и предсказуемым.

**Зависимости**
- Шаги 6-7.

### 9. Покрыть поведение unit-спеками и фикстурами

**Что делаем**
- Создаём fixture-файлы в `spec/fixtures/files/`:
  - минимальный Oxford CSV;
  - минимальный NGSL CSV;
  - минимальный NGSL Spoken CSV;
  - минимальный Poliglot JSON.
- Добавляем unit-спеки для каждой операции в `spec/operations/content_bootstrap/`:
  - `spec/operations/content_bootstrap/import_oxford_lexemes_spec.rb`
  - `spec/operations/content_bootstrap/import_ngsl_core_lexemes_spec.rb`
  - `spec/operations/content_bootstrap/import_ngsl_spoken_lexemes_spec.rb`
  - `spec/operations/content_bootstrap/import_poliglot_glosses_spec.rb`
- При необходимости добавляем лёгкие model-спеки на ассоциации/валидации новых моделей.

**Что обязательно проверить**
- happy path;
- отсутствующий файл -> `raise` с именем файла;
- blank headword -> warn + skip;
- повторный вызов не создаёт дубликаты;
- Poliglot слово с несколькими значениями создаёт несколько `LexemeGloss`;
- отсутствие перевода не ломает импорт.
- baseline PostgreSQL 18+ зафиксирован в `docker-compose.yml`, а `bin/setup` вручную подтверждает, что setup-path проходит на этом baseline без дополнительных обходных путей.

**Зависимости**
- Шаги 2-8.

### 10. Провести ручную верификацию и замкнуть acceptance loop

**Что делаем**
- Запускаем `bundle exec rspec`.
- На пустой БД запускаем `bin/rails db:seed`.
- Повторно запускаем `bin/rails db:seed` и сравниваем counts.
- Проверяем базовые выборки в консоли или через `bin/rails runner`.
- Отдельно меряем холодный импорт: `time bin/rails db:seed`.

**Зависимости**
- Шаг 9.

## Зависимости между шагами

```text
Preconditions
  -> 1. PostgreSQL 18+ baseline + DB uuidv7()
  -> 2. PostgreSQL 18+ preflight check
  -> 3. Migration
  -> 4. Models
  -> 5. Base import infrastructure
  -> 6. Lexeme import operations
  -> 7. Poliglot gloss import
  -> 8. Rake + seeds orchestration
  -> 9. Specs + fixtures
  -> 10. Manual verification
```

Критические блокеры:
- без шага 2 нельзя надёжно опираться на `uuidv7()` в миграциях;
- без шага 3 нельзя стабильно писать импорт и тесты;
- без шага 6 нельзя делать gloss import;
- без рабочего Bundler нельзя прогнать ни тесты, ни ручную верификацию.

## Grounding по текущему коду

### Какие файлы точно будут затронуты

**Уже существуют и будут изменены**
- `README.md`
- `docker-compose.yml`
- `config/application.rb`
- `bin/setup`
- `db/seeds.rb`
- `db/schema.rb` после применения новой миграции

**С высокой вероятностью будут созданы**
- `app/models/language.rb`
- `app/models/lexeme.rb`
- `app/models/lexeme_gloss.rb`
- `app/operations/content_bootstrap/base_operation.rb`
- `app/operations/content_bootstrap/import_oxford_lexemes.rb`
- `app/operations/content_bootstrap/import_ngsl_core_lexemes.rb`
- `app/operations/content_bootstrap/import_ngsl_spoken_lexemes.rb`
- `app/operations/content_bootstrap/import_poliglot_glosses.rb`
- `db/migrate/*_create_languages_lexemes_lexeme_glosses.rb`
- `lib/tasks/content_bootstrap.rake`
- `spec/fixtures/files/*`
- `spec/operations/content_bootstrap/import_oxford_lexemes_spec.rb`
- `spec/operations/content_bootstrap/import_ngsl_core_lexemes_spec.rb`
- `spec/operations/content_bootstrap/import_ngsl_spoken_lexemes_spec.rb`
- `spec/operations/content_bootstrap/import_poliglot_glosses_spec.rb`
- возможно `spec/models/language_spec.rb`, `spec/models/lexeme_spec.rb`, `spec/models/lexeme_gloss_spec.rb`

### Как план ложится на текущую архитектуру

- Проект сейчас минимальный: есть только `User`, auth-контроллеры и базовый Rails skeleton.
- `app/operations/` ещё отсутствует, но это нормальная точка расширения для Rails, конфликта с текущим кодом нет.
- `lib/tasks/` пустой, так что task namespace можно вводить свободно.
- `db/data/` уже содержит все четыре входных файла, и форматы Oxford/NGSL/NGSL Spoken совпадают со spec.
- Но текущий infra baseline ещё не совпадает с новым решением: в репозитории задокументирован и зашит `PostgreSQL 16`, поэтому переход на `uuidv7()` требует обновить окружение, а не только миграции.
- Конфигурация подключения уже работает через `.env` + `.envrc`: `config/database.yml` читает env-переменные, а `.env` задаёт `DB_PORT=5433`, так что менять `config/database.yml` не требуется.
- В `README.md` есть ссылка на `.env.example`, но такого файла сейчас нет в репозитории, поэтому в baseline-шаге нужно убрать это упоминание или заменить его на описание текущего `.env`-контракта.

### Найденные противоречия и риски

1. **Глобальное правило UUID v7 уже нарушено существующим `users` table.**  
   Это не блокирует фичу 2, если ограничить план новыми content-таблицами. Но это нужно понимать: фича 2 не исправит историческое отклонение в `users`.

2. **Текущий repo baseline ещё на PostgreSQL 16.**  
   `README.md` и `docker-compose.yml` явно указывают на PostgreSQL 16, а новое решение требует `PostgreSQL 18+`. Это нужно обновить до начала реализации, иначе план и реальное окружение будут расходиться.

3. **Окружение не готово к запуску Rails-команд.**  
   `bin/rails` сейчас падает, потому что Bundler не checkout'нул git dependency `rb-fsrs`. Перед реализацией нужен `bundle install` или `bin/setup`.

4. **Poliglot JSON нельзя читать наивно.**  
   В файле есть некорректные байты в поле транскрипции. Их нужно scrub'ить до `JSON.parse`, иначе импорт будет падать.

5. **В проекте нет заготовки под import/service pattern.**  
   Это не конфликт, но означает, что naming и базовый контракт операций нужно определить сразу и последовательно использовать.

## Feasibility

План технически осуществим в рамках текущего проекта.

Почему:
- данных порядка 9.5k лексем, это умеренный объём;
- `insert_all` подходит под требование batch insert и под лимит производительности;
- при `PostgreSQL 18+` можно держать UUID v7 generation в самой БД через `DEFAULT uuidv7()`;
- project-level guardrail в `config/application.rb` предотвращает возврат к bigint PK в будущих генераторах;
- домен isolated: UI, контроллеры и существующая auth-часть почти не затрагиваются.

## Что проверить повторно перед началом реализации

1. Не появились ли новые миграции или content-модели.
2. Не появился ли в проекте уже принятый service/operation pattern.
3. Не изменился ли формат файлов в `db/data`.
4. Не появились ли локальные изменения в `db/seeds.rb`, `lib/tasks/`, `README.md`, `docker-compose.yml`, `bin/setup` или `config/application.rb`.

## Post-implementation: итоги ревью (2026-04-03)

### Что было исправлено по замечаниям

- **`expect.to receive` → `have_received`** в двух спеках (oxford, ngsl_spoken) — нарушение RSpec style guide проекта.
- **`bin/setup` не запускал `db:seed`** — Acceptance Criteria не выполнялись на чистой БД. Добавлен вызов `db:seed` после `db:prepare`.
- **Одна большая миграция переделана в три** — по одной на каждую таблицу (`create_languages`, `create_lexemes`, `create_lexeme_glosses`).
- **PostgreSQL 16 → 18** в `docker-compose.yml` для нативного `uuidv7()`.
- **`dotenv-rails`** добавлен для загрузки `.env` без direnv в рантайме.

### Открытые технические долги

1. **`allow_any_instance_of` в спеках** — стаббинг приватного метода `data_path`. Правильное решение: инжектировать `data_dir` через конструктор `BaseOperation`.
2. **`db/seeds.rb` вызывает Rake task** — `Rake::Task["content_bootstrap:import_all"].invoke`. Надёжнее вызывать операции напрямую; rake tasks — только для CLI.
3. **Непоследовательная нормализация headword** — `ImportPoliglotGlosses` делает `.downcase.strip` inline вместо `normalize_headword`. Стоит унифицировать через `BaseOperation`.
4. **Три идентичных CSV-импортёра** — сигнал к параметризованной экстракции при появлении четвёртого.

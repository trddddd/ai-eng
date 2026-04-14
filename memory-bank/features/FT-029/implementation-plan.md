---
title: "FT-029: Implementation Plan"
doc_kind: feature
doc_function: derived
purpose: "Execution-план реализации FT-029 (Lexeme Sense & Context Families). Фиксирует discovery context, шаги, риски и test strategy без переопределения canonical feature-фактов."
derived_from:
  - feature.md
status: active
audience: humans_and_agents
must_not_define:
  - ft_029_scope
  - ft_029_architecture
  - ft_029_acceptance_criteria
  - ft_029_blocker_state
---

# План имплементации

## Цель текущего плана

Создать foundation-слой для PRD-002: доменные сущности `Sense` и `ContextFamily`, импорт sense-данных из WordNet 3.1, импорт предложений из Tatoeba CSV, классификация всех `SentenceOccurrence` по sense и context family. После выполнения плана все occurrences привязаны к sense и context family (NOT NULL), существующие карточки и review logs не затронуты.

## Current State / Reference Points

| Path / module | Current role | Why relevant | Reuse / mirror |
| --- | --- | --- | --- |
| `app/models/lexeme.rb` | Доменная модель: headword, nullable pos, cefr_level, language. Ассоциации: `has_many :lexeme_glosses` | Нужна ассоциация `has_many :senses` (REQ-01). ImportSenses должен корректно обработать `pos = nil` у NGSL-лексем | Паттерн `has_many :lexeme_glosses, dependent: :destroy` |
| `app/models/sentence_occurrence.rb` | Связь sentence ↔ lexeme. `has_many :cards, dependent: :restrict_with_exception`. Метод `cloze_text` | Нужны `belongs_to :sense` и `belongs_to :context_family` (REQ-03, REQ-04) | Паттерн `belongs_to` + uniqueness scope |
| `app/models/card.rb` | FSRS-карточка. `delegate :lexeme, :sentence, :form, :cloze_text, to: :sentence_occurrence` | Нужны `delegate :sense, :context_family` (HIGH-8 из spec review) | Существующий delegation pattern |
| `app/models/sentence.rb` | Предложение: text, source, language. `has_many :sentence_occurrences, dependent: :restrict_with_exception` | `Sentences::ImportTatoeba` создаёт Sentence записи | `source` field distinguishes providers; uniqueness: `(language_id, text)` |
| `app/operations/content_bootstrap/base_operation.rb` | Базовый класс: `.call`, `data_dir`, `data_path`, `normalize_headword` | Все новые operations наследуют от BaseOperation | Паттерн: class method `.call`, idempotent `insert_all` |
| `app/operations/content_bootstrap/import_oxford_lexemes.rb` | Импорт Oxford CSV → Lexeme. `insert_all` с `unique_by` | Паттерн ImportSenses: парсинг внешнего источника → bulk insert | `parse_rows` + `insert_all` с `unique_by`; `now` для timestamps |
| `app/operations/sentences/import_quizword.rb` | Скрейпинг Quizword → Sentence + SentenceTranslation + SentenceOccurrence | `Sentences::ImportTatoeba` заменяет этот источник (ASM-04). Паттерн создания occurrences | `find_lexeme` (word boundary matching); `insert_batch` с transaction |
| `app/operations/cards/build_starter_deck.rb` | Создание стартовой колоды: raw SQL для выборки occurrences | После FT-029 может фильтровать по sense/context_family | Raw SQL pattern с `DISTINCT ON` |
| `lib/tasks/content_bootstrap.rake` | Rake tasks для content pipeline | Добавить `import_senses`, `assign_fallback_senses`, `assign_context_families`, `import_tatoeba` | Паттерн `desc` + `task :name => :environment` |
| `db/data/oxford-5000.csv` | Oxford 5000: word, level, pos, definition_url, voice_url | ImportSenses маппит lexemes → WordNet synsets по headword + POS | POS mapping: Oxford POS → WordNet POS (ADR-001, 296 лексем с нестандартным POS) |
| `spec/operations/content_bootstrap/import_oxford_lexemes_spec.rb` | Тесты: import, idempotency, error handling | Паттерн тестирования operations: fixture files, `data_dir:` parameter | `let(:data_dir) { Rails.root.join("spec/fixtures/files") }`; idempotency: second call = no duplicates |
| `spec/factories/` | FactoryBot: lexeme, sentence, sentence_occurrence, card, language, sentence_translation, lexeme_gloss | Нужны factories для sense и context_family | Существующий factory pattern: `association`, `sequence` |
| ADR-001 | WordNet 3.1 via ruby-wordnet. `accepted` | Canonical input для ImportSenses. CON-03 approval = granted | ruby-wordnet API: `lex.lookup_synsets("run")`, `synset.definition`, `synset.lexical_domain` |
| ADR-002 | Consolidated flat list (~17 context families). `accepted` | Canonical input для ContextFamily seed + AssignContextFamilies | Маппинг WordNet lexical domains → context families (17 строк) |

## Test Strategy

**Layered Rails Test Strategy:** При планировании обязателен запуск `/layers:spec-test` на всех затрагиваемых файлах для получения рекомендаций по тест-стратегии с учётом слоёв.

| Test surface | Canonical refs | Existing coverage | Planned automated coverage | Required local suites / commands | Required CI suites / jobs | Manual-only gap / justification | Manual-only approval ref |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Sense` model (validations, associations) | `REQ-01`, `SC-01`, `SC-02`, `CHK-01` | None (new) | Model spec: validations, `belongs_to :lexeme`, `has_many` checks, factory | `bundle exec rspec spec/models/sense_spec.rb` | CI: rspec | none | none |
| `ContextFamily` model (validations) | `REQ-02`, `SC-03`, `CHK-02` | None (new) | Model spec: validates name presence/uniqueness, factory | `bundle exec rspec spec/models/context_family_spec.rb` | CI: rspec | none | none |
| `SentenceOccurrence` (sense + context_family) | `REQ-03`, `REQ-04`, `CTR-03`, `CTR-04`, `CHK-02` | Validates form, uniqueness `(sentence_id, lexeme_id)`, `cloze_text` | Add: `belongs_to :sense`, `belongs_to :context_family` specs | `bundle exec rspec spec/models/sentence_occurrence_spec.rb` | CI: rspec | none | none |
| `Card` delegation | `HIGH-8` (spec review) | Delegates lexeme, sentence, form, cloze_text | Add: delegation of `:sense`, `:context_family` | `bundle exec rspec spec/models/card_spec.rb` | CI: rspec | none | none |
| `ImportSenses` operation | `REQ-05`, `SC-04`, `NEG-01`, `NEG-03`, `CHK-03` | None (new) | Operation spec: import from WordNet, POS mapping, idempotency, fallback, error handling | `bundle exec rspec spec/operations/content_bootstrap/import_senses_spec.rb` | CI: rspec | none | none |
| `AssignFallbackSenses` operation | `REQ-06`, `ASM-01`, `SC-05` | None (new) | Operation spec: creates fallback senses, skips lexemes with existing senses, idempotency | `bundle exec rspec spec/operations/content_bootstrap/assign_fallback_senses_spec.rb` | CI: rspec | none | none |
| `Sentences::ImportTatoeba` operation | `REQ-08`, `SC-07`, `CHK-06` | None (new) | Operation spec: import TSV, create Sentence+Translation+Occurrence, idempotency, quizword isolation | `bundle exec rspec spec/operations/sentences/import_tatoeba_spec.rb` | CI: rspec | none | none |
| `AssignContextFamilies` operation | `REQ-02`, `REQ-04`, `SC-03`, `FM-03` | None (new) | Operation spec: assign via sense→synset→lexical domain→mapping, unknown fallback, idempotency | `bundle exec rspec spec/operations/content_bootstrap/assign_context_families_spec.rb` | CI: rspec | none | none |
| Non-destructive migration | `REQ-07`, `EC-03`, `SC-06`, `CHK-05` | Full suite covers Card, ReviewLog | Existing test suite: Card.count, ReviewLog.count unchanged after migration | `bundle exec rspec` | CI: rspec | none | none |
| NOT NULL constraint validation | `EC-02`, `CHK-02` | None | DB query in test: all occurrences have sense_id and context_family_id after backfill | `bundle exec rspec` | CI: rspec | none | none |
| Top-100 polysemous verification | `EC-04`, `ASM-08`, `CHK-04` | None | DB query test: verify configured top-100 lexemes have >= 2 senses | `bundle exec rspec` | CI: rspec | Manual: verify configured list after full WordNet import | `none` |

## Open Questions / Ambiguities

Все критические design-неизвестности из spec review разрешены через ADR-001, ADR-002 и обновления feature.md. Остаются execution-проверки перед конкретными шагами.

| Open Question ID | Question | Why unresolved | Blocks | Default action / escalation owner |
| --- | --- | --- | --- | --- |
| `OQ-01` | ruby-wordnet API: точный формат `lexical_domain` (строка `"noun.motion"` или число?) | Требует smoke-теста при STEP-01 | `STEP-05` (ImportSenses) | Smoke-тест в STEP-01 верифицирует формат. Если не строка — добавить mapping в ImportSenses |
| `OQ-02` | Tatoeba data files: доступны ли `sentences.tar.bz2` и `links.tar.bz2` для скачивания? Требуется решение о месте хранения | Требует проверки доступности и соглашения о storage | `STEP-07` (`Sentences::ImportTatoeba`) | Скачать с tatoeba.org, положить в `db/data/tatoeba/`. Если недоступны — стоп и rescope decision; FT-029 не считается завершённой без `REQ-08` |

## Environment Contract

| Area | Contract | Used by | Failure symptom |
| --- | --- | --- | --- |
| git | Feature branch `feat/029-lexeme-sense` активна (`git branch --show-current` не `main`) | All steps | Агент работает в `main` — стоп, создать ветку: `git checkout -b feat/029-lexeme-sense` |
| setup | `bin/setup` выполнен, PostgreSQL запущен (docker compose), `bundle exec rspec` зелёные | All steps | `bin/rails db:migrate` fails — проверить docker compose |
| test | `bundle exec rspec` — эталонная команда. `bundle exec rubocop` — линтер | All CHK-* steps | Тесты красные — стоп, исправить до продолжения |
| gems | ruby-wordnet + wordnet-defaultdb добавлены в Gemfile group `:development` | `STEP-05`, `STEP-08` | `require "wordnet"` fails — проверить `bundle install` |
| data | Oxford 5000 CSV в `db/data/oxford-5000.csv`. Tatoeba TSV files в `db/data/tatoeba/` | `STEP-05`, `STEP-07` | `File not found` — проверить наличие файлов |

## Preconditions

| Precondition ID | Canonical ref | Required state | Used by steps | Blocks start |
| --- | --- | --- | --- | --- |
| `PRE-GIT` | `engineering/git-workflow.md` | Feature branch `feat/029-lexeme-sense` создана от `main` | All steps | **yes** — создать автономно до первого изменения кода |
| `PRE-01` | `DEC-01` / ADR-001 | ADR-001 `decision_status: accepted`. WordNet 3.1 via ruby-wordnet — canonical source | `STEP-01`, `STEP-05` | no (ADR already accepted) |
| `PRE-02` | `DEC-02` / ADR-002 | ADR-002 `decision_status: accepted`. Consolidated flat list ~17 context families — canonical taxonomy | `STEP-03`, `STEP-08` | no (ADR already accepted) |
| `PRE-03` | `ASM-04` | Tatoeba TSV files доступны в `db/data/tatoeba/` | `STEP-07` | **yes** — нужен AG-02 если файлы нужно скачивать |
| `PRE-04` | `ASM-07` | Rake task backfill — отдельный lifecycle от db:migrate | `STEP-10`, `STEP-11` | no |

## Workstreams

| Workstream | Implements | Result | Owner | Dependencies |
| --- | --- | --- | --- | --- |
| `WS-1` Schema & Models | `REQ-01`, `REQ-02`, `REQ-03`, `REQ-04`, `CTR-01`–`CTR-04` | Таблицы `senses`, `context_families`, FK на `sentence_occurrences`, модели с ассоциациями и валидациями | agent | PRE-GIT |
| `WS-2` WordNet Import | `REQ-05`, `REQ-06` | Operations `ImportSenses`, `AssignFallbackSenses` с тестами | agent | WS-1 (Sense model) |
| `WS-3` Tatoeba Import | `REQ-08` | Operation `Sentences::ImportTatoeba` с тестами | agent | WS-1 (FK columns) |
| `WS-4` Classification & Backfill | `REQ-02`, `REQ-04` | Operation `AssignContextFamilies` с тестами, rake tasks, NOT NULL constraint | agent | WS-2 (senses exist), WS-3 (occurrences exist) |

## Approval Gates

| Approval Gate ID | Trigger | Applies to | Why approval is required | Approver / evidence |
| --- | --- | --- | --- | --- |
| `AG-01` | Добавление ruby-wordnet + wordnet-defaultdb в Gemfile | `STEP-01` | CON-03: новые гемы требуют approval. Approval granted via ADR-001 acceptance | ADR-001 `decision_status: accepted` |
| `AG-02` | Скачивание Tatoeba data files (~50+ MB) | `STEP-07` | Внешние данные: нужно подтверждение источника и места хранения | Human: скачать и положить в `db/data/tatoeba/` |

## Порядок работ

**Обязательный Layered Rails шаг:** При планировании фичи — запустить `/layers:spec-test` на всех затрагиваемых файлах для получения рекомендаций по тест-стратегии с учётом слоёв.

| Step ID | Actor | Implements | Goal | Touchpoints | Artifact | Verifies | Evidence IDs | Check command / procedure | Blocked by | Needs approval | Escalate if |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `STEP-LAYERS-SPEC-TEST` | agent | — | Получение рекомендаций по тест-стратегии с учётом слоёв | `app/models/lexeme.rb`, `app/models/sentence_occurrence.rb`, `app/models/card.rb`, `app/operations/content_bootstrap/`, `app/operations/sentences/import_tatoeba.rb` | Рекомендации по тест-стратегии | — | `EVID-LAYERS-SPEC` | `/layers:spec-test` на каждом файле | — | `none` | — |
| `STEP-01` | agent | `CON-03`, ADR-001 | Добавить ruby-wordnet + wordnet-defaultdb в Gemfile group `:development` | `Gemfile`, `Gemfile.lock` | Гемы установлены, `require "wordnet"` работает | PRE-01 | `EVID-01` | `bundle install` + smoke test: `bundle exec rails runner 'require "wordnet"; lex = WordNet::Lexicon.new; puts lex.lookup_synsets("run").first.definition'` | PRE-GIT | `AG-01` | Гем несовместим с Ruby проекта |
| `STEP-02` | agent | `REQ-01`, `CTR-01`, `CON-01`, `CON-02` | Создать таблицу `senses` + модель `Sense` + обновить `Lexeme` | `db/migrate/*_create_senses.rb`, `app/models/sense.rb`, `app/models/lexeme.rb`, `spec/models/sense_spec.rb`, `spec/factories/senses.rb` | Sense model с валидациями, `Lexeme has_many :senses` | `CHK-01` | `EVID-02` | `bin/rails db:migrate` + `bundle exec rspec spec/models/sense_spec.rb` | PRE-GIT | `none` | — |
| `STEP-03` | agent | `REQ-02`, `CTR-02`, `DEC-02` | Создать таблицу `context_families` + модель + seed data (ADR-002 mapping) | `db/migrate/*_create_context_families.rb`, `app/models/context_family.rb`, `db/seeds/context_families.rb` (или rake task), `spec/models/context_family_spec.rb`, `spec/factories/context_families.rb` | ContextFamily model + 17 seed records | `CHK-02` | `EVID-03` | `bin/rails db:migrate` + verify seed | PRE-GIT | `none` | — |
| `STEP-04` | agent | `REQ-03`, `REQ-04`, `CTR-03`, `CTR-04` | Добавить nullable FK `sense_id`, `context_family_id` на `sentence_occurrences` + обновить модели | `db/migrate/*_add_sense_and_context_family_to_sentence_occurrences.rb`, `app/models/sentence_occurrence.rb`, `app/models/card.rb`, `spec/models/sentence_occurrence_spec.rb`, `spec/models/card_spec.rb`, `spec/factories/sentence_occurrences.rb` | FK columns exist (nullable), associations updated, Card delegates sense + context_family | `CHK-01`, `CHK-02` | `EVID-04` | `bin/rails db:migrate` + `bundle exec rspec spec/models/` | STEP-02, STEP-03 | `none` | — |
| `STEP-05` | agent | `REQ-05`, `DEC-01` | Создать `ImportSenses` operation: WordNet → Sense records | `app/operations/content_bootstrap/import_senses.rb`, `spec/operations/content_bootstrap/import_senses_spec.rb` | ImportSenses создаёт Sense записи из WordNet synsets, idempotent, POS mapping | `CHK-03`, `SC-04` | `EVID-05` | `bundle exec rspec spec/operations/content_bootstrap/import_senses_spec.rb` | STEP-01, STEP-02 | `none` | WordNet API отличается от документации (OQ-01) |
| `STEP-06` | agent | `REQ-06`, `ASM-01` | Создать `AssignFallbackSenses` operation: fallback sense для lexemes без WordNet match | `app/operations/content_bootstrap/assign_fallback_senses.rb`, `spec/operations/content_bootstrap/assign_fallback_senses_spec.rb` | Все lexemes имеют >= 1 sense | `CHK-01` | `EVID-06` | `bundle exec rspec spec/operations/content_bootstrap/assign_fallback_senses_spec.rb` | STEP-02 | `none` | — |
| `STEP-07` | agent | `REQ-08`, `ASM-04` | Создать `Sentences::ImportTatoeba` operation: Tatoeba CSV → Sentence + Translation + Occurrence | `app/operations/sentences/import_tatoeba.rb`, `spec/operations/sentences/import_tatoeba_spec.rb`, `spec/fixtures/files/tatoeba/` | Tatoeba sentences imported, `source: "tatoeba"`, quizword records untouched | `CHK-06`, `SC-07` | `EVID-07` | `bundle exec rspec spec/operations/sentences/import_tatoeba_spec.rb` | STEP-04, PRE-03 | `AG-02` | Tatoeba TSV files unavailable (OQ-02) |
| `STEP-08` | agent | `REQ-02`, `REQ-04`, `FM-02`, `FM-03` | Создать `AssignContextFamilies` operation: occurrence → sense (MFS baseline) → lexical domain → context family mapping | `app/operations/content_bootstrap/assign_context_families.rb`, `spec/operations/content_bootstrap/assign_context_families_spec.rb` | Все occurrences имеют sense_id (MFS) и context_family_id | `CHK-02` | `EVID-08` | `bundle exec rspec spec/operations/content_bootstrap/assign_context_families_spec.rb` | STEP-05, STEP-06, STEP-03 | `none` | — |
| `STEP-09` | agent | — | Добавить rake tasks для всех operations + обновить `content_bootstrap:import_all` | `lib/tasks/content_bootstrap.rake` | Rake tasks доступны | — | `EVID-09` | `bin/rails -T content_bootstrap` | STEP-05, STEP-06, STEP-07, STEP-08 | `none` | — |
| `STEP-10` | agent | `REQ-06`, `ASM-07`, `FM-04` | Backfill: запустить rake tasks в последовательности (ImportSenses → AssignFallbackSenses → Sentences::ImportTatoeba → AssignContextFamilies). Batch size=500, resume from last ID | Rake task execution | Все occurrences имеют sense_id и context_family_id (nullable Phase 2 complete) | `EC-01`, `EC-02` | `EVID-10` | DB queries: `SentenceOccurrence.where(sense_id: nil).count == 0` etc. | STEP-09 | `none` | Backfill не может завершиться — проверить errors list |
| `STEP-11` | agent | `CTR-03`, `CTR-04` | Добавить NOT NULL constraint migration (Phase 3) | `db/migrate/*_add_not_null_constraints_to_sentence_occurrences.rb` | `sense_id` NOT NULL, `context_family_id` NOT NULL | `EC-02` | `EVID-11` | `bin/rails db:migrate` + `bundle exec rspec` | STEP-10 | `none` | NOT NULL fails — backfill incomplete |
| `STEP-12` | agent | `EC-04`, `ASM-08` | Верификация: full test suite зелёные, configured top-100 verification, DB counts unchanged | All specs | All CHK-* pass, all EVID-* filled | `CHK-01`–`CHK-06` | `EVID-12` | `bundle exec rspec` + `bundle exec rubocop` + DB verification queries | STEP-11 | `none` | — |
| `STEP-LAYERS-REVIEW` | agent | — | Проверка архитектурных границ Layered Rails | Все новые/изменённые файлы | Ревью-отчёт без критических нарушений | `CP-LAYERS` | `EVID-LAYERS` | `/layers:review` на всех новых/изменённых файлах | `STEP-02`–`STEP-09` | `none` | При критических нарушениях — эскалация в ADR |

## Parallelizable Work

- `PAR-01` STEP-02 (Sense) и STEP-03 (ContextFamily) — независимые таблицы/модели, можно выполнять параллельно
- `PAR-02` STEP-07 (`Sentences::ImportTatoeba`) может разрабатываться параллельно с STEP-05/STEP-06 (ImportSenses/AssignFallbackSenses) — разные touchpoints, но оба зависят от STEP-04
- `PAR-03` STEP-05 и STEP-06 последовательны: AssignFallbackSenses требует результата ImportSenses (senses из WordNet существуют)

## Checkpoints

**Layered Rails Review Checkpoint:** После написания кода обязателен запуск `/layers:review` на всех новых/изменённых файлах для проверки архитектурных границ.

| Checkpoint ID | Refs | Condition | Evidence IDs |
| --- | --- | --- | --- |
| `CP-01` | `STEP-02`–`STEP-04` | Schema готов: таблицы созданы, FK columns exist (nullable), модели работают, `bundle exec rspec spec/models/` зелёные | `EVID-02`, `EVID-03`, `EVID-04` |
| `CP-02` | `STEP-05`–`STEP-08` | Operations готовы: все 4 operations проходят тесты, `bundle exec rspec spec/operations/` зелёные | `EVID-05`, `EVID-06`, `EVID-07`, `EVID-08` |
| `CP-03` | `STEP-10`, `STEP-11` | Backfill complete: все occurrences имеют sense_id и context_family_id, NOT NULL constraints applied | `EVID-10`, `EVID-11` |
| `CP-04` | `STEP-12` | Full validation: `bundle exec rspec` + `bundle exec rubocop` зелёные, DB counts unchanged, configured top-100 verified | `EVID-12` |
| `CP-LAYERS` | All steps | `/layers:review` пройден без критических нарушений архитектурных границ | `EVID-LAYERS` |

## Execution Risks

| Risk ID | Risk | Impact | Mitigation | Trigger |
| --- | --- | --- | --- | --- |
| `ER-01` | ruby-wordnet API не совпадает с документацией (OQ-01): `lexical_domain` в другом формате, `synset.definition` возвращает что-то неожиданное | ImportSenses нужно переписывать | Smoke-тест в STEP-01 верифицирует API до написания operation. При несовпадении — адаптерный слой в ImportSenses | Smoke-тест падает |
| `ER-02` | Tatoeba TSV files недоступны для скачивания или формат изменился (OQ-02) | `REQ-08` блокируется, FT-029 не может быть закрыта в текущем scope | Проверить доступность в AG-02. При недоступности — стоп и rescope decision: либо найти mirror/storage, либо вынести `REQ-08` в отдельную feature с обновлением FT-029 | `curl -I` возвращает не 200 |
| `ER-03` | WordNet покрывает <90% Oxford 5000 lexemes (ADR-01 acceptance gate) | Больше fallback senses, чем ожидалось | Fallback sense — валидное состояние (ASM-01). Покрытие <80% — эскалация к человеку | ImportSenses: `skipped > 20%` |
| `ER-04` | Backfill долгий на production-like объёме (>60K occurrences) | Таймаут rake task | Batch processing (500 per transaction), resume from last ID (ASM-07). При timeout — уменьшить batch size до 100 | Rake task >10 min без прогресса |

## Stop Conditions / Fallback

| Stop ID | Related refs | Trigger | Immediate action | Safe fallback state |
| --- | --- | --- | --- | --- |
| `STOP-01` | `ER-01` | ruby-wordnet гем несовместим с Ruby проекта или API критически отличается | Стоп на STEP-01. Не продолжать WS-2 | Schema (WS-1) может быть реализован без ruby-wordnet. ImportSenses отложить до решения |
| `STOP-02` | `ER-02` | Tatoeba files недоступны | Остановить `STEP-07` и эскалировать rescope decision. Не закрывать FT-029 как complete без `REQ-08` | До решения можно продолжать независимую разработку WS-1/WS-2, но acceptance FT-029 остаётся blocked |
| `STOP-03` | `STEP-11` | NOT NULL constraint migration падает (есть occurrences без sense_id/context_family_id) | Не форсировать. Вернуться к STEP-10, проверить errors list | FK columns остаются nullable. NOT NULL applied после ручного исправления данных |

## Implementation Details

### STEP-02: Sense Schema

```ruby
create_table :senses, id: false do |t|
  t.column :id, :uuid, primary_key: true, default: -> { "uuidv7()" }
  t.references :lexeme, type: :uuid, null: false,
                        foreign_key: { on_delete: :cascade }, index: true
  t.integer :external_id  # WordNet synset offset
  t.text :definition, null: false
  t.string :pos, null: false # WordNet POS; fallback without POS uses "unknown"
  t.integer :sense_rank, default: 1  # MFS ordering (1 = most frequent)
  t.jsonb :examples, default: []     # array of strings
  t.string :source, null: false, default: "wordnet"
  t.string :lexical_domain  # "noun.motion", "verb.cognition", etc.

  t.timestamps
end

add_index :senses, [:lexeme_id, :external_id], unique: true, where: "external_id IS NOT NULL"
add_index :senses, :external_id
add_index :senses, [:lexeme_id, :pos]
```

Примечание: `sense_rank` и `lexical_domain` — implementation additions для MFS baseline и context family classification. Не изменяют canonical контракт CTR-01, расширяют его.

### STEP-03: ContextFamily Seed (ADR-002)

17 записей из маппинга ADR-002. Seed через отдельный файл `db/seeds/context_families.rb`:

```ruby
# db/seeds/context_families.rb
FAMILIES = [
  { name: "people & relationships", description: "Люди, группы, социальные взаимодействия" },
  { name: "communication", description: "Речь, язык, передача информации" },
  { name: "body & health", description: "Тело, здоровье, физические функции" },
  { name: "food & drink", description: "Еда, питьё, потребление" },
  { name: "movement & sports", description: "Движение, спорт, соревнования" },
  { name: "thinking & knowledge", description: "Мышление, знание, обучение" },
  { name: "emotions & feelings", description: "Чувства, эмоции, мотивация" },
  { name: "objects & tools", description: "Предметы, инструменты, технологии" },
  { name: "nature & environment", description: "Природа, животные, растения" },
  { name: "places & travel", description: "Места, география, путешествия" },
  { name: "time & events", description: "Время, события, изменения" },
  { name: "actions & activities", description: "Действия, создание, активности" },
  { name: "possession & commerce", description: "Владение, торговля, финансы" },
  { name: "physical interaction", description: "Физический контакт, восприятие" },
  { name: "weather", description: "Погода, климатические явления" },
  { name: "qualities & states", description: "Абстрактные качества, состояния, формы" },
  { name: "unknown", description: "Fallback: прилагательные/наречия, function words" }
].freeze
```

### STEP-05: POS Mapping Table (ADR-001 Risk: POS Mismatch)

Oxford POS → WordNet POS mapping для 296 лексем с нестандартным POS:

```ruby
POS_MAPPING = {
  "noun" => :noun,
  "verb" => :verb,
  "adjective" => :adj,
  "adverb" => :adv,
  "modal verb" => :verb,
  "auxiliary verb" => :verb,
  "linking verb" => :verb,
  "pronoun" => nil,     # no WordNet match → fallback sense
  "preposition" => nil,
  "determiner" => :adj,
  "number" => :noun,
  "ordinal number" => :adj,
  "conjunction" => nil,
  "exclamation" => nil,
  "indefinite article" => nil,
  "definite article" => nil,
  "infinitive marker" => nil
}.freeze
```

Если `lexeme.pos` присутствует и mapping возвращает `nil`, создаётся fallback sense (FM-01). Если `lexeme.pos` отсутствует (`nil` у части NGSL-лексем), ImportSenses выполняет lookup без POS-filter и сохраняет POS из WordNet synset; если WordNet match не найден, fallback sense получает `pos = "unknown"`.

### STEP-08: Occurrence → Sense Algorithm (MFS Baseline)

Для каждого `SentenceOccurrence` без `sense_id`:

1. Найти `occurrence.lexeme.senses`
2. Если 1 sense → привязать к нему (monosemous / fallback)
3. Если >1 sense и `occurrence.lexeme.pos` присутствует → POS filter: выбрать sense с `sense.pos == occurrence.lexeme.pos`, среди них — lowest `sense_rank`
4. Если `occurrence.lexeme.pos` отсутствует или POS match нет → привязать к sense с lowest `sense_rank` среди всех senses этой lexeme; для POS mismatch логировать warning
5. Если senses пусты → логировать warning, пропустить (FM-01)

### STEP-08: Occurrence → Context Family Algorithm

Через транзитивную цепочку: occurrence → sense → `lexical_domain` → context family mapping.

Mapping table живёт в коде AssignContextFamilies (из ADR-002). Если `lexical_domain` отсутствует или не match → `unknown`.

## Готово для приемки

План считается исчерпанным когда:

1. Все CHK-* из `feature.md` имеют результат pass в evidence
2. Все EVID-* из `feature.md` заполнены конкретными carriers
3. `bundle exec rspec` + `bundle exec rubocop` зелёные
4. `/layers:review` выполнен на всех новых/изменённых файлах, критических нарушений нет
5. Simplify review выполнен: код минимально сложен

**Обязательные Layered Rails условия:**
- `EVID-LAYERS-SPEC`: `/layers:spec-test` выполнен на всех затрагиваемых файлах при планировании
- `EVID-LAYERS`: `/layers:review` выполнен на всех новых/изменённых файлах после реализации, критических нарушений архитектурных границ нет

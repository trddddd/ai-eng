---
title: "FT-029 Research: Sense Data Sources & Sentence Linking"
doc_kind: research
doc_function: canonical
purpose: "Комплексный ресерч источников sense-данных, методов WSD и интеграции с контент-пайплайном Lingvize. Основа для решения DEC-01 (выбор источника) и проектирования импорта."
derived_from:
  - ./feature.md
  - ../../prd/PRD-002-word-mastery.md
status: active
audience: humans_and_agents
---

# FT-029 Research: Sense Data Sources & Sentence Linking

## Контекст

PRD-002 (Word Mastery) требует перехода от card-first к word-centric модели. FT-029 — foundation-слой: сущности `Sense` и `ContextFamily`, импорт sense-данных, привязка `SentenceOccurrence` к конкретным значениям слов.

**Ключевые решения, которые блокирует ресерч:**
- `DEC-01` — выбор источника sense-данных (WordNet, Oxford, другой)
- Выбор Ruby-гема для работы с WordNet
- Выбор метода автоматической привязки предложений к synsets (WSD)

**Текущее состояние проекта:**
- 5949 лексем (Oxford 5000: word + CEFR level + POS)
- Сущности: `Lexeme`, `Sentence`, `SentenceOccurrence`, `Card`
- Контент-пайплайн: Oxford CSV → Lexemes, Quizword → Sentences + Occurrences
- `SentenceOccurrence` не привязан к sense/context family

---

## 1. WordNet: Что это и какие данные даёт

**WordNet** (Princeton) — лексическая база данных английского языка. Организована как граф синсетов (с) — групп синонимов, выражающих одно понятие.

**Версии:** WordNet 3.0 (2006, финальная) и WordNet 3.1 (2011, maintenance release). Различия минимальные: часть synsets объединена, offset'ы изменились.

**Объём WordNet 3.1:**
- 155,327 слов / 117,659 synsets / 207,016 word-sense пар
- 4 части речи: noun (82K), verb (13K), adjective (18K), adverb (3.6K)

**Данные, доступные по каждому synset:**

| Данные | Описание | Пример (run) |
|---|---|---|
| Synset ID (offset) | Уникальный числовой ID | 02092478 |
| Слова (lemmas) | Синонимы в synset | run, sprint, race |
| Definition | Текстовое определение | "move fast on foot" |
| Examples | Примеры употребления | "He ran home" |
| POS | Часть речи | verb |
| Lexical domain | Семантический домен | verb.motion |
| Hypernyms | Более общие понятия (вверх по дереву) | travel, go |
| Hyponyms | Более конкретные (вниз) | jog, sprint, trot |
| Meronyms/Holonyms | Часть-целое (для nouns) | — |
| Sense rank | Порядок по частотности | run₁ = самый частый |

**Ключевое свойство: Sense Rank (= Most Frequent Sense)**
WordNet упорядочивает senses слова по частотности на основе SemCor. Первый sense — самый частый. Для Oxford 5000 слов первый sense покрывает ~65% употреблений в среднем, а для слов с 1-2 значениями — до 80-85%.

**Лицензия:** WordNet 3.0 — свободная (wordnet license, аналогична BSD). WordNet 3.1 — аналогично. Допускает коммерческое использование.

---

## 2. Ruby-гемы для WordNet

### 2.1. rwordnet (doches/rwordnet)

| Характеристика | Значение |
|---|---|
| GitHub | https://github.com/doches/rwordnet |
| Версия | 2.0.0 (декабрь 2016) |
| WordNet | **3.0** |
| Зависимости | Нет (чистый Ruby) |
| БД | Плоские файлы data.{noun,verb,adj,adv} в комплекте (~8 MB) |
| Synset ID | `(pos, byte_offset)` — целое число + символ POS |
| Поддержка | Неактивен с 2019 |

**API:**
```ruby
# Найти все synsets слова
lemma = WordNet::Lemma.find("run", :verb)
lemma.synsets.each { |s| puts s.gloss }
# "move fast on foot; "He ran all the way to the store""
# "be operating; "The engine is running smoothly""

# Hypernyms
lemma.synsets.first.hypernyms
```

**Проблемы:**
- `gloss` содержит и определение, и примеры в одной строке — нужно парсить вручную
- Нет отдельного метода для examples
- Не поддерживается (последний коммит 6+ лет)
- Медленный при массовых запросах

### 2.2. ruby-wordnet (ged/ruby-wordnet)

| Характеристика | Значение |
|---|---|
| GitHub | https://github.com/ged/ruby-wordnet |
| Версия | 1.2.0 (май 2023) |
| WordNet | **3.1** |
| Зависимости | sequel, sqlite3, loggability |
| БД | SQLite3 (~34 MB, через gem wordnet-defaultdb) |
| Synset ID | Числовой offset (9+ цифр) |
| Ruby | ~> 3.0 |
| Поддержка | Умеренно активен |
| Лицензия | BSD-3-Clause |

**API:**
```ruby
lex = WordNet::Lexicon.new

# Все synsets слова
synsets = lex.lookup_synsets("run")
# => [#<WordNet::Synset {02092478} 'run' (verb): ...>, ...]

# Definition — отдельно от examples
synsets.first.definition
# => "move fast on foot"

# Обход графа с глубиной
lex[:run].traverse(:hypernyms).with_depth.each { |ss, d| ... }

# Hypernyms, Hyponyms, Meronyms — отдельные методы
synsets.first.hypernyms
synsets.first.hyponyms
```

**Преимущества:**
- `definition` — отдельно (не смешана с примерами)
- Обход графа (`traverse` с depth)
- SUMO ontology mapping (дополнительная классификация)
- Может подключаться к PostgreSQL через Sequel
- Человеко-читаемый inspect: `{105650820} 'language, speech' (noun): [noun.cognition] ...`

**Проблемы:**
- 4 runtime-зависимости (sequel, sqlite3, loggability, hoe)
- БД ~34 MB
- Требует Ruby ~> 3.0

### 2.3. Сравнение и рекомендация

| Критерий | rwordnet | ruby-wordnet |
|---|---|---|
| WordNet версия | 3.0 | **3.1** |
| Definition | Смешана с examples | **Отдельно** |
| Graph traversal | Нет | **Да (с depth)** |
| Поддержка | Неактивен | **Умеренно активен** |
| Зависимости | Нет | 4 гема |
| Размер БД | ~8 MB | ~34 MB |
| Synset ID формат | (pos, offset) | **integer offset** |
| Lexical domain | lexfilenum (int) | **Строка ("noun.motion")** |

**Рекомендация: ruby-wordnet** — богаче API, `definition` отделён от examples, WN 3.1, traverse с глубиной, lexical_domain в читаемом формате. Зависимости (sequel, sqlite3) — разумный trade-off для Rails-проекта.

> **Но:** ruby-wordnet нужен только на этапе импорта (content pipeline), не в рантайме. После импорта synset-данные живут в нашей PostgreSQL.

---

## 3. Oxford 5000: Текущий формат и ограничения

**Текущий файл:** `db/data/oxford-5000.csv`

```csv
word,level,pos,definition_url,voice_url
a,a1,indefinite article,https://...,https://...
abandon,b2,verb,https://...,https://...
about,a1,preposition,https://...,https://...
```

**Статистика:** 5949 записей (word+POS пар). Распределение по CEFR:
- A1: 1076 | A2: 990 | B1: 902 | B2: 1571 | C1: 1404

**Ограничения текущего формата:**
- Нет sense-разметки (сколько значений у слова, какие именно)
- Нет определений (только URL на Oxford Learners Dict)
- Полисемия: одно слово может иметь несколько строк с разными POS (например `about` — adverb и preposition), но нет разделения senses внутри одного POS
- `definition_url` содержит `_1` суффикс (номер sense в Oxford), но не используется

**Пример полисемии в Oxford:**
```
about_1 → preposition (a1)  — "on the subject of"
about_2 → adverb (a1)       — "a little more or less than"
```
Но `about` как adverb имеет и sense "approximately" и sense "in the opposite direction" — это не различается.

---

## 4. Tatoeba: Источник предложений (через Quizword и напрямую)

**Контекст:** Quizword — текущий источник предложений в Lingvize. Содержит предложения из Tatoeba с русскими переводами. Импорт через `ImportQuizword` (скрейпинг quizword.net). Это не отдельный от Tatoeba источник, а конкретный провайдер Tatoeba-данных.

### Объём

| Метрика | Значение |
|---|---|
| Всего предложений | 13.4M (429 языков) |
| Английских | 2,030,794 |
| Русских | 1,199,810 |
| Eng-Rus пар (оценка) | ~150,000+ |
| Ссылок-переводов | 25.9M |
| Английских с аудио | ~841K |
| Русских с аудио | ~10.6K |

### Формат данных (TSV)

**sentences.tar.bz2:**
```
SentenceID  Lang  Text  DateLastModified
1           eng   The meeting was canceled.  2024-01-15
77          rus   Встреча была отменена.     2024-01-15
```

**links.tar.bz2:**
```
SentenceID  TranslationID
1           77
77          1
```

### Лицензия

- **CC-BY 2.0 FR** (основная масса) — коммерческое использование с атрибуцией
- **CC0 1.0** (подмножество)
- Требование: указать Tatoeba и лицензию

### Качество

- Любой пользователь может добавлять предложения
- Нет систематической проверки всех предложений
- ~85% предложений — переводы (не оригиналы), возможна неестественность
- Теговая система: `@needs native check`, `proverb`, `colloquial`
- Рекомендация: фильтровать по уровню автора и наличию проверки

### Где качать

| Ресурс | URL |
|---|---|
| Downloads | https://tatoeba.org/en/downloads |
| Прямой доступ | https://downloads.tatoeba.org/exports/ |
| Все предложения | `sentences.tar.bz2` (~700 MB) |
| Links | `links.tar.bz2` (~145 MB) |
| Per-language | `per_language/eng_sentences.tar.bz2` |
| Готовые Anki-пары | https://www.manythings.org/anki/ (`rus-eng.zip`) |

### Связь Tatoeba с WordNet

**Прямой связи нет.** Tatoeba не содержит word-level аннотаций. Привязка предложений к конкретным synsets требует WSD.

---

## 5. Word Sense Disambiguation (WSD)

### 5.1. Что такое WSD и зачем она нужна

Задача: дано слово в предложении → определить, какой именно sense (synset) имеется в виду. Для Lingvize это нужно, чтобы привязать `SentenceOccurrence` к конкретному `Sense`.

### 5.2. Уровни точности (SOTA)

| Метод | Тип | F1 (fine-grained) | Сложность реализации |
|---|---|---|---|
| **Most Frequent Sense (MFS)** | Baseline | ~65% | 0 строк кода |
| Simplified Lesk | Knowledge-based | ~27-32% | 20 строк |
| Adapted Lesk | Knowledge-based | ~32% | 50 строк |
| Extended Lesk + embeddings | Knowledge-based | ~64% | 200 строк |
| UKB (PPR) | Knowledge-based | ~67% | CLI + wrapper |
| pywsd (adapted_lesk) | Knowledge-based | ~50-60% | pip install + wrapper |
| BERT-based (GlossBERT) | Neural | ~77% | HuggingFace + GPU |
| Fine-tuned LLM (2025) | Neural | ~86% | API/GPU |
| Human agreement | — | ~75-80% | — |

### 5.3. Рекомендация для Lingvize: Гибридный подход

**Фаза 1 (MVP): Most Frequent Sense + POS filter**
```
1. У слова 1 sense → берём его (100%)
2. Слово имеет POS (из Oxford CSV) → фильтруем senses по POS
3. Берём первый (самый частый) sense → ~70-75% accuracy для Oxford 5000
```
Реализация: Ruby через ruby-wordnet, несколько строк в `ImportSenses` operation.

**Фаза 2: Adapted Lesk через pywsd для сложных случаев**
- Слова с 3+ senses без доминирующего → запускать WSD
- pywsd как Python subprocess из Rake task
- Поднимает accuracy до ~78-82%

**Почему MFS достаточно для MVP:**
- Большинство Oxford 5000 слов — частотные, 1-2 доминирующих смысла
- В cloze-карточках пользователь видит полное предложение — контекст проясняет значение
- 15-20% ошибок в привязке sense некритичны: пример предложения сам по себе показывает значение
- Можно итеративно улучшать разметку post-launch

---

## 6. Pre-annotated Corpora (Готовые датасеты)

### 6.1. SemCor 3.0
- 352 текста из Brown Corpus, ~360K слов
- Каждое content word размечено WordNet synset
- Доступ через NLTK: `from nltk.corpus import semcor`
- Можно извлечь пары (sentence, word, synset_id) как gold standard

### 6.2. OntoNotes 5.0
- 1.5M слов, word senses с agreement >= 90%
- Требует лицензию LDC
- Sense inventory не полностью совпадает с WordNet

### 6.3. OMSTI
- 1M автоматически размеченных instances
- Semi-supervised, можно использовать для обучения

**Рекомендация:** SemCor использовать для оценки качества WSD (gold standard). Не как основной источник предложений — слишком мало и академический стиль.

---

## 7. Альтернативные источники предложений

| Источник | Eng-Rus пар | Качество | Лицензия | Примечание |
|---|---|---|---|---|
| **Tatoeba (через Quizword)** | ~150K+ | Среднее | CC-BY 2.0 FR | Текущий источник в Lingvize |
| **Tatoeba (прямой импорт)** | ~150K+ | Среднее | CC-BY 2.0 FR | Основной источник предложений в FT-029 (`REQ-08`) |
| OpenSubtitles | ~30M | Низкое | varies | Разговорный, шумный |
| UN Corpus | ~20M | Высокое | Свободная | Только офиц. документы |
| ParaCrawl | Большой | Низкое | CC Zero | Web-crawled, шумный |

---

## 8. Итоговая рекомендация (DEC-01)

### Выбор источника sense-данных: **WordNet 3.1 через ruby-wordnet**

**Обоснование:**
1. Покрытие: WordNet покрывает >95% Oxford 5000 слов (все content words)
2. Бесплатно и свободная лицензия
3. Структурированные данные: definition, POS, examples, hypernyms
4. Sense rank (частотность) — готовый MFS baseline
5. ruby-wordnet даёт богатый API с traverse и отдельным definition

### Выбор источника предложений: **Tatoeba direct import**

- Quizword — текущий интегрированный провайдер Tatoeba-данных, но остаётся только compatibility path
- Прямой импорт Tatoeba CSV — основной источник предложений в FT-029 (`REQ-08`), потому что устраняет HTML-скрейпинг и зависимость от доступности quizword.net
- Привязка к synsets: MFS + POS filter (Фаза 1), затем Adapted Lesk (Фаза 2)

### Архитектура импорта

```
Шаг 1: ImportSenses (однократно)
  Oxford 5000 CSV → ruby-wordnet lookup → создать Sense записи
  - Для каждого (word, pos) из Oxford: найти synsets в WordNet
  - Создать Sense с: synset_id, definition, pos, sense_rank
  - Fallback: если WordNet не знает слово → 1 Sense с definition=""

Шаг 2: LinkOccurrences (однократно)
  SentenceOccurrence → привязать к Sense
  - Фаза 1: MFS (берём самый частый sense для данного POS)
  - Фаза 2: Adapted Lesk через pywsd для полисемичных слов

Шаг 3: ImportTatoebaSentences
  Прямой импорт Tatoeba CSV → новые Sentence + SentenceOccurrence
  - Фильтр по качеству (длина, native speaker)
  - Автоматический word matching (как в ImportQuizword)
  - Привязка к Sense через MFS

Шаг 4: AssignContextFamilies (curated)
  SentenceOccurrence → ContextFamily
  - v1: curated labels из контролируемого словаря
  - Fallback: "unknown"
```

### Что ruby-wordnet даёт для Context Families

Lexical domain из WordNet — готовая coarse-grained классификация:
- `noun.artifact`, `noun.food`, `noun.body`, `noun.communication`...
- `verb.motion`, `verb.cognition`, `verb.communication`...
- `adj.all`, `adv.all`

Это ~45 доменов. Можно использовать как стартовую таксономию context families (с маппингом на более читаемые labels).

---

## 9. Quizword → Tatoeba Direct Import

### Контекст

Текущий источник предложений — `ImportQuizword` (`app/operations/sentences/import_quizword.rb`). Скрейпит HTML с quizword.net (Tatoeba-провайдер с русскими переводами). 10 потоков, retry, binary search последней страницы, Nokogiri-парсинг.

**Проблемы Quizword:**
- Хрупкий HTML-скрейпинг (ломается при изменении вёрстки)
- Ограниченное покрытие: только то, что quizword.net решил показать
- Нестабильная доступность (HTTP timeouts, retry logic)
- quizword.net — просто переупаковка Tatoeba, без добавленной ценности

### Предложение: прямой импорт Tatoeba

Заменить скрейпинг quizword.net на обработку Tatoeba CSV-файлов, скачанных с https://tatoeba.org/en/downloads.

**Необходимые файлы:**

| Файл | Формат | Что даёт |
|---|---|---|
| `sentences.tar.bz2` | `id \t lang \t text \t modified` | Все предложения (eng, rus) |
| `links.tar.bz2` | `sentence_id \t translation_id` | Связи переводов |
| `sentences_with_audio.tar.bz2` | `id \t lang \t text \t username \t license` | Информация об аудио |

**Алгоритм ImportTatoeba (вместо ImportQuizword):**

```
1. Скачать files (или читать из db/data/ — предзагруженные)
2. Распаковать tar.bz2 → TSV
3. Отфильтровать sentences: lang in [eng, rus]
4. Построить eng-rus пары через links:
     eng_sentences = sentences.where(lang: "eng")
     rus_sentences = sentences.where(lang: "rus")
     pairs = links.where(sentence_id in eng, translation_id in rus)
5. Для каждой eng-rus пары:
     - find_lexeme(text_eng, lexemes) — тот же алгоритм
     - Создать Sentence (source: "tatoeba")
     - Создать SentenceTranslation
     - Создать SentenceOccurrence
6. Batch insert (insert_all, unique_by) — идемпотентно
```

**Преимущества:**

| Критерий | Quizword (сейчас) | Tatoeba direct |
|---|---|---|
| Источник данных | HTML-скрейпинг | Локальные TSV-файлы |
| Надёжность | Зависит от доступности сайта | 100% (файлы локально) |
| Скорость | HTTP + retry + binary search | Чтение файлов с диска |
| Покрытие eng-rus | Ограничено quizword.net | ~150K+ пар (весь Tatoeba) |
| Парсинг | Nokogiri HTML | Стандартный TSV |
| Зависимости | net/http, nokogiri | rubygems (csv, zlib) |
| Audio info | audio_id из HTML | Отдельный файл с лицензиями |

**Риски и нюансы:**

1. **Audio URL формат:** Quizword даёт `audio_id` (целое число). Tatoeba хранит аудио отдельно, URL-паттерн: `https://audio.tatoeba.org/sentences/eng/{id}.mp3`. Нужно проверить, использует ли текущий UI audio_id напрямую или строит URL — при смене формата потребуется адаптация.

2. **Существующие данные:** Записи с `source: "quizword"` останутся в БД. Новые будут `source: "tatoeba"`. Это нормально — source marker различает происхождение.

3. **Размер файлов:** `sentences.tar.bz2` ~700 MB (все языки). Можно предзагрузить только eng + rus через `per_language/` файлы (меньше). Или скачать один раз в `db/data/tatoeba/`.

4. **Обновления:** Tatoeba обновляет дампы еженедельно. Можно обновлять по мере необходимости, а не rely на живой сайт.

### Статус

`ImportQuizword` → deprecated (оставить для совместимости, не удалять). Новый `Sentences::ImportTatoeba` — основной источник предложений и зафиксирован в FT-029 как `REQ-08`.

---

## 10. Риски и открытые вопросы

1. **WordNet покрытие Oxford 5000:** Нужно протестировать — возможно, часть function words (a, the, about как preposition) не имеет synsets. Fallback = monosemous sense.

2. **Gloss/Definition качество:** Определения WordNet — академические, не адаптированные для learners. Для A1-B1 пользователей может потребоваться упрощение (отдельная задача).

3. **Examples в WordNet:** Количество examples ограничено (0-3 на synset, многие без примеров). Tatoeba direct — основной источник предложений, WordNet examples — вспомогательный.

4. **POS mismatch:** Oxford CSV может иметь POS "indefinite article", а WordNet — "noun". Нужен маппинг POS между Oxford и WordNet.

5. **ruby-wordnet как runtime-зависимость:** Гем нужен только в content pipeline (rake tasks / operations). В рантайме приложения — не нужен, все synset-данные в нашей PostgreSQL.

6. **Повторный импорт:** Идемпотентность ImportSenses — повторный запуск не создаёт дубли (unique_by на lexeme_id + synset_id).

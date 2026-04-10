# Spec: Некорректный матчинг слов — substring без учёта границ

**Brief:** [memory-bank/fixes/001/brief.md](brief.md)
**Issue:** trddddd/ai-eng#17

---

## Цель

Алгоритм матчинга лексем при импорте предложений (`Sentences::ImportQuizword`) должен совпадать только с целыми словами, а не с подстроками внутри других слов.

## Scope

**Входит:**
- Замена `String#include?` на regex с `\b` (word boundaries) в `find_lexeme`
- Замена `String#index` на regex `index` для определения позиции матча
- Замена `String#index` на regex `index` при извлечении `form` (строка 115)
- Новые тест-кейсы для word boundary matching

**НЕ входит:**
- Поддержка опечаток и нечёткого матчинга
- Учёт словоформ ("run" vs "running")
- Изменение логики tie-breaking (longest match, earliest position, etc.)
- Изменение формата ответа API или структуры данных
- Многоязычный матчинг (только английский)

---

## Контекст: текущий код

Три места используют substring match без границ слов:

### 1. Фильтрация кандидатов (строка 232)

```ruby
candidates = lexemes.select { |_id, hw| text_eng.downcase.include?(hw.downcase) }
```

`String#include?` — substring match. "ago" совпадёт с "agony", "cat" с "category".

### 2. Позиция матча для tie-breaking (строка 236)

```ruby
idx = text_eng.downcase.index(hw.downcase)
```

`String#index` — та же substring проблема. Позиция может указывать внутрь другого слова.

### 3. Извлечение form (строка 115)

```ruby
form = row[:text_eng][row[:text_eng].downcase.index(hw.downcase), hw.length]
```

Извлекает подстроку по позиции — нужно использовать ту же regex позицию для консистентности.

---

## Решение

### Helper-метод

```ruby
def word_boundaries_regex(headword)
  Regexp.new("\\b#{Regexp.escape(headword)}\\b", Regexp::IGNORECASE)
end
```

- `\b` — word boundary (переход между `\w` и `\W`)
- `Regexp.escape` — экранирует спецсимволы в headword (например, `C++`, `don't`)
- `Regexp::IGNORECASE` — case-insensitive matching

### Изменение 1: фильтрация кандидатов (строка 232)

```ruby
# Было:
candidates = lexemes.select { |_id, hw| text_eng.downcase.include?(hw.downcase) }

# Стало:
downcased = text_eng.downcase
candidates = lexemes.select { |_id, hw| word_boundaries_regex(hw).match?(downcased) }
```

### Изменение 2: позиция в tie-breaking (строка 236)

```ruby
# Было:
idx = text_eng.downcase.index(hw.downcase)

# Стало:
idx = downcased.index(word_boundaries_regex(hw))
```

### Изменение 3: извлечение form (строка 115)

```ruby
# Было:
form = row[:text_eng][row[:text_eng].downcase.index(hw.downcase), hw.length]

# Стало:
form = row[:text_eng][row[:text_eng].downcase.index(word_boundaries_regex(hw)), hw.length]
```

---

## Миграция существующих данных

Существующие `SentenceOccurrence`, импортированные с багом, содержат неверные связки (например, "ago" → предложение с "agony"). После фикса алгоритма:

1. Удалить все записи `SentenceOccurrence` с `source: "quizword"` (через `Sentence` с `source: "quizword"`)
2. Перезапустить полный импорт `Sentences::ImportQuizword` с `START_PAGE=1`
3. Существующие `Sentence` и `SentenceTranslation` не трогаем — они корректны, проблема только в связке с лексемами

> **Note:** Шаги 1–3 выполняются вручную после деплоя. В спеке нет автозадачи, потому что реимпорт зависит от доступа к quizword.net.

---

## Зависимость: DB dump (feat 005)

После фикса и переимпорта необходимо пересобрать DB dump, чтобы cold start (dev/CI) разворачивал базу с корректными `SentenceOccurrence`. Дамп из feat 005 содержит данные, импортированные с багом.

---

## Инварианты

1. Логика tie-breaking **не меняется**: `[-hw.length, idx, hw.downcase, id.to_s]` — longest headword, earliest position, lexicographic, smallest ID
2. Case-insensitive matching сохраняется (через `Regexp::IGNORECASE`)
3. Извлечение `form` продолжает сохранять оригинальный регистр из текста предложения
4. `Regexp.escape` предотвращает regex injection из headword
5. Helper `word_boundaries_regex` — private-метод класса `ImportQuizword`, не добавляется в public API

---

## Сценарии ошибок

| Сценарий | Поведение |
|----------|-----------|
| Headword содержит спецсимволы (`C++`, `don't`) | `Regexp.escape` экранирует корректно — матчинг работает |
| Headword — пустая строка | `\b\b` не матчит ничего — кандидат отбрасывается (безопасно) |
| Текст содержит headword как часть другого слова | **Не матчит** — это и есть цель фикса |
| Текст содержит headword как отдельное слово | **Матчит** — нормальное поведение сохраняется |
| Несколько вхождений headword в текст | `index` возвращает первое вхождение — как раньше |

---

## Тест-кейсы

Добавить в `spec/operations/sentences/import_quizword_spec.rb`.

### Контекст 1: substring внутри другого слова не матчится

```
Контекст: "when a lexeme appears as a substring inside another word"

Лексема: headword = "cat"
Предложение: "The category is broad."

Ожидание:
- Предложение НЕ связывается с лексемой (no match)
- Skipped rows увеличивается
```

### Контекст 2: "ago" не матчится внутри "agony"

```
Контекст: "when lexeme 'ago' appears inside 'agony'"

Лексема: headword = "ago"
Предложение: "What agony it was."

Ожидание:
- Предложение НЕ связывается с лексемой (no match)
- Skipped rows увеличивается
```

### Контекст 3: слово как отдельная единица матчится корректно

```
Контекст: "when the same lexeme appears as a whole word"

Лексема: headword = "ago"
Предложение: "I saw it three years ago."

Ожидание:
- Предложение связывается с лексемой "ago"
- SentenceOccurrence создаётся с корректным lexeme_id
- form = "ago"
```

### Контекст 4: headword со спецсимволами

```
Контекст: "when headword contains regex special characters"

Лексема: headword = "don't"
Предложение: "I don't know."

Ожидание:
- Предложение связывается с лексемой "don't"
- form = "don't" (оригинальный регистр сохраняется)
```

---

## Acceptance Criteria

- [ ] `find_lexeme` использует regex с `\b` вместо `String#include?`
- [ ] Извлечение `form` использует regex `index` вместо `String#index`
- [ ] Helper `word_boundaries_regex(headword)` экранирует спецсимволы через `Regexp.escape`
- [ ] Тест: "cat" не матчится внутри "category" — предложение пропускается
- [ ] Тест: "ago" не матчится внутри "agony" — предложение пропускается
- [ ] Тест: "ago" матчится как отдельное слово в "I saw it three years ago."
- [ ] Тест: headword со спецсимволами ("don't") матчится корректно
- [ ] Существующие тесты (longest match, tie-breaking, idempotency) продолжают проходить
- [ ] `bundle exec rspec` — все тесты проходят
- [ ] `bundle exec rubocop` — без нарушений

---

## Ограничения реализации

- Не добавлять новые гемы
- Не менять структуру данных (возвращаемое значение `find_lexeme` — тот же `[id, hw]` tuple)
- Не менять логику tie-breaking
- Не менять `insert_batch` и другие методы
- Helper `word_boundaries_regex` — private-метод в `Sentences::ImportQuizword`
- Файлы совместимы с Zeitwerk (без изменений в autoload paths)
- После фикса и переимпорта пересобрать DB dump (feat 005)

---

_Spec v1.0 | 2026-04-07_

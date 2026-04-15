---
title: "PRD-002: Word Mastery — Dual-Level Spaced Repetition"
doc_kind: prd
doc_function: canonical
purpose: Фиксирует продуктовую проблему, целевых пользователей, goals, scope и success metrics инициативы перехода от card-first к word-centric модели обучения.
derived_from:
  - ../domain/problem.md
  - PRD-001-lingvize-mvp.md
status: active
audience: humans_and_agents
must_not_define:
  - implementation_sequence
  - architecture_decision
  - feature_level_verify_contract
---

# PRD-002: Word Mastery — Dual-Level Spaced Repetition

## Problem

MVP Lingvize (PRD-001) построен на card-first модели: FSRS живёт на карточке, а знание слова как отдельная сущность отсутствует. Это создаёт три продуктовых проблемы:

1. **Ложное освоение.** Пользователь успешно вспоминает слово в одном заученном предложении, но не узнаёт его в новом контексте. FSRS оптимизирует запоминание конкретного предложения, а не знание слова.

2. **Полисемия не учтена.** `run` как "бежать" и `run` как "работать (о моторе)" — разные знания. Текущая модель склеивает их в один `Lexeme`, и успех в одном значении ложно засчитывается другому.

3. **Один контекст на слово.** `BuildStarterDeck` выдаёт по одной карточке на лексему. Нет механизма расширения контекстного покрытия — пользователь застревает в одном примере навсегда.

Подробный project-wide контекст: [`../domain/problem.md`](../domain/problem.md).

## Users And Jobs

| User / Segment | Job To Be Done | Current Pain |
| --- | --- | --- |
| Изучающий английский (A1-B2) | Знать слово в разных контекстах и значениях, а не узнавать одно предложение | Успешно отвечает на знакомую карточку, но не понимает слово в новом тексте |
| Изучающий английский (B1+) | Различать значения полисемичных слов | Все значения `run` склеены — нет контроля, какие освоены |
| Контент-менеджер (внутренний) | Группировать контент по значениям и контекстным семьям | Нет инструмента: предложения привязаны к headword без семантической разметки |

## Goals

- `G-01` Учебная единица = слово как `lemma + sense`, а не карточка. Пользователь видит прогресс по словам, а не по карточкам.
- `G-02` Система планирует повторение на двух уровнях: контекст (не забыть конкретный пример) и слово (знаю ли слово достаточно широко).
- `G-03` Контекстное покрытие: для каждого слова/значения нужны примеры из разных контекстных семей. Повторы near-duplicate предложений дают слабый вклад в mastery.
- `G-04` Полисемия: разные значения одного headword отслеживаются и оцениваются независимо.
- `G-05` Результат ответа на карточку влияет на оценку знания всего слова с учётом новизны контекста и семьи.

## Non-Goals

- `NG-01` Полный пересмотр FSRS-алгоритма на уровне карточек — card FSRS остаётся как есть.
- `NG-02` A/B тестирование dual-level vs card-only — это задача post-launch эксперимента.
- `NG-03` Автоматическая WSD (word sense disambiguation) в рантайме — контекстная дизамбигуация при ответе пользователя вне scope.
- `NG-04` Месячная персонализация FSRS-параметров — требует достаточного объёма данных, вне scope.
- `NG-05` Пользовательский UI для управления значениями и контекстными семьями.

## Product Scope

### In Scope

- Новая сущность "значение слова" (`sense`) как атом обучения, отделённый от headword.
- Персональное состояние знания слова/значения у пользователя (word mastery) с метриками: stability, context coverage, sense coverage, reliability.
- Классификация контекстных семей (context families) для предложений. Контекстная семья — группа предложений, использующих слово в схожей ситуации или домене (напр., `run` в спорте vs. `run` в бизнесе). Таксономия v1 — curated (не algorithmic), формат и состав фиксируются в feature spec.
- Импорт sense-данных из минимум одного утверждённого внешнего источника для автоматической разметки значений при сборке контента. Выбор источника и критерии готовности импорта фиксируются в feature/ADR.
- Ответ пользователя обновляет card-level scheduling и формирует evidence для word mastery.
- Session builder, учитывающий два долга: card debt (просроченные карточки) и word debt (слова с плохим покрытием).
- Выбор лучшего occurrence при word debt: предпочтение невиденной контекстной семьи.
- Прозрачная трассируемость: каждый вклад review в word mastery записан с весом и обоснованием.
- Dashboard прогресса по словам (не только по карточкам).

### Out Of Scope

- Рекомендательная система "какое слово учить следующим" (curriculum).
- Аналитика переноса знания на невиденные контексты (experimental metric).
- Множественные колоды и курсы.
- Геймификация и социальные функции.

## UX / Business Rules

- `BR-01` Учебная единица для полисемии — `lemma + sense`, а не surface word. Для monosemous слов допустимо `lemma == sense` как упрощение.
- `BR-02` Карточка остаётся единицей показа в сессии. Пользователь по-прежнему видит cloze-предложение и вводит ответ.
- `BR-03` Ответ обновляет card FSRS (как в PRD-001), затем формирует evidence для word mastery.
- `BR-04` Вес evidence зависит от новизны контекста (порядок приоритета):
  - Новая контекстная семья: максимальный вклад.
  - Виденная семья, новое предложение: сниженный вклад.
  - Near-duplicate предложение: минимальный вклад.
  Конкретные коэффициенты — вопрос ADR (весовая модель агрегации card → word mastery).
- `BR-05` Ошибка в базовом/простом контексте сильнее бьёт по word mastery, чем ошибка в редком/сложном.
- `BR-06` Планировщик сессии учитывает card debt и word debt. Card debt (просроченные карточки) приоритетнее; word debt (слова с низким покрытием) заполняет оставшееся место в сессии. Если due слово, но нет due карточки — сессия выбирает лучший unseen occurrence. Конкретные пропорции — вопрос feature/ADR.
- `BR-07` Dashboard показывает прогресс по словам: сколько слов освоено, в процессе, не начато. Для каждого слова пользователь видит уровень mastery (визуальный индикатор глубины знания). Конкретный формат отображения mastery — вопрос дизайна (ADR/feature), но PRD фиксирует: пользователь должен понимать *насколько* он знает слово, а не только бинарное "знаю/не знаю". Прогресс карточек остаётся доступен как детализация.
- `BR-08` Существующие карточки и review logs не теряются. Миграция не-деструктивна: новые сущности дополняют, а не заменяют текущую схему. 100% existing cards должны быть mapped к word mastery state после миграции.
- `BR-09` Система корректно работает при любом количестве контекстов для слова, включая один. Слово с единственным предложением нормально живёт в dual-level модели: word mastery строится от имеющихся карточек, context coverage = 1 — это валидное состояние, а не ошибка. Расширение контекстов происходит по мере появления контента.

## Success Metrics

| Metric ID | Metric | Baseline | Target | Measurement method |
| --- | --- | --- | --- | --- |
| `MET-01` | Word mastery state существует для каждого слова пользователя | 0 | 100% карточек имеют upstream word mastery | DB query |
| `MET-02` | Контекстное покрытие: среднее число контекстных семей на освоенное слово (среди слов с 2+ доступными context families) | 1 | >= 2 в течение 3 месяцев после запуска | `AVG(distinct_context_families_count) WHERE mastered AND available_families >= 2` |
| `MET-03` | Session builder учитывает word debt | Нет | При наличии word-debt candidates и отсутствии higher-priority due cards, сессия включает минимум 1 word-debt карточку | RSpec: synthetic pool с word_debt candidates |
| `MET-04` | Evidence traceability: каждый review имеет contribution record | 0% | 100% | `ReviewLog.count == LexemeReviewContribution.count` |
| `MET-05` | Existing cards mapped к word mastery state после миграции | 0% | 100% | `Card.joins(:word_mastery_state).count == Card.count` |
| `MET-06` | Полисемичные лексемы имеют раздельный sense-tracking | 0 | 100% из configured top-100 полисемичных лексем имеют ≥2 senses с independent user-level state | DB query: top-100 list (curated) × `UserSenseState.where(lexeme:).distinct(:sense).count >= 2` |

## Relation To PRD-001

PRD-002 расширяет, а не заменяет PRD-001. Конкретные изменения:

- **MET-04** (FSRS scheduling) — PRD-002 добавляет word-level scheduling поверх card-level. Card FSRS из PRD-001 остаётся.
- **BR-01—BR-03** — PRD-002 расширяет обработку ответа: помимо card FSRS, ответ формирует evidence для word mastery.
- **G-01** (стартовая колода) — PRD-002 не меняет starter deck flow, но starter deck должен создавать word mastery states для выданных слов.

## Risks And Open Questions

- `RISK-01` Сложность sense-разметки: 9500+ лексем. Mitigation: импорт sense-данных из WordNet/Oxford при сборке контента (автоматизация в scope). Mono-sense assumption как fallback до разметки.
- `RISK-02` Определение context families: нет готовой таксономии. Mitigation: v1 = curated string labels из контролируемого словаря; fallback для неклассифицированных = `unknown`. Формализация таксономии — итеративно.
- `RISK-03` Весовая модель агрегации card → word может потребовать итераций. Mitigation: traceability через contribution records позволяет пересчитывать mastery.

### Resolved Questions

- `OQ-01` **Сколько контекстных семей для "закреплённого" слова?** Resolution: жёсткий порог не нужен. Context coverage — непрерывный сигнал для приоритизации в очереди, а не бинарный gate. 1 семья = функционально, 2+ = уверенно. Пользователь чувствует прогресс с первой успешной карточки; система тихо расширяет контексты по мере появления контента и места в сессии.
- `OQ-02` **FSRS vs rule-based для word mastery?** Resolution: hybrid. Word mastery вычисляется rule-based агрегатом из card states (прозрачно, объяснимо). Word debt должен учитывать и due-карточки, и потребность расширения context coverage. Конкретный алгоритм вычисления word due — вопрос ADR/feature spec. Полноценный FSRS на word level не нужен — слово не ревьюится напрямую.
- `OQ-03` **Sense не размечен?** Resolution: fallback `lexeme == sense`. UserLexemeState строится для lexeme, mastery агрегируется от его карточек. При появлении sense-разметки state разделяется. Система работает с первого дня без sense-данных.

## Downstream Features

| Feature | Why it exists | Status |
| --- | --- | --- |
| [`FT-029`](../features/FT-029/) | Lexeme Sense: доменная сущность `sense`, контекстные семьи, импорт из WordNet (ADR-001), Tatoeba direct import | active |
| `FT-XXX` | Word Mastery State: персональное состояние знания слова у пользователя | planned |
| `FT-XXX` | Review Pipeline v2: contribution card → word mastery | planned |
| `FT-XXX` | Session Builder v2: dual-level scheduling (card debt + word debt) | planned |
| `FT-XXX` | Word Progress Dashboard: прогресс по словам вместо карточек | planned |

# Spec: Дизайн-система и редизайн экрана сессии повторений

**Brief:** [008 — Дизайн-система проекта](brief.md)
**Reference:** `memory-bank/DESIGN.md` (справочник), `memory-bank/features/008/reference.html` (целевой макет)

## Цель

Внедрить дизайн-систему из `DESIGN.md` в проект и пересобрать экран сессии повторений (`/review`) по макету `reference.html`, валидируя работоспособность справочника.

## Scope

**Входит:**

1. Настройка дизайн-токенов: цвета, шрифты, скругления (по `DESIGN.md`)
2. Подключение шрифтов: Manrope, Newsreader, Inter, Material Symbols Outlined
3. Редизайн layout приложения — навигация, glassmorphism-шапка, filament-прогресс, мобильная bottom-навигация
4. Редизайн экрана `/review` — карточка, прогресс, таймер, пустое состояние
5. Адаптация клиентской логики — обновление валидации, таймер сессии, обработка Enter

**Не входит:**

- Редизайн других экранов (dashboard, admin, auth)
- Реализация компонентной библиотеки
- Тёмная тема (dark mode)
- Новая бизнес-логика или изменения моделей/миграций/маршрутов
- RTL-языки
- Функциональность кнопок «Не знаю», «Пропустить», «Замедлить произношение» — рендерятся как заглушки
- Страница «Профиль» — ссылка-заглушка

---

## Требования

### 1. Дизайн-токены

Система использует кастомную тему с токенами, описанными в `DESIGN.md` (source of truth):

**Цвета:** полный перечень из `DESIGN.md` секция 2, включая:
- Surface-иерархия: `surface`, `surface-container-lowest`, `surface-container-low`, `surface-container`, `surface-container-high`, `surface-container-highest`, `surface-dim`, `surface-bright`, `surface-tint`, `surface-variant`
- Primary-токены: `primary`, `primary-container`, `primary-fixed`, `primary-fixed-dim`, `on-primary`, `on-primary-container`, `on-primary-fixed`, `on-primary-fixed-variant`
- Secondary-токены: аналогичный набор
- Tertiary-токены: аналогичный набор
- Error-токены: `error`, `error-container`, `on-error`, `on-error-container`
- Outline-токены: `outline`, `outline-variant`
- Background-токены: `background`, `on-background`
- Inverse-токены: `inverse-surface`, `inverse-on-surface`, `inverse-primary`

**Шрифты:**
- `font-headline` — Manrope (для заголовков и UI)
- `font-body` — Newsreader (для контента/иноязычного текста)
- `font-label` — Inter (для меток и мелкого текста)

**Скругления:**
- `sm` — 0.25rem (маленькие элементы)
- `md` — 0.75rem (кнопки, интерактивные элементы)
- `lg` — 1rem (основные карточки)
- `xl` — 1.5rem (hero-секции)
- `full` — 9999px (pills, chips)

**Правило "No-Line":** запрет на использование 1px solid borders для секционирования — границы определяются через изменение цвета фона.

### 2. Layout приложения

**Глобальные элементы:**

- Фон приложения: `bg-surface text-on-surface`
- Flex-колонка для структуры: `min-h-screen flex flex-col`
- Main content: центрирование, `max-w-4xl`, нижний padding для mobile bottom nav

**Навигация (верхняя):**

- Sticky позиционирование вверху экрана
- Glassmorphism-эффект: прозрачность 80% + backdrop blur
- Логотип "Lingvize" шрифтом Manrope
- Активная страница: подчёркивание и акцентный цвет

**Filament-прогресс:**

- Полоса 2px цвета `tertiary` под навигацией
- Видна только на `/review`
- Ширина = `(position / total) * 100%`
- При `total = 0` скрыта

**Flash-сообщения:**

- Alert: `error-container` фон + `on-error-container` текст
- Notice: `tertiary-fixed` фон (10% opacity) + `tertiary` текст

**Mobile bottom nav:**

- Фиксированная внизу экрана, видна только на мобильных (скрыта на desktop)
- Glassmorphism-эффект, скруглённые верхние углы
- Три элемента: Главная, Обучение, Профиль
- Текст под иконками, шрифт Inter, 10px

**Инварианты layout:**

- Mobile bottom nav рендерится только в layout, не дублируется в других шаблонах
- Filament-прогресс условно рендерится — существует только на `/review`
- Контент на мобильных получает дополнительный padding снизу, чтобы не перекрываться bottom nav

### 3. Карточка сессии повторений

**Контейнер карточки:**

- Фон: `surface-container-lowest`
- Скругление: `xl` (1.5rem)
- Отступы: большие (10rem на desktop, меньше на mobile)
- Тень: whisper shadow — мягкая, без чётких границ

**Аудио-кнопка:**

- Расположена ВЫШЕ cloze-предложения (целевое слово не отображается)
- Круглая форма, medium size
- Фон: `primary-fixed` с `on-primary-fixed` текстом
- Hover: `primary` фон с белым текстом
- Focus: ring-эффект с полупрозрачным primary
- Рендерится только при наличии `sentence.audio_id`

**Cloze-отображение:**

- Целевое слово (`card.form`) **НЕ отображается** на экране — пользователь угадывает по контексту
- Input встроен в текст предложения (inline), не вынесен отдельным полем
- Предложение разделено на части: текст до слова, input, текст после слова
- Разбиение через case-insensitive split по целевому слову
- Шрифт: Newsreader (font-body), курсив, размер xl-lg
- Цвет: `on-surface-variant`

**Inline-input:**

- Минималистичный ledger-стиль — без бэкграунда, только bottom border
- Фон: прозрачный
- Border: `outline-variant` (2px)
- На фокусе: border меняется на `primary`
- Ширина динамическая — подстраивается под длину ожидаемого слова
- Центрированный текст
- Шрифт и стиль наследуются от предложения

**Подсказка (glosses):**

- Расположена под предложением
- Цвет: `primary` с 60% opacity
- Шрифт: Inter (font-label), medium weight, курсив
- Размер: small

**Кнопки:**

**"Проверить" (primary):**
- Gradient: `primary` → `primary-container` под углом 135°
- Текст: белый
- Скругление: `md`
- Hover: подъём на 2px вверх
- Focus: ring-эффект с `primary`
- Disabled: opacity 50%, курсор not-allowed, gradient сохраняется
- Loading: текст заменяется на "...", кнопка disabled
- Transition: все 300ms

**"Знаю это слово" (secondary):**
- Фон: `surface-container-high`
- Текст: `on-surface-variant`
- Скругление: `md`
- Иконка: verified
- Hover: `surface-container-highest` + подъём 2px
- Focus: ring-эффект с `outline-variant`
- Disabled: opacity 50%

**"Не знаю" / "Пропустить" (tertiary):**
- Текстовые кнопки без фона
- Цвет: `on-surface-variant`
- Шрифт: Inter (font-label), small
- Иконки: `help_outline`, `skip_next`
- Hover: цвет меняется на `on-surface`
- Заглушки: при клике показывают alert с описанием будущей функциональности

**Декоративный элемент:**

- Иконка `auto_stories` в правом верхнем углу карточки
- Opacity: 5%
- Не интерактивная

**Инварианты карточки:**

- Целевое слово никогда не отображается как видимый элемент
- Аудио-кнопка рендерится только при наличии audio_id
- Заглушки-кнопки не имеют бизнес-логики, только `onclick="alert(...)"`

### 4. Прогресс и Таймер

**Блок прогресса + таймер (бок о бок):**

- Прогресс слева, таймер справа
- Full width, justify-between, alignment: bottom

**Прогресс:**

- Label: "Прогресс" — шрифт Inter (font-label), x-small, uppercase, tracking-widest, medium
- Счётчик: "N/M" — шрифт Manrope (font-headline), x-large, bold, цвет `on-surface`
- Слэш: цвет `on-surface-variant` с 40% opacity, горизонтальные отступы

**Таймер:**

- Label: "Таймер сессии" — стиль как у label прогресса
- Иконка: `timer`, размер 20px
- Значение: формат MM:SS с ведущими нулями, шрифт Manrope (font-headline), bold, large, цвет `primary`

**Вычисление прогресса:**

- `total` — общее количество карточек в сессии
- `position` — текущая позиция (1-based)
- При загрузке страницы: position = 1
- После submit: position = предыдущее + 1
- При завершении (нет следующей карточки): position = total, отображается M/M
- Передаются через hidden fields в форме

**Таймер (логика):**

- Запускается при загрузке карточки
- Обновляется каждую секунду
- Формат: MM:SS
- Останавливается при смене карточки или уходе со страницы

### 5. Study Metadata

Под карточкой — 3-колоночная сетка на desktop, 1 колонка на mobile:

**Контекстная подсказка:**
- Заголовок: Manrope, bold, small, `on-surface`
- Текст-заглушка: Newsreader, `on-surface-variant`, base, leading-relaxed, содержимое о будущем поле context_note

**Сложность:**
- Заголовок: как выше
- Индикатор: серия точек (h-1.5 w-6 rounded-full)
- Заполненные: `tertiary-fixed`
- Пустые: `surface-container-highest`
- Заглушка: 2 из 3 точек заполнены

**Настройки аудио:**
- Заголовок: как выше
- Кнопка-заглушка "Замедлить произношение": `primary`, small, medium, left-aligned, hover underline

Все три колонки — заглушки с TODO-комментариями для будущей функциональности.

### 6. Empty state

**Контейнер:**

- Фон: `surface-container-lowest`
- Скругление: `xl`
- Тень: whisper shadow
- Отступы: 10rem
- Центрирование текста

**Иконка завершения:**

- Круг с фоном `tertiary-fixed` (10% opacity)
- Галочка цветом `tertiary`

**Текст:**

- Заголовок: Manrope, large, semibold
- Сообщение: Newsreader/Inter, `on-surface-variant`

**Кнопка:**

- Gradient primary (как кнопка "Проверить")

### 7. Клиентская логика (Stimulus)

**Цели:**

- Таймер сессии
- Валидация ввода в реальном времени
- Ghost text после ошибки
- Обработка Enter в input
- Динамическая ширина input

**Enter key:**

- При нажатии Enter в input предотвращается стандартный submit формы
- Вызывается тот же обработчик что и при клике на кнопку submit

**Timer:**

- Интервал 1 секунда
- Обновляет текстовое значение таймера (MM:SS)
- Останавливается при disconnect

**Ghost text:**

- После неправильного ответа input показывает правильный ответ как placeholder
- При начале ввода placeholder очищается
- Восстанавливается если пользователь снова очистил input

**Валидация ввода (real-time):**

- Если префикс ожидаемого слова совпадает с введённым — border меняется на `tertiary`
- Если не совпадает — border меняется на `error`
- Если пустой — стандартный цвет

**После submit:**

- Правильный: border `tertiary`
- Неправильный: border `error`
- Повторная попытка: border `primary`

**Форма:**

- Использует Turbo для async submit без перезагрузки

### 8. CSS Utility Classes

Определены следующие утилитарные классы:

- `.editorial-shadow` — whisper shadow
- `.filament-progress` — полоса прогресса с transition
- `.material-symbols-outlined` — настройки для Material Symbols
- `.inline-input-wrapper` — обёртка для inline input
- `.inline-input` — стили inline input (transparent background, bottom border)

### 9. Accessibility

- Все кнопки с иконками имеют `aria-label`
- Inline cloze input имеет `aria-label` с описанием
- Контрастность текста на фонах соответствует WCAG AA (>= 4.5:1)
- Focus visible: inline input меняет border-color, кнопки получают ring-эффект

### 10. Иконки

Используются Material Symbols Outlined (Google Fonts):

Замены эмодзи и SVG:
- `🧠` → `verified`
- SVG галочка → `check_circle`

Новые иконки:
- `volume_up`, `help_outline`, `skip_next`, `auto_stories`, `timer`, `dashboard`, `menu_book`, `person`

---

## Инварианты

1. `DESIGN.md` является единственным источником истины для визуальных решений
2. Целевое слово (`card.form`) никогда не отображается как видимый элемент
3. Аудио-кнопка рендерится только при наличии `sentence.audio_id`
4. Mobile bottom nav рендерится только в layout, не дублируется
5. Filament-прогресс существует только на `/review`, скрыт на других страницах
6. Заглушки-кнопки не имеют бизнес-логики, только визуальное представление
7. Таймер останавливается при смене карточки или уходе со страницы
8. Ghost text появляется только после первой ошибки, очищается при вводе
9. `correct` фиксируется по первой попытке, не меняется при retry (унаследовано из feat 007)

---

## Сценарии ошибок

| Сценарий | Поведение |
|----------|-----------|
| Шрифты не загрузились (Google Fonts недоступен) | Fallback: headline → system sans-serif, body → system serif, label → system sans-serif |
| Material Symbols не загрузились | Иконки пропадают, текст через `aria-label` сохраняется |
| Audio URL пуст или невалиден | Аудио-кнопка не рендерится |
| `card.sentence.text` не содержит `card.form` | Case-insensitive split, если не нашёл — fallback: показать `cloze_text` как текст + отдельный input |
| Все карточки пройдены | `@next_card` nil, прогресс показывает M/M, рендерится empty state |
| Двойной submit (Enter + клик кнопки) | `preventDefault()` на Enter предотвращает дублирование |

---

## Acceptance Criteria

### Дизайн-токены
- [ ] `DESIGN.md` находится в `memory-bank/DESIGN.md` и используется как source of truth
- [ ] Шрифты Manrope, Newsreader, Inter, Material Symbols Outlined подключены через Google Fonts
- [ ] Все цветовые токены из `DESIGN.md` определены в кастомной теме
- [ ] Все шрифтовые токены определены
- [ ] Все токены скругления определены
- [ ] Utility-классы определены: editorial-shadow, filament-progress, inline-input, inline-input-wrapper, material-symbols-outlined

### Layout
- [ ] Layout содержит sticky-навигацию с glassmorphism (backdrop blur)
- [ ] Filament-прогресс рендерится только на `/review`, ширина корректно вычисляется
- [ ] Filament-прогресс скрыт при `total = 0`
- [ ] Mobile bottom nav видна только на мобильных (`md:hidden`), glassmorphism, фиксирована внизу
- [ ] Main content получает нижний padding на мобильных, не перекрывается bottom nav
- [ ] Bottom nav НЕ дублируется — рендерится только в layout
- [ ] Flash-сообщения используют правильные цвета: alert → error-container/on-error-container, notice → tertiary-fixed

### Карточка
- [ ] Карточка использует `bg-surface-container-lowest`, `rounded-xl`, editorial-shadow
- [ ] Целевое слово (`card.form`) **НЕ отображается** на экране
- [ ] Аудио-кнопка рендерится только при наличии `sentence.audio_id`
- [ ] Аудио-кнопка имеет правильный icon, стиль, hover/focus состояния
- [ ] Cloze-input встроен в текст предложения (inline), не вынесен отдельным полем
- [ ] Inline-input использует minimalist ledger-стиль (transparent bg, bottom border)
- [ ] Inline-input ширина динамическая, подстраивается под длину ожидаемого слова
- [ ] Предложение использует Newsreader, курсив, `on-surface-variant`
- [ ] Glosses используют `primary/60`, Inter, курсив
- [ ] Кнопка "Проверить": gradient primary, белый текст, правильные hover/focus/disabled состояния
- [ ] Кнопка "Знаю это слово": `surface-container-high`, `on-surface-variant`, иконка verified
- [ ] Кнопки "Не знаю" / "Пропустить": текстовые, показывают alert с описанием функциональности
- [ ] Декоративный элемент `auto_stories` присутствует с opacity 5%

### Прогресс и Таймер
- [ ] Прогресс показывает корректное "N/M"
- [ ] Прогресс label и счётчик используют правильные шрифты и цвета
- [ ] Таймер label использует правильный стиль
- [ ] Таймер показывает формат MM:SS с ведущими нулями
- [ ] Таймер обновляется каждую секунду
- [ ] При завершении карточек прогресс показывает "M/M"
- [ ] Hidden fields для position и total корректно передаются

### Клиентская логика
- [ ] Нажатие Enter в input вызывает submit с `preventDefault()`
- [ ] Timer запускается при загрузке карточки, останавливается при disconnect
- [ ] Ghost text появляется после ошибки, очищается при вводе
- [ ] Валидация ввода: правильный префикс → border tertiary, иначе → error
- [ ] Валидация после submit: правильный → tertiary, неправильный → error, retry → primary
- [ ] Форма использует Turbo для async submit

### Empty state
- [ ] Empty state использует `bg-surface-container-lowest`, `rounded-xl`, editorial-shadow
- [ ] Иконка завершения использует `tertiary-fixed/10` и `tertiary`
- [ ] Кнопка использует gradient primary

### Accessibility и прочее
- [ ] Все кнопки с иконками имеют `aria-label`
- [ ] Inline input имеет `aria-label`
- [ ] Контрастность соответствует WCAG AA
- [ ] Focus visible состояния работают корректно
- [ ] Иконки Material Symbols загружаются и отображаются
- [ ] Ручная проверка на breakpoints: контент не обрезается, кнопки доступны
- [ ] `bundle exec rubocop` проходит без новых нарушений
- [ ] `bundle exec rspec` проходит

---

## Ограничения

- НЕ менять модели, миграции, маршруты
- В контроллере допускается только: передача `@total`, `@position`, hidden fields, метод для расчёта переменных прогресса
- НЕ добавлять новые гемы
- Использовать `@theme` в CSS (Tailwind v4 синтаксис)
- Иконки через Material Symbols Outlined (Google Fonts CDN), не через npm
- НЕ реализовывать бизнес-логику заглушек — только alert с описанием

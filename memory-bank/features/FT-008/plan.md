# Plan: Дизайн-система и редизайн экрана сессии повторений

**Spec:** [008 — spec.md](spec.md)
**Grounding:** 2026-04-07

## Архитектурные решения

### Прогресс-блок (N/M) — внутри turbo frame
Блок `N/M` живёт внутри `_card_form.html.erb` (в `turbo_frame_tag "review_card"`), а не в `show.html.erb` снаружи. Иначе он не обновится при Turbo-переходе между карточками. Доступ к `@position`/`@total` — через instance variables контроллера.

### Таймер сессии — рядом с прогрессом
Таймер (MM:SS) отображается справа от прогресс-блока, оба внутри `_card_form.html.erb`. Обновляется каждую секунду через JavaScript.

### Filament — обновляется вторым turbo_stream action
Filament в nav находится снаружи turbo frame. При Turbo-переходе (`create.turbo_stream.erb`) добавляем второй action: `turbo_stream.replace "filament-container"`. Весь контейнер `id="filament-container"` всегда присутствует в DOM layout — при замене пересчитывается и ширина, и видимость.

### content_for :filament_width — только при начальной загрузке
`show.html.erb` задаёт `content_for :filament_width` для первичного рендера. При Turbo-переходах filament обновляется через turbo_stream.

### Inline cloze — split в шаблоне, без хелпера
Прямо в `_card_form.html.erb`:
```erb
<% before, after = card.sentence.text.split(/#{Regexp.escape(card.form)}/i, 2) %>
```
Если split не нашёл совпадения (`before.nil?` или `after.nil?`) — fallback: `card.cloze_text` как текст + отдельный input ниже.

### Целевое слово — НИГДЕ не отображается
`card.form` используется только для:
- data-атрибута контроллера (expected answer)
- разбиения предложения на части для inline input
- placeholder после ошибки (ghost text)

Никакого `<h1>` или видимого элемента с `card.form`.

### Audio URL — Tatoeba CDN
URL строится как: `https://audio.tatoeba.org/sentences/eng/#{audio_id}.mp3`. Не использовать внутренний route.

### Кастомные CSS-классы — через @layer в application.css
`.editorial-shadow`, `.filament-progress`, `.inline-input`, `.inline-input-wrapper`, `.material-symbols-outlined` — определяются в `@layer components` после `@theme`.

### review_controller.js — style.borderBottomColor вместо classList
Inline input имеет только `border-bottom`, поэтому `ring-*` классы убираются. Валидация: `this.inputTarget.style.borderBottomColor = <css-var>`.

### Таймер в Stimulus — отдельный метод и interval
При `connect()` создаётся интервал 1 секунда, обновляющий `timerTarget.textContent`. При `disconnect()` интервал очищается.

---

## Зависимости

```
Группа A (параллельно, без зависимостей):
  Step 1: DESIGN.md → корень проекта
  Step 2: CSS tokens (@theme в application.css)
  Step 3: Контроллер (@total, @position)

Группа B (после A, параллельно между собой):
  Step 4: Layout (application.html.erb) — зависит от Step 2 (токены известны)
  Step 5: show.html.erb — зависит от Step 3
  Step 6: _card_form.html.erb — зависит от Step 2 и Step 3
  Step 7: _empty_state.html.erb — зависит от Step 2
  Step 8: create.turbo_stream.erb — зависит от Step 3 и Step 4 (id="filament-container" в layout)
  Step 9: review_controller.js — зависит от Step 6 (понимание нового DOM)
  Step 10: i18n — нет зависимостей

Группа C (после B):
  Step 11: Верификация (rubocop, rspec, мануальный чек)
```

---

## Шаги реализации

### Step 1: DESIGN.md в корень

**Файл:** `DESIGN.md`

Скопировать `memory-bank/DESIGN.md` в `DESIGN.md` (корень проекта). Это единственный справочник визуальных решений — AC требует его наличие в корне.

---

### Step 2: CSS дизайн-токены

**Файл:** `app/assets/tailwind/application.css`

После `@import "tailwindcss"` добавить:

```css
@theme {
  /* Цвета — полный перечень из DESIGN.md */
  --color-surface: #f7f9fb;
  --color-surface-container-lowest: #ffffff;
  --color-surface-container-low: #f2f4f6;
  --color-surface-container: #eceef0;
  --color-surface-container-high: #e6e8ea;
  --color-surface-container-highest: #e0e3e5;
  --color-surface-dim: #d8dadc;
  --color-surface-bright: #f7f9fb;
  --color-surface-tint: #005db6;
  --color-surface-variant: #e0e3e5;
  --color-on-surface: #191c1e;
  --color-on-surface-variant: #424752;
  --color-primary: #00478d;
  --color-primary-container: #005eb8;
  --color-primary-fixed: #d6e3ff;
  --color-primary-fixed-dim: #a9c7ff;
  --color-on-primary: #ffffff;
  --color-on-primary-container: #c8daff;
  --color-on-primary-fixed: #001b3d;
  --color-on-primary-fixed-variant: #00468c;
  --color-secondary: #515f74;
  --color-secondary-container: #d5e3fc;
  --color-secondary-fixed: #d5e3fc;
  --color-secondary-fixed-dim: #b9c7df;
  --color-on-secondary: #ffffff;
  --color-on-secondary-container: #57657a;
  --color-on-secondary-fixed: #0d1c2e;
  --color-on-secondary-fixed-variant: #3a485b;
  --color-tertiary: #005237;
  --color-tertiary-container: #006d4a;
  --color-tertiary-fixed: #6ffbbe;
  --color-tertiary-fixed-dim: #4edea3;
  --color-on-tertiary: #ffffff;
  --color-on-tertiary-container: #65f2b5;
  --color-on-tertiary-fixed: #002113;
  --color-on-tertiary-fixed-variant: #005236;
  --color-error: #ba1a1a;
  --color-error-container: #ffdad6;
  --color-on-error: #ffffff;
  --color-on-error-container: #93000a;
  --color-outline: #727783;
  --color-outline-variant: #c2c6d4;
  --color-background: #f7f9fb;
  --color-on-background: #191c1e;
  --color-inverse-surface: #2d3133;
  --color-inverse-on-surface: #eff1f3;
  --color-inverse-primary: #a9c7ff;

  /* Шрифты */
  --font-headline: "Manrope", sans-serif;
  --font-body: "Newsreader", serif;
  --font-label: "Inter", sans-serif;

  /* Скругления */
  --radius-sm: 0.25rem;
  --radius-md: 0.75rem;
  --radius-lg: 1rem;
  --radius-xl: 1.5rem;
  --radius-full: 9999px;
}

@layer components {
  .editorial-shadow {
    box-shadow: 0 10px 40px -10px rgba(25, 28, 30, 0.08);
  }

  .filament-progress {
    height: 2px;
    background-color: var(--color-tertiary);
    transition: width 0.6s cubic-bezier(0.4, 0, 0.2, 1);
  }

  .material-symbols-outlined {
    font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24;
    display: inline-block;
    line-height: 1;
  }

  .inline-input-wrapper {
    display: inline-flex;
    vertical-align: baseline;
    position: relative;
  }

  .inline-input {
    width: 140px;
    padding: 0 0.5rem;
    border: 0;
    border-bottom: 2px solid var(--color-outline-variant);
    background: transparent;
    font-family: inherit;
    font-style: inherit;
    text-align: center;
    outline: none;
    transition: border-color 0.3s;
  }

  .inline-input:focus {
    border-color: var(--color-primary);
  }
}
```

---

### Step 3: Контроллер — @total, @position

**Файл:** `app/controllers/review_sessions_controller.rb`

```ruby
def show
  @cards = Reviews::BuildSession.call(user: current_user)
  @card = @cards.first
  @total = @cards.size
  @position = 1
end

def create
  @card = current_user.cards.find(params[:card_id])
  # ... existing RecordAnswer code ...

  @next_cards = Reviews::BuildSession.call(user: current_user)
  @next_card = @next_cards.first
  @total = @next_cards.size
  @position = params[:position].to_i + 1
end
```

---

### Step 4: Layout

**Файл:** `app/views/layouts/application.html.erb`

**Изменения в `<head>`:**
- Добавить Google Fonts: Manrope, Newsreader, Inter, Material Symbols Outlined

**Изменения в `<body>`:**
- Класс: `bg-surface text-on-surface font-label min-h-screen flex flex-col`

**Sticky nav с glassmorphism:**
```erb
<nav class="bg-surface/80 backdrop-blur-xl sticky top-0 z-50">
  <!-- Logo "Lingvize" с Manrope -->
  <!-- Nav ссылки: Dashboard, Review -->
</nav>
```

**Filament bar под nav:**
```erb
<div id="filament-container" class="<%= content_for?(:filament_width) ? 'w-full bg-surface-container-low h-[2px]' : 'hidden' %>">
  <div class="filament-progress" style="<%= content_for?(:filament_width) ? yield(:filament_width) : 'width: 0%' %>"></div>
</div>
```

**Flash-сообщения:**
- `alert`: `bg-error-container text-on-error-container`
- `notice`: `bg-tertiary-fixed/10 text-tertiary`

**Main content:**
```erb
<main class="flex-grow flex flex-col items-center justify-center px-6 py-12 max-w-4xl mx-auto w-full pb-24 md:pb-0">
  <%= yield %>
</main>
```

**Mobile bottom nav:**
```erb
<div class="fixed bottom-0 left-0 w-full flex justify-around items-center px-4 pb-4 pt-2 md:hidden bg-surface/80 backdrop-blur-lg z-50 rounded-t-xl">
  <!-- Главная, Обучение (active), Профиль (stub) -->
</div>
```

---

### Step 5: show.html.erb

**Файл:** `app/views/review_sessions/show.html.erb`

```erb
<% if @total > 0 %>
  <% content_for :filament_width do %><%= "width: #{(@position.to_f / @total * 100).round}%" %><% end %>
<% end %>

<div class="w-full">
  <% if @card %>
    <%= render "card_form", card: @card %>
  <% else %>
    <%= render "empty_state" %>
  <% end %>
</div>
```

---

### Step 6: _card_form.html.erb — полный редизайн

**Файл:** `app/views/review_sessions/_card_form.html.erb`

Структура (без отображения `card.form`):

```erb
<%= turbo_frame_tag "review_card" do %>
  <%# Прогресс + Таймер %>
  <div class="w-full flex justify-between items-end mb-12">
    <div class="flex flex-col gap-1">
      <span class="text-on-surface-variant font-label text-xs font-medium tracking-widest uppercase">Прогресс</span>
      <span class="font-headline text-2xl font-bold text-on-surface">
        <%= @position %><span class="text-on-surface-variant/40 mx-1">/</span><%= @total %>
      </span>
    </div>
    <div class="flex flex-col items-end gap-1">
      <span class="text-on-surface-variant font-label text-xs font-medium tracking-widest uppercase">Таймер сессии</span>
      <div class="flex items-center gap-2">
        <span class="material-symbols-outlined text-[20px]">timer</span>
        <span class="text-primary font-headline font-bold text-xl" data-review-target="timer">00:00</span>
      </div>
    </div>
  </div>

  <%# Карточка %>
  <div class="w-full bg-surface-container-lowest rounded-xl p-10 md:p-16 editorial-shadow flex flex-col items-center text-center relative overflow-hidden"
       data-controller="review"
       data-review-answer-value="<%= card.form.downcase %>">

    <%# Декоративный элемент %>
    <div class="absolute top-0 right-0 p-4 opacity-5 pointer-events-none">
      <span class="material-symbols-outlined text-[120px]">auto_stories</span>
    </div>

    <%# Cloze + аудио %>
    <div class="flex flex-col items-center gap-6 mb-12">
      <%# Аудио-кнопка (над предложением) %>
      <% if card.sentence.audio_id %>
        <button type="button"
                aria-label="<%= t('reviews.play_audio') %>"
                class="w-12 h-12 rounded-full flex items-center justify-center bg-primary-fixed text-on-primary-fixed hover:bg-primary hover:text-white focus:ring-2 focus:ring-primary/50 transition-all duration-300"
                data-action="click->review#triggerAudio">
          <span class="material-symbols-outlined">volume_up</span>
        </button>
      <% end %>

      <%# Inline cloze %>
      <% parts = card.sentence.text.split(/#{Regexp.escape(card.form)}/i, 2) %>
      <% if parts.length == 2 %>
        <p class="font-body text-xl md:text-2xl text-on-surface-variant italic leading-relaxed max-w-2xl">
          "<%= parts[0] %><span class="inline-input-wrapper">
            <input type="text"
                   autofocus
                   autocomplete="off"
                   aria-label="<%= t('reviews.input_label') %>"
                   class="inline-input"
                   data-review-target="input"
                   data-action="input->review#onInput keydown->review#trackKey" />
          </span><%= parts[1] %>"
        </p>
      <% else %>
        <%# Fallback: обычное отображение %>
        <p class="font-body text-xl md:text-2xl text-on-surface-variant italic leading-relaxed max-w-2xl mb-4">
          "<%= card.cloze_text %>"
        </p>
        <input type="text"
               autofocus
               autocomplete="off"
               aria-label="<%= t('reviews.input_label') %>"
               class="inline-input"
               data-review-target="input"
               data-action="input->review#onInput keydown->review#trackKey" />
      <% end %>

      <%# Глоссы %>
      <% glosses = card.lexeme.lexeme_glosses.select { |g| g.target_language.code == "ru" } %>
      <% if glosses.any? %>
        <span class="text-primary/60 font-label text-sm italic font-medium mt-2">
          <%= glosses.map(&:gloss).join(", ") %>
        </span>
      <% end %>
    </div>

    <%# Форма %>
    <%= form_with url: review_path, method: :post, data: { action: "submit->review#submit" } do |f| %>
      <%= f.hidden_field :card_id, value: card.id %>
      <%= f.hidden_field :position, value: @position %>
      <%= f.hidden_field :total, value: @total %>
      <%= f.hidden_field :answer_text, value: "", data: { review_target: "answerText" } %>
      <%= f.hidden_field :elapsed_ms, value: 0, data: { review_target: "elapsed" } %>
      <%= f.hidden_field :attempts, value: 1, data: { review_target: "attempts" } %>
      <%= f.hidden_field :backspace_count, value: 0, data: { review_target: "backspaces" } %>

      <div class="w-full max-w-lg flex flex-col gap-6">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <%= f.submit t("reviews.submit"),
              class: "w-full bg-gradient-to-br from-primary to-primary-container text-white font-headline font-semibold py-4 rounded-md transition-all duration-300 hover:translate-y-[-2px] active:scale-[0.98] focus:ring-2 focus:ring-primary/50 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer" %>

          <%= link_to master_card_path(card), data: { turbo_method: :post },
              class: "w-full bg-surface-container-high text-on-surface-variant font-headline font-semibold py-4 rounded-md transition-all duration-300 hover:bg-surface-container-highest hover:translate-y-[-2px] focus:ring-2 focus:ring-outline-variant focus:ring-offset-2 flex items-center justify-center gap-2",
              aria: { label: t("reviews.master") } do %>
            <span class="material-symbols-outlined text-[20px]">verified</span>
            <%= t("reviews.master") %>
          <% end %>
        </div>

        <div class="flex justify-center gap-8">
          <button type="button"
                  aria-label="<%= t('reviews.dont_know') %>"
                  onclick="alert('TODO: Не знаю — кнопка в разработке')"
                  class="text-on-surface-variant font-label text-sm font-medium hover:text-on-surface transition-colors duration-300 flex items-center gap-2">
            <span class="material-symbols-outlined text-[18px]">help_outline</span>
            <%= t("reviews.dont_know") %>
          </button>
          <button type="button"
                  aria-label="<%= t('reviews.skip') %>"
                  onclick="alert('TODO: Пропустить — кнопка в разработке')"
                  class="text-on-surface-variant font-label text-sm font-medium hover:text-on-surface transition-colors duration-300 flex items-center gap-2">
            <span class="material-symbols-outlined text-[18px]">skip_next</span>
            <%= t("reviews.skip") %>
          </button>
        </div>
      </div>
    <% end %>
  </div>

  <%# Study Metadata (3 колонки) %>
  <div class="w-full mt-12 grid grid-cols-1 md:grid-cols-3 gap-8 text-left">
    <%# Контекстная подсказка %>
    <div>
      <h3 class="font-headline font-bold text-on-surface text-sm mb-2">Контекст</h3>
      <p class="font-body text-on-surface-variant text-base leading-relaxed">
        TODO: реализовать поле context_note в модели Sentence...
      </p>
    </div>

    <%# Сложность %>
    <div>
      <h3 class="font-headline font-bold text-on-surface text-sm mb-2">Сложность</h3>
      <div class="flex gap-1">
        <div class="h-1.5 w-6 rounded-full bg-tertiary-fixed"></div>
        <div class="h-1.5 w-6 rounded-full bg-tertiary-fixed"></div>
        <div class="h-1.5 w-6 rounded-full bg-surface-container-highest"></div>
      </div>
      <p class="text-on-surface-variant text-xs mt-1">TODO: получить реальную сложность из FSRS</p>
    </div>

    <%# Настройки аудио %>
    <div>
      <h3 class="font-headline font-bold text-on-surface text-sm mb-2">Аудио</h3>
      <button type="button"
              onclick="alert('TODO: Замедлить произношение — реализовать через audio.playbackRate')"
              class="text-primary text-sm font-medium text-left hover:underline">
        Замедлить произношение
      </button>
      <p class="text-on-surface-variant text-xs mt-1">TODO: реализовать настройку</p>
    </div>
  </div>
<% end %>
```

**Заметки:**
- `card.form` НИГДЕ не отображается (нет `<h1>` или видимого текста)
- Аудио-кнопка рендерится только при наличии `sentence.audio_id`
- Audio URL — Tatoeba CDN, передаётся через Stimulus, не используется внутренний route
- Кнопки "Не знаю" и "Пропустить" — заглушки с inline `onclick="alert(...)"`
- Добавлены hidden fields: `position` и `total`

---

### Step 7: _empty_state.html.erb

**Файл:** `app/views/review_sessions/_empty_state.html.erb`

```erb
<%= turbo_frame_tag "review_card" do %>
  <div class="w-full bg-surface-container-lowest rounded-xl editorial-shadow p-10 text-center flex flex-col items-center">
    <div class="w-16 h-16 bg-tertiary-fixed/10 rounded-full flex items-center justify-center mx-auto mb-4">
      <span class="material-symbols-outlined text-tertiary text-[32px]">check_circle</span>
    </div>
    <h2 class="font-headline text-xl font-semibold text-on-surface mb-2"><%= t("reviews.done_title") %></h2>
    <p class="text-on-surface-variant font-label mb-6"><%= t("reviews.done_message") %></p>
    <%= link_to t("reviews.back_to_dashboard"), dashboard_path,
        class: "inline-block bg-gradient-to-br from-primary to-primary-container text-white font-headline font-semibold px-6 py-3 rounded-md hover:translate-y-[-2px] transition-all duration-300" %>
  </div>
<% end %>
```

---

### Step 8: create.turbo_stream.erb

**Файл:** `app/views/review_sessions/create.turbo_stream.erb`

Два action: заменить карточку и обновить filament.

```erb
<%= turbo_stream.replace "review_card" do %>
  <% if @next_card %>
    <%= render "review_sessions/card_form", card: @next_card %>
  <% else %>
    <%= render "review_sessions/empty_state" %>
  <% end %>
<% end %>

<%= turbo_stream.replace "filament-container" do %>
  <% if @total > 0 %>
    <div id="filament-container" class="w-full bg-surface-container-low h-[2px]">
      <div class="filament-progress" style="width: <%= (@position.to_f / @total * 100).round %>%"></div>
    </div>
  <% else %>
    <div id="filament-container" class="hidden"></div>
  <% end %>
<% end %>
```

---

### Step 9: review_controller.js

**Файл:** `app/javascript/controllers/review_controller.js`

**Изменения targets:**
```js
static targets = ["input", "answerText", "elapsed", "attempts", "backspaces", "timer"]
```

**Добавить переменные:**
```js
connect() {
  // ... existing code ...
  this.startTimer()  // NEW
}

disconnect() {
  // ... existing code ...
  this.stopTimer()   // NEW
}
```

**Убрать audioUrlValue** — не используется, аудио через CDN загружается preloadAudio (уже существует).

**Timer методы:**
```js
startTimer() {
  this.updateTimer()
  this.timerInterval = setInterval(() => this.updateTimer(), 1000)
}

stopTimer() {
  if (this.timerInterval) {
    clearInterval(this.timerInterval)
    this.timerInterval = null
  }
}

updateTimer() {
  if (!this.hasTimerTarget) return

  const elapsed = Date.now() - this.startedAt
  const minutes = Math.floor(elapsed / 60000)
  const seconds = Math.floor((elapsed % 60000) / 1000)

  this.timerTarget.textContent =
    String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0")
}
```

**Изменения в `onInput()` и `resetUIForRetry()` — использовать CSS vars:**
```js
onInput() {
  const typed = this.inputTarget.value.toLowerCase()
  const expected = this.answerValue
  this.resizeInput()

  if (typed.length > 0) {
    this.inputTarget.placeholder = ""
  }

  const tertiary = getComputedStyle(document.documentElement).getPropertyValue('--color-tertiary').trim()
  const errorColor = getComputedStyle(document.documentElement).getPropertyValue('--color-error').trim()
  const outlineVariant = getComputedStyle(document.documentElement).getPropertyValue('--color-outline-variant').trim()

  if (typed.length === 0) {
    this.inputTarget.style.borderBottomColor = outlineVariant
  } else if (expected.startsWith(typed)) {
    this.inputTarget.style.borderBottomColor = tertiary
  } else {
    this.inputTarget.style.borderBottomColor = errorColor
  }
}

resetUIForRetry() {
  this.inputTarget.value = ""
  this.inputTarget.placeholder = this.answerValue

  const primary = getComputedStyle(document.documentElement).getPropertyValue('--color-primary').trim()
  this.inputTarget.style.borderBottomColor = primary

  this.inputTarget.focus()
}
```

**Добавить `triggerAudio()`** — для ручного воспроизведения (без auto-submit):
```js
async triggerAudio() {
  if (!this.audioBuffer || !this.audioContext) return

  try {
    if (this.audioContext.state === "suspended") {
      await this.audioContext.resume()
    }

    if (this.audioSource) {
      this.audioSource.onended = null
      this.audioSource.stop()
    }

    const source = this.audioContext.createBufferSource()
    this.audioSource = source
    source.buffer = this.audioBuffer
    source.connect(this.audioContext.destination)
    source.onended = () => {
      if (this.audioSource === source) this.audioSource = null
    }
    source.start(0)
  } catch {
    // Audio unavailable — silent fallback
  }
}
```

**Обновить `preloadAudio()` — использовать Tatoeba CDN URL:**
```js
async preloadAudio() {
  if (!this.audioUrlValue) return

  try {
    this.audioContext = this.audioContext || new AudioContext()
    const response = await fetch(this.audioUrlValue)
    const arrayBuffer = await response.arrayBuffer()
    this.audioBuffer = await this.audioContext.decodeAudioData(arrayBuffer)
  } catch {
    // Audio unavailable — silent fallback
  }
}
```

**Убрать все `classList.remove/add` с `border-green-500`, `border-red-500`, `ring-*`, `border-amber-500`** — теперь используется `style.borderBottomColor`.

---

### Step 10: i18n ключи

**Файлы:** `config/locales/ru.yml` (и `en.yml` если есть)

Добавить недостающие ключи:
- `reviews.play_audio` → "Воспроизвести произношение"
- `reviews.input_label` → "Введите пропущенное слово"
- `reviews.dont_know` → "Не знаю"
- `reviews.skip` → "Пропустить"
- `reviews.master` → может уже существовать

Перед добавлением — проверить существующие ключи.

---

### Step 11: Верификация

```bash
bundle exec rubocop          # без новых нарушений
bundle exec rspec            # все тесты проходят
```

Ручная проверка:
- `/review` — карточка отображается, `card.form` НЕ видно, inline cloze работает, кнопки стилизованы
- Прогресс и таймер отображаются корректно, N/M считается правильно
- Таймер обновляется каждую секунду (MM:SS)
- Filament виден только на `/review`, обновляется между карточками
- Study Metadata (3 колонки) отображается под карточкой
- Empty state — tertiary иконка, gradient кнопка
- Flash messages — правильные цвета
- Mobile bottom nav — видна только на мобильных, glassmorphism
- Breakpoints 320px, 768px, 1024px — контент не обрезается

---

## Файлы, которые НЕ меняются

- Модели, миграции, маршруты
- `Reviews::BuildSession`, `Reviews::RecordAnswer` — бизнес-логика
- Другие контроллеры и вьюхи (dashboard, auth, admin)

---

## Потенциальные риски

1. **Tailwind v4 `@theme` синтаксис** — подтверждён: `tailwindcss-ruby 4.2.1` (Gemfile.lock). `@theme` корректен.

2. **Zeitwerk** — новых директорий не добавляется, риска нет.

3. **Turbo frame + прогресс** — прогресс-блок внутри `_card_form.html.erb` (внутри turbo frame) обновится при Turbo-переходе. Filament обновляется через `turbo_stream.replace "filament-container"`.

4. **Audio CDN** — Tatoeba URL должен быть доступен. Если нет — silent fallback.

5. **Timer memory leak** — интервал очищается при `disconnect()`. Проверить что callback корректно привязан к `this`.

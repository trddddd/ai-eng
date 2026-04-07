# Postimplementation: Сессия повторений со спейсед репетишн

**Spec:** [memory-bank/features/007/spec.md](spec.md)
**Issue:** trddddd/ai-eng#14
**Основной коммит:** `c19574b` feat(review-session): spaced repetition review cycle with FSRS (#14)
**Фиксы:** `c2654d0`..`b20d710` (5 коммитов)

---

## Что пришлось исправить после реализации по спеке

### 1. CORS: аудио Tatoeba не грузится из браузера

**Проблема:** Спека указывала прямой URL `https://audio.tatoeba.org/sentences/eng/{id}.mp3` в data-attribute. На практике `fetch()` из Web Audio API блокируется CORS-политикой Tatoeba — сервер не возвращает `Access-Control-Allow-Origin`.

**Что спека не учла:** Что внешний CDN может не поддерживать CORS. Спека описала audio pipeline как чисто клиентский (`fetch → decodeAudioData → AudioBuffer`), не проверив CORS-заголовки Tatoeba.

**Решение:** Серверный прокси `GET /audio/sentences/:id` — Rails скачивает mp3 через `Net::HTTP` и отдаёт клиенту. Потребовалось:
- Новый `AudioController` (не предусмотрен спекой)
- Новый маршрут в `routes.rb`
- Замена URL в partial: `audio_sentence_path(id)` вместо прямой ссылки на Tatoeba

**Коммиты:** `c2654d0`, `b67f1ba`

**Урок для будущих спек:** При интеграции с внешними ресурсами (CDN, API) — проверять CORS-заголовки до написания спеки. Если ресурс не отдаёт CORS — закладывать серверный прокси в спеку.

---

### 2. Вложенный turbo_frame ломал рендеринг

**Проблема:** Спека описала `turbo_frame_tag "review_card"` и в `show.html.erb`, и в `_card_form.html.erb`. Результат — вложенный `<turbo-frame>` внутри `<turbo-frame>`, что приводило к некорректному matching при Turbo Stream swap.

**Что спека не учла:** Turbo Frame matching работает по ID. Когда partial уже обёрнут в `turbo_frame_tag`, родительский view не должен дублировать обёртку — иначе Turbo ищет фрейм внутри фрейма и не находит.

**Решение:** Убран `turbo_frame_tag` из `show.html.erb` — фрейм остался только в partials, которые и являются единицей замены.

**Коммит:** `4cca70f`

**Урок для будущих спек:** Явно указывать, кто владеет `turbo_frame_tag` — родительский view или partial. Правило: partial владеет фреймом, parent просто рендерит partial.

---

### 3. Ghost text: absolute overlay не работал

**Проблема:** Спека описала ghost text как `position: absolute` overlay поверх input. На практике overlay не выравнивался с текстом в input (разные padding, font metrics, рендеринг зависит от браузера).

**Что спека не учла:** CSS absolute positioning для текстового overlay поверх input — хрупкий паттерн, требующий pixel-perfect совпадения шрифтов и отступов. Проще и надёжнее использовать нативный `placeholder`.

**Решение:** Ghost text реализован через `input.placeholder = this.answerValue` вместо отдельного DOM-элемента. При retry placeholder показывает правильный ответ, при вводе — восстанавливается оригинальный placeholder.

**Коммит:** `7d0277b`

**Урок для будущих спек:** Предпочитать нативные HTML-механизмы (placeholder, title, aria-label) вместо кастомных overlay. Если спека описывает кастомную реализацию — указывать fallback.

---

### 4. Audio + submit: race condition и UX

**Проблема:** Спека описала `playAudio()` и `finalSubmit()` как два последовательных вызова. На практике: (a) audio играет асинхронно, submit происходит мгновенно — пользователь не успевает услышать аудио перед сменой карточки; (b) `requestSubmit()` триггерит Stimulus `submit` повторно — бесконечный цикл.

**Что спека не учла:**
- `playAudio()` — fire-and-forget, а `finalSubmit()` → `requestSubmit()` вызывает navigation/swap до окончания воспроизведения
- `requestSubmit()` на форме повторно вызывает обработчик `submit` в Stimulus — нужен guard

**Решение:**
- `playAudioThenSubmit()` — audio воспроизводится полностью, submit происходит в `source.onended` callback
- Флаг `readyToSubmit` — guard для `requestSubmit()`, чтобы повторный `submit` event прошёл в браузер без перехвата Stimulus
- Флаг `submitting` — блокировка двойного submit
- `disconnect()` — cleanup audio source при смене карточки
- `AudioContext.resume()` — для браузеров, блокирующих autoplay

**Коммит:** `b20d710`

**Урок для будущих спек:** Для async UI flows (audio → submit, animation → navigation) спека должна описывать последовательность как state machine с явными переходами, а не как последовательность вызовов функций.

---

### 5. button_to → link_to для Master

**Проблема:** `button_to` генерирует вложенную `<form>` внутри основной формы карточки. Вложенные формы невалидны в HTML и ведут к непредсказуемому поведению.

**Решение:** Заменён на `link_to` с `data: { turbo_method: :post }`.

**Коммит:** `b20d710`

---

## Сводка расхождений спеки и реализации

| # | Область | Спека описала | Реализовано | Причина |
|---|---------|--------------|-------------|---------|
| 1 | Audio URL | Прямой fetch на `audio.tatoeba.org` | Серверный прокси `/audio/sentences/:id` | CORS |
| 2 | Turbo Frame | `turbo_frame_tag` в show + partial | Только в partial | Вложенный frame ломает matching |
| 3 | Ghost text | `position: absolute` overlay div | `input.placeholder` | Overlay не выравнивается |
| 4 | Audio + submit | `playAudio(); finalSubmit()` | `await playAudioThenSubmit()` + state guards | Race condition, UX |
| 5 | Master button | `button_to` | `link_to` + `turbo_method` | Вложенная form невалидна |

## Рекомендации для будущих спек

1. **Внешние ресурсы** — проверять CORS/auth headers до спеки; закладывать прокси как fallback
2. **Turbo Frame ownership** — явно указывать, кто владеет фреймом (partial vs parent)
3. **Кастомный CSS vs нативный HTML** — предпочитать нативные механизмы; для кастомных — описывать fallback
4. **Async UI flows** — описывать как state machine с переходами, не как sequence of calls
5. **Вложенные формы** — при наличии кнопок-действий внутри формы, использовать `link_to` с `turbo_method`

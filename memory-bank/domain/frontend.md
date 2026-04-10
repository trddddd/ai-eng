---
title: Frontend
doc_kind: domain
doc_function: canonical
purpose: UI-поверхности, design system и i18n-слой Lingvize. Читать при работе с интерфейсом.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Frontend

## UI Surfaces

- **Public web** — server-rendered Rails views (ERB + Hotwire). Код: `app/views/`, `app/javascript/`.
- Boundary с backend: контроллеры рендерят HTML, Turbo Streams для partial updates, Stimulus для интерактивности.
- Canonical owner для design decisions: `memory-bank/engineering/DESIGN.md` (The Editorial Scholar).

## Design System: The Editorial Scholar

Source of truth для цветов, типографики и компонентов — `memory-bank/engineering/DESIGN.md`.

### Ключевые принципы

- **"No-Line" Rule** — никаких 1px solid borders для секционирования. Границы только через background color shifts (surface hierarchy).
- **"Glass & Signature"** — floating nav/modals через glassmorphism (80% opacity + backdrop-blur). Primary CTA — gradient, не flat.
- **Tonal Layering** — глубина через luminosity shifts, не через box-shadow. Ambient shadows ("Whisper Shadow") только для floating элементов.

### Surface Hierarchy

| Token | Hex | Usage |
| --- | --- | --- |
| `surface` | #f7f9fb | Base background |
| `surface-container-low` | #f2f4f6 | Lowest importance |
| `surface-container-lowest` | #ffffff | Active/floating cards |
| `surface-container-high` | — | Sidebar, utility panels |

### Typography: Dual-Key System

- **UI/Interface:** Manrope (headlines, display), Inter (labels, metadata)
- **Content/Language:** Newsreader (foreign text, lesson content, cloze)

| Level | Token | Font | Size | Weight |
| --- | --- | --- | --- | --- |
| Display | `display-lg` | Manrope | 3.5rem | 700 |
| Headline | `headline-md` | Manrope | 1.75rem | 600 |
| Lesson Title | `title-lg` | Newsreader | 1.375rem | 500 |
| Foreign Text | `body-lg` | Newsreader | 1.0rem | 400 |
| UI Labels | `label-md` | Inter | 0.75rem | 500 |

### Roundedness Scale

| Token | Value | Usage |
| --- | --- | --- |
| `sm` | 0.25rem | Tooltips |
| `md` | 0.75rem | Buttons, inputs |
| `lg` | 1rem | Content cards |
| `xl` | 1.5rem | Hero, bottom sheets |
| `full` | 9999px | Pills, chips |

## Component Rules

- Inputs: "Minimalist Ledger" — `surface-container-low` background + bottom-border, transforms to `primary` on focus. No "box" style.
- Buttons: Primary = gradient (primary → primary-container, 135deg). Tertiary = text only, hover background.
- Cards: No 1px dividers. Vertical whitespace (1.5rem) для разделения.
- Progress: 2px "Filament" line (`tertiary`), не chunky bars.
- Errors: `error-container` (#ffdad6) + `on-error-container` text, не alert red.
- Text: `on-surface` (#191c1e), никогда не pure black (#000).

## Interaction Patterns

- **Server-rendered** HTML + **Turbo Streams** для partial page updates (review session card switching).
- **Stimulus controllers** для client-side интерактивности: таймер, валидация ввода, keyboard shortcuts, audio playback.
- **Web Audio API** для воспроизведения аудио (Tatoeba через серверный proxy `/audio/sentences/:id`).
- Inline cloze: transparent input с bottom border, ghost text placeholder после ошибки.

## Localization

- Primary locale: `:ru`, fallback: `:en`.
- Файлы: `config/locales/ru.yml`, `config/locales/en.yml`.
- Добавление ключей: в оба файла одновременно.
- UI-тексты по умолчанию на русском.

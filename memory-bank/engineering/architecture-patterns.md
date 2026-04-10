---
title: Architecture Patterns — Layered Rails
doc_kind: engineering
doc_function: canonical
purpose: Layered Design паттерны для Rails-кодовой базы Lingvize. Основан на "Layered Design for Ruby on Rails Applications" (Vladimir Dementyev). Читать при создании новых классов, рефакторинге или ревью.
derived_from:
  - ../dna/governance.md
  - ../domain/architecture.md
status: active
audience: humans_and_agents
canonical_for:
  - rails_layer_boundaries
  - operation_pattern
  - model_responsibilities
  - controller_responsibilities
---

# Architecture Patterns — Layered Rails

Подход основан на "Layered Design for Ruby on Rails Applications" (Vladimir Dementyev).

**Tooling:** в проекте установлен скилл `layered-rails`. Используй его команды при реализации фич и ревью.

## Четыре слоя

```
┌─────────────────────────────────────────┐
│          PRESENTATION LAYER             │
│  Controllers, Views, Channels, Mailers  │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│          APPLICATION LAYER              │
│  Service Objects, Form Objects, etc.    │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│            DOMAIN LAYER                 │
│  Models, Value Objects, Domain Events   │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│         INFRASTRUCTURE LAYER            │
│  Active Record, APIs, File Storage      │
└─────────────────────────────────────────┘
```

**Core Rule:** Нижние слои никогда не зависят от верхних. Данные текут сверху вниз.

## Четыре правила

1. **Unidirectional Data Flow** — данные текут сверху вниз
2. **No Reverse Dependencies** — нижние слои не зависят от верхних
3. **Abstraction Boundaries** — каждая абстракция принадлежит ровно одному слою
4. **Minimize Connections** — меньше связей между слоями = слабее coupling

## The Specification Test

> Если спецификация объекта описывает возможности за пределами основной ответственности его архитектурного слоя, эти возможности должны быть вынесены в нижние слои.

**Как применять:**
1. Перечислить обязанности кода
2. Оценить каждую относительно primary concern слоя
3. Вынести несоответствующие обязанности в правильный слой

## Ответственности слоёв

### Presentation Layer (Controllers, Views, Mailers)

- Принимает и валидирует HTTP params
- Вызывает application layer
- Рендерит response (HTML, Turbo Stream, JSON, redirect)
- Управляет authentication flow
- Пишет в `Current.*` (единственное разрешённое место для записи)

**НЕ должен:** содержать бизнес-логику, сложные query chains, доменные вычисления.

### Application Layer (Services, Form Objects, Policy Objects)

- Оркестрирует domain objects
- Координирует multi-step операции
- **Services — "waiting room":** временное место для кода, пока не появится правильная абстракция. `app/services` не должен становиться свалкой.

**НЕ должен:** содержать domain logic (это делают модели), принимать request objects, зависеть от HTTP-контекста.

### Domain Layer (Models, Value Objects, Concerns)

- Бизнес-правила и domain logic
- Валидации, ассоциации, scopes
- Делегирование к domain-библиотекам (FSRS)
- Enums, state definitions

**НЕ должен:** обращаться к `Current.*` (violation!), вызывать mailers/notifications, зависеть от presentation context.

**Важно: избегай Anemic Models.** Domain logic живёт в моделях, а не в сервисах. Сервисы оркестрируют, модели знают бизнес-правила.

### Infrastructure Layer (Active Record, APIs, Storage)

- Persistence (Active Record)
- Внешние API (Tatoeba, Quizword)
- File storage, cache

## Каталог паттернов

| Паттерн | Слой | Когда использовать |
| --- | --- | --- |
| Service Object | Application | Оркестрация domain operations (multi-step) |
| Form Object | Presentation | Multi-model формы, сложная валидация |
| Filter Object | Presentation | Трансформация request params |
| Policy Object | Application | Авторизация |
| Query Object | Domain | Сложные, переиспользуемые queries |
| Value Object | Domain | Immutable, identity-less concepts |
| Presenter | Presentation | View-specific logic, несколько моделей |
| Concern | Domain | Shared behavioral extraction (НЕ code-slicing!) |

### "Куда поместить этот код?"

| Если у тебя... | Рассмотри... |
| --- | --- |
| Сложная multi-model форма | Form Object |
| Фильтрация/трансформация params | Filter Object |
| View-specific форматирование | Presenter |
| Сложный query в нескольких местах | Query Object |
| Бизнес-операция через несколько моделей | Service Object (как waiting room) |
| Правила авторизации | Policy Object |
| Multi-channel уведомления | Delivery Object |

## Callback Scoring

| Тип | Score | Оставить? |
| --- | --- | --- |
| Transformer (вычисление значений) | 5/5 | Да |
| Normalizer (санитизация input) | 4/5 | Да |
| Utility (counter caches) | 4/5 | Да |
| Observer (side effects) | 2/5 | Может быть |
| Operation (бизнес-шаги) | 1/5 | **Выноси** |

Callbacks допустимы для инвариантов модели (нормализация, default values). Callbacks с score ≤ 2 — кандидаты на вынос в caller или event handler.

## Распространённые нарушения

| Violation | Пример | Fix |
| --- | --- | --- |
| Model uses Current | `Current.user` в модели | Передать user явным параметром |
| Service accepts request | `param :request` в сервисе | Извлечь value object из request |
| Business logic в controller | Вычисления в action | Вынести в service или model |
| Anemic models | Вся логика в services | Domain logic → в модели |
| Code-slicing concern | Группировка по типу артефакта | Behavioral concern или inline |

## Текущее состояние Lingvize

В проекте используются Operations в `app/operations/` с `.call()` entry point — это наш вариант Service Objects (application layer). Текущие операции:

- `Reviews::RecordAnswer` — оркестрация оценки ответа
- `Reviews::BuildSession` — сборка сессии повторения
- `Cards::BuildStarterDeck` — создание стартовой колоды
- `ContentBootstrap::*` — импорт контента
- `Sentences::ImportQuizword` — импорт предложений

Domain logic (FSRS scheduling, accuracy, recall quality) корректно живёт в моделях `Card` и `ReviewLog`.

## Команды скилла

При реализации фич и ревью используй команды `layered-rails`:

| Команда | Когда |
| --- | --- |
| `/layers:review` | При ревью кода на архитектурные нарушения |
| `/layers:spec-test` | Проверить конкретный файл на specification test |
| `/layers:analyze` | Полный анализ кодовой базы |
| `/layers:analyze:callbacks` | Оценить callbacks, найти кандидатов на extraction |
| `/layers:analyze:gods` | Найти god objects (churn × complexity) |
| `/layers:gradual [goal]` | Спланировать постепенное внедрение паттернов |

## Model Organization

Рекомендуемый порядок внутри модели:

```ruby
class User < ApplicationRecord
  # 1. Gems/DSL extensions
  has_secure_password

  # 2. Associations
  belongs_to :account
  has_many :posts

  # 3. Enums
  enum :status, { pending: 0, active: 1 }

  # 4. Normalization
  normalizes :email, with: -> { _1.strip.downcase }

  # 5. Validations
  validates :email, presence: true

  # 6. Scopes
  scope :active, -> { where(status: :active) }

  # 7. Callbacks (transformers only, score 4+)
  before_validation :set_defaults

  # 8. Delegations
  delegate :name, to: :account, prefix: true

  # 9. Public methods
  def full_name = "#{first_name} #{last_name}"

  # 10. Private methods
  private

  def set_defaults
    self.locale ||= I18n.default_locale
  end
end
```

## Тестовая стратегия по слоям

| Слой | Что тестировать | Где |
| --- | --- | --- |
| Presentation | HTTP flow, auth, response format | `spec/requests/` |
| Application | Оркестрация, бизнес-сценарии end-to-end | `spec/operations/` |
| Domain | Валидации, scopes, domain methods, бизнес-правила | `spec/models/` |
| Infrastructure | Не тестируется отдельно; покрывается через domain/application tests | — |

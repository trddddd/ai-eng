---
title: Memory Bank Index — Lingvize
doc_kind: project
doc_function: index
purpose: Точка входа в memory-bank Lingvize. Навигация по всем слоям и промпты для прайминга.
status: active
audience: humans_and_agents
---

# Memory Bank — Lingvize

## Layers

| Layer | Purpose | Entry Point |
| --- | --- | --- |
| **DNA** | Governance-ядро: SSoT, frontmatter, lifecycle | [dna/README.md](dna/README.md) |
| **Domain** | Продукт, архитектура, UI | [domain/README.md](domain/README.md) |
| **Flows** | Lifecycle flows, шаблоны | [flows/README.md](flows/README.md) |
| **Engineering** | Тесты, код, автономность, git, layered-rails | [engineering/README.md](engineering/README.md) |
| **Ops** | Development, stages, release, config | [ops/README.md](ops/README.md) |
| **PRD** | Product Requirements Documents | [prd/README.md](prd/README.md) |
| **Features** | Feature packages (FT-XXX) | [features/README.md](features/README.md) |
| **ADR** | Architecture Decision Records | [adr/README.md](adr/README.md) |
| **Use Cases** | Canonical user/operational scenarios | [use-cases/README.md](use-cases/README.md) |

## Glossary

- [glossary.md](glossary.md) — словарь доменных, governance и архитектурных терминов.

## Аннотированный индекс

- [`domain/README.md`](domain/README.md) — product context, архитектура (Rails 8 + FSRS), design system (Editorial Scholar).
- [`prd/README.md`](prd/README.md) — PRD-001: Lingvize MVP. Инициативы между problem statement и features.
- [`use-cases/README.md`](use-cases/README.md) — canonical user/operational scenarios (пока пусто).
- [`ops/README.md`](ops/README.md) — bin/setup, docker compose, direnv, env vars, cold start.
- [`engineering/README.md`](engineering/README.md) — RSpec, RuboCop, SimpleCov 80%, layered-rails patterns, autonomy boundaries.
- [`dna/README.md`](dna/README.md) — governance: SSoT, frontmatter, lifecycle.
- [`flows/README.md`](flows/README.md) — feature lifecycle gates, шаблоны feature/ADR/PRD.
- [`adr/README.md`](adr/README.md) — Architecture Decision Records (пока пусто).
- [`features/README.md`](features/README.md) — 7 фич (FT-002—FT-008) + 2 фикса (FIX-001—FIX-002), все done.

## Priming Prompts

### Начало новой сессии

```text
Прочитай memory-bank/domain/ и memory-bank/engineering/. Контекст проекта загружен. Что делаем?
```

### Новая фича

```text
Прочитай memory-bank/flows/feature-flow.md и memory-bank/flows/templates/feature/.
Создай feature package FT-XXX для: [описание фичи].
```

### Ревью PRD

```text
Прочитай .prompts/prd/review.md.
Проведи ревью PRD по критериям PRDAS: [путь к PRD].
```

### Bug fix

```text
Прочитай memory-bank/flows/workflows.md (секция bug fix).
Проблема: [описание бага]. Найди причину и исправь.
```

### Ревью memory-bank

```text
Проведи ревью memory-bank/ на governance и консистентность.
Проверь: frontmatter, derived_from, ссылки между документами, отсутствие orphan files.
```

### Продолжение работы

```text
Прочитай memory-bank/features/README.md. Какие фичи в работе? Продолжи с [FT-XXX].
```

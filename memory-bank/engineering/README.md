---
title: Engineering Documentation Index
doc_kind: engineering
doc_function: index
purpose: Навигация по engineering-level документации Lingvize.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Engineering Documentation Index

- [Testing Policy](testing-policy.md) — RSpec, SimpleCov 80%, FactoryBot, GitHub Actions CI. Когда feature обязана иметь test cases и когда допустим manual-only verify.
- [Architecture Patterns — Layered Rails](architecture-patterns.md) — Layered Design (Dementyev): 4 слоя (Presentation → Application → Domain → Infrastructure), specification test, callback scoring, каталог паттернов, команды скилла `/layers:*`.
- [Autonomy Boundaries](autonomy-boundaries.md) — границы автономии агента: автопилот, супервизия, эскалация.
- [Coding Style](coding-style.md) — Ruby/Rails конвенции, Zeitwerk, RuboCop, Tailwind, SQL/migrations.
- [Git Workflow](git-workflow.md) — ветки, коммиты, PR, conventional commits.
- [Tech Debt Registry](tech-debt.md) — реестр известного техдолга с условиями активации и планами исправления.
- [ADR](../adr/README.md) — Architecture Decision Records проекта.

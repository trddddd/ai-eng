---
title: "FT-034: Feature Package"
doc_kind: feature
doc_function: index
purpose: "Bootstrap-safe навигация по документации фичи. Читать, чтобы сначала перейти к canonical `feature.md`, а optional derived docs добавлять только после их появления."
derived_from:
  - ../../dna/governance.md
  - feature.md
status: active
audience: humans_and_agents
---

# FT-034: Feature Package

## О разделе

Каталог feature package хранит canonical `feature.md`, а optional derived/external routes добавляются только после появления соответствующих документов. Сначала читай `feature.md`, затем расширяй routing по мере появления execution и decision artifacts.

## Аннотированный индекс

- [`feature.md`](feature.md)
  Читать, когда нужно: открыть instantiated canonical feature-документ сразу после bootstrap нового feature package.
  Отвечает на вопрос: где находятся scope, design, verify, blockers и canonical IDs для этой фичи.

- [`implementation-plan.md`](implementation-plan.md)
  Читать, когда нужно: начать или возобновить выполнение фичи.
  Отвечает на вопрос: какой порядок шагов, какие риски, какие test gates и preconditions.

- [`eval/strategy.md`](eval/strategy.md)
  Читать, когда нужно: понять eval layers и decision rules для этой фичи.

- [`eval/suite/happy-path.md`](eval/suite/happy-path.md)
  Основные сценарии: RecordCoverage integration, contribution_type, dashboard buckets.

- [`eval/suite/edge-cases.md`](eval/suite/edge-cases.md)
  Граничные случаи: incorrect answers, NULL dimensions, idempotency, empty dashboard.

- [`eval/suite/regression.md`](eval/suite/regression.md)
  Регрессия: FSRS scheduling, backfill, существующие coverage records, dashboard поля.

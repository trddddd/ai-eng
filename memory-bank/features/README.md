---
title: Feature Packages Index
doc_kind: feature
doc_function: index
purpose: Навигация по feature packages Lingvize.
derived_from:
  - ../dna/governance.md
  - ../flows/feature-flow.md
status: active
audience: humans_and_agents
---

# Feature Packages Index

## Rules

- Каждый package создается по правилам из [`../flows/feature-flow.md`](../flows/feature-flow.md).
- Для bootstrap используй шаблоны из [`../flows/templates/feature/`](../flows/templates/feature/).
- Naming: `FT-XXX/` для фич, `FIX-XXX/` для фиксов. XXX = номер GitHub issue.

## Registry

| ID | Title | Status | Issue | Branch |
| --- | --- | --- | --- | --- |
| FT-002 | Content Bootstrap for Study MVP | done | #2 | main |
| FT-003 | Test Coverage & CI Setup | done | #4 | main |
| FT-004 | Sentence Domain & Quizword Import | done | #6 | main |
| FT-005 | Cold Start via DB Dump | done | #8 | main |
| FT-006 | Personal Starter Deck | done | #10 | main |
| FT-007 | Spaced Repetition Review Session | done | #14 | main |
| FT-008 | Design System & UI Redesign | done | #16 | main |
| FIX-001 | Word Matching Fix (word boundaries) | done | #17 | main |
| FIX-002 | CI Cleanup (drop fork CI, add coverage) | done | #20 | main |
| FT-023 | Direct Landing on Study Content | done | #23 | main |

## Legacy Note

Фичи FT-002 — FT-008 и FIX-001 — FIX-002 мигрированы из старого формата `memory-bank-legacy/`. Артефакты (brief.md, spec.md, plan.md) сохранены в оригинальном виде.

---
title: "FT-031: Word Mastery State — README"
doc_kind: feature
doc_function: routing
purpose: "Навигация по артефактам FT-031: Word Mastery State."
derived_from:
  - ../../flows/feature-flow.md
status: active
audience: humans_and_agents
---

# FT-031: Word Mastery State

> GitHub Issue: [xtrmdk/ai-eng#31](https://github.com/xtrmdk/ai-eng/issues/31)

## Status

| Field | Value |
| --- | --- |
| **Delivery status** | `planned` |
| **Feature status** | `draft` |
| **Upstream PRD** | [PRD-002: Word Mastery](../../prd/PRD-002-word-mastery.md) |
| **Upstream feature** | [FT-029: Lexeme Sense & Context Families](../FT-029/) |

## Documents

| Document | Status | Purpose |
| --- | --- | --- |
| [`feature.md`](feature.md) | draft | Canonical intent, scope, verify contract |
| `implementation-plan.md` | absent | Created at Design Ready |
| `eval/` | absent | Created at Design Ready |
| `attempts/` | absent | Created at Plan Ready |

## Context

FT-031 — вторая downstream-фича из PRD-002 (Word Mastery — Dual-Level Spaced Repetition).

**Что сделано (FT-029):** доменные сущности `Sense` и `ContextFamily` созданы; `SentenceOccurrence` привязана к sense и context_family.

**Что делает FT-031:** создаёт персональное состояние знания слова для каждого пользователя — отслеживает, какие значения (senses) и контекстные семьи (context families) пользователь уже встречал хотя бы один раз с правильным ответом, и вычисляет процент охваченных значений и семей.

**Что будет после:** Session Builder v2 использует данные FT-031 для приоритизации слов с низким покрытием при планировании сессий.

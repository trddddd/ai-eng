---
title: Stages And Non-Local Environments
doc_kind: engineering
doc_function: canonical
purpose: Non-local environments Lingvize.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Stages And Non-Local Environments

На данный момент проект работает только в локальной разработке и CI.

## Environment Inventory

| Environment | Purpose | Access path | Notes |
| --- | --- | --- | --- |
| `development` | Локальная разработка | `localhost:3000` | Docker Compose для PostgreSQL/Redis |
| `test` | CI и локальные тесты | GitHub Actions | PostgreSQL 18-alpine service |

Production и staging окружения пока не развёрнуты. Этот документ будет дополнен при появлении новых stages.

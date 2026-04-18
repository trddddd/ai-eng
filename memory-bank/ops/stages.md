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

## Environment Inventory

| Environment | Purpose | Access path | Infrastructure | Notes |
| --- | --- | --- | --- | --- |
| `development` | Локальная разработка | `localhost:3000` | Docker Compose для PostgreSQL/Redis | — |
| `test` | CI и локальные тесты | GitHub Actions | PostgreSQL 18-alpine service | — |
| `production` | Живой продукт | `https://lingvize.com` | Selectel VDS, Kamal 2, PostgreSQL accessory | ADR-003 |

## Production Details

- **VDS:** Selectel (2 vCPU, 4GB RAM, Ubuntu 24.04)
- **Deploy tool:** Kamal 2 (zero-downtime via kamal-proxy)
- **SSL:** Let's Encrypt (автоматический через kamal-proxy)
- **Database:** PostgreSQL 18 как Kamal accessory на том же сервере
- **Error tracking:** Sentry cloud (sentry.io)
- **CI/CD:** GitHub Actions → `kamal deploy` при merge в main

## Runbooks

- [Deploy](runbooks/deploy.md)
- [Rollback](runbooks/rollback.md)

---
title: Release And Deployment
doc_kind: engineering
doc_function: canonical
purpose: Релизный процесс Lingvize.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Release And Deployment

## Release Flow

1. Feature branch → PR → review → squash merge в `main`
2. CI (`rails.yml`) проверяет lint + tests автоматически
3. При успешном CI — GitHub Actions (`deploy.yml`) запускает `kamal deploy`
4. Kamal собирает Docker image, пушит на сервер, выполняет zero-downtime deploy
5. kamal-proxy делает healthcheck (`/up`), при success — переключает трафик

## Versioning

Git SHA используется как версия контейнера. Отдельного семантического версионирования пока нет.

## Rollback

```bash
bundle exec kamal rollback <VERSION>
```

Подробнее: [Rollback Runbook](runbooks/rollback.md)

## Deployment Commands

```bash
# Автоматический деплой (при merge в main)
# Ручной деплой
bundle exec kamal deploy

# Статус
bundle exec kamal app details

# Логи
bundle exec kamal app logs
```

Подробнее: [Deploy Runbook](runbooks/deploy.md)

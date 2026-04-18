---
title: Rollback Runbook
doc_kind: engineering
doc_function: canonical
purpose: Пошаговая инструкция для отката Lingvize на предыдущую версию через Kamal 2.
derived_from:
  - ../../adr/ADR-003-deployment-platform.md
  - ../../features/FT-038/feature.md
status: active
audience: humans_and_agents
---

# Rollback Runbook

## When to Rollback

- Production ошибки после деплоя (Sentry алерты)
- Healthcheck fails, приложение недоступно
- Критический баг обнаружен после деплоя

## Rollback Procedure

```bash
# 1. Посмотреть доступные версии
bundle exec kamal app containers

# 2. Откатить на предыдущую версию
bundle exec kamal rollback <VERSION>

# 3. Проверить что приложение работает
curl -s -o /dev/null -w "%{http_code}" https://lingvize.com/up
# Ожидаемый ответ: 200

# 4. Проверить логи
bundle exec kamal app logs
```

## Database Migration Rollback

Если деплой включал миграцию, которую нужно откатить:

```bash
# Посмотреть статус миграций
bundle exec kamal app exec 'bin/rails db:migrate:status'

# Откатить конкретную миграцию
bundle exec kamal app exec 'bin/rails db:migrate:down VERSION=<timestamp>'
```

**Важно:** откатывать только миграции текущей сессии. Никогда не использовать `db:migrate VERSION=0`.

## After Rollback

1. Проверить healthcheck: `curl https://lingvize.com/up` → 200
2. Проверить Sentry на новые ошибки
3. Создать issue для исправления проблемы
4. После fix — обычный деплой через merge в main

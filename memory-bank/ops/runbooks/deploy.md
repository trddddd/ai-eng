---
title: Deploy Runbook
doc_kind: engineering
doc_function: canonical
purpose: Пошаговая инструкция для деплоя Lingvize в production через Kamal 2.
derived_from:
  - ../../adr/ADR-003-deployment-platform.md
  - ../../features/FT-038/feature.md
status: active
audience: humans_and_agents
---

# Deploy Runbook

## Prerequisites

- SSH-доступ к VDS (ключ добавлен в ssh-agent)
- Docker установлен локально
- `.kamal/secrets` заполнен актуальными значениями
- `config/master.key` существует локально

## First Deploy (kamal setup)

```bash
# 1. Убедиться что секреты заполнены
test -s .kamal/secrets && echo "secrets OK" || echo "MISSING: .kamal/secrets"

# 2. Первичная настройка (устанавливает Docker, kamal-proxy, аксессуары)
bundle exec kamal setup

# 3. Проверить что приложение доступно
curl -s -o /dev/null -w "%{http_code}" https://lingvize.com/up
# Ожидаемый ответ: 200

# 4. Проверить логи
bundle exec kamal app logs
```

## Regular Deploy

Автоматический деплой через GitHub Actions при merge в `main`. При необходимости ручного деплоя:

```bash
bundle exec kamal deploy
```

## Deploy Check

```bash
# Статус контейнеров
bundle exec kamal app details

# Логи приложения
bundle exec kamal app logs

# Healthcheck
curl -s -o /dev/null -w "%{http_code}" https://lingvize.com/up
```

## Troubleshooting

| Проблема | Действие |
| --- | --- |
| Deploy зависает на healthcheck | `kamal app logs` — проверить ошибки запуска |
| Миграция упала | Исправить миграцию, redeploy. При необходимости: `kamal app exec 'bin/rails db:migrate:status'` |
| Контейнер не стартует | `kamal app logs --since 5m` — найти причину |
| SSL сертификат не получен | Проверить DNS A-запись, порт 443 открыт, `kamal proxy logs` |

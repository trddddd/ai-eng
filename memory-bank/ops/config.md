---
title: Configuration Guide
doc_kind: engineering
doc_function: canonical
purpose: Ownership-модель конфигурации Lingvize.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Configuration Guide

## Configuration Architecture

- `.env` — base env vars (checked in, defaults)
- `.env.local` — local overrides (gitignored)
- `.envrc` — direnv loader (loads `.env` + `.env.local`, auto PORT)
- `config/application.rb` — Rails defaults (locale, UUID keys, test framework)
- `config/database.yml` — DB connection (reads `DATABASE_URL`)
- Rails credentials — для секретов (если используются)

## File Layout

```text
.env                    # base defaults (committed)
.env.local              # local overrides (gitignored)
.envrc                  # direnv config
config/
├── application.rb      # Rails app config
├── database.yml        # DB connection
├── environments/       # per-env Rails config
├── locales/
│   ├── ru.yml          # Russian translations
│   └── en.yml          # English translations
└── credentials/        # encrypted secrets
```

## Important Variables

| Variable | Description | Default | Owner |
| --- | --- | --- | --- |
| `DATABASE_URL` | PostgreSQL connection | `postgres://lingvize:@localhost:5433/lingvize_development` | platform |
| `REDIS_URL` | Redis connection | `redis://localhost:6379` | platform |
| `PORT` | Web server port | `3000` | local |
| `RAILS_ENV` | Environment | `development` | runtime |
| `START_PAGE` | Quizword import start page | `1` | content ops |
| `END_PAGE` | Quizword import end page | — | content ops |
| `CONCURRENCY` | Quizword import threads | `10` | content ops |

## Secrets

- Реальные значения секретов не хранятся в репозитории.
- Для локальной разработки: `.env.local` (gitignored).
- Для CI: GitHub Actions secrets.

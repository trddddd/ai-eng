---
title: Git Workflow
doc_kind: engineering
doc_function: convention
purpose: Шаблон git workflow документа. После копирования зафиксируй реальные branch names, commit rules и PR expectations проекта.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Git Workflow

## Default Branch

`main`

## Commits

- Present-tense, concise: `fix: normalize cache key`, `feat(007): spaced repetition review session`
- Conventional commits prefix: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`
- Feature scope в скобках: `feat(008): design system`
- Issue ref через `(#N)` в конце: `fix(002): drop fork CI (#20)`
- Auto-close keywords: `Closes #N`, `Fixes #N`

## Branches

- Feature: `feat/short-description` (например `feat/starter-deck`)
- Fix: `fix/short-description`
- Удаляются после merge в main.

**Правило:** перед первым изменением кода агент создаёт ветку автономно (`git checkout -b feat/...`). Это часть gate "Plan Ready → Execution" в `flows/feature-flow.md`. Работа напрямую в `main` недопустима.

## Pull Requests

- Перед PR: `bundle exec rspec` + `bundle exec rubocop` зелёные
- Title короткий и предметный (< 70 символов)
- Body: что изменено, как проверено, риски/manual steps
- Squash merge в main

## Feature Artifacts в Commits

- Brief, spec, plan включаются в коммиты вместе с кодом
- Перед commit: проверить `git status` на наличие untracked файлов, относящихся к фиче (memory-bank docs, plan, brief) — не пропускать их
- После merge: закрыть GitHub issue + обновить brief (`status: CLOSED`)
  - `gh issue close <N> --comment "Реализовано в #<PR>. <одна фраза>"`
  - Найти brief: `grep -r "#N" memory-bank/features/` (номер директории НЕ обязательно совпадает с issue)
  - Обновить `State:` → `CLOSED`
  - Commit: `docs(feat-NNN): close brief — feature shipped`

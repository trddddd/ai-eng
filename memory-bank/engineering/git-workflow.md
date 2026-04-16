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

## Branches / Worktrees

- Feature: `feat/short-description` (например `feat/starter-deck`)
- Fix: `fix/short-description`
- Удаляются после merge в main.

**Feature-flow rule:** перед первым write-action в стадии Execution агент создаёт отдельный worktree для attempt-а:

```bash
git worktree add -b feat/ft-XXX-att1 ../lingvize-ft-XXX-att1
```

Простая смена ветки через `git checkout -b` не считается attempt isolation.

**Small-task exception:** для коротких документационных или review-only задач можно работать в текущей ветке, если пользователь явно попросил это сделать и задача не запускает feature Execution. Работа напрямую в `main` для feature implementation остаётся недопустимой.

## Pull Requests

- Перед PR: `bundle exec rspec` + `bundle exec rubocop` зелёные
- Title короткий и предметный (< 70 символов)
- Body: что изменено, как проверено, риски/manual steps
- Squash merge в main

## Feature Artifacts в Commits

- Feature package (README.md, feature.md, implementation-plan.md) включается в коммиты вместе с кодом
- Перед commit: проверить `git status` на наличие untracked файлов из `memory-bank/features/FT-XXX/` — не пропускать их
- После merge: закрыть GitHub issue если не закрылся автоматически через `Closes #N`
  - `gh issue close <N> --comment "Реализовано в #<PR>. <одна фраза>"`
  - Brief хранится в GitHub Issue — отдельного `brief.md` нет (удаляется после создания issue, см. `flows/templates/feature/brief.md`)

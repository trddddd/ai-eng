---
title: "FT-XXX: Attempt Template"
doc_kind: governance
doc_function: template
purpose: "Шаблон attempt-tracking для одной попытки реализации фичи. Используется как структура директории attempts/attempt-N/."
derived_from:
  - ../feature-flow.md
status: active
audience: humans_and_agents
template_for: attempt
template_target_path: ../../../features/FT-XXX/attempts/attempt-N/
---

# FT-XXX: Attempt Template

Attempt — первая попытка реализации фичи в изолированном worktree.

## Wrapper Notes

Этот шаблон описывает структуру attempt-директории. Каждый attempt создаётся:
- В отдельном git worktree
- С meta.yaml, start.md, end.md и artifacts/
- Evidence обязателен для accept

## Directory Structure

```
attempts/attempt-N/
├── meta.yaml      # attempt metadata (model, agent, started_at)
├── start.md       # state snapshot перед началом работы
├── end.md         # completion summary с decision
└── artifacts/      # evidence: diff, logs, screenshots
```

## meta.yaml

```yaml
---
attempt_id: attempt-N
agent: builder
model: opus-4.6
branch: feat/ft-xxx-attN
worktree_path: ../lingvize-ft-XXX-attN
base_branch: main
started_at: 2026-04-16T10:00:00Z

previous_attempts: []  # links to previous attempts

context_snapshot:
  feature_status: active
  feature_delivery_status: in_progress
  unresolved_questions: []

orchestration:
  pattern: sequential  # sequential | parallel | delegated
  rationale: "Почему этот паттерн"
  parallel_worktrees: []  # только для parallel: [feat/ft-xxx-att1-ws2, ...]
  delegated_steps: []     # только для delegated: [{step: STEP-04, agent: layers-reviewer}]
  merge_strategy: null    # только для parallel: описание стратегии слияния результатов

human_control_points:
  - id: HC-01
    trigger: "условие"
    status: pending  # pending | approved | skipped

planned_checks:
  - CHK-01
  - CHK-02
```

## start.md

```markdown
---
# Start: attempt-N

## State Snapshot

- Feature: `FT-XXX: Feature Name`
- Stage: Execution
- Previous attempts: none

## Pre-Attempt Checklist

Выполнить до первого write-action. Не начинать код, пока все пункты не отмечены.

- [ ] `feature.md` прочитан, `delivery_status` проверен
- [ ] `implementation-plan.md` прочитан, первый незакрытый `STEP-*` найден
- [ ] Eval suite существует (`eval/suite/happy-path.md`, `edge-cases.md`, `regression.md`)
- [ ] Eval criteria зафиксированы: для каждого `CHK-*` понятно что считается pass
- [ ] Evidence pre-declaration заполнена в `implementation-plan.md` до кода
- [ ] Orchestration pattern выбран и зафиксирован в `meta.yaml`
- [ ] Human Control Map заполнена (или явно `none`)
- [ ] Все `PRE-*` preconditions выполнены
- [ ] Worktree создан и текущий checkout находится внутри `worktree_path`

## What to do this attempt

- [ ] REQ-01: [description]
- [ ] REQ-02: [description]
- [ ] CHK-01: [check]

## Notes

[Любые observation перед началом]
```

## end.md

```markdown
---
# End: attempt-N

## Outcome

- **Decision:** [accept / revise / retry / abandon / split]

## Results

### Completed REQ-*

- [ ] REQ-01: ✅ / ❌
- [ ] REQ-02: ✅ / ❌

### Evidence Summary

| Check ID | Status | Evidence |
|----------|--------|----------|
| CHK-01 | ✅ pass | `artifacts/chk-01/screenshot.png` |
| CHK-02 | ❌ fail | missing |

### Missing Evidence

- CHK-02: нужно добавить скриншот из сессии обучения

### What was learned

[Что пошло не так, что можно улучшить в следующей попытке]

### Next Steps

- [ ] Retry this attempt (collect missing evidence)
- [ ] Move to attempt-N+1 (new worktree)
- [ ] Escalate (if 3 failed attempts)
- [ ] Split scope into downstream feature package(s)
```

## Attempt Acceptance Rules

Attempt может получить `decision: accept` только если:
- все `REQ-*`, выбранные для attempt-а, закрыты и перечислены в `Completed REQ-*`;
- все relevant `CHK-*` из `planned_checks` имеют pass/fail verdict;
- каждый passed `CHK-*` имеет конкретный `EVID-*` carrier;
- manual-only gaps имеют approval ref из `AG-*` / `HC-*`;
- `/eval:run` перед closure feature может использовать этот attempt как проверяемый evidence source.

## artifacts/

Содержит:
- diff.patch — git diff от main
- logs/ — логи выполнения
- screenshots/ — скриншоты для evidence
- db-state/ — state dump для data integrity checks

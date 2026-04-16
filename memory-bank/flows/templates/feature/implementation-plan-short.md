---
title: FT-XXX Feature Template - Implementation Plan (Short)
doc_kind: feature
doc_function: template
purpose: "Лёгкий wrapper-шаблон плана имплементации для коротких фич. Использовать когда change surface ≤ 3 файлов и нет Layered Rails затрагиваемых слоёв."
derived_from:
  - ../../feature-flow.md
  - ../../../dna/frontmatter.md
status: active
audience: humans_and_agents
template_for: feature
template_target_path: ../../../features/FT-XXX/implementation-plan.md
---

# План имплементации (Short)

Лёгкий шаблон для коротких фич. Использовать когда одновременно:
- change surface ≤ 3 файлов
- нет controllers / operations / models в change surface
- нет approval gates, rollout stages или ADR-зависимостей

Если хотя бы одно условие нарушено — используй полный `implementation-plan.md`.

## Instantiated Frontmatter

```yaml
title: "FT-XXX: Implementation Plan"
doc_kind: feature
doc_function: derived
purpose: "Execution-план реализации FT-XXX. Фиксирует discovery context, шаги и verify."
derived_from:
  - feature.md
status: active
audience: humans_and_agents
must_not_define:
  - ft_xxx_scope
  - ft_xxx_architecture
  - ft_xxx_acceptance_criteria
  - ft_xxx_blocker_state
```

## Instantiated Body

```markdown
# План имплементации

## Цель

[Одно предложение: какой delivery outcome.]

## Current State

| Path | Current role | Why relevant |
| --- | --- | --- |
| `path/to/file` | Что делает | Почему меняется |

## Execution Isolation

| Area | Contract |
| --- | --- |
| worktree | Execution идёт в attempt worktree `../lingvize-ft-XXX-att1` на branch `feat/ft-XXX-att1`; `git checkout -b` в основном checkout не считается attempt isolation |

## Layered Rails

[Пометка: N/A — change surface не затрагивает layered code, если применимо.]

## Порядок работ

| Step ID | Implements | Goal | Touchpoints | Verifies | Blocked by |
| --- | --- | --- | --- | --- | --- |
| `STEP-01` | `REQ-01` | Что делаем | Какие файлы | `CHK-01` | `PRE-GIT` |

## Verify

| Command | Why |
| --- | --- |
| `команда` | Что проверяет |

Выбирай verify command по `testing-policy.md` → «Verification by Change Type».
```

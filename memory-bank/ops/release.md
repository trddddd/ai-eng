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

На данный момент формализованного релизного процесса нет. Проект в стадии активной разработки, деплой в production не производится.

## Current Flow

1. Feature branch → PR → review → squash merge в `main`
2. CI (`rails.yml`) проверяет lint + tests автоматически
3. Coverage artifact публикуется в GitHub Actions

## Future

При появлении production deployment этот документ будет дополнен:
- release flow и versioning
- deployment commands
- rollback процедура
- release test plan template

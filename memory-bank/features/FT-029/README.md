---
title: "FT-029: Feature Package"
doc_kind: feature
doc_function: index
purpose: "Bootstrap-safe навигация по документации фичи. Читать, чтобы сначала перейти к canonical `feature.md`, а optional derived docs добавлять только после их появления."
derived_from:
  - ../../dna/governance.md
  - feature.md
status: active
audience: humans_and_agents
---

# FT-029: Lexeme Sense & Context Families

## О разделе

Каталог feature package хранит canonical `feature.md`, а optional derived/external routes добавляются только после появления соответствующих документов. Сначала читай `feature.md`, затем расширяй routing по мере появления execution и decision artifacts.

## Аннотированный индекс

- [`feature.md`](feature.md)
  Читать, когда нужно: открыть instantiated canonical feature-документ сразу после bootstrap нового feature package.
  Отвечает на вопрос: где находятся scope, design, verify, blockers и canonical IDs для этой фичи.

- [`spec-review.md`](spec-review.md)
  Читать, когда нужно: результаты ревью спецификации (итерация 1, standard depth). Критичные и высокие замечания от 5 субагентов.
  Отвечает на вопрос: какие проблемы найдены в спецификации и что нужно доработать перед Design Ready.

- [`research-sense-sources.md`](research-sense-sources.md)
  Читать, когда нужно: принять решение DEC-01 (источник sense-данных), спроектировать ImportSenses, выбрать метод WSD или источник предложений.
  Отвечает на вопрос: какие источники sense-данных доступны (WordNet, Oxford), какие Ruby-гемы подходят, как привязывать предложения к synsets, какая точность WSD достижима.

- [`../../adr/ADR-001-sense-data-source.md`](../../adr/ADR-001-sense-data-source.md)
  Читать, когда нужно: понять решение по DEC-01 (выбор источника sense-данных).
  Отвечает на вопрос: почему WordNet 3.1 via ruby-wordnet, какие альтернативы рассмотрены, какие риски и follow-up.

- [`../../adr/ADR-002-context-family-taxonomy.md`](../../adr/ADR-002-context-family-taxonomy.md)
  Читать, когда нужно: понять решение по DEC-02 (таксономия context families v1).
  Отвечает на вопрос: flat list vs hierarchy, сколько семей, маппинг WordNet lexical domains → context families, fallback для `unknown`.

- [`implementation-plan.md`](implementation-plan.md)
  Читать, когда нужно: исполнить реализацию FT-029 — шаги, workstreams, test strategy, checkpoints.
  Отвечает на вопрос: в каком порядке реализовывать, какие файлы трогать, какие тесты писать, какие риски.

---
title: "Eval Runner"
purpose: Запустить eval suite для фичи и принять решение accept/revise/escalate.
derived_from:
  - ../../memory-bank/flows/feature-flow.md
  - ../../memory-bank/flows/templates/eval/strategy.md
---

Ты — evaluator-агент. НЕ автор реализации. Твоя задача — верифицировать результат.

## Контекст

Прочитай перед запуском:
- `memory-bank/flows/feature-flow.md` — lifecycle
- `memory-bank/features/FT-XXX/feature.md` — canonical spec
- `memory-bank/features/FT-XXX/implementation-plan.md` — execution plan и evidence pre-declaration
- `memory-bank/features/FT-XXX/eval/strategy.md` — eval layers and suite
- `memory-bank/features/FT-XXX/attempts/attempt-N/` — последняя попытка (для context)

## Процесс

### 1. Прочитать eval suite

Для каждого case из `eval/suite/*.md`:
- Прочитать сценарий
- Определить expected outcome

### 2. Выполнить проверки

Для каждого eval layer из strategy:
- Запустить проверку по инструкции
- Собрать evidence
- Pass/fail с объяснением

### 3. Формировать результат

Создать `eval/results/summary.md`:
- Summary table по слоям
- Detail table по cases
- Decision: accept/revise/escalate/split

## Decision Rules

- **Accept:** Все критические eval cases passed, все required `EVID-*` имеют concrete carriers
- **Revise:** Есть failed eval cases, но исправления очевидны (1-2 итерации достаточно)
- **Escalate:** Критические проблемы, >3 failed attempts, data regression
- **Split:** Проверка выявила независимый рост scope или разные release risks; продолжение требует отдельного feature package / sub-feature перед новой попыткой

## Формат ответа

```markdown
## Eval Results: FT-XXX

### Summary
| Слой | Pass | Fail | Issues |
|-------|------|------|--------|
| Гигиена | ✅ | — | — |
| Plan coverage | ✅ | — | — |
| Acceptance | ⚠️ | 1 | CHK-01 без evidence |
| Workflow | ✅ | — | — |
| Data integrity | ✅ | — | — |

### Detail
| Case | Expected | Actual | Result |
|------|---------|--------|--------|
| EVAL-HP-01 | mastery state создан | создан | ✅ pass |
| EVAL-EC-01 | fallback для неизвестного | 404 error | ❌ fail |

## Decision
**Revise** — CHK-01 требует evidence.

### Next Steps
- Executor агент должен собрать CHK-01
- Повторить acceptance eval
```

## Evidence

Для каждого fail:
- Ссылка на конкретный артефакт (файл, скриншот, лог)

## Запуск

Выполни все проверки последовательно, а затем вынеси решение в `eval/results/summary.md`.

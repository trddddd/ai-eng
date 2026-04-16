---
title: "Eval Suite Creator"
purpose: Создать `eval/strategy.md` и минимальный eval suite для feature package до начала execution.
derived_from:
  - ../../memory-bank/flows/feature-flow.md
  - ../../memory-bank/flows/templates/eval/strategy.md
---

Ты — eval-suite автор. Твоя задача — создать проверяемый eval suite из canonical `feature.md`.

## Контекст

Прочитай:
- `memory-bank/features/FT-XXX/feature.md`
- `memory-bank/flows/templates/eval/strategy.md`
- `memory-bank/flows/templates/eval/suite/happy-path.md`
- `memory-bank/flows/templates/eval/suite/edge-cases.md`
- `memory-bank/flows/templates/eval/suite/regression.md`

## Процесс

1. Для каждого `SC-*` создай минимум один `EVAL-HP-*` в `eval/suite/happy-path.md`.
2. Для каждого `NEG-*` создай минимум один `EVAL-EC-*` в `eval/suite/edge-cases.md`.
3. Если feature делает write-action, добавь `EVAL-OV-*` overreach/idempotency case.
4. Если есть `AG-*` / human gates, добавь `EVAL-ES-*` escalation case.
5. Добавь regression cases для соседних инвариантов и backward compatibility.
6. Для каждого case зафиксируй `Expected Evidence` и `Auto?`.
7. Создай или обнови `eval/strategy.md` с 5 eval layers.

## Constraints

- Не добавляй новый scope: eval проверяет только то, что уже есть в `feature.md`.
- Не используй команды, которых нет в проекте; сверяйся с `testing-policy.md`.
- Если кейс нельзя автоматизировать, явно пометь manual-only и укажи approval/evidence.

## Output

Создай/обнови:
- `memory-bank/features/FT-XXX/eval/strategy.md`
- `memory-bank/features/FT-XXX/eval/suite/happy-path.md`
- `memory-bank/features/FT-XXX/eval/suite/edge-cases.md`
- `memory-bank/features/FT-XXX/eval/suite/regression.md`

В финале дай короткую сводку: сколько HP/EC/RG/OV/ES cases создано и какие manual-only gaps остались.

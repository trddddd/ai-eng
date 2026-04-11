---
title: Tech Debt Registry
doc_kind: engineering
doc_function: canonical
purpose: "Реестр известного техдолга. Каждая запись фиксирует проблему, контекст возникновения, условие активации и предлагаемое решение."
derived_from:
  - ../../CLAUDE.md
status: active
audience: humans_and_agents
---

# Tech Debt Registry

## Правила ведения

1. Новая запись добавляется, когда решение осознанно принимается как "достаточно для текущего масштаба", но имеет известный предел.
2. Каждая запись содержит: откуда возникло, почему допустимо сейчас, когда станет проблемой и что делать.
3. При закрытии — пометить статус `resolved` и ссылку на PR/commit.

## Registry

| ID | Title | Origin | Status | Trigger to fix |
| --- | --- | --- | --- | --- |
| `TD-001` | [ReviewLog без user_id — JOIN через cards](#td-001) | FT-025 | open | >10k review_logs на пользователя или dashboard latency >200ms |

---

### TD-001

**ReviewLog без прямого user_id — запросы через JOIN на cards**

**Контекст:** `review_logs` не имеет колонки `user_id`. Для получения логов пользователя нужен JOIN: `ReviewLog.joins(:card).where(cards: { user_id: })`. Решение принято в FT-025 (`CON-01`, `OQ-01`).

**Почему допустимо сейчас:** объём данных мал (сотни записей на пользователя), JOIN на индексированных колонках (`review_logs.card_id`, `cards.user_id`) работает за O(log n). Dashboard — единственный consumer, нагрузка минимальна.

**Когда станет проблемой:**
- >10k review_logs на пользователя
- Несколько потребителей user-scoped review_logs (аналитика, экспорт, API)
- Dashboard latency >200ms

**Решение:**
1. Миграция: добавить `user_id` в `review_logs` с foreign key и index
2. Backfill: `UPDATE review_logs SET user_id = cards.user_id FROM cards WHERE review_logs.card_id = cards.id`
3. Обновить модель: `belongs_to :user` + валидация
4. Обновить `Reviews::RecordAnswer` — проставлять `user_id` при создании
5. Обновить запросы в `Dashboard::BuildProgress` — убрать JOIN

**Альтернатива:** materialized view или кэш на уровне операции (может быть достаточно без денормализации).

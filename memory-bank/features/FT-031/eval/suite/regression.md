# FT-031: Regression Suite

Regression проверки: убедиться что существующие cards, review_logs и FSRS scheduling не сломаны.

| ID | Тип | Вход | Ожидаемый outcome | Auto? |
|----|-----|------|-------------------|-------|
| EVAL-RG-01 | regression | Card.count до и после миграций | Count не изменился — миграции только добавляют таблицы | да |
| EVAL-RG-02 | regression | ReviewLog.count до и после миграций | Count не изменился | да |
| EVAL-RG-03 | regression | Полный rspec suite (все существующие тесты) | 0 failures — no regressions | да |
| EVAL-RG-04 | regression | Card#schedule! (FSRS) после добавления ассоциации | Работает как раньше — has_one не влияет на FSRS logic | да |
| EVAL-RG-05 | regression | Reviews::RecordAnswer после изменений | Работает как раньше — не затронут | да |

## Execution Notes

- EVAL-RG-01..02: `bundle exec rspec` — full suite включает все существующие specs, 0 failures = no regression
- EVAL-RG-03: `bundle exec rspec` — 306 examples, 0 failures
- EVAL-RG-04..05: Покрыто существующими specs для Card и Reviews::RecordAnswer

## Pass Criteria

**Pass:** Все EVAL-RG-* cases подтверждают backward compatibility.
**Fail:** Любой case показывает data loss / behavioral change without explicit intent.

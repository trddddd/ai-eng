# Spec: CI fix — удалить чужой CI, починить Rails CI

**Brief:** [memory-bank/fixes/002/brief.md](brief.md)
**Issue:** trddddd/ai-eng#—

---

## Цель

Привести CI в зелёное состояние: удалить `ci.yml` (чужая кодовая база, пришедшая из форка), оставить только `rails.yml` и добавить в него артефакт покрытия.

---

## Контекст

`ci.yml` — CI для AI-toolchain из `.ai-setup/` (форк чужого репо). Он проверяет shell-скрипты, markdown и запускает smoke-тесты на установку AI-агентов. Это не наша кодовая база, мы не контролируем `mise.toml`-зависимости, скрипты и markdown-файлы из `.ai-setup/`. Починить его в рамках нашего проекта невозможно и бессмысленно.

`rails.yml` — наш CI: RuboCop + RSpec. Его мы контролируем полностью.

---

## Scope

**Входит:**
- Удаление `.github/workflows/ci.yml`
- Добавление шага `upload-artifact` в `rails.yml` для экспорта `coverage/`

**НЕ входит:**
- Любые изменения в `.ai-setup/`
- Изменение логики тестов или RuboCop-конфига
- Рост процента покрытия — порог уже задан (`minimum_coverage 80` в `spec_helper.rb`)
- Интеграция с Codecov / Coveralls

---

## Диагностика

### `ci.yml` — удалить

Джобы `Lint`, `Smoke (ubuntu-latest)`, `Smoke (macos-latest)` принадлежат AI-toolchain CI из форка. Зависимости (zellij, markdownlint-правила, скрипты) вне нашего контроля. Решение — удалить файл.

### `rails.yml` — coverage artifact

`spec/spec_helper.rb` уже содержит:
```ruby
SimpleCov.start "rails" do
  minimum_coverage 80
  ...
end
```

Порог машинно-читаем — SimpleCov завершает `rspec` с exit 1, если покрытие < 80%. `rails.yml` не публикует `coverage/` как артефакт.

**Фикс:** добавить шаг `upload-artifact` после `Run tests`.

---

## Изменение: `rails.yml`

После шага `Run tests`:

```yaml
- name: Upload coverage report
  uses: actions/upload-artifact@v4
  if: always()
  with:
    name: coverage-report
    path: coverage/
    retention-days: 7
```

`if: always()` — артефакт публикуется даже при падении тестов.

---

## Инварианты

1. `spec_helper.rb` не меняется
2. `rails.yml` lint-джоб (RuboCop) не меняется
3. Тесты в `spec/` не трогаются
4. `.ai-setup/` не трогается

---

## Сценарии ошибок

| Сценарий | Поведение |
|---|---|
| Покрытие ниже 80% | SimpleCov завершает rspec exit 1; `upload-artifact` с `if: always()` публикует coverage/ для анализа |

---

## Acceptance Criteria

- [ ] `.github/workflows/ci.yml` удалён
- [ ] `rails.yml` содержит шаг `Upload coverage report` после `Run tests`
- [ ] Rails CI lint-джоб (`rails.yml`) — зелёный
- [ ] Rails CI test-джоб (`rails.yml`) — зелёный и публикует артефакт `coverage-report`

---

## Ограничения реализации

- Только два действия: удалить `ci.yml`, добавить шаг в `rails.yml`
- Версия `actions/upload-artifact` — `v4`

---

_Spec v1.2 | 2026-04-10_

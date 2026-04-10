# Spec: Cold Start via DB Dump

**Brief:** `memory-bank/features/005/brief.md`
**Issue:** `trddddd/ai-eng#8`
**Branch:** `feat/cold-start-db-dump`

## Цель

Сократить время `bin/setup` на чистом окружении с ~30 минут до ≤5 минут за счёт восстановления БД из готового дампа вместо полного прогона миграций и сидов.

## Scope

**Входит:**
- Rake task `db:dump:create` — создаёт дамп текущей development БД
- Rake task `db:dump:restore` — восстанавливает БД из дампа
- Изменение `bin/setup`: если дамп есть — использует его, иначе прогоняет полный `db:prepare` и создаёт дамп автоматически
- `db/dump/` добавляется в `.gitignore`

**НЕ входит:**
- Автоматическое обновление дампа при новых миграциях
- CI-артефакты, S3, распределённое хранение дампа
- Продакшн-деплой и резервное копирование
- Изменения в `config/database.yml`, docker-compose.yml

---

## Поведение `bin/setup`

### До изменения (текущее)
```
db:prepare → db:schema:load + db:seed   # ~30 мин на пустой БД
```

### После изменения

`bin/setup` проверяет наличие файла `db/dump/development.dump`:

**Файл найден:**
1. `db:dump:restore` — восстановление из дампа через `pg_restore`
2. `db:migrate` — накатить миграции новее дампа (если есть)

**Файл не найден (первый запуск):**
1. Предупреждение: `No dump found — running full setup (~30 min)...`
2. `db:prepare` — схема + сиды (полный прогон)
3. `db:dump:create` — сохраняет дамп автоматически
4. Сообщение: `Dump saved to db/dump/development.dump. Next run will be fast.`

Флаг `--reset` (существующее поведение) не изменяется.

---

## Rake Tasks

### `db:dump:create`

Файл: дополнение к `lib/tasks/` (новый файл `db_dump.rake`)

Поведение:
- Создаёт директорию `db/dump/` если не существует
- Выполняет `pg_dump` через `docker compose exec -T postgres`
- Формат: custom (`-Fc`) — бинарный, поддерживает `pg_restore --clean --if-exists`
- Выводит в stdout: `Dump created: db/dump/development.dump (X MB)`
- Завершается с exit code ≠ 0 если `pg_dump` упал

Команда, которую выполняет task:
```
docker compose exec -T postgres \
  pg_dump -U lingvize -Fc lingvize_development \
  > db/dump/development.dump
```

### `db:dump:restore`

Поведение:
- Проверяет наличие `db/dump/development.dump`; если нет — `abort "Dump not found: db/dump/development.dump"`
- Выполняет `pg_restore` через `docker compose exec -T postgres` с флагами `--clean --if-exists`
- Выводит в stdout: `Restored from db/dump/development.dump`
- Завершается с exit code ≠ 0 если `pg_restore` упал

Команда, которую выполняет task:
```
docker compose exec -T postgres \
  pg_restore -U lingvize -d lingvize_development --clean --if-exists \
  < db/dump/development.dump
```

---

## Изменения в `bin/setup`

Заменить блок:
```ruby
puts "\n== Preparing database =="
system! "bin/rails db:prepare"
system! "bin/rails db:reset" if ARGV.include?("--reset")
```

На:
```ruby
puts "\n== Preparing database =="
if ARGV.include?("--reset")
  system! "bin/rails db:reset"
elsif File.exist?(File.join(APP_ROOT, "db/dump/development.dump"))
  system! "bin/rails db:dump:restore"
  system! "bin/rails db:migrate"
else
  puts "No dump found — running full setup (~30 min)..."
  system! "bin/rails db:prepare"
  system! "bin/rails db:dump:create"
  puts "Dump saved to db/dump/development.dump. Next run will be fast."
end
```

---

## Поведение по ситуациям

| Ситуация | Что происходит |
|----------|----------------|
| Первый запуск, дампа нет | Полный setup (~30 мин) → автоматически создаёт дамп |
| Последующие запуски | Быстрое восстановление из дампа + `db:migrate` (≤5 мин) |
| `--reset` | Старое поведение (`db:reset`), дамп не затрагивается |

---

## Инварианты

- `db/dump/development.dump` никогда не попадает в git
- `db:dump:restore` всегда сопровождается `db:migrate` — для случая когда дамп старее текущих миграций
- `pg_dump` / `pg_restore` вызываются через `docker compose exec -T` (не через прямое подключение к хосту), так как PostgreSQL доступен только через Docker

---

## Сценарии ошибок

| Ситуация | Поведение |
|----------|-----------|
| `db/dump/development.dump` не найден при `bin/setup` | Полный `db:prepare` + автосоздание дампа по завершении |
| `pg_dump` упал (нет запущенного docker compose) | `system!` бросает исключение с сообщением об ошибке, exit code ≠ 0 |
| `pg_restore` упал (повреждённый дамп) | `system!` бросает исключение, setup прерывается |
| Дамп старее текущей схемы | `db:migrate` после restore накатит недостающие миграции |
| `db:dump:create` упал после успешного `db:prepare` (fallback-путь) | `warn "Warning: dump creation failed, next setup will run full seed again"` — setup завершается с кодом 0, дамп не создан |

---

## Acceptance Criteria

- [ ] `bin/rails db:dump:create` создаёт файл `db/dump/development.dump` в формате pg_dump custom
- [ ] `bin/rails db:dump:restore` восстанавливает БД из дампа; после восстановления `Lexeme.count > 0` и `Sentence.count > 0`
- [ ] `bin/setup --skip-server` при наличии дампа завершается за ≤5 минут _(проверяется вручную: `time bin/setup --skip-server` на чистой БД)_
- [ ] `bin/setup --skip-server` при отсутствии дампа завершается успешно: выводит `No dump found — running full setup (~30 min)...`, прогоняет полный `db:prepare`, создаёт `db/dump/development.dump`, выводит `Dump saved`
- [ ] После `bin/setup --skip-server` с дампом `bin/rails db:migrate:status` не показывает `down`-миграций
- [ ] `db/dump/` присутствует в `.gitignore`
- [ ] `bin/setup --reset` работает как прежде (вызывает `db:reset`)
- [ ] `bundle exec rubocop` проходит без новых нарушений

---

## Ограничения на реализацию

- Не добавлять новые гемы
- Не изменять `docker-compose.yml` и `config/database.yml`
- Не менять существующий путь `--reset` в `bin/setup`
- Вызовы `docker compose exec -T` — не прямое подключение к порту 5433 с хоста

---

## Test Plan

Тесты пишутся по правилам проекта (RSpec). HTTP и shell-вызовы — через `allow(...).to receive(...)`, реальные `docker compose`-команды не выполняются.

**Файл:** `spec/tasks/db_dump_rake_spec.rb`

### `db:dump:create`

- Создаёт директорию `db/dump/` если не существует
- Создаёт файл `db/dump/development.dump` после успешного вызова
- Выводит в stdout строку, соответствующую `/Dump created: db\/dump\/development\.dump/`
- Если `system` возвращает false (имитация падения `pg_dump`) — задача завершается с ненулевым кодом

### `db:dump:restore`

- Вызывает `pg_restore` с флагами `--clean --if-exists`
- Выводит в stdout `Restored from db/dump/development.dump`
- Если файл `db/dump/development.dump` отсутствует — вызывает `abort` с сообщением, содержащим `Dump not found`
- Если `system` возвращает false (имитация падения `pg_restore`) — задача завершается с ненулевым кодом

### `bin/setup` (интеграционный, проверяется вручную)

- При наличии дампа: stdout содержит `Restored from` и не содержит `running full setup`
- При отсутствии дампа: stdout содержит `No dump found — running full setup` и `Dump saved`

---

_Spec v1.1 | 2026-04-05_

# Plan: Cold Start via DB Dump

**Spec:** `memory-bank/features/005/spec.md`
**Issue:** `trddddd/ai-eng#8`
**Branch:** `feat/cold-start-db-dump`

---

## Grounding

| Что проверялось | Результат |
|-----------------|-----------|
| `lib/tasks/content_bootstrap.rake` | Существует. Паттерн: `namespace :x { task y: :environment { SomeClass.call } }` |
| `spec/tasks/` | **Не существует.** Новый тип тестов для проекта — создаём директорию |
| `spec/operations/content_bootstrap/import_oxford_lexemes_spec.rb` | Паттерн тестирования: `stub_const`, стабы через `allow(...).to receive(...)`, реальных shell-вызовов нет |
| `.gitignore` | `db/dump/` отсутствует — нужно добавить |
| `bin/setup` | Строки 30–32: `db:prepare` + `db:reset` — точка изменения известна |
| `spec/support/` | Не существует — в рамках этой задачи не создаём |

**Конфликтов с существующим кодом нет. План осуществим.**

---

## Паттерн оркестрации

**Один агент, последовательно.** Шагов мало, зависимости линейные, параллелизм не даст выигрыша.

---

## Шаги

### Шаг 1 — `.gitignore`

**Файл:** `.gitignore`

Добавить в конец файла:

```
/db/dump/
```

Никаких зависимостей. Делается первым.

---

### Шаг 2 — Rake tasks

**Файл:** `lib/tasks/db_dump.rake` _(новый)_

```ruby
namespace :db do
  namespace :dump do
    desc "Create a pg_dump of the development database"
    task create: :environment do
      dump_path = Rails.root.join("db/dump/development.dump")
      FileUtils.mkdir_p(dump_path.dirname)

      success = system(
        "docker compose exec -T postgres " \
        "pg_dump -U lingvize -Fc lingvize_development",
        out: dump_path.to_s
      )

      abort "pg_dump failed" unless success

      size_mb = (dump_path.size / 1_048_576.0).round(1)
      puts "Dump created: #{dump_path} (#{size_mb} MB)"
    end

    desc "Restore the development database from a pg_dump"
    task restore: :environment do
      dump_path = Rails.root.join("db/dump/development.dump")
      abort "Dump not found: #{dump_path}" unless dump_path.exist?

      success = system(
        "docker compose exec -T postgres " \
        "pg_restore -U lingvize -d lingvize_development --clean --if-exists",
        in: dump_path.to_s
      )

      abort "pg_restore failed" unless success

      puts "Restored from #{dump_path}"
    end
  end
end
```

**Зависит от:** шага 1 (логически независим, но `.gitignore` должен быть готов до первого создания дампа).

---

### Шаг 3 — Тесты

**Файл:** `spec/tasks/db_dump_rake_spec.rb` _(новый, новая директория)_

Тесты используют стабы `system` — реальные `docker compose`-вызовы не делаются.

```ruby
require "rails_helper"
require "rake"

RSpec.describe "db:dump rake tasks" do
  before(:all) do
    Rails.application.load_tasks
  end

  before do
    Rake::Task["db:dump:create"].reenable
    Rake::Task["db:dump:restore"].reenable
  end

  describe "db:dump:create" do
    context "when pg_dump succeeds" do
      before do
        allow(FileUtils).to receive(:mkdir_p)
        allow_any_instance_of(Object).to receive(:system).and_return(true)
        allow_any_instance_of(Pathname).to receive(:exist?).and_return(true)
        allow_any_instance_of(Pathname).to receive(:size).and_return(10 * 1_048_576)
      end

      it "prints the dump path and size" do
        expect { Rake::Task["db:dump:create"].invoke }
          .to output(/Dump created:.*development\.dump/).to_stdout
      end
    end

    context "when pg_dump fails" do
      before do
        allow(FileUtils).to receive(:mkdir_p)
        allow_any_instance_of(Object).to receive(:system).and_return(false)
      end

      it "aborts with an error message" do
        expect { Rake::Task["db:dump:create"].invoke }
          .to raise_error(SystemExit)
      end
    end
  end

  describe "db:dump:restore" do
    context "when dump file exists and pg_restore succeeds" do
      before do
        allow_any_instance_of(Pathname).to receive(:exist?).and_return(true)
        allow_any_instance_of(Object).to receive(:system).and_return(true)
      end

      it "prints restored message" do
        expect { Rake::Task["db:dump:restore"].invoke }
          .to output(/Restored from.*development\.dump/).to_stdout
      end
    end

    context "when dump file does not exist" do
      before do
        allow_any_instance_of(Pathname).to receive(:exist?).and_return(false)
      end

      it "aborts with dump not found message" do
        expect { Rake::Task["db:dump:restore"].invoke }
          .to raise_error(SystemExit)
      end
    end

    context "when pg_restore fails" do
      before do
        allow_any_instance_of(Pathname).to receive(:exist?).and_return(true)
        allow_any_instance_of(Object).to receive(:system).and_return(false)
      end

      it "aborts" do
        expect { Rake::Task["db:dump:restore"].invoke }
          .to raise_error(SystemExit)
      end
    end
  end
end
```

**Зависит от:** шага 2.

---

### Шаг 4 — `bin/setup`

**Файл:** `bin/setup`

Заменить блок (строки 30–32):

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
  begin
    system! "bin/rails db:dump:create"
    puts "Dump saved to db/dump/development.dump. Next run will be fast."
  rescue RuntimeError => e
    warn "Warning: dump creation failed, next setup will run full seed again (#{e.message})"
  end
end
```

**Зависит от:** шага 2 (tasks должны существовать).

---

### Шаг 5 — Rubocop + проверка

```
bundle exec rubocop lib/tasks/db_dump.rake spec/tasks/db_dump_rake_spec.rb bin/setup
```

Исправить все нарушения до нуля.

**Зависит от:** шагов 2–4.

---

## Граф зависимостей

```
[1 .gitignore] ──┐
                 ├──► [2 rake tasks] ──► [3 specs] ──┐
                                    └──► [4 bin/setup]├──► [5 rubocop]
```

---

## Acceptance Criteria (чеклист для агента)

После каждого шага — запустить соответствующую проверку:

- [ ] Шаг 1: `git diff .gitignore` содержит `/db/dump/`
- [ ] Шаг 2: `bin/rails -T db:dump` выводит обе задачи с описанием
- [ ] Шаг 3: `bundle exec rspec spec/tasks/db_dump_rake_spec.rb` — все зелёные
- [ ] Шаг 4: `grep -n "db:dump:restore" bin/setup` — строка присутствует
- [ ] Шаг 5: `bundle exec rubocop` — 0 нарушений
- [ ] Финал (вручную): `time bin/setup --skip-server` с дампом ≤5 мин

---

_Plan v1.1 | 2026-04-05_
